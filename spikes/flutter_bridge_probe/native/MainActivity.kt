package com.navinjournal.navin_journal_bridge_probe

import android.os.Handler
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
        private const val TEST_MARKER_FILE = "nj_crash_phase.txt"
    }

    private val protector = AndroidKeystoreKeyProtector()
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var diagnosticChannel: MethodChannel? = null

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
        diagnosticChannel?.setMethodCallHandler(null)
        diagnosticChannel = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        executor.shutdown()
        super.onDestroy()
    }
}
