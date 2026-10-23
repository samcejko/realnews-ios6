#import "RNFeedDiscovery.h"
#import "RNHTTPRequest.h"
#import "RNFeedParser.h"
#import "RNCommon.h"
#import "RNFeedStore.h"

@implementation RNDiscoveredFeed
@end

@implementation RNFeedDiscovery

+ (void)discoverFeedsForURL:(NSString *)inputURL completion:(RNFeedDiscoveryCompletion)completion
{
    if (!inputURL.length) {
        if (completion) completion(@[], nil);
        return;
    }

    NSString *trimmed = [inputURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![trimmed hasPrefix:@"http://"] && ![trimmed hasPrefix:@"https://"]) {
        trimmed = [@"http://" stringByAppendingString:trimmed];
    }

    NSInteger timeout = [RNFeedStore sharedStore].networkTimeout;

    // Step 1: Check if the URL is already an RSS/Atom feed directly
    RNHTTPRequest *req = [RNHTTPRequest requestWithURLString:trimmed];
    req.connectTimeout = timeout;
    req.readTimeout = timeout;
    req.onComplete = ^(NSInteger status, NSData *body, NSError *error) {
        if (!error && status >= 200 && status < 400 && body.length > 0) {
            RNFeed *directFeed = [RNFeedParser parseFeedData:body feedURL:trimmed error:NULL];
            if (directFeed && (directFeed.title.length || directFeed.items.count > 0)) {
                RNDiscoveredFeed *item = [[RNDiscoveredFeed alloc] init];
                item.url = trimmed;
                item.title = directFeed.title.length ? directFeed.title : trimmed;
                if (completion) completion(@[ item ], nil);
                return;
            }

            // Step 2: It's an HTML page - parse <link rel="alternate" ...> tags
            NSString *html = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            if (!html) html = [[NSString alloc] initWithData:body encoding:NSISOLatin1StringEncoding];

            if (html.length > 0) {
                NSArray *discovered = [self parseAlternateLinksFromHTML:html baseURL:trimmed];
                if (discovered.count > 0) {
                    if (completion) completion(discovered, nil);
                    return;
                }
            }
        }

        // Step 3: Probing common endpoints (/feed, /rss, /atom.xml)
        [self probeCommonEndpointsForBaseURL:trimmed completion:completion];
    };
    [req start];
}

+ (NSArray *)parseAlternateLinksFromHTML:(NSString *)html baseURL:(NSString *)baseURL
{
    NSMutableArray *results = [NSMutableArray array];
    NSMutableSet *seenUrls = [NSMutableSet set];

    // Regex matching <link ...> tags
    NSRegularExpression *linkTagRegex = [NSRegularExpression regularExpressionWithPattern:@"<link[^>]+>"
                                                                                  options:NSRegularExpressionCaseInsensitive
                                                                                    error:NULL];
    NSArray *matches = [linkTagRegex matchesInString:html options:0 range:NSMakeRange(0, html.length)];

    for (NSTextCheckingResult *m in matches) {
        NSString *tag = [html substringWithRange:m.range];

        BOOL isFeedType = ([tag rangeOfString:@"application/rss+xml" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                           [tag rangeOfString:@"application/atom+xml" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                           [tag rangeOfString:@"text/xml" options:NSCaseInsensitiveSearch].location != NSNotFound);

        BOOL isAlternate = ([tag rangeOfString:@"alternate" options:NSCaseInsensitiveSearch].location != NSNotFound);

        if (isFeedType || (isAlternate && [tag rangeOfString:@"xml" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
            // Extract href
            NSRegularExpression *hrefRegex = [NSRegularExpression regularExpressionWithPattern:@"href=[\"']([^\"']+)[\"']"
                                                                                       options:NSRegularExpressionCaseInsensitive
                                                                                         error:NULL];
            NSTextCheckingResult *hrefMatch = [hrefRegex firstMatchInString:tag options:0 range:NSMakeRange(0, tag.length)];
            if (hrefMatch && hrefMatch.numberOfRanges > 1) {
                NSString *rawHref = [tag substringWithRange:[hrefMatch rangeAtIndex:1]];
                NSURL *bURL = [NSURL URLWithString:baseURL];
                NSURL *absURL = [NSURL URLWithString:rawHref relativeToURL:bURL];
                NSString *finalURL = absURL.absoluteString.length ? absURL.absoluteString : rawHref;

                if (![seenUrls containsObject:finalURL]) {
                    [seenUrls addObject:finalURL];

                    // Extract title if present
                    NSString *title = nil;
                    NSRegularExpression *titleRegex = [NSRegularExpression regularExpressionWithPattern:@"title=[\"']([^\"']+)[\"']"
                                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                                  error:NULL];
                    NSTextCheckingResult *titleMatch = [titleRegex firstMatchInString:tag options:0 range:NSMakeRange(0, tag.length)];
                    if (titleMatch && titleMatch.numberOfRanges > 1) {
                        title = [tag substringWithRange:[titleMatch rangeAtIndex:1]];
                    }
                    if (!title.length) {
                        title = finalURL.lastPathComponent;
                    }

                    RNDiscoveredFeed *item = [[RNDiscoveredFeed alloc] init];
                    item.url = finalURL;
                    item.title = title;
                    [results addObject:item];
                }
            }
        }
    }

    return [results copy];
}

+ (void)probeCommonEndpointsForBaseURL:(NSString *)baseURL completion:(RNFeedDiscoveryCompletion)completion
{
    NSURL *bURL = [NSURL URLWithString:baseURL];
    if (!bURL) {
        if (completion) completion(@[], nil);
        return;
    }

    NSString *origin = [NSString stringWithFormat:@"%@://%@", bURL.scheme, bURL.host];
    NSArray *candidates = @[
        [origin stringByAppendingString:@"/feed"],
        [origin stringByAppendingString:@"/rss"],
        [origin stringByAppendingString:@"/atom.xml"],
        [origin stringByAppendingString:@"/rss.xml"]
    ];

    NSInteger timeout = [RNFeedStore sharedStore].networkTimeout;
    __block NSInteger remaining = (NSInteger)candidates.count;
    NSMutableArray *found = [NSMutableArray array];

    for (NSString *candURL in candidates) {
        RNHTTPRequest *req = [RNHTTPRequest requestWithURLString:candURL];
        req.connectTimeout = timeout;
        req.readTimeout = timeout;
        req.onComplete = ^(NSInteger status, NSData *body, NSError *error) {
            remaining--;
            if (!error && status >= 200 && status < 400 && body.length > 0) {
                RNFeed *feed = [RNFeedParser parseFeedData:body feedURL:candURL error:NULL];
                if (feed && (feed.title.length || feed.items.count > 0)) {
                    RNDiscoveredFeed *item = [[RNDiscoveredFeed alloc] init];
                    item.url = candURL;
                    item.title = feed.title.length ? feed.title : candURL;
                    @synchronized (found) {
                        [found addObject:item];
                    }
                }
            }

            if (remaining == 0) {
                if (completion) completion([found copy], nil);
            }
        };
        [req start];
    }
}

@end
