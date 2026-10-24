#import "RNLegacyCollections.h"
#import "RNFeed.h"

@implementation RNFeed

- (instancetype)initWithURL:(NSString *)url title:(NSString *)title
{
    self = [super init];
    if (self) {
        _url = [url copy];
        _title = title.length ? [title copy] : [url copy];
        _items = [NSMutableArray array];
        _iconBackgroundEnabled = YES;
        _channelExtraData = [NSDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
    if (self && dict) {
        _url = [[dict objectForKey:@"url"] copy];
        _title = [[dict objectForKey:@"title"] copy];
        _siteURL = [[dict objectForKey:@"siteURL"] copy];
        _feedDescription = [[dict objectForKey:@"feedDescription"] copy];
        _category = [[dict objectForKey:@"category"] copy];
        _lastError = [[dict objectForKey:@"lastError"] copy];
        _iconURL = [[dict objectForKey:@"iconURL"] copy];
        _iconBackgroundEnabled = [dict objectForKey:@"iconBackgroundEnabled"] ? [[dict objectForKey:@"iconBackgroundEnabled"] boolValue] : YES;
        if ([dict objectForKey:@"lastUpdated"]) {
            _lastUpdated = [NSDate dateWithTimeIntervalSince1970:[[dict objectForKey:@"lastUpdated"] doubleValue]];
        }
        if ([dict objectForKey:@"channelExtraData"] && [[dict objectForKey:@"channelExtraData"] isKindOfClass:[NSDictionary class]]) {
            _channelExtraData = [[dict objectForKey:@"channelExtraData"] copy];
        } else {
            _channelExtraData = [NSDictionary dictionary];
        }

        _items = [NSMutableArray array];
        NSArray *rawItems = [dict objectForKey:@"items"];
        if ([rawItems isKindOfClass:[NSArray class]]) {
            for (NSDictionary *idict in rawItems) {
                if ([idict isKindOfClass:[NSDictionary class]]) {
                    RNFeedItem *it = [[RNFeedItem alloc] initWithDictionary:idict];
                    [_items addObject:it];
                }
            }
        }
    }
    return self;
}

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (_url) RNSetDictionaryObject(d, @"url", _url);
    if (_title) RNSetDictionaryObject(d, @"title", _title);
    if (_siteURL) RNSetDictionaryObject(d, @"siteURL", _siteURL);
    if (_feedDescription) RNSetDictionaryObject(d, @"feedDescription", _feedDescription);
    if (_category) RNSetDictionaryObject(d, @"category", _category);
    if (_lastError) RNSetDictionaryObject(d, @"lastError", _lastError);
    if (_iconURL) RNSetDictionaryObject(d, @"iconURL", _iconURL);
    RNSetDictionaryObject(d, @"iconBackgroundEnabled", @(_iconBackgroundEnabled));
    if (_lastUpdated) RNSetDictionaryObject(d, @"lastUpdated", @([_lastUpdated timeIntervalSince1970]));
    if (_channelExtraData) RNSetDictionaryObject(d, @"channelExtraData", _channelExtraData);

    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:_items.count];
    for (RNFeedItem *it in _items) {
        [arr addObject:[it toDictionary]];
    }
    RNSetDictionaryObject(d, @"items", arr);
    return [d copy];
}

- (NSString *)effectiveIconURL
{
    if (_iconURL.length > 0) {
        return _iconURL;
    }
    NSString *base = _siteURL.length ? _siteURL : _url;
    if (!base.length) return nil;
    NSURL *u = [NSURL URLWithString:base];
    if (!u.scheme || !u.host) return nil;
    return [NSString stringWithFormat:@"%@://%@/favicon.ico", u.scheme, u.host];
}

- (NSInteger)unreadCount
{
    NSInteger count = 0;
    for (RNFeedItem *it in _items) {
        if (!it.isRead) count++;
    }
    return count;
}

- (void)addItem:(RNFeedItem *)item
{
    if (!item) return;
    item.feedURL = self.url;
    [_items insertObject:item atIndex:0];
}

- (void)mergeItems:(NSArray *)newItems maxItems:(NSInteger)maxItems
{
    if (!newItems.count) return;

    NSMutableDictionary *existingMap = [NSMutableDictionary dictionary];
    for (RNFeedItem *it in _items) {
        if (it.identifier.length) {
            RNSetDictionaryObject(existingMap, it.identifier, it);
        } else if (it.link.length) {
            RNSetDictionaryObject(existingMap, it.link, it);
        }
    }

    NSMutableArray *merged = [NSMutableArray array];
    for (RNFeedItem *newItem in newItems) {
        newItem.feedURL = self.url;
        NSString *key = newItem.identifier.length ? newItem.identifier : newItem.link;
        if (key.length && [existingMap objectForKey:key]) {
            RNFeedItem *existing = [existingMap objectForKey:key];
            // Preserve user states
            newItem.isRead = existing.isRead;
            newItem.isFavorite = existing.isFavorite;
            [merged addObject:newItem];
            [existingMap removeObjectForKey:key];
        } else {
            [merged addObject:newItem];
        }
    }

    // Keep older items that weren't in the incoming feed up to maxItems
    for (RNFeedItem *remaining in _items) {
        NSString *key = remaining.identifier.length ? remaining.identifier : remaining.link;
        if (key.length && [existingMap objectForKey:key]) {
            [merged addObject:remaining];
        }
    }

    // Sort descending by publishDate
    [merged sortUsingComparator:^NSComparisonResult(RNFeedItem *a, RNFeedItem *b) {
        if (!a.publishDate && !b.publishDate) return NSOrderedSame;
        if (!a.publishDate) return NSOrderedDescending;
        if (!b.publishDate) return NSOrderedAscending;
        return [b.publishDate compare:a.publishDate];
    }];

    if (maxItems > 0 && merged.count > (NSUInteger)maxItems) {
        _items = [[merged subarrayWithRange:NSMakeRange(0, maxItems)] mutableCopy];
    } else {
        _items = merged;
    }
}

@end
