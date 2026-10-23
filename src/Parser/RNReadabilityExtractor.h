#import <Foundation/Foundation.h>

@interface RNReadabilityResult : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *byline;
@property (nonatomic, copy) NSString *contentHTML;
@property (nonatomic, copy) NSString *leadImageURL;
@end

typedef void (^RNReadabilityCompletion)(RNReadabilityResult *result, NSError *error);

@interface RNReadabilityExtractor : NSObject

+ (void)extractArticleFromURL:(NSString *)urlString completion:(RNReadabilityCompletion)completion;
+ (RNReadabilityResult *)extractArticleFromHTML:(NSString *)html baseURL:(NSString *)baseURL;

@end
