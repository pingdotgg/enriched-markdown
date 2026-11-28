#import "EnrichedMarkdownTextShadowNode.h"
#import "ENRMViewFreeMeasurement.h"
#import "EnrichedMarkdownText.h"
#import "ShadowMeasurementUtils.h"
#import <yoga/Yoga.h>

namespace facebook::react {

extern const char EnrichedMarkdownTextComponentName[] = "EnrichedMarkdownText";

EnrichedMarkdownTextShadowNode::EnrichedMarkdownTextShadowNode(const ShadowNodeFragment &fragment,
                                                               const ShadowNodeFamily::Shared &family,
                                                               ShadowNodeTraits traits)
    : ConcreteViewShadowNode(fragment, family, traits)
{
}

EnrichedMarkdownTextShadowNode::EnrichedMarkdownTextShadowNode(const ShadowNode &sourceShadowNode,
                                                               const ShadowNodeFragment &fragment)
    : ConcreteViewShadowNode(sourceShadowNode, fragment),
      localHeightRecalculationCounter_(
          static_cast<const EnrichedMarkdownTextShadowNode &>(sourceShadowNode).localHeightRecalculationCounter_),
      previousMeasurement_(static_cast<const EnrichedMarkdownTextShadowNode &>(sourceShadowNode).previousMeasurement_)
{
  dirtyLayoutIfNeeded();
}

void EnrichedMarkdownTextShadowNode::dirtyLayoutIfNeeded()
{
  const auto state = this->getStateData();
  const int receivedCounter = state.getHeightRecalculationCounter();

  if (receivedCounter > localHeightRecalculationCounter_) {
    localHeightRecalculationCounter_ = receivedCounter;
    YGNodeMarkDirty(&yogaNode_);
  }
}

// React Native dirties a measurable node's every clone. A parent's layout re-clones its children without
// new props (React Native's adoptYogaChild), and dirtying those clones re-measured every mounted text on
// each commit: one view's state update measured all its siblings again. New props dirty the measurement;
// the view asks for a re-measure through the height counter (dirtyLayoutIfNeeded).
bool EnrichedMarkdownTextShadowNode::shouldNewRevisionDirtyMeasurement(const ShadowNode & /*sourceShadowNode*/,
                                                                       const ShadowNodeFragment &fragment) const
{
  return fragment.props != nullptr;
}

Size EnrichedMarkdownTextShadowNode::measureContent(const LayoutContext &layoutContext,
                                                    const LayoutConstraints &layoutConstraints) const
{
  const auto propsHandle = std::static_pointer_cast<const EnrichedMarkdownTextProps>(this->getProps());
  const EnrichedMarkdownTextProps *props = propsHandle.get();
  CGFloat pointScaleFactor = layoutContext.pointScaleFactor;
  NSWritingDirection resolvedLayoutDirection = layoutConstraints.layoutDirection == LayoutDirection::RightToLeft
                                                   ? NSWritingDirectionRightToLeft
                                                   : NSWritingDirectionLeftToRight;

  return ENRMMeasureMarkdownContent<EnrichedMarkdownTextProps, EnrichedMarkdownText>(
      propsHandle, getStateData().getComponentViewRef(), getStateData().getHeightRecalculationCounter(),
      previousMeasurement_, MarkdownFlavor::CommonMark, layoutContext, layoutConstraints, resolvedLayoutDirection,
      ^id(CGFloat fontScale) {
        return ENRMRenderMarkdownViewFree(*props, ENRMStyleConfigFromProps(*props, fontScale), resolvedLayoutDirection);
      },
      ^(EnrichedMarkdownText *view, CGFloat maxWidth, CGFloat fontScale, id rendered) {
        return ENRMMeasureMarkdownViewFree(*props, maxWidth, fontScale, pointScaleFactor, resolvedLayoutDirection,
                                           rendered);
      });
}

} // namespace facebook::react
