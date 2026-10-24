// Device-only feedback regression bridge. Disabled unless Documents/feedback-checks exists.
#import "RNDeviceChecks.h"
#import "RNUtils.h"
#import "RNSettingsViewController.h"
#import "RetroUIKit.h"
#import "RNHTTPRequest.h"
#import "RNFeedStore.h"
#import "RNMetadataViewController.h"
#import "RNImageViewerViewController.h"
#import "RNAddFeedViewController.h"
#import <objc/runtime.h>

// The pre-iOS-8 touch event layout follows KIF's Apache-2.0 test support.
// See docs/third-party/KIF.txt. These are touch events, not sendActions calls.
@interface RNCheckEventProxy : NSObject {
@public
    unsigned int flags, type, ignored1;
    float x1, y1, x2, y2;
    unsigned int ignored2[10], ignored3[7];
    float sizeX, sizeY, x3, y3;
    unsigned int ignored4[3];
}
@end
@implementation RNCheckEventProxy
@end
@interface UITouch (RNCheckPrivate)
- (void)setWindow:(UIWindow *)window;
- (void)setView:(UIView *)view;
- (void)setTapCount:(NSUInteger)count;
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)setPhase:(UITouchPhase)phase;
- (void)setGestureView:(UIView *)view;
- (void)_setIsFirstTouchForView:(BOOL)first;
- (void)_setLocationInWindow:(CGPoint)point resetPrevious:(BOOL)reset;
@end
@interface UIEvent (RNCheckPrivate)
- (void)_clearTouches;
- (void)_addTouch:(UITouch *)touch forDelayedDelivery:(BOOL)delayed;
- (void)_setGSEvent:(void *)event;
- (void)_setTimestamp:(NSTimeInterval)timestamp;
@end
@interface UIApplication (RNCheckPrivate)
- (UIEvent *)_touchesEvent;
@end

static NSString *RNCheckPath(void) { return [NSTemporaryDirectory() stringByAppendingPathComponent:@"feedback-check.json"]; }
static void RNCheckWrite(NSDictionary *result) {
    [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL] writeToFile:RNCheckPath() atomically:YES];
}
static void RNCheckViews(UIView *view, NSMutableArray *views) {
    [views addObject:view]; for (UIView *child in view.subviews) RNCheckViews(child, views);
}
static BOOL RNCheckTap(UIWindow *window, CGPoint point) {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) return NO;
    UIApplication *application = [UIApplication sharedApplication];
    if (![application respondsToSelector:@selector(_touchesEvent)]) return NO;
    UIView *hit = [window hitTest:point withEvent:nil];
    UITouch *touch = [[UITouch alloc] init];
    [touch setWindow:window]; [touch setTapCount:1];
    [touch _setLocationInWindow:point resetPrevious:YES]; [touch setView:hit];
    if ([touch respondsToSelector:@selector(_setIsFirstTouchForView:)]) [touch _setIsFirstTouchForView:YES];
    else {
        Ivar flags = class_getInstanceVariable([UITouch class], "_touchFlags");
        if (flags) *((char *)(__bridge void *)touch + ivar_getOffset(flags)) |= 1;
    }
    if ([touch respondsToSelector:@selector(setGestureView:)]) [touch setGestureView:hit];
    UIEvent *event = [application _touchesEvent];
    RNCheckEventProxy *proxy = [[RNCheckEventProxy alloc] init];
    proxy->type = 3001; proxy->sizeX = proxy->sizeY = 1;
    proxy->x1 = proxy->x2 = proxy->x3 = point.x; proxy->y1 = proxy->y2 = proxy->y3 = point.y;
    for (NSUInteger phase = 0; phase < 2; phase++) {
        [touch setPhase:phase == 0 ? UITouchPhaseBegan : UITouchPhaseEnded];
        [touch setTimestamp:[[NSProcessInfo processInfo] systemUptime]];
        proxy->flags = phase == 0 ? 0x3010180 : 0x1010180;
        [event _clearTouches]; [event _setGSEvent:(__bridge void *)proxy];
        [event _setTimestamp:touch.timestamp]; [event _addTouch:touch forDelayedDelivery:NO];
        [application sendEvent:event];
    }
    return YES;
}

@interface RNCheckRequest : NSObject
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) NSUInteger ticks;
@property (nonatomic, strong) RNHTTPRequest *request;
- (void)tick:(NSTimer *)timer;
@end
@implementation RNCheckRequest
- (void)tick:(NSTimer *)timer { self.ticks++; }
@end

