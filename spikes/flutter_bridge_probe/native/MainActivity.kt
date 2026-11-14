package com.navinjournal.navin_journal_bridge_probe

import android.app.Activity
import java.io.ByteArrayOutputStream
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Handler
import android.view.WindowManager
import java.security.MessageDigest
import android.os.Looper
import com.navinjournal.security.spike.AndroidKeystoreKeyProtector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.GeneralSecurityException
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * A2.4 experimental Flutter bridge. NO REAL DIARY DATA.
 *
 * This host runs AndroidKeyStore calls on a single worker thread and delivers
 * method responses on the main thread. It does not auto-create a missing key.
 * Raw DEKs inevitably cross the StandardMessageCodec boundary; no promise
 * of reliable memory zeroization can be made in Flutter or JVM heap.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "navin_journal/security_key_wrap_v1"
        const val TEST_LIFECYCLE_CHANNEL = "navin_journal/test_lifecycle_v1"
        const val FICTIONAL_EXPORT_CHANNEL = "navin_journal/fictional_export_v1"
        private const val CREATE_FICTIONAL_ARCHIVE = 7481
        private const val OPEN_FICTIONAL_ARCHIVE = 7482
        private const val MAX_FICTIONAL_ARCHIVE_BYTES = 32 * 1024 * 1024
        private const val TEST_MARKER_FILE = "nj_crash_phase.txt"
    }

    private val protector = AndroidKeystoreKeyProtector()
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var diagnosticChannel: MethodChannel? = null
    private var fictionalExportChannel: MethodChannel? = null
    private data class PendingFictionalExport(
        val bytes: ByteArray,
        val reply: MethodChannel.Result,
    )
    private var pendingFictionalExport: PendingFictionalExport? = null
    private var pendingFictionalImport: MethodChannel.Result? = null
    private var fictionalExportSecure = false
    private var fictionalImportSecure = false

    private fun updateSecureWindow() {
        if (fictionalExportSecure || fictionalImportSecure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun readBoundedEncryptedDocument(uri: android.net.Uri): ByteArray {
        val output = ByteArrayOutputStream()
        contentResolver.openInputStream(uri)?.use { input ->
            val block = ByteArray(32 * 1024)
            try {
                while (true) {
                    val n = input.read(block)
                    if (n < 0) break
                    if (n == 0) continue
                    if (output.size().toLong() + n >
                        MAX_FICTIONAL_ARCHIVE_BYTES.toLong()) {
                        throw IllegalArgumentException("Archive exceeds import bound")
                    }
                    output.write(block, 0, n)
                }
            } finally {
                block.fill(0)
            }
        } ?: throw IllegalStateException("Document cannot be read")
        if (output.size() == 0) throw IllegalArgumentException("Empty archive")
        return output.toByteArray()
    }

    private fun isDebugHarness(): Boolean =
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun verifySelectedDocument(uri: android.net.Uri, source: ByteArray): Boolean {
        // No filenames, paths, ciphertext, or destination URI are ever logged.
        // A provider returning a write ACK alone is not a successful export.
        val expected = MessageDigest.getInstance("SHA-256").digest(source)
        contentResolver.openOutputStream(uri, "wt")?.use { output ->
            output.write(source)
            output.flush()
        } ?: return false
        val digest = MessageDigest.getInstance("SHA-256")
        var seen = 0L
        contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(32 * 1024)
            try {
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    if (n == 0) continue
                    seen += n
                    if (seen > MAX_FICTIONAL_ARCHIVE_BYTES) return false
                    digest.update(buffer, 0, n)
                }
            } finally {
                buffer.fill(0)
            }
        } ?: return false
        return seen == source.size.toLong() &&
            MessageDigest.isEqual(expected, digest.digest())
    }

    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OPEN_FICTIONAL_ARCHIVE) {
            val waiting = pendingFictionalImport ?: return
            pendingFictionalImport = null
            val selected = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (selected == null) {
                fictionalImportSecure = false
                updateSecureWindow()
                waiting.success(null)
                return
            }
            try {
                executor.execute {
                    var encrypted: ByteArray? = null
                    try {
                        encrypted = readBoundedEncryptedDocument(selected)
                        val valid = encrypted
                        mainHandler.post {
                            if (valid != null && !isFinishing && !isDestroyed) {
                                // Secure flag was set BEFORE launching the
                                // picker; never return private key-entry UI
                                // to an unprotected window.
                                waiting.success(valid)
                            } else {
                                fictionalImportSecure = false
                                updateSecureWindow()
                                waiting.error("IMPORT_UNAVAILABLE",
                                    "Chosen document could not be read", null)
                            }
                            valid?.fill(0)
                        }
                    } catch (_: Exception) {
                        encrypted?.fill(0)
                        mainHandler.post {
                            fictionalImportSecure = false
                            updateSecureWindow()
                            waiting.error("IMPORT_UNAVAILABLE",
                                "Chosen document could not be read", null)
                        }
                    }
                }
            } catch (_: RejectedExecutionException) {
                fictionalImportSecure = false
                updateSecureWindow()
                waiting.error("IMPORT_UNAVAILABLE",
                    "Document reader unavailable", null)
            }
            return
        }
        if (requestCode != CREATE_FICTIONAL_ARCHIVE) return
        val pending = pendingFictionalExport ?: return
        pendingFictionalExport = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            pending.bytes.fill(0)
            pending.reply.success(false)
            return
        }
        try {
            executor.execute {
                var verified = false
                try {
                    verified = verifySelectedDocument(uri, pending.bytes)
                } catch (_: Exception) {
                    // A failed provider can leave a partial ciphertext file.
                    // Never delete/rewrite unknown provider documents.
                } finally {
                    pending.bytes.fill(0)
                }
                mainHandler.post {
                    if (verified && !isFinishing && !isDestroyed) {
                        // Establish screenshot protection BEFORE Dart receives
                        // the result containing the manually transcribed key.
                        fictionalExportSecure = true
                        updateSecureWindow()
                        pending.reply.success(true)
                    } else {
                        pending.reply.error(
                            "EXPORT_UNVERIFIED",
                            "The chosen document could not be read back and verified",
                            null,
                        )
                    }
                }
            }
        } catch (_: RejectedExecutionException) {
            pending.bytes.fill(0)
            pending.reply.error("EXPORT_UNAVAILABLE", "File handoff unavailable", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        // Test-only A3.4 lifecycle hook: exposes app-private path and test
        // status markers, never the encrypted DEK, journal text or key alias.
        val diagnostic = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TEST_LIFECYCLE_CHANNEL,
        )
        diagnosticChannel = diagnostic
        val exportChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FICTIONAL_EXPORT_CHANNEL,
        )
        fictionalExportChannel = exportChannel
        exportChannel.setMethodCallHandler { call, result ->
            if (!isDebugHarness()) {
                result.error("DISABLED", "Fictional diagnostics unavailable", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "saveFictionalArchive" -> {
                    val raw = call.argument<ByteArray>("archive")
                    if (raw == null || raw.isEmpty() ||
                        raw.size > MAX_FICTIONAL_ARCHIVE_BYTES ||
                        pendingFictionalExport != null ||
                        pendingFictionalImport != null) {
                        result.error("INVALID_ARGUMENT", "Export unavailable", null)
                    } else {
                        // Native copies this encrypted payload. No raw DEK or
                        // offline recovery key is transmitted through this bridge.
                        val copy = raw.copyOf()
                        pendingFictionalExport =
                            PendingFictionalExport(copy, result)
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE,
                                "navin-journal-FICTIONAL-only.njr")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        }
                        try {
                            startActivityForResult(intent, CREATE_FICTIONAL_ARCHIVE)
                        } catch (_: Exception) {
                            pendingFictionalExport = null
                            copy.fill(0)
                            result.error("PICKER_UNAVAILABLE",
                                "Document picker unavailable", null)
                        }
                    }
                }
                "openFictionalArchive" -> {
                    if (pendingFictionalImport != null ||
                        pendingFictionalExport != null) {
                        result.error("IMPORT_BUSY", "File picker unavailable", null)
                    } else {
                        fictionalImportSecure = true
                        updateSecureWindow()
                        pendingFictionalImport = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try {
                            startActivityForResult(intent, OPEN_FICTIONAL_ARCHIVE)
                        } catch (_: Exception) {
                            pendingFictionalImport = null
                            fictionalImportSecure = false
                            updateSecureWindow()
                            result.error("PICKER_UNAVAILABLE",
                                "Document picker unavailable", null)
                        }
                    }
                }
                "hideImportRecoveryInput" -> {
                    fictionalImportSecure = false
                    updateSecureWindow()
                    result.success(true)
                }
                "hideRecoveryKey" -> {
                    fictionalExportSecure = false
                    updateSecureWindow()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        diagnostic.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPrivateRoot" -> result.success(filesDir.absolutePath)
                "getStartPhase" ->
                    result.success(intent.getStringExtra("nj_test_phase") ?: "")
                "markPhase" -> {
                    val marker = call.argument<String>("marker")
                    if (marker !in setOf(
                            "ACK_V1", "ACK_V2", "RECOVERED_V1",
                            "RECOVERED_V2", "FAILED",
                            "PORTABLE_EXPORT_READY", "PORTABLE_WRONG_KEY",
                            "PORTABLE_RESTORE_OK", "PORTABLE_REOPEN_OK",
                            "PORTABLE_ENOSPC_PRE", "PORTABLE_ENOSPC_POST",
                            "PORTABLE_ENOSPC_REOPEN",
                            "CANDIDATE_RETAINED", "CANDIDATE_REOPEN_OK",
                            "CANDIDATE_KEY_LOSS_SAFE",
                            "IME_PREEDIT_READY", "IME_BACKGROUND_ACK_V1",
                            "IME_FINAL_ACK_V2", "IME_REOPENED_V2",
                        )
                    ) {
                        result.error("INVALID_ARGUMENT", "Unknown test marker", null)
                    } else {
                        try {
                            java.io.File(filesDir, TEST_MARKER_FILE)
                                .writeText(marker!!, Charsets.US_ASCII)
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("NATIVE_ERROR", "Test marker unavailable", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        channel.setMethodCallHandler { call, result ->
            if (call.method !in setOf("provision", "wrap", "unwrap", "retire")) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                executor.execute {
                    try {
                        val output = dispatch(call)
                        mainHandler.post { result.success(output) }
                    } catch (_: IllegalArgumentException) {
                        mainHandler.post {
                            result.error("INVALID_ARGUMENT", "Invalid key operation", null)
                        }
                    } catch (_: IllegalStateException) {
                        mainHandler.post {
                            result.error("KEY_STATE", "Device key unavailable or exists", null)
                        }
                    } catch (_: GeneralSecurityException) {
                        mainHandler.post {
                            result.error("AUTH_FAILED", "Key authentication failed", null)
                        }
                    } catch (_: Exception) {
                        mainHandler.post {
                            result.error("NATIVE_ERROR", "Native wrapping operation failed", null)
                        }
                    }
                }
            } catch (_: RejectedExecutionException) {
                result.error("NATIVE_ERROR", "Native bridge unavailable", null)
            }
        }
    }

    private fun requireAlias(call: MethodCall): String =
        call.argument<String>("alias")
            ?: throw IllegalArgumentException("alias required")

    private fun requireBytes(
        call: MethodCall,
        name: String,
        length: Int? = null,
    ): ByteArray {
        val raw = call.argument<ByteArray>(name)
            ?: throw IllegalArgumentException("byte buffer missing")
        if (length != null && raw.size != length) {
            throw IllegalArgumentException("unexpected byte size")
        }
        if (raw.isEmpty()) throw IllegalArgumentException("empty buffer")
        return raw
    }

    private fun dispatch(call: MethodCall): Any? {
        val alias = requireAlias(call)
        return when (call.method) {
            "provision" -> {
                protector.provision(alias)
                null
            }
            "wrap" -> {
                val source = requireBytes(call, "dek", 32)
                val aad = requireBytes(call, "aad")
                // Copy only the working bytes; do not mutate the Flutter codec
                // input, whose lifetime is owned by the platform messenger.
                val keyCopy = source.copyOf()
                try {
                    val wrapped = protector.wrap(alias, keyCopy, aad)
                    mapOf(
                        "nonce" to wrapped.nonce,
                        "ciphertext" to wrapped.ciphertext,
                        "tag" to wrapped.tag,
                    )
                } finally {
                    keyCopy.fill(0)
                }
            }
            "unwrap" -> {
                val nonce = requireBytes(call, "nonce", 12)
                val ciphertext = requireBytes(call, "ciphertext", 32)
                val tag = requireBytes(call, "tag", 16)
                val aad = requireBytes(call, "aad")
                protector.unwrap(
                    alias,
                    AndroidKeystoreKeyProtector.Wrapped(nonce, ciphertext, tag),
                    aad,
                )
            }
            "retire" -> {
                protector.retire(alias)
                null
            }
            else -> throw IllegalArgumentException("Unknown method")
        }
    }

    override fun onDestroy() {
        pendingFictionalExport?.let {
            it.bytes.fill(0)
            it.reply.error("EXPORT_CANCELLED", "The app closed during export", null)
        }
        pendingFictionalExport = null
        pendingFictionalImport?.error(
            "IMPORT_CANCELLED", "App closed during import", null)
        pendingFictionalImport = null
        fictionalImportSecure = false
        fictionalExportSecure = false
        updateSecureWindow()
        fictionalExportChannel?.setMethodCallHandler(null)
        fictionalExportChannel = null
        diagnosticChannel?.setMethodCallHandler(null)
        diagnosticChannel = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        executor.shutdown()
        super.onDestroy()
    }
}
