package com.navinjournal.security.spike

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * STAGED ANDROID CANDIDATE, NOT COMPILED/DEVICE-TESTED OR INTEGRATED.
 *
 * The wrapping key lives under AndroidKeyStore. Only AES-GCM-wrapped DEK
 * bytes and nonce/tag may be persisted; raw DEKs must never be logged,
 * written to SharedPreferences or sent to analytics.
 *
 * This adapter does not implement biometric policy, backup recovery, Android
 * process synchronization, Android key attestation, or independent security
 * review. setUserAuthenticationRequired(false) is intentional for the *spike*;
 * the final unlock policy must be designed/approved separately.
 *
 * Minimum Android API level 23.
 */
class AndroidKeystoreKeyProtector {
    data class Wrapped(
        val nonce: ByteArray,
        val ciphertext: ByteArray,
        val tag: ByteArray,
    )

    private val store: KeyStore = KeyStore.getInstance("AndroidKeyStore").apply {
        load(null)
    }

    private val validAlias = Regex("nj-v1-[a-f0-9]{32}-g[1-9][0-9]*")

    private fun checkAlias(alias: String) {
        require(validAlias.matches(alias)) { "Invalid journal key alias" }
    }

    private fun existingKey(alias: String): SecretKey {
        checkAlias(alias)
        // Never regenerate a missing key during read/unwrap. Missing key is
        // an unrecoverable state without a separate user-controlled archive.
        if (!store.containsAlias(alias)) {
            throw IllegalStateException("Wrapping key unavailable")
        }
        val key = store.getKey(alias, null) as? SecretKey
        return key ?: throw IllegalStateException("Wrong wrapping key type")
    }

    @Synchronized
    fun provision(alias: String) {
        checkAlias(alias)
        if (store.containsAlias(alias)) {
            throw IllegalStateException("Refusing to replace existing key")
        }
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore"
        )
        val spec = KeyGenParameterSpec.Builder(
            alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .setUserAuthenticationRequired(false)
            .build()
        generator.init(spec)
        generator.generateKey()
    }

    fun wrap(alias: String, rawDataKey: ByteArray, aad: ByteArray): Wrapped {
        require(rawDataKey.size == 32) { "Expected 32-byte data-encryption key" }
        require(aad.isNotEmpty()) { "Authenticated envelope context required" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, existingKey(alias))
        cipher.updateAAD(aad)
        val combined = cipher.doFinal(rawDataKey)
        val tagLength = 16
        require(combined.size == 32 + tagLength)
        return Wrapped(
            nonce = cipher.iv.copyOf(),
            ciphertext = combined.copyOfRange(0, 32),
            tag = combined.copyOfRange(32, combined.size),
        )
    }

    fun unwrap(alias: String, wrapped: Wrapped, aad: ByteArray): ByteArray {
        require(wrapped.nonce.size == 12) { "Invalid AES-GCM nonce" }
        require(wrapped.ciphertext.size == 32) { "Invalid wrapped DEK" }
        require(wrapped.tag.size == 16) { "Invalid AES-GCM tag" }
        require(aad.isNotEmpty()) { "Authenticated envelope context required" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            existingKey(alias),
            GCMParameterSpec(128, wrapped.nonce),
        )
        cipher.updateAAD(aad)
        // Authentication failure will throw, never return fallback bytes.
        return cipher.doFinal(wrapped.ciphertext + wrapped.tag)
    }

    @Synchronized
    fun retire(alias: String) {
        checkAlias(alias)
        if (!store.containsAlias(alias)) {
            throw IllegalStateException("Wrapping key unavailable")
        }
        // Call ONLY after the new envelope has been durably promoted and
        // independently verified, never on a wrong-key or restore error.
        store.deleteEntry(alias)
    }
}
