package com.appylab.rooko

/** Keeps the current overlay total available without waiting on Room from Accessibility events. */
internal class FloatingCounterTotalCache {
    internal data class LoadTicket(
        val localDate: String,
        val appIds: Set<String>,
        val generation: Long,
        val revision: Long,
    )

    private var localDate: String? = null
    private var appIds: Set<String> = emptySet()
    private var generation = 0L
    private var revision = 0L
    private var loaded = false

    var total: Int = 0
        private set

    val isLoaded: Boolean
        get() = loaded

    fun setScope(localDate: String, appIds: Set<String>): Boolean {
        if (this.localDate == localDate && this.appIds == appIds) return false
        this.localDate = localDate
        this.appIds = appIds.toSet()
        generation += 1L
        revision = 0L
        loaded = false
        total = 0
        return true
    }

    fun beginLoad(): LoadTicket {
        val date = checkNotNull(localDate) { "Counter total scope must be set before loading" }
        return LoadTicket(date, appIds, generation, revision)
    }

    /** Returns false when a newer scope or count event makes this query stale. */
    fun acceptLoad(ticket: LoadTicket, total: Int): Boolean {
        if (ticket.localDate != localDate || ticket.appIds != appIds ||
            ticket.generation != generation || ticket.revision != revision
        ) return false
        this.total = total.coerceAtLeast(0)
        loaded = true
        return true
    }

    /** Called only after the count store accepted and persisted a new event. */
    fun recordCountedEvent(): Int {
        revision += 1L
        if (loaded) total += 1
        return total
    }
}
