package com.swmansion.enriched.markdown

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Paint
import android.os.Looper
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.widget.TextView
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.ImageCache
import com.swmansion.enriched.markdown.utils.text.ImageDownloader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// Issue #932: a block image with maxHeight starts at maxHeight and shrinks to its
// fitted height once the view's width is known. The TextView must rebuild its Layout
// then, or the image line keeps maxHeight and the text after it overflows the component.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ImageSpanReflowTest {
  @Test
  fun imageLineShrinksToTheFittedHeightOnceTheWidthIsKnown() {
    val context = RuntimeEnvironment.getApplication()

    ImageCache.putOriginal(ImageCache.requestKey(URL, emptyMap()), Bitmap.createBitmap(100, 50, Bitmap.Config.ARGB_8888))
    val span = ImageSpan(context, URL, styleConfig(image = mapOf("maxHeight" to MAX_HEIGHT.toDouble(), "resizeMode" to "contain")))

    val view =
      EnrichedMarkdownInternalText(context).apply {
        layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
        applyStyledText(SpannableStringBuilder("￼\nafter").apply { setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) })
      }

    layOut(view)
    assertEquals(MAX_HEIGHT, imageLineHeight(view))

    span.registerTextView(view)

    layOut(view)
    assertEquals(WIDTH / 2, imageLineHeight(view))
  }

  // Issue pingdotgg/t3code#32724: a README badge row starts with a linked image, which
  // nothing precedes, so it was laid out as a block image.
  @Test
  fun linkedImageAtTheStartOfAParagraphIsInline() {
    val image = MarkdownASTNode(NodeType.Image, attributes = mapOf("url" to "test://linked-badge"))
    val link = MarkdownASTNode(NodeType.Link, attributes = mapOf("url" to "https://example.com"), children = listOf(image))
    val rendered = render(styleConfig(), paragraph(link, text(" after")))

    val span = rendered.getSpans(0, rendered.length, ImageSpan::class.java).single()
    assertTrue(span.isInline)

    val standalone = render(styleConfig(), paragraph(link))
    assertFalse(standalone.getSpans(0, standalone.length, ImageSpan::class.java).single().isInline)
  }

  // Badges are SVG served without an extension; the type comes from the bytes.
  @Test
  fun inlineSvgImageKeepsItsAspectRatio() {
    val span = ImageSpan(RuntimeEnvironment.getApplication(), SVG_100_BY_20, styleConfig(inlineImageSize = 20.0), isInline = true)

    assertEquals(100, span.getSize(Paint(), "\uFFFC", 0, 1, null))
    assertEquals(20, span.drawable.bounds.height())
  }

  // Shields' live badges put every label inside an SVG <a>; a decoder that skips link
  // children draws the badge frame with no text.
  @Test
  fun svgContentInsideALinkIsDrawn() {
    val context = RuntimeEnvironment.getApplication()
    val linked =
      ImageDownloader.decodeBytesDownsampled(
        context,
        """<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><a href="https://example.com"><rect width="20" height="20" fill="#f00"/></a></svg>"""
          .toByteArray(),
      )!!
    assertEquals(Color.RED, linked.getPixel(linked.width / 2, linked.height / 2))

    val stars = ImageDownloader.decodeBytesDownsampled(context, javaClass.getResource("/shields-github-stars.svg")!!.readBytes())!!
    // Of the 88x20 badge, the "Stars" label spans x 22-49 and the "51k" count x 64-83, in #333.
    assertTrue(hasDarkPixel(stars, 22..49))
    assertTrue(hasDarkPixel(stars, 64..83))
  }

  @Test
  fun inlineImageWiderThanTheLineShrinksWithoutDistortion() {
    val context = RuntimeEnvironment.getApplication()
    ImageCache.putOriginal(ImageCache.requestKey(WIDE_URL, emptyMap()), Bitmap.createBitmap(800, 40, Bitmap.Config.ARGB_8888))
    val span = ImageSpan(context, WIDE_URL, styleConfig(inlineImageSize = 20.0), isInline = true)
    assertEquals(400, span.getSize(Paint(), "\uFFFC", 0, 1, null))
    val text = SpannableStringBuilder("\uFFFC").apply { setSpan(span, 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) }
    span.prepareForMeasurement(text, NARROW_WIDTH)
    assertEquals(NARROW_WIDTH, span.getSize(Paint(), text, 0, 1, null))
    assertEquals(NARROW_WIDTH, span.drawable.bounds.width())

    val view =
      EnrichedMarkdownInternalText(context).apply {
        layoutParams = ViewGroup.LayoutParams(NARROW_WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
        applyStyledText(text)
      }
    layOut(view, NARROW_WIDTH)
    span.registerTextView(view)
    layOut(view, NARROW_WIDTH)

    assertEquals(NARROW_WIDTH, span.drawable.bounds.width())
    assertEquals(NARROW_WIDTH / 20, span.drawable.bounds.height())
    assertTrue(view.layout.getLineWidth(0) <= NARROW_WIDTH)
    shadowOf(Looper.getMainLooper()).idle()

    layOut(view, WIDTH)
    assertEquals(WIDTH, span.drawable.bounds.width())
    assertEquals(WIDTH / 20, span.drawable.bounds.height())

    layOut(view, NARROW_WIDTH)
    assertEquals(NARROW_WIDTH, span.drawable.bounds.width())
    assertEquals(NARROW_WIDTH / 20, span.drawable.bounds.height())
    assertTrue(view.layout.getLineWidth(0) <= NARROW_WIDTH)
  }

  private fun layOut(
    view: TextView,
    width: Int = WIDTH,
  ) {
    view.measure(
      MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)
  }

  private fun hasDarkPixel(
    badge: Bitmap,
    columns: IntRange,
  ): Boolean {
    val scale = badge.width / 88f
    return (columns.first * scale).toInt().until((columns.last * scale).toInt()).any { x ->
      (4 * scale).toInt().until((16 * scale).toInt()).any { y ->
        badge.getPixel(x, y).let { Color.alpha(it) > 0x80 && Color.red(it) < 0x80 }
      }
    }
  }

  private fun imageLineHeight(view: TextView): Int = view.layout.getLineBottom(0) - view.layout.getLineTop(0)

  private companion object {
    const val URL = "test://issue-932"
    const val WIDTH = 400
    const val MAX_HEIGHT = 300
    const val WIDE_URL = "test://wide-inline"
    const val NARROW_WIDTH = 200

    // <svg xmlns="http://www.w3.org/2000/svg" width="100" height="20"><rect width="100" height="20" fill="#4c1"/></svg>
    const val SVG_100_BY_20 =
      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMjAiPjxyZWN0" +
        "IHdpZHRoPSIxMDAiIGhlaWdodD0iMjAiIGZpbGw9IiM0YzEiLz48L3N2Zz4="
  }
}
