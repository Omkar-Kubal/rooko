package com.appylab.rooko

/** Tracks whether the Accessibility service is connected and currently processing events. */
internal class AccessibilityServiceHealth {
    private var connected = false
    private var interrupted = false

    val isOperational: Boolean
        get() = connected && !interrupted

    fun onServiceConnected() {
        connected = true
        interrupted = false
    }

    fun onInterrupt() {
        if (connected) interrupted = true
    }

    fun onAccessibilityEventReceived() {
        if (connected) interrupted = false
    }

    fun onServiceDisconnected() {
        connected = false
        interrupted = false
    }
}
