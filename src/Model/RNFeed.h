#import <Foundation/Foundation.h>
#import "RNFeedItem.h"

@interface RNFeed : NSObject

@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *siteURL;
@property (nonatomic, copy) NSString *feedDescription;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, strong) NSDate *lastUpdated;
@property (nonatomic, copy) NSString *lastError;
@property (nonatomic, copy) NSString *iconURL;
@property (nonatomic) BOOL iconBackgroundEnabled;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSDictionary *channelExtraData;

- (instancetype)initWithURL:(NSString *)url title:(NSString *)title;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

- (NSString *)effectiveIconURL;
- (NSInteger)unreadCount;
- (void)addItem:(RNFeedItem *)item;
- (void)mergeItems:(NSArray *)newItems maxItems:(NSInteger)maxItems;

@end
