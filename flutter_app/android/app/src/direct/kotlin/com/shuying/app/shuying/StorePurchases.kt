package com.shuying.app.shuying

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

// 非 Play 渠道尚未接入支付，不创建 Google Billing 客户端。
class StorePurchases(activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "com.bookmovie.revisit/purchases")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(false)
                    "product" -> result.success(null)
                    "buy", "restore" -> result.error("unavailable", "此渠道尚未开放购买", null)
                    else -> result.notImplemented()
                }
            }
    }
}
