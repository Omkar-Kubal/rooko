package com.appylab.rooko

/** Debug evidence contains only static Android resource names and coarse event metadata. */
internal object StructuralProbeFormatter {
    private val resourceName = Regex("[A-Za-z_][A-Za-z0-9_]{0,79}")
    private val className = Regex("[A-Za-z0-9_.$]{1,120}")
    private val version = Regex("[A-Za-z0-9._-]{1,80}")

    fun resourceNameFor(fullViewId: String?, packageName: String): String? {
        val prefix = "$packageName:id/"
        if (fullViewId?.startsWith(prefix) != true) return null
        return fullViewId.removePrefix(prefix).takeIf(resourceName::matches)
    }

    fun format(
        appId: String,
        versionName: String,
        eventType: Int,
        fromIndex: Int,
        toIndex: Int,
        sourceId: String?,
        viewIds: Set<String>,
        nodeFeatures: List<StructuralNodeFeature> = emptyList(),
        elapsedRealtimeMillis: Long,
    ): String {
        val safeVersion = versionName.takeIf(version::matches) ?: "unknown"
        val safeSource = sourceId?.takeIf(resourceName::matches).orEmpty()
        val safeIds = viewIds.asSequence()
            .filter(resourceName::matches)
            .distinct()
            .sorted()
            .take(64)
            .joinToString(",")
        val safeFeatures = nodeFeatures.asSequence()
            .filter { resourceName.matches(it.resourceName) }
            .mapNotNull { feature ->
                val safeClassName = feature.className?.takeIf(className::matches) ?: return@mapNotNull null
                val bounds = listOf(
                    feature.bounds.left,
                    feature.bounds.top,
                    feature.bounds.right,
                    feature.bounds.bottom,
                ).joinToString(",")
                val base = listOf(
                    feature.resourceName,
                    safeClassName,
                    feature.childCount.coerceIn(0, 500),
                    feature.scrollable,
                    feature.selected,
                    feature.visible,
                    bounds,
                ).joinToString("|")
                val ordinal = feature.identityOrdinal?.takeIf { it in 0..500 }
                    ?: return@mapNotNull base
                val relations = buildList {
                    feature.uniqueIdRelation?.let { add("identity$ordinal=${it.wireValue}") }
                    feature.alternativeIdentityRelations?.let { signals ->
                        add("nodehandle$ordinal=${signals.nodeHandle.wireValue}")
                        add("topology$ordinal=${signals.topology.wireValue}")
                        add("state$ordinal=${signals.state.wireValue}")
                    }
                }
                if (relations.isEmpty()) base else "$base|${relations.joinToString("|")}"
            }
            .distinct()
            .sorted()
            .take(48)
            .joinToString(";")
        val coarseTime = elapsedRealtimeMillis / 100L * 100L
        return listOf(
            coarseTime, appId, safeVersion, eventType, fromIndex, toIndex,
            safeSource, safeIds, safeFeatures,
        ).joinToString("\t")
    }
}

internal data class StructuralNodeFeature(
    val resourceName: String,
    val className: String?,
    val childCount: Int,
    val scrollable: Boolean,
    val selected: Boolean,
    val visible: Boolean,
    val bounds: StructuralBounds,
    val identityOrdinal: Int? = null,
    val uniqueIdRelation: UniqueIdRelation? = null,
    val alternativeIdentityRelations: AlternativeIdentityRelations? = null,
)

internal data class StructuralBounds(
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int,
)
