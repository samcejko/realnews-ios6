#import <Foundation/Foundation.h>

@interface RNDiscoveredFeed : NSObject
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *title;
@end

typedef void (^RNFeedDiscoveryCompletion)(NSArray *feeds, NSError *error);

@interface RNFeedDiscovery : NSObject

+ (void)discoverFeedsForURL:(NSString *)urlString completion:(RNFeedDiscoveryCompletion)completion;

@end
