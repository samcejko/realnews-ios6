#import <Foundation/Foundation.h>
#import "RNFeed.h"
#import "RNFeedItem.h"

@interface RNFeedStore : NSObject

@property (nonatomic, readonly) NSArray *feeds;
@property (nonatomic) NSInteger retentionDays;       // default 14 (0 = forever)
@property (nonatomic) NSInteger maxItemsPerFeed;     // default 50 (0 = unlimited)
@property (nonatomic) NSInteger networkTimeout;       // default 10 seconds
@property (nonatomic, readonly) BOOL isRefreshing;

+ (instancetype)sharedStore;

- (void)save;
- (void)saveSynchronously;
- (void)addFeedWithURL:(NSString *)url title:(NSString *)title category:(NSString *)category completion:(void(^)(RNFeed *feed, NSError *error))completion;
- (void)removeFeed:(RNFeed *)feed;
- (void)moveFeedAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

- (void)refreshFeed:(RNFeed *)feed completion:(void(^)(BOOL success, NSError *error))completion;
- (void)refreshAllFeedsWithCompletion:(void(^)(void))completion;

- (void)markItem:(RNFeedItem *)item asRead:(BOOL)isRead;
- (void)markAllItemsAsReadInFeed:(RNFeed *)feed;
- (void)toggleFavoriteForItem:(RNFeedItem *)item;

- (NSArray *)allUnreadItems;
- (NSArray *)starredItems;
- (NSInteger)totalUnreadCount;

- (void)purgeOldArticles;
- (void)clearAllCache;

@end
