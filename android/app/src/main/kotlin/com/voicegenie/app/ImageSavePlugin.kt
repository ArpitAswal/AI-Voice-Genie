package com.voicegenie.app

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/// Native Kotlin handler for saving generated images to the device gallery.
///
/// Android 10+ (API 29+): Uses MediaStore.Images with scoped storage.
///   No WRITE_EXTERNAL_STORAGE permission needed — the app owns its own media.
///
/// Android 9 and below (API 28-): Falls back to direct filesystem write
///   into the public Pictures directory, which requires WRITE_EXTERNAL_STORAGE
///   declared with maxSdkVersion="28" in AndroidManifest.xml.
///
/// Channel: "com.voicegenie.app/image_save"
/// Method:  "saveImageBytes" with arguments:
///   "bytes"    → ByteArray   — raw image bytes
///   "fileName" → String      — safe file name including extension
///   "mimeType" → String      — e.g. "image/jpeg", "image/png"
///
/// Returns: Map<String, Any?>
///   "success"  → Boolean
///   "error"    → String? (null on success)
object ImageSavePlugin {

    private const val CHANNEL = "com.voicegenie.app/image_save"

    fun register(context: Context, channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "saveImageBytes") {
                handleSave(context, call, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun handleSave(context: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            // Extract arguments from the Flutter side
            val bytes = call.argument<ByteArray>("bytes")
                ?: return result.success(mapOf("success" to false, "error" to "no_bytes"))
            val fileName = call.argument<String>("fileName")
                ?: return result.success(mapOf("success" to false, "error" to "no_filename"))
            val mimeType = call.argument<String>("mimeType") ?: "image/jpeg"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ — use MediaStore scoped storage (no permission needed)
                saveWithMediaStore(context, bytes, fileName, mimeType, result)
            } else {
                // Android 9 and below — write directly to Pictures directory
                saveLegacy(bytes, fileName, result)
            }
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "error" to "unexpected: ${e.message}"))
        }
    }

    /// Saves image bytes using MediaStore on Android 10+ (API 29+).
    ///
    /// Sets IS_PENDING=1 before writing and IS_PENDING=0 after to comply with
    /// Android's atomic media insert contract, ensuring the image only appears
    /// in the gallery when the write is fully complete.
    private fun saveWithMediaStore(
        context: Context,
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
        result: MethodChannel.Result
    ) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            // Relative path inside the shared Pictures directory — user-visible
            put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/AI Voice Genie")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Mark as pending so gallery scanner ignores incomplete writes
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }

        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return result.success(mapOf("success" to false, "error" to "mediastore_insert_failed"))

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: return result.success(mapOf("success" to false, "error" to "stream_open_failed"))

            // Clear the pending flag so the image is now visible in the gallery
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }

            result.success(mapOf("success" to true, "error" to null))
        } catch (e: Exception) {
            // Clean up the orphaned MediaStore entry if the write failed
            resolver.delete(uri, null, null)
            result.success(mapOf("success" to false, "error" to "write_failed: ${e.message}"))
        }
    }

    /// Legacy save path for Android 9 and below.
    ///
    /// Writes directly to the public Pictures/AI Voice Genie directory.
    /// Requires WRITE_EXTERNAL_STORAGE permission declared with maxSdkVersion="28".
    private fun saveLegacy(bytes: ByteArray, fileName: String, result: MethodChannel.Result) {
        val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val appDir = File(picturesDir, "AI Voice Genie").apply { mkdirs() }
        val file = File(appDir, fileName)

        try {
            FileOutputStream(file).use { stream -> stream.write(bytes) }
            result.success(mapOf("success" to true, "error" to null))
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "error" to "legacy_write_failed: ${e.message}"))
        }
    }
}
