package com.shuying.app.shuying

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Base64
import com.android.billingclient.api.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import java.util.concurrent.Executors

class StorePurchases(private val activity: Activity, messenger: BinaryMessenger) : PurchasesUpdatedListener {
    private val session = ++activeSession
    private val channel = MethodChannel(messenger, "com.bookmovie.revisit/purchases")
    private val productId = "com.bookmovie.revisit.app.pro.lifetime"
    private val handler = Handler(Looper.getMainLooper())
    private val requests = mutableSetOf<Request>()
    private var buying: Request? = null
    private val cache by lazy { SignedPurchaseCache(activity.applicationContext, productId) }
    private var cacheAllowed = true
    private var entitlementRevision = 0L
    private val client = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    init {
        channel.setMethodCallHandler { call, reply ->
            val timeout = when (call.method) {
                "buy" -> 120_000L
                "status" -> 12_000L // 留出 2 秒读缓存，早于 Dart 的 15 秒等待期限。
                else -> 15_000L
            }
            val result = Request(reply, timeout, call.method == "status")
            if (BuildConfig.PLAY_LICENSE_KEY.isEmpty()) {
                when (call.method) {
                    "product" -> result.success(mapOf("purchasesEnabled" to false))
                    "status" -> result.success(false)
                    else -> result.error("unconfigured", "此渠道购买尚未配置", null)
                }
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

    // Dart 的等待超时不会取消商店交易；只清理旧的通道回复，迟到的已验证
    // 购买仍由 onPurchasesUpdated 正常确认并通过 changed 交付权益。
    private inner class Request(private val reply: MethodChannel.Result, timeout: Long,
        var cachedStatusAllowed: Boolean) : MethodChannel.Result {
        var completed = false
            private set
        private var cacheStarted = false
        private val expiry = Runnable { unavailable("timeout", "商店结果尚未确认，请稍后刷新或恢复购买", null) }
        private val cacheExpiry = Runnable { error("timeout", "离线权益未能确认，请联网后重试", null) }
        init { requests.add(this); handler.postDelayed(expiry, timeout) }
        private fun finish(block: () -> Unit) {
            if (completed) return
            completed = true
            handler.removeCallbacks(expiry)
            handler.removeCallbacks(cacheExpiry)
            requests.remove(this)
            if (buying === this) buying = null
            block()
        }
        override fun success(value: Any?) = finish { reply.success(value) }
        override fun error(code: String, message: String?, details: Any?) = finish { reply.error(code, message, details) }
        override fun notImplemented() = finish { reply.notImplemented() }

        fun unavailable(code: String, message: String, details: Any?) {
            if (completed || cacheStarted) return
            if (session != activeSession || !cachedStatusAllowed || !cacheAllowed) {
                error(code, message, details); return
            }
            cacheStarted = true
            handler.removeCallbacks(expiry)
            handler.postDelayed(cacheExpiry, 2_000L)
            val revision = entitlementRevision
            cacheWorker.execute {
                val purchase = try { cache.read() } catch (_: Exception) { null }
                val valid = purchase != null && verified(purchase)
                if (!valid) try { cache.clear() } catch (_: Exception) { }
                handler.post {
                    if (session == activeSession && cachedStatusAllowed && cacheAllowed &&
                        revision == entitlementRevision && valid)
                        success(true)
                    else error(code, message, details)
                }
            }
        }
    }

    private fun connect(result: Request, block: () -> Unit) {
        if (client.isReady) { block(); return }
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(response: BillingResult) {
                if (result.completed) return
                if (response.responseCode == BillingClient.BillingResponseCode.OK) block()
                else fail(result, response)
            }
            override fun onBillingServiceDisconnected() {
                requests.toList().forEach {
                    it.unavailable("disconnected", "商店连接中断，请刷新状态或恢复购买", null)
                }
            }
        })
    }

    private fun product(result: Request, block: (ProductDetails?) -> Unit) {
        val item = QueryProductDetailsParams.Product.newBuilder()
            .setProductId(productId).setProductType(BillingClient.ProductType.INAPP).build()
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder()
            .setProductList(listOf(item)).build()) { response, products ->
            if (result.completed) return@queryProductDetailsAsync
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
        val revision = entitlementRevision
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP).build()) { response, purchases ->
            if (session != activeSession || revision != entitlementRevision) {
                if (result is Request) result.cachedStatusAllowed = false
                result.error("superseded", "商店状态已更新，请重新查询", null)
                return@queryPurchasesAsync
            }
            if (response.responseCode != BillingClient.BillingResponseCode.OK) { fail(result, response) }
            else {
                // 已得到商店答案后，确认交易的失败不能退回旧缓存。
                if (result is Request) result.cachedStatusAllowed = false
                val purchase = purchases.firstOrNull { verified(it) }
                if (purchase == null) {
                    entitlementRevision++
                    cacheAllowed = false
                    cacheWorker.execute { try { cache.clear() } catch (_: Exception) { } }
                    channel.invokeMethod("changed", false)
                    result.success(false)
                } else deliver(purchase, result) {
                    result.success(true)
                }
            }
        }
    }

    override fun onPurchasesUpdated(response: BillingResult, purchases: MutableList<Purchase>?) {
        if (session != activeSession) return
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
                    deliver(purchase, target) {
                        result?.success("purchased")
                    }
                } else if (purchases?.any { it.purchaseState == Purchase.PurchaseState.PENDING } == true) {
                    result?.success("pending")
                } else result?.error("verification", "购买验证未通过", null)
            }
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                if (result != null) status(object : MethodChannel.Result {
                    override fun success(value: Any?) {
                        if (value == true) result.success("restored")
                        else result.error("not_owned", "当前商店账号没有已确认的购买", null)
                    }
                    override fun error(code: String, message: String?, details: Any?) { result.error(code, message, details) }
                    override fun notImplemented() { result.notImplemented() }
                })
            }
            else -> if (result != null) fail(result, response)
        }
    }

    private fun fail(result: MethodChannel.Result, response: BillingResult) {
        val message = "购买服务暂不可用，请重试（${response.responseCode}）"
        val temporary = response.responseCode in setOf(
            BillingClient.BillingResponseCode.NETWORK_ERROR,
            BillingClient.BillingResponseCode.SERVICE_DISCONNECTED,
            BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE,
            BillingClient.BillingResponseCode.ERROR)
        if (result is Request && temporary) result.unavailable("billing", message, null)
        else result.error("billing", message, null)
    }

    private fun deliver(purchase: Purchase, result: MethodChannel.Result, done: () -> Unit) {
        val revision = ++entitlementRevision
        cacheAllowed = false
        acknowledge(purchase, result) delivery@{
            if (session != activeSession || revision != entitlementRevision) {
                result.error("superseded", "商店状态已更新，请重新查询", null)
                return@delivery
            }
            cacheWorker.execute {
                val saved = try { cache.write(purchase); true } catch (_: Exception) {
                    try { cache.clear() } catch (_: Exception) { }
                    false
                }
                handler.post {
                    // 后到的确认回调不能覆盖更新的查无权益或其他购买结果。
                    if (session != activeSession || revision != entitlementRevision) {
                        result.error("superseded", "商店状态已更新，请重新查询", null)
                    } else {
                        cacheAllowed = saved
                        channel.invokeMethod("changed", true)
                        done()
                    }
                }
            }
        }
    }

    private companion object {
        // KeyStore 和文件操作在单个后台队列执行，撤销与写入保持顺序。
        val cacheWorker = Executors.newSingleThreadExecutor()
        var activeSession = 0L
    }
}
