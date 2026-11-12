#import "../../ios/attachments/ENRMImageAttachment.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/renderer/AttributedRenderer.h"
#import "../../ios/renderer/RenderContext.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMImageDownloader.h"
#import "../../ios/utils/RuntimeKeys.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

// <svg xmlns="http://www.w3.org/2000/svg" width="100" height="20"><rect width="100" height="20" fill="#4c1"/></svg>
static NSString *const ENRMSvg100By20 =
    @"data:image/"
    @"svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMjAiPjxyZWN0"
    @"IHdpZHRoPSIxMDAiIGhlaWdodD0iMjAiIGZpbGw9IiM0YzEiLz48L3N2Zz4=";

// The live https://img.shields.io/github/stars/pingdotgg/t3code badge, as served.
static NSString *const ENRMShieldsStarsSvg =
    @"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"88\" height=\"20\"><style>a:hover #llink{fill:url(#b"
    @");stroke:#ccc}a:hover #rlink{fill:#4183c4}</style><linearGradient id=\"a\" x2=\"0\" y2=\"100%\"><stop "
    @"offset=\"0\" stop-color=\"#fcfcfc\" stop-opacity=\"0\"/><stop offset=\"1\" stop-opacity=\".1\"/></linearGr"
    @"adient><linearGradient id=\"b\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#ccc\" stop-opacity=\""
    @".1\"/><stop offset=\"1\" stop-opacity=\".1\"/></linearGradient><g stroke=\"#d5d5d5\"><rect stroke=\"none"
    @"\" fill=\"#fcfcfc\" x=\".5\" y=\".5\" width=\"54\" height=\"19\" rx=\"2\"/><rect x=\"60.5\" y=\".5\" "
    @"width=\"27\" h"
    @"eight=\"19\" rx=\"2\" fill=\"#fafafa\"/><rect x=\"60\" y=\"7.5\" width=\".5\" height=\"5\" stroke=\"#fafafa\"/><"
    @"path d=\"M60.5 6.5 l-3 3v1 l3 3\" fill=\"#fafafa\"/></g><image x=\"5\" y=\"3\" width=\"14\" height=\"14\" hr"
    @"ef=\"data:image/svg+xml;base64,PHN2ZyBmaWxsPSIjMTgxNzE3IiByb2xlPSJpbWciIHZpZXdCb3g9IjAgMCAyNCAyNC"
    @"IgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48dGl0bGU+R2l0SHViPC90aXRsZT48cGF0aCBkPSJNMTIgLj"
    @"I5N2MtNi42MyAwLTEyIDUuMzczLTEyIDEyIDAgNS4zMDMgMy40MzggOS44IDguMjA1IDExLjM4NS42LjExMy44Mi0uMjU4Lj"
    @"gyLS41NzcgMC0uMjg1LS4wMS0xLjA0LS4wMTUtMi4wNC0zLjMzOC43MjQtNC4wNDItMS42MS00LjA0Mi0xLjYxQzQuNDIyID"
    @"E4LjA3IDMuNjMzIDE3LjcgMy42MzMgMTcuN2MtMS4wODctLjc0NC4wODQtLjcyOS4wODQtLjcyOSAxLjIwNS4wODQgMS44Mz"
    @"ggMS4yMzYgMS44MzggMS4yMzYgMS4wNyAxLjgzNSAyLjgwOSAxLjMwNSAzLjQ5NS45OTguMTA4LS43NzYuNDE3LTEuMzA1Lj"
    @"c2LTEuNjA1LTIuNjY1LS4zLTUuNDY2LTEuMzMyLTUuNDY2LTUuOTMgMC0xLjMxLjQ2NS0yLjM4IDEuMjM1LTMuMjItLjEzNS"
    @"0uMzAzLS41NC0xLjUyMy4xMDUtMy4xNzYgMCAwIDEuMDA1LS4zMjIgMy4zIDEuMjMuOTYtLjI2NyAxLjk4LS4zOTkgMy0uND"
    @"A1IDEuMDIuMDA2IDIuMDQuMTM4IDMgLjQwNSAyLjI4LTEuNTUyIDMuMjg1LTEuMjMgMy4yODUtMS4yMy42NDUgMS42NTMuMj"
    @"QgMi44NzMuMTIgMy4xNzYuNzY1Ljg0IDEuMjMgMS45MSAxLjIzIDMuMjIgMCA0LjYxLTIuODA1IDUuNjI1LTUuNDc1IDUuOT"
    @"IuNDIuMzYuODEgMS4wOTYuODEgMi4yMiAwIDEuNjA2LS4wMTUgMi44OTYtLjAxNSAzLjI4NiAwIC4zMTUuMjEuNjkuODI1Lj"
    @"U3QzIwLjU2NSAyMi4wOTIgMjQgMTcuNTkyIDI0IDEyLjI5N2MwLTYuNjI3LTUuMzczLTEyLTEyLTEyIi8+PC9zdmc+\"/><g "
    @"aria-hidden=\"false\" fill=\"#333\" text-anchor=\"middle\" font-family=\"Helvetica Neue,Helvetica,Arial"
    @",sans-serif\" text-rendering=\"geometricPrecision\" font-weight=\"700\" font-size=\"110px\" line-height"
    @"=\"14px\"><a target=\"_blank\" href=\"https://github.com/pingdotgg/t3code\"><text aria-hidden=\"true\" x"
    @"=\"355\" y=\"150\" fill=\"#fff\" transform=\"scale(.1)\" textLength=\"270\">Stars</text><text x=\"355\" y=\"1"
    @"40\" transform=\"scale(.1)\" textLength=\"270\">Stars</text><rect id=\"llink\" stroke=\"#d5d5d5\" fill=\"u"
    @"rl(#a)\" x=\".5\" y=\".5\" width=\"54\" height=\"19\" rx=\"2\"/></a><a target=\"_blank\" href=\"https://github"
    @".com/pingdotgg/t3code/stargazers\"><rect width=\"28\" x=\"60\" height=\"20\" fill=\"rgba(0,0,0,0)\"/><tex"
    @"t aria-hidden=\"true\" x=\"735\" y=\"150\" fill=\"#fff\" transform=\"scale(.1)\" textLength=\"190\">51k</tex"
    @"t><text id=\"rlink\" x=\"735\" y=\"140\" transform=\"scale(.1)\" textLength=\"190\">51k</text></a></g></sv"
    @"g>";

