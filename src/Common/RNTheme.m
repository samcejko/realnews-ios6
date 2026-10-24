#import "RNTheme.h"
#import "RNModern.h"
#import <QuartzCore/QuartzCore.h>

@implementation RNTheme

+ (UIColor *)brandOrangeColor
{
    return [UIColor colorWithRed:238.0f/255.0f green:120.0f/255.0f blue:24.0f/255.0f alpha:1.0f];
}

+ (UIColor *)brandDarkOrangeColor
{
    return [UIColor colorWithRed:196.0f/255.0f green:85.0f/255.0f blue:10.0f/255.0f alpha:1.0f];
}

+ (UIColor *)unreadBadgeColor
{
    return [UIColor colorWithRed:38.0f/255.0f green:122.0f/255.0f blue:226.0f/255.0f alpha:1.0f];
}

+ (UIColor *)starredGoldColor
{
    return [UIColor colorWithRed:235.0f/255.0f green:170.0f/255.0f blue:20.0f/255.0f alpha:1.0f];
}

+ (UIColor *)textColor
{
    return [UIColor colorWithRed:30.0f/255.0f green:30.0f/255.0f blue:30.0f/255.0f alpha:1.0f];
}

+ (UIColor *)subtitleColor
{
    return [UIColor colorWithRed:120.0f/255.0f green:120.0f/255.0f blue:125.0f/255.0f alpha:1.0f];
}

+ (UIColor *)separatorColor
{
    return [UIColor colorWithWhite:0.86f alpha:1.0f];
}

+ (UIColor *)cellHighlightColor
{
    return [UIColor colorWithRed:2.0f/255.0f green:110.0f/255.0f blue:230.0f/255.0f alpha:1.0f];
}

+ (void)applyAppearance
{
    UINavigationBar *navBar = [UINavigationBar appearance];
    [navBar setTintColor:RNModernIOS() ? [UIColor whiteColor] : [self brandDarkOrangeColor]];
    
    // Preserve iOS 6 skeuomorphic gradient on iOS 7+
    UIImage *gradient44 = [self navbarGradientImageForHeight:44.0f];
    UIImage *gradient32 = [self navbarGradientImageForHeight:32.0f];
    [navBar setBackgroundImage:gradient44 forBarMetrics:UIBarMetricsDefault];
    [navBar setBackgroundImage:gradient32 forBarMetrics:UIBarMetricsLandscapePhone];
    
    UIToolbar *toolbar = [UIToolbar appearance];
    [toolbar setTintColor:RNModernIOS() ? [UIColor whiteColor] : [self brandDarkOrangeColor]];
    
    [toolbar setBackgroundImage:gradient44 forToolbarPosition:UIToolbarPositionBottom barMetrics:UIBarMetricsDefault];
    RNModernApplyNavigationBarBackground(navBar, gradient44, nil, nil, nil, nil);
    RNModernApplyToolbarBackground(toolbar, gradient44);
}

+ (UIImage *)navbarGradientImageForHeight:(CGFloat)height
{
    CGSize size = CGSizeMake(1.0f, height);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[8] = {
        242.0f/255.0f, 130.0f/255.0f, 30.0f/255.0f, 1.0f,
        185.0f/255.0f, 75.0f/255.0f, 5.0f/255.0f, 1.0f
    };
    CGFloat locations[2] = { 0.0f, 1.0f };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, height), 0);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIView *)badgeViewWithCount:(NSInteger)count
{
    if (count <= 0) return nil;
    
    NSString *text = (count > 999) ? @"999+" : [NSString stringWithFormat:@"%ld", (long)count];
    UIFont *font = [UIFont boldSystemFontOfSize:14.0f];
    CGSize textSize = [text sizeWithFont:font];
    
    CGFloat paddingX = 8.0f;
    CGFloat height = 22.0f;
    CGFloat width = MAX(height, textSize.width + paddingX * 2);
    
    UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    badge.backgroundColor = [self unreadBadgeColor];
    badge.layer.cornerRadius = height / 2.0f;
    badge.layer.masksToBounds = YES;
    badge.userInteractionEnabled = NO;
    
    UILabel *label = [[UILabel alloc] initWithFrame:badge.bounds];
    label.text = text;
    label.font = font;
    label.textColor = [UIColor whiteColor];
    label.textAlignment = UITextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [badge addSubview:label];
    
    return badge;
}

+ (UIImage *)upArrowImage
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(20.0f, 20.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(4.0f, 12.5f)];
        [p addLineToPoint:CGPointMake(10.0f, 6.5f)];
        [p addLineToPoint:CGPointMake(16.0f, 12.5f)];
        p.lineWidth = 2.5f;
        p.lineCapStyle = kCGLineCapRound;
        p.lineJoinStyle = kCGLineJoinRound;
        [[UIColor whiteColor] setStroke];
        [p stroke];
        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

+ (UIImage *)downArrowImage
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(20.0f, 20.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(4.0f, 7.5f)];
        [p addLineToPoint:CGPointMake(10.0f, 13.5f)];
        [p addLineToPoint:CGPointMake(16.0f, 7.5f)];
        p.lineWidth = 2.5f;
        p.lineCapStyle = kCGLineCapRound;
        p.lineJoinStyle = kCGLineJoinRound;
        [[UIColor whiteColor] setStroke];
        [p stroke];
        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

