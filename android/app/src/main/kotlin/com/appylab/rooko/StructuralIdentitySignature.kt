package com.appylab.rooko

internal data class StructuralChildSignal(
    val resourceName: String?,
    val className: String?,
    val childCount: Int,
    val visible: Boolean,
)

/** Creates bounded signatures from layout metadata only; it has no content-bearing inputs. */
internal object StructuralIdentitySignature {
    private val resourceName = Regex("[A-Za-z_][A-Za-z0-9_]{0,79}")
    private val className = Regex("[A-Za-z0-9_.$]{1,120}")

    fun topology(
        className: String?,
        childCount: Int,
        children: List<StructuralChildSignal>,
    ): String? {
        if (childCount !in 0..MAX_CHILDREN || children.size != childCount) return null
        val safeClassName = className?.takeIf(this.className::matches) ?: return null
        val signature = buildString {
            append(safeClassName)
            append('|')
            append(childCount)
            children.forEach { child ->
                val safeChildClass = child.className?.takeIf(this@StructuralIdentitySignature.className::matches)
                    ?: "_"
                val safeChildResource = child.resourceName?.takeIf(resourceName::matches) ?: "_"
                append('|')
                append(safeChildResource)
                append(':')
                append(safeChildClass)
                append(':')
                append(child.childCount.coerceIn(0, 500))
                append(':')
                append(child.visible)
            }
        }
        return signature.takeIf { it.length <= MAX_SIGNATURE_LENGTH }
    }

    fun state(
        visible: Boolean,
        selected: Boolean,
        scrollable: Boolean,
        bounds: StructuralBounds,
    ): String {
        fun coarse(value: Int) = value / BOUNDS_BUCKET_PX * BOUNDS_BUCKET_PX
        return "visible=$visible|selected=$selected|scrollable=$scrollable|bounds=" + listOf(
            coarse(bounds.left),
            coarse(bounds.top),
            coarse(bounds.right),
            coarse(bounds.bottom),
        ).joinToString(",")
    }

    fun nodeHandleAndTopology(nodeHandle: Int, topology: String?): String? =
        topology?.takeIf { it.isNotBlank() }?.let { "handle=$nodeHandle|topology=$it" }

    const val MAX_CHILDREN = 16
    private const val MAX_SIGNATURE_LENGTH = 512
    private const val BOUNDS_BUCKET_PX = 32
}