// RGBA pixels, top row first, of image data decoded the way Markdown images are and drawn
// into a width x height sRGB canvas.
static NSData *ENRMRasterizeImageData(NSData *data, size_t width, size_t height)
{
  RCTUIImage *image = ENRMDecodeImageData(data);
  if (!image)
    return nil;
  NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
  CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space,
                                               (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
  CGColorSpaceRelease(space);
  CGContextTranslateCTM(context, 0, height);
  CGContextScaleCTM(context, 1, -1);
  UIGraphicsPushContext(context);
  [image drawInRect:CGRectMake(0, 0, width, height)];
  UIGraphicsPopContext();
  CGContextRelease(context);
  return pixels;
}

// Whether an opaque dark pixel lies in the given columns of a 20pt-high badge's text band.
static BOOL ENRMHasDarkPixel(NSData *pixels, size_t width, size_t scale, NSRange columns)
{
  if (pixels.length < width * 20 * scale * 4)
    return NO;
  const uint8_t *bytes = (const uint8_t *)pixels.bytes;
  for (size_t y = 4 * scale; y < 16 * scale; y++) {
    for (size_t x = columns.location * scale; x < NSMaxRange(columns) * scale; x++) {
      const uint8_t *pixel = bytes + (y * width + x) * 4;
      if (pixel[3] > 0x80 && pixel[0] < 0x80)
        return YES;
    }
  }
  return NO;
}

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

@interface ENRMImageTestTextView : UITextView <ENRMImageLayoutObserver>
@property (nonatomic, strong) XCTestExpectation *layoutResolved;
@end

@implementation ENRMImageTestTextView
- (void)imageAttachmentDidResolveLayout
{
  [self.layoutResolved fulfill];
  self.layoutResolved = nil;
}
@end

@interface ENRMImageAttachmentTests : XCTestCase
@end

@implementation ENRMImageAttachmentTests

// pingdotgg/t3code#32724: a README badge row starts with a linked image, which nothing
// precedes, so it was laid out as a block image.
- (void)testLinkedImagesInABadgeRowAreInline
{
  MarkdownASTNode *image = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeImage];
  image.attributes[@"url"] = @"test://linked-badge";
  MarkdownASTNode *link = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeLink];
  link.attributes[@"url"] = @"https://example.com";
  [link addChild:image];
  MarkdownASTNode *space = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeText];
  space.content = @" ";
  MarkdownASTNode *row = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeParagraph];
  [row addChild:link];
  [row addChild:space];
  [row addChild:link];
  AttributedRenderer *renderer = [[AttributedRenderer alloc] initWithConfig:ENRMImageTestConfig()];
  NSAttributedString *rowText = [renderer renderNodes:@[ row ] context:[[RenderContext alloc] init] block:nil];
  XCTAssertTrue(ENRMFirstImageAttachment(rowText).isInline);

  MarkdownASTNode *caption = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeText];
  caption.content = @" Watch the intro";
  MarkdownASTNode *captioned = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeParagraph];
  [captioned addChild:link];
  [captioned addChild:caption];
  NSAttributedString *captionedText = [renderer renderNodes:@[ captioned ]
                                                    context:[[RenderContext alloc] init]
                                                      block:nil];
  XCTAssertFalse(ENRMFirstImageAttachment(captionedText).isInline);

  MarkdownASTNode *standalone = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeParagraph];
  [standalone addChild:link];
  NSAttributedString *standaloneText = [renderer renderNodes:@[ standalone ]
                                                     context:[[RenderContext alloc] init]
                                                       block:nil];
  XCTAssertFalse(ENRMFirstImageAttachment(standaloneText).isInline);
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
  XCTestExpectation *resolved = [self expectationWithDescription:@"inline image layout resolved"];
  ENRMImageTestTextView *textView = [[ENRMImageTestTextView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
  textView.layoutResolved = resolved;
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

  [self waitForExpectations:@[ resolved ] timeout:5];

  XCTAssertEqualWithAccuracy(laidOutSize().width, 100, 0.5);
  XCTAssertNotNil(attachment.image);
  XCTAssertEqualWithAccuracy(attachment.bounds.size.height, 20, 0.5);
}

// Shields' live badges put every label inside an SVG <a>; a decoder that skips link
// children draws the badge frame with no text.
- (void)testSvgContentInsideALinkIsDrawn
{
  NSString *shape = @"<rect width=\"20\" height=\"20\" fill=\"#f00\"/>";
  NSString *plain = [NSString stringWithFormat:
                                  @"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" "
                                  @"height=\"20\">%@</svg>",
                                  shape];
  NSString *linked = [NSString stringWithFormat:
                                   @"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" "
                                   @"height=\"20\"><a href=\"https://example.com\">%@</a></svg>",
                                   shape];
  for (NSString *svg in @[ plain, linked ]) {
    NSData *pixels = ENRMRasterizeImageData([svg dataUsingEncoding:NSUTF8StringEncoding], 20, 20);
    XCTAssertNotNil(pixels, @"%@", svg);
    if (!pixels)
      continue;
    const uint8_t *center = (const uint8_t *)pixels.bytes + (10 * 20 + 10) * 4;
    XCTAssertGreaterThan(center[0], 0xF0, @"%@", svg);
    XCTAssertLessThan(center[1], 0x10, @"%@", svg);
    XCTAssertGreaterThan(center[3], 0xF0, @"%@", svg);
  }

  const size_t scale = 4;
  NSData *stars =
      ENRMRasterizeImageData([ENRMShieldsStarsSvg dataUsingEncoding:NSUTF8StringEncoding], 88 * scale, 20 * scale);
  XCTAssertNotNil(stars);
  // Of the 88x20 badge, the "Stars" label spans x 22-49 and the "51k" count x 64-83, in #333.
  XCTAssertTrue(ENRMHasDarkPixel(stars, 88 * scale, scale, NSMakeRange(22, 28)));
  XCTAssertTrue(ENRMHasDarkPixel(stars, 88 * scale, scale, NSMakeRange(64, 20)));
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

  // View-free measurement builds attachments off the main thread, which stays blocked meanwhile.
  // dispatch_sync could run the block on this thread, so wait on a semaphore instead.
  __block BOOL ranOffMain = NO;
  __block CGRect roomyOffMain = CGRectZero;
  __block CGRect narrowOffMain = CGRectZero;
  dispatch_semaphore_t measured = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    ranOffMain = !NSThread.isMainThread;
    ENRMImageAttachment *offMain = [ENRMImageAttachment attachmentForURL:url config:ENRMImageTestConfig() isInline:YES];
    roomyOffMain = [offMain attachmentBoundsForTextContainer:nil
                                        proposedLineFragment:CGRectMake(0, 0, 1000, 20)
                                               glyphPosition:CGPointZero
                                              characterIndex:0];
    narrowOffMain = [offMain attachmentBoundsForTextContainer:nil
                                         proposedLineFragment:CGRectMake(0, 0, 200, 20)
                                                glyphPosition:CGPointZero
                                               characterIndex:0];
    dispatch_semaphore_signal(measured);
  });
  dispatch_semaphore_wait(measured, DISPATCH_TIME_FOREVER);
  XCTAssertTrue(ranOffMain);
  XCTAssertEqualWithAccuracy(roomyOffMain.size.width, 400, 0.5);
  XCTAssertEqualWithAccuracy(roomyOffMain.size.height, 20, 0.5);
  XCTAssertEqualWithAccuracy(narrowOffMain.size.width, 200, 0.5);
  XCTAssertEqualWithAccuracy(narrowOffMain.size.height, 10, 0.5);
}

@end
