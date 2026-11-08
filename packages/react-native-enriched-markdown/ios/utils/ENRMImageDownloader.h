#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// Decoded pixel cost, shared by native image caches.
FOUNDATION_EXPORT NSUInteger ENRMImageByteCost(RCTUIImage *image);

typedef void (^ENRMImageDownloadCompletion)(RCTUIImage *_Nullable image);

/// Decodes raster image data, falling back to SVG by content: badge services serve SVG
/// from URLs without an extension.
FOUNDATION_EXPORT RCTUIImage *_Nullable ENRMDecodeImageData(NSData *_Nullable data);

/// Cache cost of an image decoded from data: its pixels, or the data for a vector image.
FOUNDATION_EXPORT NSUInteger ENRMDecodedImageCost(RCTUIImage *image, NSData *data);

/**
 * Cache identity for a remote image request. Returns the URL itself when no
 * headers are set; otherwise appends a SHA-256 digest of the sorted header
 * pairs, so the same URL fetched with different headers is cached and
 * deduplicated separately without embedding header values in the key.
 * Header names are compared case-insensitively.
 */
NSString *ENRMImageCacheKey(NSString *url, NSDictionary<NSString *, NSString *> *_Nullable headers);

/// Document headers under per-image headers, names lowercased so the override and
/// the cache identity are independent of header casing.
NSDictionary<NSString *, NSString *> *
ENRMMergeImageRequestHeaders(NSDictionary<NSString *, NSString *> *_Nullable documentHeaders,
                             NSDictionary<NSString *, NSString *> *_Nullable sourceHeaders);

@interface ENRMImageDownloader : NSObject

+ (instancetype)shared;

- (void)downloadURL:(NSString *)url
            headers:(nullable NSDictionary<NSString *, NSString *> *)headers
         completion:(ENRMImageDownloadCompletion)completion;

@end

NS_ASSUME_NONNULL_END
