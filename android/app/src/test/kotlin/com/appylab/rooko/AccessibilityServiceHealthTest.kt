package com.appylab.rooko

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AccessibilityServiceHealthTest {
    @Test
    fun reportsDisconnectedInterruptedRecoveredAndDisconnectedStates() {
        val health = AccessibilityServiceHealth()

        assertFalse(health.isOperational)
        health.onServiceConnected()
        assertTrue(health.isOperational)
        health.onInterrupt()
        assertFalse(health.isOperational)
        health.onAccessibilityEventReceived()
        assertTrue(health.isOperational)
        health.onServiceDisconnected()
        assertFalse(health.isOperational)
    }
}
