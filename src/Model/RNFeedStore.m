#import "RNFeedStore.h"
#import "RNHTTPRequest.h"
#import "RNFeedParser.h"
#import "RNImageLoader.h"
#import "RNCommon.h"

@interface RNFeedStore () {
    NSMutableArray *_feeds;
    NSString *_storePath;
    NSString *_settingsPath;
    dispatch_queue_t _ioQueue;
}
@end

@implementation RNFeedStore

+ (instancetype)sharedStore
{
    static RNFeedStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[self alloc] init];
    });
    return store;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _feeds = [NSMutableArray array];
        _retentionDays = 14;
        _maxItemsPerFeed = 50;
        _networkTimeout = 10;
        _ioQueue = dispatch_queue_create("com.samcejko.realnews.io", DISPATCH_QUEUE_SERIAL);

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _storePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"feeds.json"];
        _settingsPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"settings.plist"];

        [self loadSettings];
        [self loadFeeds];
    }
    return self;
}

- (NSArray *)feeds
{
    return [_feeds copy];
}

- (void)loadSettings
{
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:_settingsPath];
    if (dict) {
        if ([dict objectForKey:@"retentionDays"]) _retentionDays = [[dict objectForKey:@"retentionDays"] integerValue];
        if ([dict objectForKey:@"maxItemsPerFeed"]) _maxItemsPerFeed = [[dict objectForKey:@"maxItemsPerFeed"] integerValue];
        if ([dict objectForKey:@"networkTimeout"]) _networkTimeout = [[dict objectForKey:@"networkTimeout"] integerValue];
        if (_networkTimeout < 1) _networkTimeout = 10;
        if (_networkTimeout > 10) _networkTimeout = 10;
    }
}

- (void)saveSettings
{
    NSDictionary *dict = @{
        @"retentionDays": @(_retentionDays),
        @"maxItemsPerFeed": @(_maxItemsPerFeed),
        @"networkTimeout": @(_networkTimeout)
    };
    [dict writeToFile:_settingsPath atomically:YES];
}

- (void)loadFeeds
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:_storePath]) {
        NSData *data = [NSData dataWithContentsOfFile:_storePath];
        if (data.length) {
            NSError *err = nil;
            NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
            if ([arr isKindOfClass:[NSArray class]]) {
                for (NSDictionary *dict in arr) {
                    if ([dict isKindOfClass:[NSDictionary class]]) {
                        RNFeed *feed = [[RNFeed alloc] initWithDictionary:dict];
                        [_feeds addObject:feed];
                    }
                }
            }
        }
    }

    // Repair only exact known corrupted defaults; preserve custom feed names.
    NSDictionary *legacyDefaults = @{
        @"─îT24 - Hlavn├¡ zpr├ívy": @"ČT24 - Hlavní zprávy",
        @"Zpr├ívy ─îT24 na t├⌐ma V├╜b─¢r redakce": @"Zprávy ČT24 na téma Výběr redakce",
        @"ÄŒT24 - HlavnÃ­ zprÃ¡vy": @"ČT24 - Hlavní zprávy",
        @"─îT24 - Hlavn├ş zpr├ívy": @"ČT24 - Hlavní zprávy",
        @"ÄŒT24": @"ČT24",
        @"─îT24": @"ČT24",
        @"ZprÃ¡vy ÄŒT24 na tÃ©ma VÃ½bÄ›r redakce": @"Zprávy ČT24 na téma Výběr redakce",
        @"Zpr├ívy ─îT24 na t├ęma V├Żb─Ťr redakce": @"Zprávy ČT24 na téma Výběr redakce",
        @"ZprÃ¡vy": @"Zprávy",
        @"Zpr├ívy": @"Zprávy",
        @"ÄŒT24 - Hlavn├¡ zpr├ívy": @"ČT24 - Hlavní zprávy",
        @"Zpr├ívy ├îT24 na t├⌐ma V├╜b─¢r redakce": @"Zprávy ČT24 na téma Výběr redakce"
    };
    BOOL migratedCorruptedTitle = NO;
    for (RNFeed *feed in _feeds) {
        NSString *title = feed.title ? [legacyDefaults objectForKey:feed.title] : nil;
        NSString *category = feed.category ? [legacyDefaults objectForKey:feed.category] : nil;
        if (title) {
            feed.title = title;
            migratedCorruptedTitle = YES;
        }
        if (category) {
            feed.category = category;
            migratedCorruptedTitle = YES;
        }
    }
    if (migratedCorruptedTitle) [self save];

    // Default starter feeds if first launch
    if (![[NSFileManager defaultManager] fileExistsAtPath:_storePath]) {
        [self populateDefaultFeeds];
        [self save];
    }

    // Add Samcejko Repository feed for existing users upgrading (once)
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:_settingsPath];
    BOOL repoFeedAdded = [[settings objectForKey:@"repoFeedAdded"] boolValue];
    if (!repoFeedAdded) {
        [self addRepoFeedIfMissing];
    }
}

