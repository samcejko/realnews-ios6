#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RNImageLoader : NSObject

+ (instancetype)shared;

- (UIImage *)imageForURL:(NSString *)url;
- (void)prefetchImageForURL:(NSString *)url;
- (NSString *)cachedFilePathForURL:(NSString *)url;
- (long long)cacheSizeInBytes;
- (void)clearCache;

@end
