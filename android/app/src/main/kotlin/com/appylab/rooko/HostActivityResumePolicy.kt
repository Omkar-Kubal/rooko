package com.appylab.rooko

/** Takes one-shot feed-exit candidates when the real Rooko Activity resumes. */
internal object HostActivityResumePolicy {
    fun consumeRecognizedFeedExits(recognizedFeedAppIds: MutableSet<String>): Set<String> =
        recognizedFeedAppIds.toSet().also { recognizedFeedAppIds.clear() }
}
