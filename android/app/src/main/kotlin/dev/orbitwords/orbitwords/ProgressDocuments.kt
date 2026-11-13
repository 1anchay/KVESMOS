package dev.orbitwords.orbitwords

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** No storage permission. Only the URI granted by the document picker is opened. */
internal class ProgressDocuments(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "dev.orbitwords/progress_documents")
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "export" && call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pending != null) {
                result.error("busy", null, null)
                return@setMethodCallHandler
            }
            val write = call.method == "export"
            val bytes = if (write) call.argument<ByteArray>("bytes") else null
            if (write && (bytes == null || bytes.size > LIMIT)) {
                result.error("size", null, null)
                return@setMethodCallHandler
            }
            val intent = Intent(if (write) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType(if (write) "application/json" else "*/*")
            if (write) intent.putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
            try {
                pending = result
                exportBytes = bytes
                @Suppress("DEPRECATION")
                activity.startActivityForResult(intent, REQUEST)
            } catch (_: Exception) {
                pending = null
                exportBytes = null
                result.error("picker", null, null)
            }
        }
    }

    fun onResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != REQUEST) return false
        val result = pending ?: return true
        val bytes = exportBytes
        exportBytes = null
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null) {
            pending = null
            result.success(null)
            return true
        }
        worker.execute {
            try {
                val value: Any = if (bytes == null) read(uri) else {
                    requireNotNull(activity.contentResolver.openOutputStream(uri, "wt"))
                        .use { it.write(bytes) }
                    true
                }
                activity.runOnUiThread {
                    if (pending === result) {
                        pending = null
                        result.success(value)
                    }
                }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    if (pending === result) {
                        pending = null
                        result.error(if (error is FileTooLarge) "size" else "io", null, null)
                    }
                }
            }
        }
        return true
    }

    private fun read(uri: Uri): ByteArray {
        return requireNotNull(activity.contentResolver.openInputStream(uri)).use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (output.size() + count > LIMIT) throw FileTooLarge()
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending?.error("closed", null, null)
        pending = null
        exportBytes = null
        worker.shutdown()
    }

    private class FileTooLarge : Exception()

    companion object {
        private const val REQUEST = 9281
        private const val LIMIT = 32 * 1024 * 1024
    }
}