BOOL RNHandleDeviceCheckURL(NSURL *url, UIWindow *window, UINavigationController *navigation) {
    if (![url.host isEqualToString:@"checks"]) return NO;
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[documents stringByAppendingPathComponent:@"feedback-checks"]]) return YES;
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    for (NSString *part in [url.query componentsSeparatedByString:@"&"]) {
        NSRange equal = [part rangeOfString:@"="]; if (equal.location == NSNotFound) continue;
        NSString *key = [[part substringToIndex:equal.location] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *value = [[part substringFromIndex:equal.location + 1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (key && value) [params setObject:value forKey:key];
    }
    NSString *command = [params objectForKey:@"command"];
    if ([command isEqualToString:@"back"]) { [navigation dismissViewControllerAnimated:NO completion:nil]; return YES; }
    if ([command isEqualToString:@"settings"]) {
        [navigation presentViewController:[[UINavigationController alloc] initWithRootViewController:[[RNSettingsViewController alloc] init]] animated:NO completion:nil];return YES;
    }
    if ([command isEqualToString:@"alert"]) {
        [[[RetroAlertView alloc] initWithTitle:@"RealNews" message:@"iOS 6 dialog" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];return YES;
    }
    if ([command isEqualToString:@"sheet"]) {
        [[[RetroActionSheet alloc] initWithTitle:@"RealNews" delegate:nil cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Copy link",@"Open in Safari",nil] showInView:window];return YES;
    }
    if ([command isEqualToString:@"activate"]) {
        NSMutableArray *views=[NSMutableArray array]; RNCheckViews(window,views);
        NSUInteger index=[[params objectForKey:@"index"] integerValue], found=0;
        for (UIView *view in views) if ([view isKindOfClass:[UIControl class]]) {
            if (found++ == index) {
                if ([view isKindOfClass:[UISwitch class]]) { UISwitch *toggle=(UISwitch *)view; [toggle setOn:!toggle.on animated:NO];[toggle sendActionsForControlEvents:UIControlEventValueChanged]; }
                else [(UIControl *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
        }
        return YES;
    }
    if ([command isEqualToString:@"image"]) {
        [navigation presentViewController:[[RNImageViewerViewController alloc] initWithImage:[UIImage imageNamed:@"Icon-72.png"]] animated:NO completion:nil];
        return YES;
    }
    if ([command isEqualToString:@"metadata"]) {
        RNFeedItem *item = [[RNFeedItem alloc] init]; item.title = @"Feedback date check";
        item.publishDateString = @"Thu, 22 Oct 2026 14:00:00 +0300";
        item.extraData = @{@"pubDate":item.publishDateString, @"updated":@"2026-10-22T16:00:00Z"};
        UIViewController *controller = [[RNMetadataViewController alloc] initWithFeedItem:item];
        [navigation presentViewController:[[UINavigationController alloc] initWithRootViewController:controller] animated:NO completion:nil];
        return YES;
    }
    if ([command isEqualToString:@"edit"]) {
        NSUInteger index = [[params objectForKey:@"index"] integerValue];
        if (index < [RNFeedStore sharedStore].feeds.count) {
            RNFeed *feed = [[RNFeedStore sharedStore].feeds objectAtIndex:index];
            [navigation presentViewController:[[UINavigationController alloc] initWithRootViewController:[[RNAddFeedViewController alloc] initWithFeed:feed]] animated:NO completion:nil];
        }
        return YES;
    }
    if ([command isEqualToString:@"timeout"]) {
        RNCheckRequest *probe = [[RNCheckRequest alloc] init];
        probe.request = [RNHTTPRequest requestWithURLString:[params objectForKey:@"url"]];
        probe.request.readTimeout = MAX(1, MIN(10, [[params objectForKey:@"seconds"] integerValue]));
        probe.request.connectTimeout = probe.request.readTimeout;
        NSTimeInterval started = [NSDate timeIntervalSinceReferenceDate];
        probe.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:probe selector:@selector(tick:) userInfo:nil repeats:YES];
        probe.request.onComplete = ^(NSInteger status, NSData *body, NSError *error) {
            [probe.timer invalidate]; probe.timer = nil;
            RNCheckWrite(@{@"elapsed":@([NSDate timeIntervalSinceReferenceDate]-started), @"mainThreadTicks":@(probe.ticks), @"status":@(status), @"errorCode":@(error.code), @"error":error.localizedDescription ?: @""});
            probe.request.onComplete = nil; probe.request = nil;
        };
        RNCheckWrite(@{@"running":@YES}); [probe.request start]; return YES;
    }
    if ([command isEqualToString:@"tap"]) {
        BOOL sent = RNCheckTap(window, CGPointMake([[params objectForKey:@"x"] doubleValue], [[params objectForKey:@"y"] doubleValue]));
        RNCheckWrite(@{@"touchEventsSent":@(sent)}); return YES;
    }
    if ([command isEqualToString:@"status"]) {
        UIViewController *top = navigation;
        while (top.presentedViewController) top = top.presentedViewController;
        if ([top isKindOfClass:[UINavigationController class]]) top = [(UINavigationController *)top topViewController];
        NSMutableArray *views = [NSMutableArray array], *labels = [NSMutableArray array], *controls = [NSMutableArray array];
        RNCheckViews(window, views);
        for (UIView *view in views) {
            if (view.hidden || view.alpha == 0) continue;
            if ([view isKindOfClass:[UILabel class]] && ((UILabel *)view).text.length) [labels addObject:((UILabel *)view).text];
            if ([view isKindOfClass:[UIControl class]]) {
                CGRect rect = [view convertRect:view.bounds toView:window];
                [controls addObject:@{@"class":NSStringFromClass([view class]), @"label":view.accessibilityLabel ?: @"", @"x":@(CGRectGetMidX(rect)), @"y":@(CGRectGetMidY(rect))}];
            }
        }
        RNCheckWrite(@{@"screen":NSStringFromClass([top class]), @"labels":labels, @"controls":controls, @"modalStyle":@(top.navigationController.modalPresentationStyle), @"viewHeight":@(top.view.bounds.size.height)}); return YES;
    }
    return YES;
}
