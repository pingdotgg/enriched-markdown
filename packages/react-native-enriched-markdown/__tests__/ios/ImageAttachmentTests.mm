#import "../../ios/attachments/ENRMImageAttachment.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/renderer/AttributedRenderer.h"
#import "../../ios/renderer/RenderContext.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/RuntimeKeys.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

// <svg xmlns="http://www.w3.org/2000/svg" width="100" height="20"><rect width="100" height="20" fill="#4c1"/></svg>
static NSString *const ENRMSvg100By20 =
    @"data:image/"
    @"svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMjAiPjxyZWN0"
    @"IHdpZHRoPSIxMDAiIGhlaWdodD0iMjAiIGZpbGw9IiM0YzEiLz48L3N2Zz4=";

static StyleConfig *ENRMImageTestConfig(void)
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setInlineImageSize:20];
  [config setImageHeight:200];
  return config;
}

static ENRMImageAttachment *ENRMFirstImageAttachment(NSAttributedString *text)
{
  __block ENRMImageAttachment *found = nil;
  [text enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:0
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if ([value isKindOfClass:[ENRMImageAttachment class]]) {
                    found = value;
                    *stop = YES;
                  }
                }];
  return found;
}

@interface ENRMImageAttachmentTests : XCTestCase
@end

@implementation ENRMImageAttachmentTests

// pingdotgg/t3code#32724: a README badge row starts with a linked image, which nothing
// precedes, so it was laid out as a block image.
- (void)testLinkedImageAtTheStartOfAParagraphIsInline
{
  MarkdownASTNode *image = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeImage];
  image.attributes[@"url"] = @"test://linked-badge";
  MarkdownASTNode *link = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeLink];
  link.attributes[@"url"] = @"https://example.com";
  [link addChild:image];
  MarkdownASTNode *after = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeText];
  after.content = @" after";
  MarkdownASTNode *paragraph = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeParagraph];
  [paragraph addChild:link];
  [paragraph addChild:after];

  AttributedRenderer *renderer = [[AttributedRenderer alloc] initWithConfig:ENRMImageTestConfig()];
  NSAttributedString *text = [renderer renderNodes:@[ paragraph ] context:[[RenderContext alloc] init] block:nil];

  XCTAssertTrue(ENRMFirstImageAttachment(text).isInline);
}

// Badges are SVG served without an extension; the type comes from the bytes. The image
// arrives after the first layout, which then has to make room for its real width.
- (void)testInlineSvgImageTakesItsAspectRatioOnceLoaded
{
  ENRMImageAttachment *attachment = [ENRMImageAttachment attachmentForURL:ENRMSvg100By20
                                                                   config:ENRMImageTestConfig()
                                                                 isInline:YES];
  NSMutableAttributedString *text =
      [[NSMutableAttributedString alloc] initWithString:@"a "
                                             attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:16]}];
  [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
  UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
  textView.textContainer.lineFragmentPadding = 0;
  objc_setAssociatedObject(textView.textContainer, kTextViewKey, textView, OBJC_ASSOCIATION_ASSIGN);
  textView.attributedText = text;

  NSLayoutManager *layoutManager = textView.layoutManager;
  NSRange glyphs = [layoutManager glyphRangeForCharacterRange:NSMakeRange(2, 1) actualCharacterRange:NULL];
  CGSize (^laidOutSize)(void) = ^{
    [layoutManager ensureLayoutForTextContainer:textView.textContainer];
    return [layoutManager boundingRectForGlyphRange:glyphs inTextContainer:textView.textContainer].size;
  };
  XCTAssertEqualWithAccuracy(laidOutSize().width, 20, 0.5);

  NSPredicate *loaded = [NSPredicate
      predicateWithBlock:^BOOL(id object, NSDictionary *bindings) { return fabs(laidOutSize().width - 100) < 0.5; }];
  [self waitForExpectations:@[ [[XCTNSPredicateExpectation alloc] initWithPredicate:loaded object:nil] ] timeout:5];

  XCTAssertNotNil(attachment.image);
  XCTAssertEqualWithAccuracy(attachment.bounds.size.height, 20, 0.5);
}

- (void)testInlineImageWiderThanTheLineShrinksWithoutDistortion
{
  NSString *url = @"test://wide-inline";
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.scale = 1;
  UIImage *wide = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(800, 40) format:format]
      imageWithActions:^(UIGraphicsImageRendererContext *context){}];
  [[ENRMImageAttachment originalImageCache] setObject:wide forKey:url];

  ENRMImageAttachment *attachment = [ENRMImageAttachment attachmentForURL:url
                                                                   config:ENRMImageTestConfig()
                                                                 isInline:YES];
  CGRect roomy = [attachment attachmentBoundsForTextContainer:nil
                                         proposedLineFragment:CGRectMake(0, 0, 1000, 20)
                                                glyphPosition:CGPointZero
                                               characterIndex:0];
  XCTAssertEqualWithAccuracy(roomy.size.width, 400, 0.5);
  XCTAssertEqualWithAccuracy(roomy.size.height, 20, 0.5);

  CGRect narrow = [attachment attachmentBoundsForTextContainer:nil
                                          proposedLineFragment:CGRectMake(0, 0, 200, 20)
                                                 glyphPosition:CGPointZero
                                                characterIndex:0];
  XCTAssertEqualWithAccuracy(narrow.size.width, 200, 0.5);
  XCTAssertEqualWithAccuracy(narrow.size.height, 10, 0.5);
}

@end
