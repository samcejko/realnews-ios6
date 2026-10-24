// RNCommon.h - Shared macros, constants and notifications for RealNews iOS 6.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RetroUIKit.h"

#pragma clang diagnostic error "-Wunguarded-availability"

#define L(key) NSLocalizedString((key), nil)
#define RNIsPad() (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define RNLog(fmt, ...) NSLog((@"[RealNews] " fmt), ##__VA_ARGS__)

static inline void RNMain(dispatch_block_t block)
{
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

extern NSString * const RNFeedsDidUpdateNotification;
extern NSString * const RNFeedDidUpdateNotification;
extern NSString * const RNArticleReadStatusChangedNotification;
extern NSString * const RNArticleStarStatusChangedNotification;
extern NSString * const RNImageDidLoadNotification;
extern NSString * const RNErrorDomain;

enum {
    RNErrorNetwork       = -1,
    RNErrorTLS           = -2,
    RNErrorCertificate   = -3,
    RNErrorTimeout       = -4,
    RNErrorCancelled     = -5,
    RNErrorBadResponse   = -6,
    RNErrorParseFailed   = -7,
};

NSError *RNMakeError(NSInteger code, NSString *message);

static inline id RNFirst(NSArray *array) { return array.count ? [array objectAtIndex:0] : nil; }