- (void)populateDefaultFeeds
{
    NSArray *defaults = @[
        @{ @"url": @"https://ct24.ceskatelevize.cz/rss/hlavni-zpravy", @"title": @"ČT24 - Hlavní zprávy", @"cat": @"Zprávy" },
        @{ @"url": @"https://www.irozhlas.cz/rss/irozhlas/zpravy-domov", @"title": @"iROZHLAS - Domov", @"cat": @"Zprávy" },
        @{ @"url": @"https://podcasts.files.bbci.co.uk/p02nq0gn.rss", @"title": @"BBC Global News Podcast", @"cat": @"Podcasty" },
        @{ @"url": @"https://feeds.bbci.co.uk/news/world/rss.xml", @"title": @"BBC News - World", @"cat": @"News" },
        @{ @"url": @"https://news.ycombinator.com/rss", @"title": @"Hacker News", @"cat": @"Tech" },
        @{ @"url": @"https://www.nasa.gov/news-release/feed/", @"title": @"NASA News Releases", @"cat": @"Science" },
        @{ @"url": @"https://repo.samcejko.eu/feed.xml", @"title": @"Samcejko Repository", @"cat": @"News" }
    ];

    for (NSDictionary *d in defaults) {
        RNFeed *feed = [[RNFeed alloc] initWithURL:[d objectForKey:@"url"] title:[d objectForKey:@"title"]];
        feed.category = [d objectForKey:@"cat"];
        [_feeds addObject:feed];
    }
}

- (void)addRepoFeedIfMissing
{
    NSString *repoURL = @"https://repo.samcejko.eu/feed.xml";
    for (RNFeed *f in _feeds) {
        if ([f.url.lowercaseString isEqualToString:repoURL.lowercaseString]) {
            return; // Already exists
        }
    }

    RNFeed *feed = [[RNFeed alloc] initWithURL:repoURL title:@"Samcejko Repository"];
    feed.category = @"News";
    [_feeds addObject:feed];
    [self save];

    // Mark as added so we don't add it again on future launches
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:_settingsPath] ?: [NSMutableDictionary dictionary];
    [settings setObject:@YES forKey:@"repoFeedAdded"];
    [settings writeToFile:_settingsPath atomically:YES];
}

- (void)save
{
    [self saveSettings];
    [self saveFeedsSync:NO];
}

- (void)saveSynchronously
{
    [self saveSettings];
    [self saveFeedsSync:YES];
}

- (void)saveFeedsSync:(BOOL)sync
{
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:_feeds.count];
    for (RNFeed *f in _feeds) {
        [arr addObject:[f toDictionary]];
    }
    NSString *storePath = _storePath;
    void (^writeBlock)(void) = ^{
        NSError *err = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:arr options:0 error:&err];
        if (data) {
            [data writeToFile:storePath atomically:YES];
        }
    };
    if (sync) {
        dispatch_sync(_ioQueue, writeBlock);
    } else {
        dispatch_async(_ioQueue, writeBlock);
    }
}

