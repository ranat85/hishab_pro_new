package com.example.hishab_pro_new

import android.content.Context
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import android.provider.MediaStore
import android.content.ContentValues
import android.os.Build
import android.util.Base64
import java.io.OutputStream
import android.app.Activity

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.hishab_pro_new/keyboard"
    private val STORAGE_CHANNEL = "com.hishab_pro_new/storage"
    private val PDF_CHANNEL = "com.hishab_pro_new/pdf"
    private val REQUEST_CODE_PICK_DIR = 42
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showInputMethodPicker" -> {
                    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                    if (imm != null) {
                        imm.showInputMethodPicker()
                        try {
                            val view = window?.decorView
                            if (view != null) imm.restartInput(view)
                        } catch (e: Exception) {
                            // ignore
                        }
                        result.success(true)
                    } else {
                        result.error("UNAVAILABLE", "InputMethodManager not available", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDirectory" -> {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    startActivityForResult(intent, REQUEST_CODE_PICK_DIR)
                }
                "saveToDirectory" -> {
                    try {
                        val args = call.arguments as Map<*, *>
                        val tree = args["treeUri"] as String?
                        if (tree == null) {
                            result.error("NO_URI", "No treeUri provided", null)
                            return@setMethodCallHandler
                        }
                        val displayName = args["displayName"] as String
                        val b64 = args["bytes"] as String
                        val data = Base64.decode(b64, Base64.DEFAULT)
                        val treeUri = Uri.parse(tree)
                        val doc = DocumentFile.fromTreeUri(this, treeUri)
                        if (doc == null) {
                            result.error("INVALID_TREE", "Unable to access selected folder", null)
                            return@setMethodCallHandler
                        }
                        val created = doc.createFile("application/octet-stream", displayName)
                        if (created == null) {
                            result.error("CREATE_FAILED", "Failed to create file in folder", null)
                            return@setMethodCallHandler
                        }
                        val out = contentResolver.openOutputStream(created.uri)
                        out?.write(data)
                        out?.close()
                        result.success(created.uri.toString())
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PDF_CHANNEL).setMethodCallHandler { call, res ->
            when (call.method) {
                "savePdf" -> {
                    try {
                        val args = call.arguments as Map<*, *>
                        val b64 = args["bytes"] as String
                        val displayName = args["displayName"] as String
                        val mime = args["mimeType"] as? String ?: "application/pdf"
                        val data = Base64.decode(b64, Base64.DEFAULT)
                        val contentValues = ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                            put(MediaStore.MediaColumns.MIME_TYPE, mime)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/HISHAB PRO NEW")
                            }
                        }

                        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                        } else {
                            MediaStore.Files.getContentUri("external")
                        }

                        val resolver = applicationContext.contentResolver
                        val uri = resolver.insert(collection, contentValues)
                        if (uri == null) throw Exception("Failed to create media store entry")
                        var out: OutputStream? = null
                        try {
                            out = resolver.openOutputStream(uri)
                            out?.write(data)
                            out?.flush()
                        } finally {
                            out?.close()
                        }
                        res.success(uri.toString())
                    } catch (e: Exception) {
                        res.error("SAVE_FAILED", e.message, null)
                    }
                }
                else -> res.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_DIR) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri = data.data
                if (uri != null) {
                    try {
                        contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        pendingResult?.success(uri.toString())
                    } catch (e: Exception) {
                        pendingResult?.error("PERSIST_FAILED", e.message, null)
                    }
                } else {
                    pendingResult?.error("NO_URI", "No uri returned by picker", null)
                }
            } else {
                pendingResult?.error("CANCELLED", "User cancelled directory selection", null)
            }
            pendingResult = null
        }
    }
}
