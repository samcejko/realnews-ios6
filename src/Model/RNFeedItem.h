#import <Foundation/Foundation.h>

@interface RNFeedItem : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *feedURL;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, strong) NSDate *publishDate;
@property (nonatomic, copy) NSString *publishDateString;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, copy) NSString *thumbnailURL;
@property (nonatomic, copy) NSString *enclosureURL;
@property (nonatomic, copy) NSString *enclosureType;
@property (nonatomic) long long enclosureLength;
@property (nonatomic) BOOL isRead;
@property (nonatomic) BOOL isFavorite;
@property (nonatomic, copy) NSString *fullTextContent;
@property (nonatomic, copy) NSString *leadImageURL;

// All extra / custom metadata fields extracted from the feed item XML
@property (nonatomic, strong) NSDictionary *extraData;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

- (NSString *)displayDate;
- (NSString *)snippetText;

@end