- (void)addFeedWithURL:(NSString *)url title:(NSString *)title category:(NSString *)category completion:(void(^)(RNFeed *feed, NSError *error))completion
{
    NSString *trimmed = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) {
        if (completion) completion(nil, RNMakeError(RNErrorNetwork, @"Empty URL"));
        return;
    }

    // Check duplicate
    for (RNFeed *f in _feeds) {
        if ([f.url.lowercaseString isEqualToString:trimmed.lowercaseString]) {
            if (completion) completion(f, nil);
            return;
        }
    }

    RNFeed *feed = [[RNFeed alloc] initWithURL:trimmed title:title];
    feed.category = category;
    // Refresh immediately to populate title and items
    [self refreshFeed:feed completion:^(BOOL success, NSError *error) {
        if (success && !error) {
            if (![self->_feeds containsObject:feed]) [self->_feeds addObject:feed];
            [self save];
        }
        if (completion) completion(success && !error ? feed : nil, error);
    }];
}

- (void)removeFeed:(RNFeed *)feed
{
    [_feeds removeObject:feed];
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:RNFeedsDidUpdateNotification object:nil];
}

- (void)moveFeedAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex >= _feeds.count || toIndex >= _feeds.count) return;
    RNFeed *f = [_feeds objectAtIndex:fromIndex];
    [_feeds removeObjectAtIndex:fromIndex];
    [_feeds insertObject:f atIndex:toIndex];
    [self save];
}

- (void)fetchFeedURL:(NSString *)urlString completion:(void(^)(NSInteger status, NSData *body, NSError *error))completion
{
    RNHTTPRequest *req = [RNHTTPRequest requestWithURLString:urlString];
    req.connectTimeout = _networkTimeout;
    req.readTimeout = _networkTimeout;
    req.onComplete = ^(NSInteger status, NSData *body, NSError *error) {
        if (completion) completion(status, body, error);
    };
    [req start];
}

- (void)handleFeedData:(NSData *)body forFeed:(RNFeed *)feed feedURL:(NSString *)feedURL saveAfter:(BOOL)saveAfter completion:(void(^)(BOOL success, NSError *error))completion
{
    NSError *parseErr = nil;
    RNFeed *parsed = [RNFeedParser parseFeedData:body feedURL:feedURL error:&parseErr];
    if (parsed) {
        if (parsed.title.length && ([feed.title isEqualToString:feed.url] || !feed.title.length)) {
            feed.title = parsed.title;
        }
        feed.siteURL = parsed.siteURL;
        feed.feedDescription = parsed.feedDescription;
        feed.channelExtraData = parsed.channelExtraData;
        if (parsed.iconURL.length) {
            feed.iconURL = parsed.iconURL;
        }
        feed.lastUpdated = [NSDate date];
        feed.lastError = nil;

        [feed mergeItems:parsed.items maxItems:self.maxItemsPerFeed];
        if (saveAfter) {
            [self save];
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:RNFeedDidUpdateNotification
                                                            object:feed
                                                          userInfo:@{ @"feedURL": feed.url }];
        if (completion) completion(YES, nil);
    } else {
        feed.lastError = parseErr.localizedDescription;
        if (completion) completion(NO, parseErr);
    }
}

- (void)handleFeedError:(NSError *)error status:(NSInteger)status forFeed:(RNFeed *)feed completion:(void(^)(BOOL success, NSError *error))completion
{
    NSString *errMsg = error ? error.localizedDescription : [NSString stringWithFormat:@"HTTP status %ld", (long)status];
    feed.lastError = errMsg;
    if (completion) completion(NO, error ? error : RNMakeError(RNErrorBadResponse, errMsg));
}

- (void)refreshFeed:(RNFeed *)feed completion:(void(^)(BOOL success, NSError *error))completion
{
    [self refreshFeed:feed saveAfter:YES completion:completion];
}

- (void)refreshFeed:(RNFeed *)feed saveAfter:(BOOL)saveAfter completion:(void(^)(BOOL success, NSError *error))completion
{
    [self fetchFeedURL:feed.url completion:^(NSInteger status, NSData *body, NSError *error) {
        if (status == 200 && body.length > 0) {
            [self handleFeedData:body forFeed:feed feedURL:feed.url saveAfter:saveAfter completion:completion];
        } else {
            [self handleFeedError:error status:status forFeed:feed completion:completion];
        }
    }];
}

