#!/usr/bin/env python3
"""Static source-contract check only; does not compile or run Billing/Android."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAY = ROOT / 'android/app/src/play/kotlin/com/shuying/app/shuying'
store = (PLAY / 'StorePurchases.kt').read_text()
cache = (PLAY / 'SignedPurchaseCache.kt').read_text()
direct = (ROOT / 'android/app/src/direct/kotlin/com/shuying/app/shuying/StorePurchases.kt').read_text()


def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


def require(text, *parts):
    for part in parts:
        assert part in text, f'Missing source safeguard: {part}'


unconfigured = section(store, 'if (BuildConfig.PLAY_LICENSE_KEY.isEmpty())', '} else connect')
require(unconfigured, '"purchasesEnabled" to false', '"status" -> result.success(false)')
require(store, 'Request(reply, timeout, call.method == "status")', '"status" -> 12_000L')

verification = section(store, 'private fun verified(', 'private fun acknowledge(')
require(verification, 'Signature.getInstance("SHA1withRSA")', 'purchase.originalJson',
        'purchase.signature', 'activity.packageName', 'purchase.products.contains(productId)',
        'purchase.purchaseState == Purchase.PurchaseState.PURCHASED')

fallback = section(store, 'fun unavailable(', 'private fun connect(')
require(fallback, '!cachedStatusAllowed || !cacheAllowed', 'cache.read()',
        'purchase != null && verified(purchase)', 'revision == entitlementRevision',
        'handler.postDelayed(cacheExpiry, 2_000L)', 'session == activeSession')

query = section(store, 'private fun status(', 'override fun onPurchasesUpdated(')
require(query, 'queryPurchasesAsync', 'result.cachedStatusAllowed = false',
        'if (purchase == null)', 'cacheAllowed = false', 'cache.clear()',
        'channel.invokeMethod("changed", false)', 'result.success(false)',
        'session != activeSession || revision != entitlementRevision')

delivery = section(store, 'private fun deliver(', 'private companion object')
require(delivery, 'acknowledge(purchase, result)', 'cache.write(purchase)',
        'session != activeSession || revision != entitlementRevision', 'cacheAllowed = saved')
assert delivery.index('acknowledge(purchase, result)') < delivery.index('cache.write(purchase)')
assert delivery.index('session != activeSession || revision != entitlementRevision') < delivery.index('cache.write(purchase)')
assert store.count('cache.write(purchase)') == 1

require(cache, 'context.noBackupFilesDir', 'AtomicFile(', '"AndroidKeyStore"',
        'Cipher.getInstance("AES/GCM/NoPadding")', 'GCMParameterSpec(128, iv)',
        '.setRandomizedEncryptionRequired(true)', '.setKeySize(256)',
        'cipher.updateAAD(associatedData)', 'cipher.init(Cipher.ENCRYPT_MODE, keyForWrite())',
        '.put("originalJson", purchase.originalJson)', '.put("signature", purchase.signature)',
        'require(length in 16..(MAX_BYTES + 16))')
read = section(cache, 'fun read()', 'fun clear()')
require(read, 'getKey(alias, null)',
        'Purchase(value.getString("originalJson"), value.getString("signature"))')
assert 'keyForWrite()' not in read
clear = section(cache, 'fun clear()', 'private companion object')
require(clear, 'store.deleteEntry(alias)', 'finally', 'file.delete()')
assert 'SharedPreferences' not in cache and 'putBoolean' not in cache
require(direct, '"status" -> result.success(false)', '"purchasesEnabled" to false')
print('通过：Play 离线权益源码约束检查；未编译、未运行支付或 Keystore 测试。')
