#import "RNCommon.h"

NSString * const RNFeedsDidUpdateNotification = @"RNFeedsDidUpdateNotification";
NSString * const RNFeedDidUpdateNotification = @"RNFeedDidUpdateNotification";
NSString * const RNArticleReadStatusChangedNotification = @"RNArticleReadStatusChangedNotification";
NSString * const RNArticleStarStatusChangedNotification = @"RNArticleStarStatusChangedNotification";
NSString * const RNImageDidLoadNotification = @"RNImageDidLoadNotification";
NSString * const RNErrorDomain = @"com.samcejko.realnews.error";

NSError *RNMakeError(NSInteger code, NSString *message)
{
    NSDictionary *ui = message.length ? @{ NSLocalizedDescriptionKey: message } : @{};
    return [NSError errorWithDomain:RNErrorDomain code:code userInfo:ui];
}
