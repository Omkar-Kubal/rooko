package com.appylab.rooko

internal enum class RookCountPose(
    val pngAsset: String,
    val svgAsset: String,
) {
    READY("rook-ready-transparent.png", "rook-ready.svg"),
    STRAINED("rook-strained-transparent.png", "rook-strained.svg"),
    INJURED("rook-injured-transparent.png", "rook-injured.svg"),
    QUEASY("rook-about-to-vomit-transparent.png", "rook-about-to-vomit.svg"),
    VOMITING("rook-vomiting-transparent.png", "rook-vomiting.svg");

    companion object {
        fun fromCount(count: Int): RookCountPose {
            require(count >= 0) { "Count cannot be negative" }
            return when (count) {
                in 0..49 -> READY
                in 50..99 -> STRAINED
                in 100..149 -> INJURED
                in 150..199 -> QUEASY
                else -> VOMITING
            }
        }
    }
}
