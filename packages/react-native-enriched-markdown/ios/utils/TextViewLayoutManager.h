#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@class StyleConfig;
@class ENRMTextHighlight;

@interface TextViewLayoutManager : NSLayoutManager

@property (nonatomic, strong) StyleConfig *config;

/// Drawn behind the glyphs, after the code backgrounds. Setting it redraws
/// only the ranges that change.
@property (nonatomic, copy) NSArray<ENRMTextHighlight *> *textHighlights;

@end

NS_ASSUME_NONNULL_END
