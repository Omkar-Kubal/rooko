package com.appylab.rooko

import android.content.Context
import android.view.View
import android.view.ViewGroup
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

        val bubbleField = FloatingCounterOverlay::class.java.getDeclaredField("bubble")
            .apply { isAccessible = true }
        val bubble = bubbleField.get(overlay) as ViewGroup
        val dismiss = findView(bubble) { it.contentDescription == "Hide floating counter" }
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

    private fun findView(root: ViewGroup, matches: (View) -> Boolean): View? {
        for (index in 0 until root.childCount) {
            val child = root.getChildAt(index)
            if (matches(child)) return child
            if (child is ViewGroup) {
                findView(child, matches)?.let { return it }
            }
        }
        return null
    }
}