+ (UIImage *)leftArrowImage
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(20.0f, 20.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(13.0f, 4.0f)];
        [p addLineToPoint:CGPointMake(7.0f, 10.0f)];
        [p addLineToPoint:CGPointMake(13.0f, 16.0f)];
        p.lineWidth = 2.5f;
        p.lineCapStyle = kCGLineCapRound;
        p.lineJoinStyle = kCGLineJoinRound;
        [[UIColor whiteColor] setStroke];
        [p stroke];
        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

+ (UIImage *)rightArrowImage
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(20.0f, 20.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(7.0f, 4.0f)];
        [p addLineToPoint:CGPointMake(13.0f, 10.0f)];
        [p addLineToPoint:CGPointMake(7.0f, 16.0f)];
        p.lineWidth = 2.5f;
        p.lineCapStyle = kCGLineCapRound;
        p.lineJoinStyle = kCGLineJoinRound;
        [[UIColor whiteColor] setStroke];
        [p stroke];
        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

+ (UIImage *)starImageFilled
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(20.0f, 20.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *p = [UIBezierPath bezierPath];
        CGPoint center = CGPointMake(10.0f, 10.0f);
        CGFloat rOut = 8.5f;
        CGFloat rIn = 3.6f;
        for (int i = 0; i < 5; i++) {
            CGFloat aOut = -M_PI_2 + i * (2.0f * M_PI / 5.0f);
            CGFloat aIn = aOut + (M_PI / 5.0f);
            CGPoint ptOut = CGPointMake(center.x + rOut * cosf(aOut), center.y + rOut * sinf(aOut));
            CGPoint ptIn = CGPointMake(center.x + rIn * cosf(aIn), center.y + rIn * sinf(aIn));
            if (i == 0) [p moveToPoint:ptOut];
            else [p addLineToPoint:ptOut];
            [p addLineToPoint:ptIn];
        }
        [p closePath];
        [[UIColor whiteColor] setFill];
        [p fill];
        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

+ (UIImage *)starImageEmpty
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(20.0f, 20.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *p = [UIBezierPath bezierPath];
        CGPoint center = CGPointMake(10.0f, 10.0f);
        CGFloat rOut = 8.0f;
        CGFloat rIn = 3.5f;
        for (int i = 0; i < 5; i++) {
            CGFloat aOut = -M_PI_2 + i * (2.0f * M_PI / 5.0f);
            CGFloat aIn = aOut + (M_PI / 5.0f);
            CGPoint ptOut = CGPointMake(center.x + rOut * cosf(aOut), center.y + rOut * sinf(aOut));
            CGPoint ptIn = CGPointMake(center.x + rIn * cosf(aIn), center.y + rIn * sinf(aIn));
            if (i == 0) [p moveToPoint:ptOut];
            else [p addLineToPoint:ptOut];
            [p addLineToPoint:ptIn];
        }
        [p closePath];
        p.lineWidth = 1.5f;
        p.lineJoinStyle = kCGLineJoinRound;
        [[UIColor whiteColor] setStroke];
        [p stroke];
        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

+ (UIImage *)gearImage
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(20.0f, 20.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGPoint center = CGPointMake(10.0f, 10.0f);

        for (int i = 0; i < 6; i++) {
            CGFloat angle = i * (M_PI / 3.0f);
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, center.x, center.y);
            CGContextRotateCTM(ctx, angle);
            UIBezierPath *tooth = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(-2.0f, -8.5f, 4.0f, 17.0f) cornerRadius:1.0f];
            [[UIColor whiteColor] setFill];
            [tooth fill];
            CGContextRestoreGState(ctx);
        }

        UIBezierPath *wheel = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3.5f, 3.5f, 13.0f, 13.0f)];
        [[UIColor whiteColor] setFill];
        [wheel fill];

        CGContextSetBlendMode(ctx, kCGBlendModeClear);
        UIBezierPath *hole = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(7.0f, 7.0f, 6.0f, 6.0f)];
        [[UIColor colorWithWhite:0 alpha:1] setFill];
        [hole fill];

        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

+ (UIImage *)playImage
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(18.0f, 18.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(5.0f, 3.0f)];
        [p addLineToPoint:CGPointMake(15.0f, 9.0f)];
        [p addLineToPoint:CGPointMake(5.0f, 15.0f)];
        [p closePath];
        [[UIColor whiteColor] setFill];
        [p fill];
        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

+ (UIImage *)pauseImage
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(18.0f, 18.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *b1 = [UIBezierPath bezierPathWithRect:CGRectMake(4.0f, 3.0f, 3.5f, 12.0f)];
        UIBezierPath *b2 = [UIBezierPath bezierPathWithRect:CGRectMake(10.5f, 3.0f, 3.5f, 12.0f)];
        [[UIColor whiteColor] setFill];
        [b1 fill];
        [b2 fill];
        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

+ (UIImage *)unreadDotImage
{
    static UIImage *s_img = nil;
    if (!s_img) {
        CGSize size = CGSizeMake(10.0f, 10.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1.0f, 1.0f, 8.0f, 8.0f)];
        [[self unreadBadgeColor] setFill];
        [dot fill];
        s_img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_img;
}

@end
