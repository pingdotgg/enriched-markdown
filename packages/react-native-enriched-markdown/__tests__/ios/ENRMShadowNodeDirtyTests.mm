#import "../../ios/internals/EnrichedMarkdownComponentDescriptor.h"
#import "../../ios/internals/EnrichedMarkdownTextComponentDescriptor.h"
#import <XCTest/XCTest.h>

#include <limits>

using namespace facebook::react;

// A parent's layout clones its children without new props (React Native's adoptYogaChild). Those clones
// must keep their measurement: dirtying them re-measured every mounted text on each commit, so mounting
// N texts at once measured N² times. New props, a higher height counter (the view asking for a
// re-measure) and, for the container, new slot children still measure again.
template <typename DescriptorT> struct ENRMLaidOutNode {
  std::shared_ptr<const ContextContainer> contextContainer = std::make_shared<const ContextContainer>();
  DescriptorT descriptor{ComponentDescriptorParameters{EventDispatcher::Weak{}, contextContainer, nullptr}};
  ShadowNodeFamily::Shared family = descriptor.createFamily(ShadowNodeFamilyFragment{1, 1, nullptr});
  std::shared_ptr<ShadowNode> node;

  template <typename PropsT> ENRMLaidOutNode(std::shared_ptr<const PropsT> props)
  {
    node = descriptor.createShadowNode(ShadowNodeFragment{props, ShadowNodeFragment::childrenPlaceholder(),
                                                          descriptor.createInitialState(props, family)},
                                       family);
    static_cast<YogaLayoutableShadowNode &>(*node).layoutTree(
        LayoutContext{}, LayoutConstraints{{0, 0}, {320, std::numeric_limits<Float>::infinity()}});
  }

  bool isClean(const ShadowNode &shadowNode) const
  {
    return static_cast<const YogaLayoutableShadowNode &>(shadowNode).getIsLayoutClean();
  }

  bool cloneIsClean(const ShadowNodeFragment &fragment) const
  {
    return isClean(*descriptor.cloneShadowNode(*node, fragment));
  }
};

template <typename DescriptorT, typename PropsT, typename StateDataT>
static void ENRMCheckWhatMeasuresAgain(ENRMLaidOutNode<DescriptorT> &laidOut)
{
  XCTAssertTrue(laidOut.isClean(*laidOut.node), @"laid out");
  XCTAssertTrue(laidOut.cloneIsClean(ShadowNodeFragment{}), @"a clone without new props keeps its measurement");
  XCTAssertFalse(laidOut.cloneIsClean(ShadowNodeFragment{std::make_shared<const PropsT>()}),
                 @"new props measure again");

  auto sameCounter = laidOut.descriptor.createState(*laidOut.family, std::make_shared<const StateDataT>(0, nullptr));
  XCTAssertTrue(laidOut.cloneIsClean(ShadowNodeFragment{ShadowNodeFragment::propsPlaceholder(),
                                                        ShadowNodeFragment::childrenPlaceholder(), sameCounter}),
                @"new state with the same height counter keeps its measurement");

  auto askedAgain = laidOut.descriptor.createState(*laidOut.family, std::make_shared<const StateDataT>(1, nullptr));
  XCTAssertFalse(laidOut.cloneIsClean(ShadowNodeFragment{ShadowNodeFragment::propsPlaceholder(),
                                                         ShadowNodeFragment::childrenPlaceholder(), askedAgain}),
                 @"a higher height counter measures again");
}

@interface ENRMShadowNodeDirtyTests : XCTestCase
@end

@implementation ENRMShadowNodeDirtyTests

- (void)testTextMeasuresAgainOnlyWhenItsInputsChange
{
  ENRMLaidOutNode<EnrichedMarkdownTextComponentDescriptor> laidOut{std::make_shared<const EnrichedMarkdownTextProps>()};
  ENRMCheckWhatMeasuresAgain<EnrichedMarkdownTextComponentDescriptor, EnrichedMarkdownTextProps,
                             EnrichedMarkdownTextState>(laidOut);
}

- (void)testContainerMeasuresAgainOnlyWhenItsInputsChange
{
  ENRMLaidOutNode<EnrichedMarkdownComponentDescriptor> laidOut{std::make_shared<const EnrichedMarkdownProps>()};
  ENRMCheckWhatMeasuresAgain<EnrichedMarkdownComponentDescriptor, EnrichedMarkdownProps, EnrichedMarkdownState>(
      laidOut);

  auto slots = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>();
  XCTAssertFalse(laidOut.cloneIsClean(ShadowNodeFragment{ShadowNodeFragment::propsPlaceholder(), slots}),
                 @"new slot children measure again");
}

@end
