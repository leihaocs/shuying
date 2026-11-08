package com.shuying.app.shuying

import android.app.Activity
import android.content.Intent
import android.content.ClipData
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var exportText: String? = null
    private var exportBytes: ByteArray? = null
    private var allowLargeRead = false
    private var pendingShare: MethodChannel.Result? = null
    private var shareActive = false
    private var fileRequestCode: Int? = null
    private var shareRequestCode: Int? = null
    private var nextRequestCode = 1000
    @Volatile private var destroyed = false
    @Volatile private var fileGeneration = 0
    private val fileIO = Executors.newSingleThreadExecutor()
    private val supportUrl: String
        get() = if (BuildConfig.FLAVOR == "play") "https://leihaocs.github.io/shuying/support.html"
                else "https://bookmovie-revisit.cn/support.html"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bookmovie.revisit/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "image") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pending != null || shareActive || destroyed) {
                    result.error("busy", "文件选择或分享尚未完成", null)
                    return@setMethodCallHandler
                }
                shareActive = true
                pendingShare = result
                try {
                    val bytes = call.argument<ByteArray>("bytes") ?: error("未收到图片")
                    require(bytes.size <= 8 * 1024 * 1024 &&
                        validBinaryExport(bytes, "review.png", "image/png")) { "图片大小或格式无效" }
                    val generation = fileGeneration
                    fileIO.execute {
                        try {
                            check(!destroyed && generation == fileGeneration) { "分享操作已中断" }
                            val dir = File(cacheDir, "review-share").apply { mkdirs() }
                            val now = System.currentTimeMillis()
                            dir.listFiles()?.filter { now - it.lastModified() > 24 * 60 * 60 * 1000L }
                                ?.forEach { it.delete() }
                            val file = File.createTempFile("shuying-review-", ".png", dir)
                                .apply { writeBytes(bytes) }
                            runOnUiThread {
                                if (pendingShare !== result || destroyed) return@runOnUiThread
                                try {
                                    val uri = FileProvider.getUriForFile(this, "$packageName.reviewshare", file)
                                    val intent = Intent(Intent.ACTION_SEND).apply {
                                        type = "image/png"
                                        putExtra(Intent.EXTRA_STREAM, uri)
                                        clipData = ClipData.newRawUri("月度书影回顾", uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    val code = newRequestCode()
                                    shareRequestCode = code
                                    startActivityForResult(Intent.createChooser(intent, "分享月度回顾"), code)
                                    pendingShare = null
                                    result.success(null)
                                } catch (e: Exception) { finishShare(result, "无法打开分享面板") }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { finishShare(result, "无法生成分享图片") }
                        }
                    }
                } catch (e: Exception) { finishShare(result, "无法打开分享面板") }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bookmovie.revisit/backup")
            .setMethodCallHandler { call, result ->
                if (call.method == "supportUrl") {
                    result.success(supportUrl)
                    return@setMethodCallHandler
                }
                if (call.method == "openSupport" || call.method == "openFiling") {
                    try {
                        val expected = if (call.method == "openFiling") "https://beian.miit.gov.cn/" else supportUrl
                        val target = if (call.method == "openFiling") expected else call.argument<String>("url") ?: expected
                        require(target == expected) { "支持地址无效" }
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(target)))
                        result.success(true)
                    } catch (e: Exception) { result.error("support", "无法打开浏览器", null) }
                    return@setMethodCallHandler
                }
                if (call.method == "storagePath") {
                    result.success(filesDir.absolutePath)
                    return@setMethodCallHandler
                }
                if (call.method == "seedDemoData") {
                    result.success(BuildConfig.FLAVOR == "play")
                    return@setMethodCallHandler
                }
                if (pending != null || shareActive || destroyed) {
                    result.error("busy", "文件选择或分享尚未完成", null)
                    return@setMethodCallHandler
                }
                pending = result
                try {
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
                        "saveBytes" -> {
                            val bytes = call.argument<ByteArray>("bytes") ?: error("未收到文件内容")
                            val name = call.argument<String>("name") ?: error("文件名无效")
                            val mime = call.argument<String>("mime") ?: error("文件类型无效")
                            require(validBinaryExport(bytes, name, mime)) { "只支持安全命名的 PNG 或 PDF 文件" }
                            exportBytes = bytes
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = mime
                                putExtra(Intent.EXTRA_TITLE, name)
                            }
                        }
                        else -> { pending = null; result.notImplemented(); return@setMethodCallHandler }
                    }
                    exportText = if (call.method == "save") call.argument<String>("text")
                        ?: error("未收到备份文本") else null
                    allowLargeRead = call.method == "open" && call.argument<Boolean>("allowLarge") == true
                    val code = newRequestCode()
                    fileRequestCode = code
                    startActivityForResult(intent, code)
                } catch (e: Exception) { finishFile(error = e.message) }
            }
        StorePurchases(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == shareRequestCode) {
            shareRequestCode = null
            shareActive = false
            return
        }
        if (requestCode != fileRequestCode) return
        fileRequestCode = null
        val operation = pending ?: return
        if (resultCode != Activity.RESULT_OK) { finishFile(); return }
        val uri = data?.data ?: run { finishFile(); return }
        val bytes = exportBytes
        val text = exportText
        val large = allowLargeRead
        val generation = fileGeneration
        // 文件提供方可能来自云盘；完整读写与 UTF-8 转换都离开 UI 线程。
        try {
            fileIO.execute {
                try {
                    check(!destroyed && generation == fileGeneration) { "文件操作已中断" }
                    val content = bytes ?: text?.toByteArray(Charsets.UTF_8)
                    val value: Any = if (content != null) {
                        val stream = contentResolver.openOutputStream(uri, "wt") ?: error("无法写入文件")
                        stream.use {
                            var offset = 0
                            while (offset < content.size) {
                                check(!destroyed && generation == fileGeneration) { "文件操作已中断" }
                                val count = minOf(65536, content.size - offset)
                                it.write(content, offset, count)
                                offset += count
                            }
                            it.flush()
                        }
                        true
                    } else readBackup(uri, large, generation)
                    runOnUiThread { if (pending === operation) finishFile(value = value) }
                } catch (e: Exception) {
                    runOnUiThread { if (pending === operation) finishFile(error = e.message ?: "无法处理文件") }
                }
            }
        } catch (e: Exception) { finishFile(error = "文件操作已结束，请重试") }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        abandonFileOperations()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        destroyed = true
        abandonFileOperations()
        fileIO.shutdown()
        super.onDestroy()
    }

    private fun abandonFileOperations() {
        fileGeneration++
        // 明确的 Activity/engine 销毁才结束等待；普通切后台不取消用户的文件选择。
        finishFile(error = "文件操作因页面重建中断，请检查目标文件后重试")
        pendingShare?.let { finishShare(it, "分享因页面重建中断，请重试") }
        shareActive = false
        shareRequestCode = null
    }

    private fun newRequestCode(): Int {
        // 不复用已废弃的选择器编号，避免旧 Activity 结果写入新请求的数据。
        check(nextRequestCode <= 0xffff) { "请重新打开应用后再操作文件" }
        return nextRequestCode++
    }

    private fun finishShare(operation: MethodChannel.Result, error: String) {
        if (pendingShare !== operation) return
        pendingShare = null
        shareRequestCode = null
        shareActive = false
        operation.error("share", error, null)
    }

    private fun readBackup(uri: Uri, allowLarge: Boolean, generation: Int): String {
        val input = contentResolver.openInputStream(uri) ?: error("无法读取文件")
        return input.use {
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                check(!destroyed && generation == fileGeneration) { "文件操作已中断" }
                val count = it.read(buffer)
                if (count < 0) break
                if (!allowLarge && output.size() + count > 20 * 1024 * 1024) error("文件超过 20 MB，请先确认大文件导入")
                output.write(buffer, 0, count)
            }
            val decoder = Charsets.UTF_8.newDecoder()
            decoder.decode(java.nio.ByteBuffer.wrap(output.toByteArray())).toString()
        }
    }

    private fun finishFile(value: Any? = null, error: String? = null) {
        val result = pending
        pending = null; fileRequestCode = null; exportText = null; exportBytes = null; allowLargeRead = false
        if (error == null) result?.success(value) else result?.error("file", error, null)
    }

    private fun validBinaryExport(bytes: ByteArray, name: String, mime: String): Boolean {
        if (name.isEmpty() || name.length > 180 || name.startsWith(".") ||
            name.any { it == '/' || it == '\\' || it.code < 32 || it.code == 127 }) return false
        return when (mime) {
            "image/png" -> name.endsWith(".png", ignoreCase = true) && bytes.size >= 8 &&
                bytes.copyOfRange(0, 8).contentEquals(byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10))
            "application/pdf" -> name.endsWith(".pdf", ignoreCase = true) && bytes.size >= 5 &&
                bytes.copyOfRange(0, 5).contentEquals("%PDF-".toByteArray(Charsets.US_ASCII))
            else -> false
        }
    }
}