- (void)refreshAllFeedsWithCompletion:(void(^)(void))completion
{
    if (_isRefreshing || _feeds.count == 0) {
        if (completion) completion();
        return;
    }
    _isRefreshing = YES;

    NSArray *feedsToRefresh = [_feeds copy];
    __block NSUInteger nextIndex = 0;
    __block NSUInteger activeCount = 0;
    __block NSUInteger completedCount = 0;
    const NSUInteger maxConcurrent = 2;
    NSUInteger total = feedsToRefresh.count;

    void (^__block startNext)(void) = ^{
        while (activeCount < maxConcurrent && nextIndex < total) {
            RNFeed *feed = [feedsToRefresh objectAtIndex:nextIndex++];
            activeCount++;
            [self refreshFeed:feed saveAfter:NO completion:^(BOOL success, NSError *error) {
                activeCount--;
                completedCount++;
                if (completedCount >= total) {
                    startNext = nil;
                    self->_isRefreshing = NO;
                    [self purgeOldArticles];
                    [self save];
                    [[NSNotificationCenter defaultCenter] postNotificationName:RNFeedsDidUpdateNotification object:nil];
                    if (completion) completion();
                } else {
                    startNext();
                }
            }];
        }
    };

    startNext();
}

- (void)markItem:(RNFeedItem *)item asRead:(BOOL)isRead
{
    if (!item) return;
    item.isRead = isRead;
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:RNArticleReadStatusChangedNotification
                                                        object:item
                                                      userInfo:@{ @"articleId": item.identifier ?: @"" }];
}

- (void)markAllItemsAsReadInFeed:(RNFeed *)feed
{
    if (!feed) return;
    for (RNFeedItem *it in feed.items) {
        it.isRead = YES;
    }
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:RNFeedDidUpdateNotification
                                                        object:feed
                                                      userInfo:@{ @"feedURL": feed.url }];
}

- (void)toggleFavoriteForItem:(RNFeedItem *)item
{
    if (!item) return;
    item.isFavorite = !item.isFavorite;
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:RNArticleStarStatusChangedNotification
                                                        object:item
                                                      userInfo:@{ @"articleId": item.identifier ?: @"" }];
}

- (NSArray *)allUnreadItems
{
    NSMutableArray *res = [NSMutableArray array];
    for (RNFeed *f in _feeds) {
        for (RNFeedItem *it in f.items) {
            if (!it.isRead) [res addObject:it];
        }
    }
    [res sortUsingComparator:^NSComparisonResult(RNFeedItem *a, RNFeedItem *b) {
        if (!a.publishDate && !b.publishDate) return NSOrderedSame;
        if (!a.publishDate) return NSOrderedDescending;
        if (!b.publishDate) return NSOrderedAscending;
        return [b.publishDate compare:a.publishDate];
    }];
    return [res copy];
}

- (NSArray *)starredItems
{
    NSMutableArray *res = [NSMutableArray array];
    for (RNFeed *f in _feeds) {
        for (RNFeedItem *it in f.items) {
            if (it.isFavorite) [res addObject:it];
        }
    }
    [res sortUsingComparator:^NSComparisonResult(RNFeedItem *a, RNFeedItem *b) {
        if (!a.publishDate && !b.publishDate) return NSOrderedSame;
        if (!a.publishDate) return NSOrderedDescending;
        if (!b.publishDate) return NSOrderedAscending;
        return [b.publishDate compare:a.publishDate];
    }];
    return [res copy];
}

- (NSInteger)totalUnreadCount
{
    NSInteger count = 0;
    for (RNFeed *f in _feeds) {
        count += f.unreadCount;
    }
    return count;
}

- (void)purgeOldArticles
{
    if (_retentionDays <= 0) return;
    NSTimeInterval cutoffSeconds = (NSTimeInterval)(_retentionDays * 86400);
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-cutoffSeconds];

    for (RNFeed *f in _feeds) {
        NSMutableArray *kept = [NSMutableArray array];
        for (RNFeedItem *it in f.items) {
            // Never purge starred items
            if (it.isFavorite) {
                [kept addObject:it];
                continue;
            }
            if (!it.publishDate || [it.publishDate compare:cutoff] == NSOrderedDescending) {
                [kept addObject:it];
            }
        }
        f.items = kept;
    }
}

- (void)clearAllCache
{
    [[RNImageLoader shared] clearCache];
}

@end
