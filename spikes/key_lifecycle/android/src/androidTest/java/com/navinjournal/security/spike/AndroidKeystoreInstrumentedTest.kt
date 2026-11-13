package com.navinjournal.security.spike

import android.security.keystore.KeyInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.security.KeyStore
import java.security.SecureRandom
import java.util.UUID
import javax.crypto.AEADBadTagException
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

/**
 * Android runtime tests for A2.3, using ONLY random fictional key material.
 *
 * These tests exercise actual AndroidKeyStore on the emulator, not the Linux
 * software mock. An emulator's keystore is NOT proof of hardware-backed keys,
 * secure biometric gating, protection from OS compromise, or portable recovery.
 */
@RunWith(AndroidJUnit4::class)
class AndroidKeystoreInstrumentedTest {
    private fun alias(generation: Int = 1): String {
        return "nj-v1-" + UUID.randomUUID().toString().replace("-", "") + "-g" + generation
    }

    private fun fakeDek(): ByteArray = ByteArray(32).also {
        SecureRandom().nextBytes(it)
    }

    private fun fakeAad(): ByteArray = "journal-vault-test-only-v1".toByteArray(Charsets.UTF_8)

    private fun assertBytesEqual(expected: ByteArray, actual: ByteArray) {
        assertArrayEquals(expected, actual)
    }

    private inline fun withAlias(block: (String, AndroidKeystoreKeyProtector) -> Unit) {
        val name = alias()
        val keystore = AndroidKeystoreKeyProtector()
        try {
            block(name, keystore)
        } finally {
            val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            if (store.containsAlias(name)) {
                keystore.retire(name)
            }
        }
    }

    @Test
    fun createAndAuthenticatedUnwrapRoundTrip() = withAlias { name, protector ->
        val dek = fakeDek()
        val aad = fakeAad()
        protector.provision(name)
        val blob = protector.wrap(name, dek, aad)
        assertEquals(12, blob.nonce.size)
        assertEquals(32, blob.ciphertext.size)
        assertEquals(16, blob.tag.size)
        assertBytesEqual(dek, protector.unwrap(name, blob, aad))
        dek.fill(0)
    }

    @Test
    fun sameAliasCannotBeProvisionedTwice() = withAlias { name, protector ->
        protector.provision(name)
        assertThrows(IllegalStateException::class.java) {
            protector.provision(name)
        }
    }

    @Test
    fun missingAliasNeverAutoProvisioned() = withAlias { name, protector ->
        val before = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        assertFalse(before.containsAlias(name))
        assertThrows(IllegalStateException::class.java) {
            protector.wrap(name, fakeDek(), fakeAad())
        }
        assertFalse(before.containsAlias(name))
    }

    @Test
    fun tamperedAuthenticationTagCannotDecrypt() = withAlias { name, protector ->
        protector.provision(name)
        val blob = protector.wrap(name, fakeDek(), fakeAad())
        val tag = blob.tag.clone().also { it[0] = (it[0].toInt() xor 1).toByte() }
        val changed = blob.copy(tag = tag)
        assertThrows(Exception::class.java) {
            protector.unwrap(name, changed, fakeAad())
        }
    }

    @Test
    fun mismatchedAssociatedDataCannotDecrypt() = withAlias { name, protector ->
        protector.provision(name)
        val blob = protector.wrap(name, fakeDek(), fakeAad())
        assertThrows(Exception::class.java) {
            protector.unwrap(name, blob, "another-vault-id".toByteArray())
        }
    }

    @Test
    fun changedCiphertextCannotDecrypt() = withAlias { name, protector ->
        protector.provision(name)
        val blob = protector.wrap(name, fakeDek(), fakeAad())
        val payload = blob.ciphertext.clone().also {
            it[it.size - 1] = (it.last().toInt() xor 1).toByte()
        }
        assertThrows(Exception::class.java) {
            protector.unwrap(name, blob.copy(ciphertext = payload), fakeAad())
        }
    }

