package com.heykakaa.rooko

import java.time.LocalDate

/** Tracks local dates already reflected by the active floating counter. */
internal class FloatingCounterDayRollover(initialLocalDate: LocalDate) {
    private var lastLocalDate = initialLocalDate

    fun hasLocalDateChanged(localDate: LocalDate): Boolean = localDate != lastLocalDate

    fun appsToRefresh(
        localDate: LocalDate,
        recognizedFeedAppIds: Set<String>,
        counterVisible: Boolean,
    ): Set<String> {
        if (localDate == lastLocalDate) return emptySet()
        lastLocalDate = localDate
        return if (counterVisible) recognizedFeedAppIds.toSet() else emptySet()
    }

    fun recordCountUpdate(localDate: LocalDate) {
        lastLocalDate = localDate
    }
}
