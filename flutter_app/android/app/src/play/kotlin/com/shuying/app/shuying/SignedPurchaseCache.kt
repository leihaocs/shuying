package com.shuying.app.shuying

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import com.android.billingclient.api.Purchase
import org.json.JSONObject
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** 只由已验签、已确认的商店交付路径写入；读取后仍须重新验证商店签名。 */
internal class SignedPurchaseCache(context: Context, productId: String) {
    private val file = AtomicFile(File(context.noBackupFilesDir, "play-receipt.v1"))
    private val alias = "${context.packageName}.play.receipt.v1"
    private val associatedData = "${context.packageName}|$productId|1".toByteArray(Charsets.UTF_8)

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun keyForWrite(): SecretKey {
        val existing = keyStore().getKey(alias, null) as? SecretKey
        if (existing != null) return existing
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .setKeySize(256)
                .build())
            generateKey()
        }
    }

    fun write(purchase: Purchase) {
        val plaintext = JSONObject()
            .put("originalJson", purchase.originalJson)
            .put("signature", purchase.signature)
            .toString().toByteArray(Charsets.UTF_8)
        require(plaintext.size <= MAX_BYTES)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keyForWrite())
        cipher.updateAAD(associatedData)
        require(cipher.iv.size == IV_BYTES)
        val ciphertext = cipher.doFinal(plaintext)
        val stream = file.startWrite()
        try {
            DataOutputStream(stream).apply {
                writeInt(1)
                write(cipher.iv)
                writeInt(ciphertext.size)
                write(ciphertext)
                flush()
            }
            file.finishWrite(stream)
        } catch (error: Exception) {
            file.failWrite(stream)
            throw error
        }
    }

    fun read(): Purchase? {
        // 不为读取生成新密钥；复制文件、重装或换机后缺少原密钥就不能解锁。
        val key = keyStore().getKey(alias, null) as? SecretKey ?: return null
        return DataInputStream(file.openRead()).use { input ->
            require(input.readInt() == 1)
            val iv = ByteArray(IV_BYTES).also { input.readFully(it) }
            val length = input.readInt()
            require(length in 16..(MAX_BYTES + 16))
            val ciphertext = ByteArray(length).also { input.readFully(it) }
            require(input.read() == -1)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
            cipher.updateAAD(associatedData)
            val value = JSONObject(String(cipher.doFinal(ciphertext), Charsets.UTF_8))
            Purchase(value.getString("originalJson"), value.getString("signature"))
        }
    }

    fun clear() {
        // 先销毁密钥：即使文件删除失败，旧的密文也不能再次用于离线解锁。
        try {
            val store = keyStore()
            if (store.containsAlias(alias)) store.deleteEntry(alias)
            check(!store.containsAlias(alias))
        } finally {
            // KeyStore 暂时不可用时仍尝试移除文件，不能因一个失败跳过另一个。
            file.delete()
        }
    }

    private companion object {
        const val IV_BYTES = 12
        const val MAX_BYTES = 128 * 1024
    }
}
