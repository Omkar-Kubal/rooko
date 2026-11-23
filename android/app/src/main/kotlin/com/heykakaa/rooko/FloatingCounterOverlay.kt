package com.heykakaa.rooko

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.InsetDrawable
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.caverock.androidsvg.SVG
import kotlin.math.roundToInt

/** A downsampled transparent count pose and the shared local daily total. */
internal class FloatingCounterOverlay(
    private val context: Context,
    private val onDismiss: () -> Unit,
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var bubble: FrameLayout? = null
    private var countValue: TextView? = null
    private var rookImage: ImageView? = null
    private var closeButton: TextView? = null
    private var lastLabel: String? = null
    private var lastPose: RookCountPose? = null
    private var rookBitmap: Bitmap? = null

    val isShowing: Boolean
        get() = bubble != null

    fun show(count: Int) = render(count, "$count Reels and Shorts counted today")

    private fun render(count: Int, description: String): Boolean {
        if (!Settings.canDrawOverlays(context)) {
            hide()
            return false
        }
        val pose = RookCountPose.fromCount(count)
        if (bubble == null && !createBubble()) return false
        if (pose != lastPose) showPose(pose)
        if (lastLabel == description) return true
        countValue?.text = count.toString()
        bubble?.contentDescription = description
        lastLabel = description
        return true
    }

    fun hide() {
        closeButton?.let { view ->
            try {
                windowManager.removeViewImmediate(view)
            } catch (_: IllegalArgumentException) {
                // Android may already have removed the window after permission loss.
            }
        }
        bubble?.let { view ->
            try {
                windowManager.removeViewImmediate(view)
            } catch (_: IllegalArgumentException) {
                // Android may already have removed the window after permission loss.
            }
        }
        bubble = null
        countValue = null
        rookImage = null
        closeButton = null
        lastPose = null
        lastLabel = null
        rookBitmap?.recycle()
        rookBitmap = null
    }

    private fun createBubble(): Boolean {
        val count = TextView(context).apply {
            textSize = 12f
            setTextColor(Palette.textOnDark)
            typeface = loadFont("GoogleSans-SemiBold.ttf")
            maxLines = 1
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Palette.badge)
                setStroke(1.dp(), Palette.badgeOutline)
            }
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        val rook = ImageView(context).apply {
            scaleType = ImageView.ScaleType.FIT_CENTER
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        val close = TextView(context).apply {
            text = "×"
            textSize = 20f
            setTextColor(Palette.closeGlyph)
            setShadowLayer(2f, 0f, 1f, Palette.closeShadow)
            gravity = Gravity.CENTER
            background = InsetDrawable(GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Palette.badge)
                setStroke(1.dp(), Palette.badgeOutline)
            }, CLOSE_BACKGROUND_INSET_DP.dp())
            contentDescription = "Hide floating counter"
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            isClickable = true
            isFocusable = true
            setOnClickListener {
                onDismiss()
                hide()
            }
        }
        val view = FrameLayout(context).apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            contentDescription = "Floating counter"
            addView(rook, FrameLayout.LayoutParams(ROOK_SIZE_DP.dp(), ROOK_SIZE_DP.dp()).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            })
            addView(count, FrameLayout.LayoutParams(34.dp(), 34.dp()).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                topMargin = COUNT_BADGE_TOP_MARGIN_DP.dp()
            })
        }
        val params = WindowManager.LayoutParams(
            BUBBLE_WIDTH_DP.dp(),
            BUBBLE_HEIGHT_DP.dp(),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = ((context.resources.displayMetrics.widthPixels - BUBBLE_WIDTH_DP.dp()) / 2)
                .coerceAtLeast(0)
            y = 0
        }
        val closeParams = WindowManager.LayoutParams(
            CLOSE_WINDOW_SIZE_DP.dp(),
            CLOSE_WINDOW_SIZE_DP.dp(),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = params.x + CLOSE_WINDOW_OFFSET_X_DP.dp()
            y = params.y
        }
        attachDrag(view, listOf(rook, count, view), params, close, closeParams)
        return try {
            windowManager.addView(view, params)
            try {
                windowManager.addView(close, closeParams)
            } catch (_: Exception) {
                windowManager.removeViewImmediate(view)
                return false
            }
            bubble = view
            countValue = count
            rookImage = rook
            closeButton = close
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun showPose(pose: RookCountPose) {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        val boundsRead = runCatching {
            context.assets.open(rookPngAsset(pose)).use {
                BitmapFactory.decodeStream(it, null, options)
            }
        }.isSuccess
        val decoded = if (boundsRead) {
            options.inJustDecodeBounds = false
            options.inPreferredConfig = Bitmap.Config.ARGB_8888
            options.inSampleSize = calculateInSampleSize(options, TARGET_IMAGE_SIZE)
            runCatching {
                context.assets.open(rookPngAsset(pose)).use {
                    BitmapFactory.decodeStream(it, null, options)
                }
            }.getOrNull()
        } else {
            null
        }
        val nextBitmap = decoded?.let { bitmap ->
            if (bitmap.width == TARGET_IMAGE_SIZE && bitmap.height == TARGET_IMAGE_SIZE) {
                bitmap
            } else {
                Bitmap.createScaledBitmap(bitmap, TARGET_IMAGE_SIZE, TARGET_IMAGE_SIZE, true)
                    .also { if (it !== bitmap) bitmap.recycle() }
            }
        } ?: renderSvg(pose)

        rookImage?.setImageBitmap(nextBitmap)
        rookBitmap?.recycle()
        rookBitmap = nextBitmap
        lastPose = pose
    }

    private fun renderSvg(pose: RookCountPose): Bitmap? = runCatching {
        val picture = SVG.getFromAsset(context.assets, rookSvgAsset(pose))
            .renderToPicture(TARGET_IMAGE_SIZE, TARGET_IMAGE_SIZE)
        Bitmap.createBitmap(
            TARGET_IMAGE_SIZE,
            TARGET_IMAGE_SIZE,
            Bitmap.Config.ARGB_8888,
        ).also { bitmap -> Canvas(bitmap).drawPicture(picture) }
    }.getOrNull()

    private fun rookPngAsset(pose: RookCountPose) =
        "flutter_assets/assets/rook/${pose.pngAsset}"

    private fun rookSvgAsset(pose: RookCountPose) =
        "flutter_assets/assets/rook/${pose.svgAsset}"

    private fun calculateInSampleSize(
        options: BitmapFactory.Options,
        targetSize: Int,
    ): Int {
        var sampleSize = 1
        var halfWidth = options.outWidth / 2
        var halfHeight = options.outHeight / 2
        while (halfWidth / sampleSize >= targetSize && halfHeight / sampleSize >= targetSize) {
            sampleSize *= 2
        }
        return sampleSize
    }

    private fun attachDrag(
        view: View,
        handles: List<View>,
        params: WindowManager.LayoutParams,
        closeView: View,
        closeParams: WindowManager.LayoutParams,
    ) {
        var downX = 0f
        var downY = 0f
        var initialX = 0
        var initialY = 0
        val listener = View.OnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    initialX = params.x
                    initialY = params.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val metrics = context.resources.displayMetrics
                    params.x = (initialX + (event.rawX - downX).roundToInt())
                        .coerceIn(
                            0,
                            (metrics.widthPixels - TOTAL_OVERLAY_WIDTH_DP.dp()).coerceAtLeast(0),
                        )
                    params.y = (initialY + (event.rawY - downY).roundToInt())
                        .coerceIn(0, (metrics.heightPixels - view.height).coerceAtLeast(0))
                    try {
                        windowManager.updateViewLayout(view, params)
                        closeParams.x = params.x + CLOSE_WINDOW_OFFSET_X_DP.dp()
                        closeParams.y = params.y
                        windowManager.updateViewLayout(closeView, closeParams)
                    } catch (_: IllegalArgumentException) {
                        hide()
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> true
                else -> false
            }
        }
        handles.forEach { it.setOnTouchListener(listener) }
    }

    private fun loadFont(fileName: String): Typeface = try {
        Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/$fileName")
    } catch (_: Exception) {
        Typeface.create("sans-serif", Typeface.NORMAL)
    }

    private fun Int.dp(): Int = (this * context.resources.displayMetrics.density).roundToInt()

    private object Palette {
        val textOnDark = Color.rgb(255, 255, 255)
        val badge = Color.rgb(0, 0, 0)
        val badgeOutline = Color.rgb(255, 255, 255)
        val closeGlyph = Color.rgb(255, 255, 255)
        val closeShadow = Color.argb(180, 0, 0, 0)
    }

    private companion object {
        const val TARGET_IMAGE_SIZE = 256
        const val BUBBLE_WIDTH_DP = 88
        const val BUBBLE_HEIGHT_DP = 106
        const val ROOK_SIZE_DP = 76
        const val COUNT_BADGE_TOP_MARGIN_DP = 68
        const val CLOSE_WINDOW_SIZE_DP = 48
        const val CLOSE_BACKGROUND_INSET_DP = 12
        const val ROOK_ART_RIGHT_INSET_DP = 8
        const val CLOSE_WINDOW_OFFSET_X_DP =
            (BUBBLE_WIDTH_DP - ROOK_SIZE_DP) / 2 + ROOK_SIZE_DP -
                CLOSE_BACKGROUND_INSET_DP - ROOK_ART_RIGHT_INSET_DP
        const val TOTAL_OVERLAY_WIDTH_DP = CLOSE_WINDOW_OFFSET_X_DP + CLOSE_WINDOW_SIZE_DP
    }
}
