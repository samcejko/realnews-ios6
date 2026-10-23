#import <Foundation/Foundation.h>

typedef void (^RNHTTPCompleteBlock)(NSInteger status, NSData *body, NSError *error);

@interface RNHTTPRequest : NSObject

@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) NSData *body;
@property (nonatomic) NSTimeInterval connectTimeout;    // seconds, default 15
@property (nonatomic) NSTimeInterval readTimeout;       // seconds, default 60
@property (nonatomic) BOOL verifyTLS;

@property (nonatomic, copy) RNHTTPCompleteBlock onComplete;
@property (nonatomic, readonly) NSInteger statusCode;
@property (nonatomic, readonly) NSDictionary *responseHeaders;
@property (nonatomic, readonly) BOOL isCancelled;
@property (nonatomic, readonly) BOOL isFinished;

+ (instancetype)requestWithURLString:(NSString *)urlString;
- (void)start;
- (void)cancel;

@end
