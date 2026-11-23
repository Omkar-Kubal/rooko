package com.appylab.rooko

import android.content.Context
import android.view.View
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.shadows.ShadowSettings
import kotlin.math.roundToInt

@RunWith(RobolectricTestRunner::class)
class FloatingCounterOverlayAccessibilityTest {
    @Test
    fun dismissControlHasAnAccessible48DpTouchTarget() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        ShadowSettings.setCanDrawOverlays(true)

        val overlay = FloatingCounterOverlay(context) {}
        assertTrue(overlay.show(0))

        val dismissField = FloatingCounterOverlay::class.java
            .getDeclaredField("closeButton")
            .apply { isAccessible = true }
        val dismiss = dismissField.get(overlay) as? View
        assertNotNull(dismiss)
        dismiss as TextView

        val expectedSizePx = (48 * context.resources.displayMetrics.density).roundToInt()
        val params = dismiss.layoutParams
        assertEquals(expectedSizePx, params.width)
        assertEquals(expectedSizePx, params.height)
        assertTrue(dismiss.isClickable)
        assertTrue(dismiss.isFocusable)

        overlay.hide()
    }
}
