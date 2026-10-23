#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RNTheme : NSObject

+ (UIColor *)brandOrangeColor;
+ (UIColor *)brandDarkOrangeColor;
+ (UIColor *)unreadBadgeColor;
+ (UIColor *)starredGoldColor;
+ (UIColor *)textColor;
+ (UIColor *)subtitleColor;
+ (UIColor *)separatorColor;
+ (UIColor *)cellHighlightColor;

+ (void)applyAppearance;
+ (UIImage *)navbarGradientImageForHeight:(CGFloat)height;
+ (UIView *)badgeViewWithCount:(NSInteger)count;

+ (UIImage *)upArrowImage;
+ (UIImage *)downArrowImage;
+ (UIImage *)leftArrowImage;
+ (UIImage *)rightArrowImage;
+ (UIImage *)starImageFilled;
+ (UIImage *)starImageEmpty;
+ (UIImage *)gearImage;
+ (UIImage *)playImage;
+ (UIImage *)pauseImage;
+ (UIImage *)unreadDotImage;

@end
