#import "RNLegacyCollections.h"
#import "RNFeedParser.h"
#import "RNFeedItem.h"
#import "RNUtils.h"
#import "RNCommon.h"

@interface RNFeedParser () {
    NSString *_feedURL;
    RNFeed *_feed;
    NSMutableArray *_items;
    NSMutableDictionary *_channelExtra;

    BOOL _inChannel;
    BOOL _inItem;
    BOOL _isAtom;

    RNFeedItem *_currentItem;
    NSMutableDictionary *_itemExtra;
    NSMutableString *_currentText;
    NSDictionary *_currentAttributes;
    NSString *_currentElement;
    NSMutableArray *_elementStack;
    NSMutableArray *_textStack;
}
@end

@implementation RNFeedParser

+ (RNFeed *)parseFeedData:(NSData *)data feedURL:(NSString *)feedURL error:(NSError **)error
{
    if (!data.length) {
        if (error) *error = RNMakeError(RNErrorParseFailed, @"Empty feed data");
        return nil;
    }

    // Let the XML parser detect the encoding from the original bytes. XML defaults
    // to UTF-8 without a declaration; prepending one breaks BOMs and UTF-16 feeds.
    RNFeedParser *parser = [[RNFeedParser alloc] init];
    parser->_feedURL = [feedURL copy];
    parser->_items = [NSMutableArray array];
    parser->_channelExtra = [NSMutableDictionary dictionary];
    parser->_elementStack = [NSMutableArray array];
    parser->_textStack = [NSMutableArray array];

    NSXMLParser *xml = [[NSXMLParser alloc] initWithData:data];
    [xml setShouldProcessNamespaces:NO]; // Keep exact tag prefixes like content:encoded, dc:creator
    [xml setShouldReportNamespacePrefixes:NO];
    [xml setShouldResolveExternalEntities:NO];
    [xml setDelegate:parser];

    BOOL ok = [xml parse];
    if (!ok) {
        NSError *parseErr = [xml parserError];
        if (error) *error = parseErr ? parseErr : RNMakeError(RNErrorParseFailed, @"XML Parsing failed");
        return nil;
    }

    if (!parser->_feed) {
        if (error) *error = RNMakeError(RNErrorParseFailed, L(@"NotAFeed"));
        return nil;
    }
    parser->_feed.channelExtraData = [parser->_channelExtra copy];
    [parser->_feed.items addObjectsFromArray:parser->_items];

    return parser->_feed;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict
{
    NSString *tag = qName.length ? qName : elementName;
    [_elementStack addObject:tag];
    _currentElement = tag;
    _currentAttributes = attributeDict;
    _currentText = [NSMutableString string];
    [_textStack addObject:_currentText];

    NSString *lowerTag = tag.lowercaseString;

    if ([lowerTag isEqualToString:@"feed"]) {
        _isAtom = YES;
        _inChannel = YES;
        _feed = [[RNFeed alloc] initWithURL:_feedURL title:nil];
    } else if ([lowerTag isEqualToString:@"channel"]) {
        _inChannel = YES;
        _feed = [[RNFeed alloc] initWithURL:_feedURL title:nil];
    } else if ([lowerTag isEqualToString:@"item"] || (_isAtom && [lowerTag isEqualToString:@"entry"])) {
        _inItem = YES;
        _currentItem = [[RNFeedItem alloc] init];
        _currentItem.feedURL = _feedURL;
        _itemExtra = [NSMutableDictionary dictionary];
    }

    // Special handling for tags with attributes (like enclosure, link, media)
    if (_inItem && _currentItem) {
        if ([lowerTag isEqualToString:@"enclosure"]) {
            _currentItem.enclosureURL = [attributeDict objectForKey:@"url"];
            _currentItem.enclosureType = [attributeDict objectForKey:@"type"];
            _currentItem.enclosureLength = [[attributeDict objectForKey:@"length"] longLongValue];
            if ([_currentItem.enclosureType hasPrefix:@"image/"] && !_currentItem.thumbnailURL.length) {
                _currentItem.thumbnailURL = _currentItem.enclosureURL;
            }
        } else if ([lowerTag isEqualToString:@"media:thumbnail"]) {
            if ([attributeDict objectForKey:@"url"]) {
                _currentItem.thumbnailURL = [attributeDict objectForKey:@"url"];
            }
        } else if ([lowerTag isEqualToString:@"media:content"]) {
            NSString *url = [attributeDict objectForKey:@"url"];
            NSString *type = [attributeDict objectForKey:@"type"];
            if (url) {
                if ([type hasPrefix:@"image/"] || [url hasSuffix:@".jpg"] || [url hasSuffix:@".png"]) {
                    if (!_currentItem.thumbnailURL.length) _currentItem.thumbnailURL = url;
                }
                if (!_currentItem.enclosureURL.length) {
                    _currentItem.enclosureURL = url;
                    _currentItem.enclosureType = type;
                }
            }
        } else if (_isAtom && [lowerTag isEqualToString:@"link"]) {
            NSString *rel = [attributeDict objectForKey:@"rel"];
            NSString *href = [attributeDict objectForKey:@"href"];
            if (href.length) {
                if (!rel.length || [rel isEqualToString:@"alternate"]) {
                    _currentItem.link = href;
                } else if ([rel isEqualToString:@"enclosure"]) {
                    _currentItem.enclosureURL = href;
                    _currentItem.enclosureType = [attributeDict objectForKey:@"type"];
                    _currentItem.enclosureLength = [[attributeDict objectForKey:@"length"] longLongValue];
                }
            }
        }

        // Store attributes into itemExtra if any exist
        if (attributeDict.count > 0) {
            for (NSString *attrKey in attributeDict) {
                NSString *compositeKey = [NSString stringWithFormat:@"%@[@%@]", tag, attrKey];
                RNSetDictionaryObject(_itemExtra, compositeKey, [attributeDict objectForKey:attrKey]);
            }
        }
    } else if (!_inItem && _inChannel && _feed) {
        if (_isAtom && [lowerTag isEqualToString:@"link"]) {
            NSString *rel = [attributeDict objectForKey:@"rel"];
            NSString *href = [attributeDict objectForKey:@"href"];
            if (href.length && (!rel.length || [rel isEqualToString:@"alternate"])) {
                _feed.siteURL = href;
            }
        }
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (_currentText) {
        [_currentText appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    NSString *cdataStr = [[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding];
    if (!cdataStr) {
        cdataStr = [[NSString alloc] initWithData:CDATABlock encoding:NSISOLatin1StringEncoding];
    }
    if (cdataStr && _currentText) {
        [_currentText appendString:cdataStr];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
    NSString *tag = qName.length ? qName : elementName;
    NSString *text = [RNUtils cleanString:_currentText];
    NSString *rawText = [_currentText copy];
    NSString *parent = _elementStack.count >= 2 ? [[_elementStack objectAtIndex:_elementStack.count - 2] lowercaseString] : @"";
    BOOL directItemChild = [parent isEqualToString:@"item"] || [parent isEqualToString:@"entry"];
    BOOL directFeedChild = [parent isEqualToString:@"channel"] || [parent isEqualToString:@"feed"];
    NSString *lowerTag = tag.lowercaseString;

    if (_inItem && _currentItem) {
        if ([lowerTag isEqualToString:@"item"] || (_isAtom && [lowerTag isEqualToString:@"entry"])) {
            // End of item
            // Fallback for ID
            if (!_currentItem.identifier.length) {
                if (_currentItem.link.length) {
                    _currentItem.identifier = _currentItem.link;
                } else {
                    _currentItem.identifier = [NSString stringWithFormat:@"%@_%@", _currentItem.title, _currentItem.publishDateString];
                }
            }
            // Fallback for publish date
            if (!_currentItem.publishDate && _currentItem.publishDateString.length) {
                _currentItem.publishDate = [RNUtils parseDateString:_currentItem.publishDateString];
            }

            // Extract thumbnail from HTML content if missing
            if (!_currentItem.thumbnailURL.length) {
                NSString *html = _currentItem.content.length ? _currentItem.content : _currentItem.summary;
                if (html.length) {
                    NSRange imgRange = [html rangeOfString:@"<img[^>]+src=[\"']([^\"']+)[\"']" options:NSRegularExpressionSearch | NSCaseInsensitiveSearch];
                    if (imgRange.location != NSNotFound) {
                        NSString *tagSub = [html substringWithRange:imgRange];
                        NSRange srcRange = [tagSub rangeOfString:@"src=[\"']([^\"']+)[\"']" options:NSRegularExpressionSearch | NSCaseInsensitiveSearch];
                        if (srcRange.location != NSNotFound) {
                            NSString *srcSub = [tagSub substringWithRange:srcRange];
                            NSRange quote1 = [srcSub rangeOfString:@"\""];
                            if (quote1.location == NSNotFound) quote1 = [srcSub rangeOfString:@"'"];
                            if (quote1.location != NSNotFound) {
                                NSString *afterQuote = [srcSub substringFromIndex:quote1.location + 1];
                                NSRange quote2 = [afterQuote rangeOfString:[srcSub substringWithRange:quote1]];
                                if (quote2.location != NSNotFound) {
                                    _currentItem.thumbnailURL = [afterQuote substringToIndex:quote2.location];
                                }
                            }
                        }
                    }
                }
            }

            if (!_currentItem.thumbnailURL.length && [_currentItem.enclosureType hasPrefix:@"image/"]) {
                _currentItem.thumbnailURL = _currentItem.enclosureURL;
            }

            _currentItem.extraData = [_itemExtra copy];
            [_items addObject:_currentItem];
            _currentItem = nil;
            _inItem = NO;
        } else {
            // Child tag inside an item
            if (directItemChild && [lowerTag isEqualToString:@"title"]) {
                _currentItem.title = text;
            } else if (directItemChild && ([lowerTag isEqualToString:@"link"] && !_isAtom)) {
                _currentItem.link = text;
            } else if (directItemChild && ([lowerTag isEqualToString:@"description"])) {
                _currentItem.summary = rawText;
            } else if (directItemChild && ([lowerTag isEqualToString:@"content:encoded"] || [lowerTag isEqualToString:@"content"])) {
                _currentItem.content = rawText;
            } else if (_isAtom && [parent isEqualToString:@"author"] && [lowerTag isEqualToString:@"name"]) {
                _currentItem.author = text;
            } else if (directItemChild && ([lowerTag isEqualToString:@"author"] || [lowerTag isEqualToString:@"dc:creator"])) {
                if (!_isAtom || !_currentItem.author.length) _currentItem.author = text;
            } else if (directItemChild && ([lowerTag isEqualToString:@"pubdate"] || [lowerTag isEqualToString:@"published"] ||
                       [lowerTag isEqualToString:@"updated"] || [lowerTag isEqualToString:@"dc:date"])) {
                _currentItem.publishDateString = text;
                _currentItem.publishDate = [RNUtils parseDateString:text];
            } else if (directItemChild && ([lowerTag isEqualToString:@"guid"] || [lowerTag isEqualToString:@"id"])) {
                _currentItem.identifier = text;
            }

            // ALWAYS store in extraData so ANY custom metadata is accessible
            if (rawText.length > 0) {
                id existing = [_itemExtra objectForKey:tag];
                if (existing) {
                    if ([existing isKindOfClass:[NSMutableArray class]]) {
                        [(NSMutableArray *)existing addObject:text];
                    } else {
                        NSMutableArray *arr = [NSMutableArray arrayWithObjects:existing, text, nil];
                        RNSetDictionaryObject(_itemExtra, tag, arr);
                    }
                } else {
                    RNSetDictionaryObject(_itemExtra, tag, text);
                }
            }
        }
    } else if (_inChannel && _feed) {
        if (directFeedChild && [lowerTag isEqualToString:@"title"]) {
            _feed.title = text;
        } else if (directFeedChild && ([lowerTag isEqualToString:@"link"] && !_isAtom)) {
            _feed.siteURL = text;
        } else if (directFeedChild && ([lowerTag isEqualToString:@"description"] || [lowerTag isEqualToString:@"subtitle"])) {
            _feed.feedDescription = text;
        } else if (directFeedChild && ([lowerTag isEqualToString:@"icon"] || [lowerTag isEqualToString:@"logo"])) {
            _feed.iconURL = text;
        } else if ([lowerTag isEqualToString:@"url"] && _elementStack.count >= 2) {
            NSString *parentTag = [_elementStack objectAtIndex:_elementStack.count - 2];
            if ([parentTag.lowercaseString isEqualToString:@"image"]) {
                _feed.iconURL = text;
            }
        }

        if (text.length > 0) {
            RNSetDictionaryObject(_channelExtra, tag, text);
        }
    }

    if (_elementStack.count > 0) {
        [_elementStack removeLastObject];
    }
    _currentElement = _elementStack.lastObject;
    [_textStack removeLastObject];
    _currentText = [_textStack lastObject];
    BOOL structuralParent = [parent isEqualToString:@"item"] || [parent isEqualToString:@"entry"] ||
        [parent isEqualToString:@"channel"] || [parent isEqualToString:@"feed"] ||
        [parent isEqualToString:@"rss"] || [parent isEqualToString:@"rdf:rdf"];
    if (_currentText && rawText.length && !structuralParent) [_currentText appendString:rawText];
    if ([lowerTag isEqualToString:@"channel"] || [lowerTag isEqualToString:@"feed"]) _inChannel = NO;
}

@end
