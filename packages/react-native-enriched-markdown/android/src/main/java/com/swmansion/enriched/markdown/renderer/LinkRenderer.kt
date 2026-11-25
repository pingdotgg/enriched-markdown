package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import android.text.TextPaint
import android.text.style.MetricAffectingSpan
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.LinkFontSpan
import com.swmansion.enriched.markdown.spans.LinkIconSpan
import com.swmansion.enriched.markdown.spans.LinkPillSpan
import com.swmansion.enriched.markdown.spans.LinkSpan
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.utils.text.extensions.applyBlockStyleFont
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import java.text.BreakIterator
import kotlin.math.max
import kotlin.math.min

private const val MAX_ICON_RUN = 24

class LinkRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  // Reused to resolve each pill's typeface; a renderer serves one render at a time.
  private val fontProbe = TextPaint()

  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val url = node.getAttribute("url") ?: return
    val recognizedLink = node.getAttribute("recognizedLink") == "true"

    factory.renderWithSpan(builder, { factory.renderChildren(node, builder, onLinkPress, onLinkLongPress) }) { start, end, blockStyle ->
      val variant = factory.styleCache.resolvedVariantForUrl(url)
      val linkSpan =
        LinkSpan(
          url,
          onLinkPress,
          onLinkLongPress,
          factory.styleCache,
          blockStyle,
          factory.context,
          recognizedLink = recognizedLink,
          keepsCodeFont = recognizedLink && node.children.any { it.type == MarkdownASTNode.NodeType.Code },
        )
      if (variant?.pill != null && canPresentAsPill(builder, factory, start, end)) {
        val fontFamily = variant.fontFamily.ifEmpty { factory.styleCache.linkFontFamily }.ifEmpty { blockStyle.fontFamily }
        val font = fontProbe.apply { applyBlockStyleFont(blockStyle.copy(fontFamily = fontFamily), factory.context) }
        val pill =
          LinkPillSpan(
            variant,
            font.typeface,
            blockStyle.fontSize,
            builder.subSequence(start, end).toString(),
            factory.context,
            config.style.linkPillContent[url],
            config.style.imageRequestHeaders,
            followsRunTypeface = variant.fontFamily.isEmpty() && factory.styleCache.linkFontFamily.isEmpty(),
          )
        // Set directly, not deferred: the pill measures with its own font, so it does not
        // need to come after the block spans, and a late insertion makes the builder re-sort.
        builder.setSpan(pill, start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
        factory.runAfterRender { text -> pill.resolveLeadingMargin(text, text.getSpanStart(pill), text.getSpanEnd(pill)) }
      } else if (variant?.inlineIcon != null && builder.getSpans(start, end, ReplacementSpan::class.java).isEmpty()) {
        // Added after the children's spans, so the link font wins when measuring as it does when drawing.
        builder.setSpan(LinkFontSpan(linkSpan), start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
        // A replacement span is neutral in bidi layout, so one over a right-to-left word could move
        // that word to the wrong end of its run. Those links keep their text and go without the icon.
        if (!startsRightToLeft(builder, start, end)) {
          builder.setSpan(
            LinkIconSpan(variant.inlineIcon, linkSpan, blockStyle.fontSize, factory.context, config.style.imageRequestHeaders),
            start,
            iconRunEnd(builder, start, end),
            SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
          )
        }
      }
      builder.setSpan(linkSpan, start, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }
  }

  /**
   * Where the icon span ends: the first point the line may break, so the icon stays with its first
   * word. A line can break on either side of a replacement span, so covering less would let that
   * word split after its first letter. Stops where the run's font changes, since a replacement is
   * measured once per run, and after [MAX_ICON_RUN] characters, so a long unbroken token still wraps.
   */
  private fun iconRunEnd(
    builder: SpannableStringBuilder,
    start: Int,
    end: Int,
  ): Int {
    val text = builder.subSequence(start, end).toString()
    val characters = BreakIterator.getCharacterInstance().apply { setText(text) }
    val firstCharacter = characters.following(0).takeIf { it != BreakIterator.DONE } ?: text.length
    val lines = BreakIterator.getLineInstance().apply { setText(text) }
    var wordEnd = lines.following(0).takeIf { it != BreakIterator.DONE } ?: text.length
    while (wordEnd > firstCharacter && text[wordEnd - 1].isWhitespace()) wordEnd--
    val limit = min(builder.nextSpanTransition(start, end, MetricAffectingSpan::class.java) - start, MAX_ICON_RUN)
    var runEnd = min(wordEnd, limit)
    if (runEnd > firstCharacter && !characters.isBoundary(runEnd)) runEnd = characters.preceding(runEnd)
    return start + max(firstCharacter, runEnd)
  }

  private fun startsRightToLeft(
    builder: CharSequence,
    start: Int,
    end: Int,
  ): Boolean {
    var index = start
    while (index < end) {
      val codePoint = Character.codePointAt(builder, index)
      when (Character.getDirectionality(codePoint)) {
        Character.DIRECTIONALITY_LEFT_TO_RIGHT -> return false
        Character.DIRECTIONALITY_RIGHT_TO_LEFT, Character.DIRECTIONALITY_RIGHT_TO_LEFT_ARABIC -> return true
      }
      index += Character.charCount(codePoint)
    }
    return false
  }

  /**
   * A pill replaces one unbroken run. Links that already hold a replacement (image,
   * math) or span a line break stay ordinary links: a replacement straddling two
   * paragraphs would be drawn once per paragraph. So do links holding a spoiler,
   * whose hidden text the label would show.
   */
  private fun canPresentAsPill(
    builder: SpannableStringBuilder,
    factory: RendererFactory,
    start: Int,
    end: Int,
  ): Boolean {
    if (builder.getSpans(start, end, ReplacementSpan::class.java).isNotEmpty()) return false
    // Spoiler spans are deferred, so the ones inside this link are not in the builder yet.
    if (factory.hasDeferredSpan(SpoilerSpan::class.java, start, end)) return false
    for (index in start until end) {
      val char = builder[index]
      if (char == '\n' || char == '\r' || char == '\u2028' || char == '\u2029') return false
    }
    return true
  }
}
