package com.appylab.rooko

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
            }, 12.dp())
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
            addView(rook, FrameLayout.LayoutParams(76.dp(), 76.dp()).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            })
            addView(count, FrameLayout.LayoutParams(34.dp(), 34.dp()).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                topMargin = 72.dp()
            })
            addView(close, FrameLayout.LayoutParams(48.dp(), 48.dp(), Gravity.TOP or Gravity.END))
        }
        val params = WindowManager.LayoutParams(
            88.dp(),
            110.dp(),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = ((context.resources.displayMetrics.widthPixels - 88.dp()) / 2).coerceAtLeast(0)
            y = 0
        }
        attachDrag(view, listOf(rook, count, view), params)
        return try {
            windowManager.addView(view, params)
            bubble = view
            countValue = count
            rookImage = rook
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
                        .coerceIn(0, (metrics.widthPixels - view.width).coerceAtLeast(0))
                    params.y = (initialY + (event.rawY - downY).roundToInt())
                        .coerceIn(0, (metrics.heightPixels - view.height).coerceAtLeast(0))
                    try {
                        windowManager.updateViewLayout(view, params)
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
    }
}
