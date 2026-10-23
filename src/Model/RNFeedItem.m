#import "RNLegacyCollections.h"
#import "RNFeedItem.h"
#import "RNUtils.h"

@implementation RNFeedItem

- (instancetype)init
{
    self = [super init];
    if (self) {
        _extraData = [NSDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [self init];
    if (self && dict) {
        _identifier = [[dict objectForKey:@"identifier"] copy];
        _feedURL = [[dict objectForKey:@"feedURL"] copy];
        _title = [[dict objectForKey:@"title"] copy];
        _link = [[dict objectForKey:@"link"] copy];
        _author = [[dict objectForKey:@"author"] copy];
        if ([dict objectForKey:@"publishDate"]) {
            _publishDate = [NSDate dateWithTimeIntervalSince1970:[[dict objectForKey:@"publishDate"] doubleValue]];
        }
        _publishDateString = [[dict objectForKey:@"publishDateString"] copy];
        _summary = [[dict objectForKey:@"summary"] copy];
        _content = [[dict objectForKey:@"content"] copy];
        _thumbnailURL = [[dict objectForKey:@"thumbnailURL"] copy];
        _enclosureURL = [[dict objectForKey:@"enclosureURL"] copy];
        _enclosureType = [[dict objectForKey:@"enclosureType"] copy];
        _enclosureLength = [[dict objectForKey:@"enclosureLength"] longLongValue];
        _isRead = [[dict objectForKey:@"isRead"] boolValue];
        _isFavorite = [[dict objectForKey:@"isFavorite"] boolValue];
        _fullTextContent = [[dict objectForKey:@"fullTextContent"] copy];
        _leadImageURL = [[dict objectForKey:@"leadImageURL"] copy];
        if ([dict objectForKey:@"extraData"] && [[dict objectForKey:@"extraData"] isKindOfClass:[NSDictionary class]]) {
            _extraData = [[dict objectForKey:@"extraData"] copy];
        }
    }
    return self;
}

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (_identifier) RNSetDictionaryObject(d, @"identifier", _identifier);
    if (_feedURL) RNSetDictionaryObject(d, @"feedURL", _feedURL);
    if (_title) RNSetDictionaryObject(d, @"title", _title);
    if (_link) RNSetDictionaryObject(d, @"link", _link);
    if (_author) RNSetDictionaryObject(d, @"author", _author);
    if (_publishDate) RNSetDictionaryObject(d, @"publishDate", @([_publishDate timeIntervalSince1970]));
    if (_publishDateString) RNSetDictionaryObject(d, @"publishDateString", _publishDateString);
    if (_summary) RNSetDictionaryObject(d, @"summary", _summary);
    if (_content) RNSetDictionaryObject(d, @"content", _content);
    if (_thumbnailURL) RNSetDictionaryObject(d, @"thumbnailURL", _thumbnailURL);
    if (_enclosureURL) RNSetDictionaryObject(d, @"enclosureURL", _enclosureURL);
    if (_enclosureType) RNSetDictionaryObject(d, @"enclosureType", _enclosureType);
    RNSetDictionaryObject(d, @"enclosureLength", @(_enclosureLength));
    RNSetDictionaryObject(d, @"isRead", @(_isRead));
    RNSetDictionaryObject(d, @"isFavorite", @(_isFavorite));
    if (_fullTextContent) RNSetDictionaryObject(d, @"fullTextContent", _fullTextContent);
    if (_leadImageURL) RNSetDictionaryObject(d, @"leadImageURL", _leadImageURL);
    if (_extraData) RNSetDictionaryObject(d, @"extraData", _extraData);
    return [d copy];
}

- (NSString *)displayDate
{
    if (_publishDate) {
        return [RNUtils relativeDateStringFromDate:_publishDate];
    }
    return _publishDateString.length ? _publishDateString : @"";
}

- (NSString *)snippetText
{
    if (_summary.length) {
        return [RNUtils stripHTML:_summary];
    }
    if (_content.length) {
        NSString *s = [RNUtils stripHTML:_content];
        if (s.length > 200) {
            s = [s substringToIndex:200];
        }
        return s;
    }
    return @"";
}

@end