    @Test
    fun wrapperCanReopenAliasWithSecondInstance() = withAlias { name, protector ->
        val dek = fakeDek()
        protector.provision(name)
        val blob = protector.wrap(name, dek, fakeAad())
        val reloaded = AndroidKeystoreKeyProtector()
        assertBytesEqual(dek, reloaded.unwrap(name, blob, fakeAad()))
        dek.fill(0)
    }

    @Test
    fun retiredAliasCannotUnwrapOldEnvelope() = withAlias { name, protector ->
        protector.provision(name)
        val blob = protector.wrap(name, fakeDek(), fakeAad())
        protector.retire(name)
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        assertFalse(store.containsAlias(name))
        assertThrows(IllegalStateException::class.java) {
            protector.unwrap(name, blob, fakeAad())
        }
        assertFalse(store.containsAlias(name))
    }

    @Test
    fun oldAndNewWrappingKeysProtectSameDatabaseKey() = withAlias { first, old ->
        val second = alias(2)
        val raw = fakeDek()
        val aad = fakeAad()
        try {
            old.provision(first)
            val original = old.wrap(first, raw, aad)
            val newer = AndroidKeystoreKeyProtector()
            newer.provision(second)
            val rotated = newer.wrap(second, raw, aad)
            assertBytesEqual(raw, old.unwrap(first, original, aad))
            assertBytesEqual(raw, newer.unwrap(second, rotated, aad))
            old.retire(first)
            assertThrows(IllegalStateException::class.java) {
                old.unwrap(first, original, aad)
            }
            assertBytesEqual(raw, newer.unwrap(second, rotated, aad))
        } finally {
            val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            if (store.containsAlias(second)) old.retire(second)
            raw.fill(0)
        }
    }

    @Test
    fun newNonceEachTimePreservesCiphertextSeparation() = withAlias { name, protector ->
        val dek = fakeDek()
        protector.provision(name)
        val a = protector.wrap(name, dek, fakeAad())
        val b = protector.wrap(name, dek, fakeAad())
        assertFalse(a.nonce.contentEquals(b.nonce))
        assertFalse(a.ciphertext.contentEquals(b.ciphertext))
        assertBytesEqual(dek, protector.unwrap(name, a, fakeAad()))
        assertBytesEqual(dek, protector.unwrap(name, b, fakeAad()))
        dek.fill(0)
    }

    @Test
    fun rejectsMalformedInputsBeforeCallingCipher() = withAlias { name, protector ->
        protector.provision(name)
        val blob = protector.wrap(name, fakeDek(), fakeAad())
        assertThrows(IllegalArgumentException::class.java) {
            protector.wrap(name, ByteArray(16), fakeAad())
        }
        assertThrows(IllegalArgumentException::class.java) {
            protector.unwrap(name, blob.copy(nonce = ByteArray(10)), fakeAad())
        }
        assertThrows(IllegalArgumentException::class.java) {
            protector.unwrap(name, blob.copy(tag = ByteArray(4)), fakeAad())
        }
        assertThrows(IllegalArgumentException::class.java) {
            protector.unwrap(name, blob, ByteArray(0))
        }
    }

    @Test
    fun keyIsProvidedByAndroidKeyStore() = withAlias { name, protector ->
        protector.provision(name)
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val key = store.getKey(name, null) as SecretKey
        assertEquals("AES", key.algorithm)
        assertNull("Android Keystore AES keys must be non-exportable", key.encoded)
        // Emulator software-backed keys are permitted in this test. Do not
        // mistake this assertion for hardware-backed or StrongBox evidence.
        val info = SecretKeyFactory.getInstance(key.algorithm, "AndroidKeyStore")
            .getKeySpec(key, KeyInfo::class.java) as KeyInfo
        assertEquals(256, info.keySize)
        assertFalse(info.isUserAuthenticationRequired)
    }
}
