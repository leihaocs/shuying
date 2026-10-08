package com.shuying.app.shuying

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var exportText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bookmovie.revisit/backup")
            .setMethodCallHandler { call, result ->
                if (call.method == "storagePath") {
                    result.success(filesDir.absolutePath)
                    return@setMethodCallHandler
                }
                if (pending != null) {
                    result.error("busy", "文件选择尚未完成", null)
                    return@setMethodCallHandler
                }
                val intent = when (call.method) {
                    "open" -> Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    "save" -> Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                    }
                    else -> { result.notImplemented(); return@setMethodCallHandler }
                }
                exportText = if (call.method == "save") call.argument<String>("text") else null
                pending = result
                try { startActivityForResult(intent, 901) }
                catch (e: Exception) { finishFile(error = e.message) }
            }
        StorePurchases(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 901) return
        if (resultCode != Activity.RESULT_OK) { finishFile(); return }
        val uri = data?.data ?: run { finishFile(); return }
        try {
            val text = exportText
            if (text != null) {
                val stream = contentResolver.openOutputStream(uri, "wt") ?: error("无法写入文件")
                stream.use { it.write(text.toByteArray(Charsets.UTF_8)) }
                finishFile(value = true)
            } else { finishFile(value = readBackup(uri)) }
        } catch (e: Exception) { finishFile(error = e.message) }
    }

    private fun readBackup(uri: Uri): String {
        val input = contentResolver.openInputStream(uri) ?: error("无法读取文件")
        return input.use {
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = it.read(buffer)
                if (count < 0) break
                if (output.size() + count > 20 * 1024 * 1024) error("文件超过 20 MB")
                output.write(buffer, 0, count)
            }
            val decoder = Charsets.UTF_8.newDecoder()
            decoder.decode(java.nio.ByteBuffer.wrap(output.toByteArray())).toString()
        }
    }

    private fun finishFile(value: Any? = null, error: String? = null) {
        if (error == null) pending?.success(value) else pending?.error("file", error, null)
        pending = null; exportText = null
    }
}
