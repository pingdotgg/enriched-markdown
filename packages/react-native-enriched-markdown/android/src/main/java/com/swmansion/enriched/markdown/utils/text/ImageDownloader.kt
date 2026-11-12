package com.swmansion.enriched.markdown.utils.text

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.graphics.createBitmap
import com.caverock.androidsvg.SVG
import com.caverock.androidsvg.SVGParseException
import okhttp3.Cache
import okhttp3.CacheControl
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.math.ceil

object ImageDownloader {
  private const val TAG = "ImageDownloader"
  private const val DISK_CACHE_SIZE = 100L * 1024 * 1024
  private const val TIMEOUT = 15L

  private val mainHandler = Handler(Looper.getMainLooper())

  @Volatile
  private var client: OkHttpClient? = null

  // No disk cache: it keys by URL alone and would mix header sets.
  @Volatile
  private var headerClient: OkHttpClient? = null
  private var maxTargetWidth: Int = 0
  private var density: Float = 1f

  private val inFlight = HashMap<String, MutableList<(Bitmap?) -> Unit>>()

  private fun getClient(context: Context): OkHttpClient =
    client ?: synchronized(this) {
      client ?: buildClient(context).also {
        client = it
        maxTargetWidth = context.applicationContext.resources.displayMetrics.widthPixels
        density = context.applicationContext.resources.displayMetrics.density
      }
    }

  private fun getHeaderClient(context: Context): OkHttpClient =
    headerClient ?: synchronized(this) {
      headerClient ?: getClient(context)
        .newBuilder()
        .cache(null)
        .build()
        .also { headerClient = it }
    }

  private fun buildClient(context: Context): OkHttpClient {
    val cacheDir = File(context.applicationContext.cacheDir, "enrm_image_cache")
    return OkHttpClient
      .Builder()
      .cache(Cache(cacheDir, DISK_CACHE_SIZE))
      .connectTimeout(TIMEOUT, TimeUnit.SECONDS)
      .readTimeout(TIMEOUT, TimeUnit.SECONDS)
      .build()
  }

  fun download(
    context: Context,
    url: String,
    headers: Map<String, String> = emptyMap(),
    callback: (Bitmap?) -> Unit,
  ) {
    val headers = ImageCache.normalizedHeaders(headers)
    val requestKey = ImageCache.requestKey(url, headers)

    ImageCache.getOriginal(requestKey)?.let {
      callback(it)
      return
    }

    synchronized(inFlight) {
      val existing = inFlight[requestKey]
      if (existing != null) {
        existing.add(callback)
        return
      }
      inFlight[requestKey] = mutableListOf(callback)
    }

    // OkHttp throws on a URL or header it cannot use; report that like any failed download.
    val request =
      try {
        Request
          .Builder()
          .url(url)
          .apply {
            headers.forEach { (name, value) -> addHeader(name, value) }
            // The HTTP cache keys by URL and server Vary, which may omit the headers
            // that make this request distinct; keep header-bearing responses out of it.
            if (headers.isNotEmpty()) {
              cacheControl(
                CacheControl
                  .Builder()
                  .noCache()
                  .noStore()
                  .build(),
              )
            }
          }.build()
      } catch (e: IllegalArgumentException) {
        Log.e(TAG, "Invalid image request: $url", e)
        dispatchCallbacks(requestKey, null)
        return
      }
    val client = if (headers.isEmpty()) getClient(context) else getHeaderClient(context)
    client.newCall(request).enqueue(
      object : Callback {
        override fun onResponse(
          call: Call,
          response: Response,
        ) {
          val bitmap =
            response.use {
              try {
                val bytes = it.body?.bytes() ?: return@use null
                decodeDownsampled(bytes, maxTargetWidth, density)
              } catch (_: OutOfMemoryError) {
                Log.e(TAG, "OOM decoding image: $url")
                null
              } catch (e: Exception) {
                Log.e(TAG, "Failed to decode image: $url", e)
                null
              }
            }

          bitmap?.let { ImageCache.putOriginal(requestKey, it) }
          dispatchCallbacks(requestKey, bitmap)
        }

        override fun onFailure(
          call: Call,
          e: IOException,
        ) {
          Log.e(TAG, "Failed to download image: $url", e)
          dispatchCallbacks(requestKey, null)
        }
      },
    )
  }

