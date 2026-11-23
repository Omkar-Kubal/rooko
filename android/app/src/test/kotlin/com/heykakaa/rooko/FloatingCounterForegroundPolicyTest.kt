package com.heykakaa.rooko

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FloatingCounterForegroundPolicyTest {
    @Test
    fun differentKnownPackageHidesEvenBeforeWindowStateEvent() {
        assertTrue(
            FloatingCounterForegroundPolicy.shouldHide(
                activeCounterPackageName = "com.instagram.android",
                eventPackageName = "com.google.android.youtube",
                windowStateChanged = false,
            ),
        )
    }

    @Test
    fun samePackageDoesNotHideTheCounter() {
        assertFalse(
            FloatingCounterForegroundPolicy.shouldHide(
                activeCounterPackageName = "com.instagram.android",
                eventPackageName = "com.instagram.android",
                windowStateChanged = true,
            ),
        )
    }

    @Test
    fun unknownPackageOnlyHidesForAWindowStateChange() {
        assertFalse(
            FloatingCounterForegroundPolicy.shouldHide(
                activeCounterPackageName = "com.instagram.android",
                eventPackageName = null,
                windowStateChanged = false,
            ),
        )
        assertTrue(
            FloatingCounterForegroundPolicy.shouldHide(
                activeCounterPackageName = "com.instagram.android",
                eventPackageName = null,
                windowStateChanged = true,
            ),
        )
    }
}
