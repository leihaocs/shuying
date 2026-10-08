package com.shuying.app.shuying

import android.app.Activity
import android.util.Base64
import com.android.billingclient.api.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec

class StorePurchases(private val activity: Activity, messenger: BinaryMessenger) : PurchasesUpdatedListener {
    private val channel = MethodChannel(messenger, "com.bookmovie.revisit/purchases")
    private val productId = "com.bookmovie.revisit.app.pro.lifetime"
    private var buying: MethodChannel.Result? = null
    private val client = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    init {
        channel.setMethodCallHandler { call, result ->
            if (BuildConfig.PLAY_LICENSE_KEY.isEmpty()) {
                if (call.method == "product") result.success(null)
                else result.error("unconfigured", "此渠道购买尚未配置", null)
            } else connect(result) {
                when (call.method) {
                    "product" -> product(result) { details ->
                        result.success(if (details == null) null else mapOf(
                            "id" to details.productId,
                            "price" to details.oneTimePurchaseOfferDetailsList?.firstOrNull()?.formattedPrice))
                    }
                    "status", "restore" -> status(result)
                    "buy" -> {
                        if (buying != null) { result.error("busy", "购买尚未完成", null) }
                        else product(result) { details ->
                            if (details == null) { result.error("product", "商品暂不可用", null) }
                            else {
                                buying = result
                                val item = BillingFlowParams.ProductDetailsParams.newBuilder()
                                    .setProductDetails(details)
                                    .setOfferToken(details.oneTimePurchaseOfferDetailsList?.firstOrNull()?.offerToken ?: "").build()
                                val response = client.launchBillingFlow(activity,
                                    BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(item)).build())
                                if (response.responseCode != BillingClient.BillingResponseCode.OK) {
                                    buying = null; fail(result, response)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun connect(result: MethodChannel.Result, block: () -> Unit) {
        if (client.isReady) { block(); return }
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(response: BillingResult) {
                if (response.responseCode == BillingClient.BillingResponseCode.OK) block()
                else fail(result, response)
            }
            override fun onBillingServiceDisconnected() { }
        })
    }

    private fun product(result: MethodChannel.Result, block: (ProductDetails?) -> Unit) {
        val item = QueryProductDetailsParams.Product.newBuilder()
            .setProductId(productId).setProductType(BillingClient.ProductType.INAPP).build()
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder()
            .setProductList(listOf(item)).build()) { response, products ->
            if (response.responseCode == BillingClient.BillingResponseCode.OK)
                block(products.productDetailsList.firstOrNull())
            else fail(result, response)
        }
    }

    private fun verified(purchase: Purchase): Boolean = try {
        val key = KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(
            Base64.decode(BuildConfig.PLAY_LICENSE_KEY, Base64.DEFAULT)))
        val signature = Signature.getInstance("SHA1withRSA")
        signature.initVerify(key)
        signature.update(purchase.originalJson.toByteArray(Charsets.UTF_8))
        signature.verify(Base64.decode(purchase.signature, Base64.DEFAULT)) &&
            JSONObject(purchase.originalJson).getString("packageName") == activity.packageName &&
            purchase.products.contains(productId) &&
            purchase.purchaseState == Purchase.PurchaseState.PURCHASED
    } catch (_: Exception) { false }

    private fun acknowledge(purchase: Purchase, result: MethodChannel.Result, done: () -> Unit) {
        if (purchase.isAcknowledged) { done(); return }
        client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken).build()) { response ->
            if (response.responseCode == BillingClient.BillingResponseCode.OK) done()
            else fail(result, response)
        }
    }

    private fun status(result: MethodChannel.Result) {
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP).build()) { response, purchases ->
            if (response.responseCode != BillingClient.BillingResponseCode.OK) { fail(result, response) }
            else {
                val purchase = purchases.firstOrNull { verified(it) }
                if (purchase == null) result.success(false)
                else acknowledge(purchase, result) { result.success(true) }
            }
        }
    }

    override fun onPurchasesUpdated(response: BillingResult, purchases: MutableList<Purchase>?) {
        val result = buying
        buying = null
        when (response.responseCode) {
            BillingClient.BillingResponseCode.USER_CANCELED -> result?.success("cancelled")
            BillingClient.BillingResponseCode.OK -> {
                val purchase = purchases?.firstOrNull { verified(it) }
                if (purchase != null) {
                    // 后台补交付也要确认交易；确认失败时下次状态查询重试。
                    val target = result ?: object : MethodChannel.Result {
                        override fun success(value: Any?) { }
                        override fun error(code: String, message: String?, details: Any?) { }
                        override fun notImplemented() { }
                    }
                    acknowledge(purchase, target) {
                        channel.invokeMethod("changed", true)
                        result?.success("purchased")
                    }
                } else if (purchases?.any { it.purchaseState == Purchase.PurchaseState.PENDING } == true) {
                    result?.success("pending")
                } else result?.error("verification", "购买验证未通过", null)
            }
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                if (result != null) status(object : MethodChannel.Result {
                    override fun success(value: Any?) { channel.invokeMethod("changed", value); result.success("restored") }
                    override fun error(code: String, message: String?, details: Any?) { result.error(code, message, details) }
                    override fun notImplemented() { result.notImplemented() }
                })
            }
            else -> if (result != null) fail(result, response)
        }
    }

    private fun fail(result: MethodChannel.Result, response: BillingResult) {
        result.error("billing", "购买服务暂不可用，请重试（${response.responseCode}）", null)
    }
}