  private fun decodeDownsampled(
    bytes: ByteArray,
    targetWidth: Int,
    density: Float,
    maxDimension: Int? = null,
  ): Bitmap? {
    val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
    if (opts.outWidth <= 0 || opts.outHeight <= 0) return decodeSvg(bytes, targetWidth, density, maxDimension)
    return decodeWithSampleSize(opts, targetWidth, maxDimension) {
      BitmapFactory.decodeByteArray(bytes, 0, bytes.size, it)
    }
  }

  /**
   * Rasterizes SVG bytes, which BitmapFactory cannot read, at the screen density and no
   * wider than [targetWidth] (or [maxDimension] on the long side). Detected by content:
   * badge services serve SVG from URLs without an extension.
   */
  private fun decodeSvg(
    bytes: ByteArray,
    targetWidth: Int,
    density: Float,
    maxDimension: Int?,
  ): Bitmap? {
    val svg =
      try {
        SVG.getFromInputStream(bytes.inputStream())
      } catch (_: SVGParseException) {
        return null
      }
    val viewBox = svg.documentViewBox
    val documentWidth = svg.documentWidth.takeIf { it > 0f } ?: viewBox?.width() ?: return null
    val documentHeight = svg.documentHeight.takeIf { it > 0f } ?: viewBox?.height() ?: return null
    if (documentWidth <= 0f || documentHeight <= 0f) return null
    // Without a viewBox the document draws at its own size instead of scaling to the bitmap.
    if (viewBox == null) svg.setDocumentViewBox(0f, 0f, documentWidth, documentHeight)
    // A root width and height draw at that many pixels, ignoring the larger viewport.
    svg.setDocumentWidth("100%")
    svg.setDocumentHeight("100%")
    val limit =
      if (maxDimension != null) maxDimension / maxOf(documentWidth, documentHeight) else targetWidth / documentWidth
    val scale = minOf(density, limit.takeIf { it > 0f } ?: density)
    val bitmap = createBitmap(ceil(documentWidth * scale).toInt().coerceAtLeast(1), ceil(documentHeight * scale).toInt().coerceAtLeast(1))
    svg.renderToCanvas(Canvas(bitmap), RectF(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat()))
    return bitmap
  }

  fun decodeBytesDownsampled(
    context: Context,
    bytes: ByteArray,
    maxDimension: Int? = null,
  ): Bitmap? = context.resources.displayMetrics.let { decodeDownsampled(bytes, it.widthPixels, it.density, maxDimension) }

  fun decodeFileDownsampled(
    context: Context,
    path: String,
    maxDimension: Int? = null,
  ): Bitmap? {
    val targetWidth = context.resources.displayMetrics.widthPixels
    val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, opts)
    if (opts.outWidth <= 0 || opts.outHeight <= 0) {
      val file = File(path).takeIf { it.isFile } ?: return null
      return decodeSvg(file.readBytes(), targetWidth, context.resources.displayMetrics.density, maxDimension)
    }
    return decodeWithSampleSize(opts, targetWidth, maxDimension) {
      BitmapFactory.decodeFile(path, it)
    }
  }

  private inline fun decodeWithSampleSize(
    opts: BitmapFactory.Options,
    targetWidth: Int,
    maxDimension: Int?,
    decode: (BitmapFactory.Options) -> Bitmap?,
  ): Bitmap? {
    if (opts.outWidth <= 0 || opts.outHeight <= 0) return null
    opts.inSampleSize =
      if (maxDimension == null) {
        calculateInSampleSize(opts.outWidth, targetWidth)
      } else {
        var sample = 1
        val limit = maxDimension.coerceAtLeast(1).toLong()
        while (maxOf(opts.outWidth, opts.outHeight).toLong() > limit * sample) sample *= 2
        sample
      }
    opts.inJustDecodeBounds = false
    return decode(opts)
  }

  private fun calculateInSampleSize(
    srcWidth: Int,
    reqWidth: Int,
  ): Int {
    if (srcWidth in 0..reqWidth) return 1
    return Integer.highestOneBit(srcWidth / reqWidth)
  }

  private fun dispatchCallbacks(
    requestKey: String,
    bitmap: Bitmap?,
  ) {
    val callbacks = synchronized(inFlight) { inFlight.remove(requestKey) } ?: return
    mainHandler.post {
      callbacks.forEach { it(bitmap) }
    }
  }
}
