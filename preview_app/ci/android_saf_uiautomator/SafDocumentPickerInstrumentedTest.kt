package com.navinjournal.navin_journal_saf_driver

import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Independent AndroidX UI Automator driver. The disposable probe runs in a
 * different package/process. This test never injects a document URI, fabricated
 * ActivityResult, key, archive bytes, or private text. The probe independently
 * authenticates the actual returned fictional encrypted file and its history.
 */
@RunWith(AndroidJUnit4::class)
class SafDocumentPickerInstrumentedTest {
    private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private val probe = "com.navinjournal.navin_journal_saf_probe"
    private val documentsUi = "com.google.android.documentsui"
    private val filename = "navin-journal-FICTIONAL-only"

    private fun shell(cmd: String) = device.executeShellCommand(cmd).trim()
    private fun marker() = shell("run-as $probe cat files/nj_crash_phase.txt").trim()

    private fun seen(expected: String, timeoutMs: Long): Boolean {
        val deadline = SystemClock.uptimeMillis() + timeoutMs
        while (SystemClock.uptimeMillis() < deadline) {
            val current = marker()
            if (current == expected) return true
            if (current == "FAILED") fail("Disposable probe rejected $expected")
            SystemClock.sleep(450L)
        }
        return false
    }

    private fun requirePhase(expected: String, timeoutMs: Long = 75_000L) {
        val confirmed = seen(expected, timeoutMs)
        if (!confirmed) {
            // Only booleans and nonsecret markers: never dump UI, file names,
            // keys, document URIs or journal text.
            println("PROBE_STATE expected=" + expected +
                " alive=" + shell("pidof $probe").isNotEmpty() +
                " runAsReady=" + shell("run-as $probe id").contains("uid=") +
                " marker=" + marker())
        }
        assertTrue("Missing native fictional phase " + expected, confirmed)
    }

    private fun phase(phase: String) {
        shell("am force-stop $probe")
        assertTrue("Failed clearing disposable app",
            shell("pm clear $probe").contains("Success"))
        SystemClock.sleep(550L)
        val result = shell("am start -n $probe/.MainActivity --es nj_test_phase $phase")
        assertTrue("Failed starting disposable probe", !result.contains("Error"))
    }

    private fun picker() {
        val googlePicker = device.wait(
            Until.hasObject(By.pkg(documentsUi)), 22_000L)
        val platformPicker = if (!googlePicker) device.wait(
            Until.hasObject(By.pkg("com.android.documentsui")), 12_000L
        ) else false
        val pickerVisible = googlePicker || platformPicker
        if (!pickerVisible) {
            // Report ONLY known package/system window categories, never a full
            // accessibility dump or private text, URI, key or archive bytes.
            val window = shell(
                "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' | head -n 2"
            )
            val category = when {
                window.contains("documentsui") -> "documentsui_not_accessible"
                window.contains("Not Responding") -> "system_anr"
                window.contains(probe) -> "probe_foreground"
                else -> "other_system_window"
            }
            println("PICKER_VISIBILITY category=" + category +
                " probeAlive=" + shell("pidof $probe").isNotEmpty() +
                " probePhase=" + marker())
        }
        assertTrue("Real DocumentsUI unavailable", pickerVisible)
    }

    private fun click(node: UiObject2) {
        var target: UiObject2? = node
        repeat(5) {
            if (target == null || target!!.isClickable) return@repeat
            target = target!!.parent
        }
        assertTrue("Clickable Android accessibility node unavailable",
            target != null && target!!.isClickable)
        target!!.click()
    }

    private fun downloads() {
        picker()
        val downloads = device.findObject(By.text("Downloads"))
        if (downloads != null) {
            click(downloads)
            return
        }
        val drawer = listOf(
            By.descContains("Show roots"),
            By.descContains("navigation drawer"),
            By.descContains("Navigate up")
        ).firstNotNullOfOrNull { device.findObject(it) }
        if (drawer != null) {
            click(drawer)
            val after = device.wait(Until.findObject(By.text("Downloads")), 8_000L)
            if (after != null) {
                click(after)
                return
            }
        }
        assertTrue("Downloads not located in real DocumentsUI",
            device.findObject(By.textContains("Download")) != null)
    }

    private fun cancelPicker() {
        picker()
        assertTrue("Cannot go Back from Android picker", device.pressBack())
    }

    @Test
    fun actualFictionalAndroidPickerRoundTrip() {
        phase("saf_roundtrip")
        requirePhase("SAF_ROUNDTRIP_EXPORT_READY")
        picker()
        downloads()
        val save = device.wait(Until.findObject(By.text("Save")), 10_000L)
        assertTrue("Real Android Save action unavailable", save != null)
        click(save!!)
        // Only posted once native provider ciphertext readback succeeds.
        requirePhase("SAF_ROUNDTRIP_IMPORT_READY")

        picker()
        downloads()
        val file = device.wait(Until.findObject(By.textContains(filename)), 15_000L)
        assertTrue("Fictional ciphertext not visible in real picker", file != null)
        click(file!!)
        if (!seen("SAF_ROUNDTRIP_VERIFIED", 12_000L)) {
            val open = device.findObject(By.text("Open"))
                ?: device.findObject(By.desc("Open"))
            if (open != null) click(open)
            requirePhase("SAF_ROUNDTRIP_VERIFIED", 65_000L)
        }
        // No synthetic report can satisfy this: native onActivityResult must
        // return real ciphertext which the probe decrypts/authenticates.
        requirePhase("SAF_ROUNDTRIP_VERIFIED", 3_000L)

        // Exercise cancellation only after the independent real-document
        // authentication has proved the core picker flow. This avoids
        // conflating repeated app resets with the primary import verdict.
        phase("saf_export_cancel")
        requirePhase("SAF_EXPORT_READY")
        cancelPicker()
        requirePhase("SAF_EXPORT_CANCELLED")

        phase("saf_import_cancel")
        requirePhase("SAF_IMPORT_READY")
        cancelPicker()
        requirePhase("SAF_IMPORT_CANCELLED")

    }
}
