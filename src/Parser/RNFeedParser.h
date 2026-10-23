#import <Foundation/Foundation.h>
#import "RNFeed.h"

@interface RNFeedParser : NSObject <NSXMLParserDelegate>

// Parses raw XML feed data into an RNFeed object with all standard and custom metadata fields
+ (RNFeed *)parseFeedData:(NSData *)data feedURL:(NSString *)feedURL error:(NSError **)error;

@end
