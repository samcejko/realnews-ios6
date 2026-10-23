#import "RNImageLoader.h"
#import "RNHTTPRequest.h"
#import "RNWebPDecoder.h"
#import "RNCommon.h"
#import "RNFeedStore.h"
#import <CommonCrypto/CommonDigest.h>

@interface RNImageLoader () {
    NSCache *_memCache;
    NSMutableSet *_activeDownloads;
    NSString *_cacheDir;
}
@end

@implementation RNImageLoader

+ (instancetype)shared
{
    static RNImageLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[self alloc] init];
    });
    return loader;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _memCache = [[NSCache alloc] init];
        [_memCache setCountLimit:30];
        [_memCache setTotalCostLimit:12 * 1024 * 1024];
        _activeDownloads = [NSMutableSet set];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemoryCache)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemoryCache)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _cacheDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"images"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_cacheDir withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clearMemoryCache
{
    [_memCache removeAllObjects];
}

- (NSString *)cacheKeyForURL:(NSString *)url
{
    const char *str = url.UTF8String;
    if (!str) return @"";
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), result);
    NSMutableString *ms = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ms appendFormat:@"%02x", result[i]];
    }
    return ms;
}

- (NSString *)cachedFilePathForURL:(NSString *)url
{
    if (!url.length) return nil;
    NSString *key = [self cacheKeyForURL:url];
    NSString *path = [_cacheDir stringByAppendingPathComponent:key];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    return nil;
}

- (UIImage *)imageForURL:(NSString *)url
{
    if (!url.length) return nil;

    // 1. Memory cache
    UIImage *img = [_memCache objectForKey:url];
    if (img) return img;

    // 2. Disk cache
    NSString *path = [self cachedFilePathForURL:url];
    if (path) {
        img = [UIImage imageWithContentsOfFile:path];
        if (!img) {
            NSData *d = [NSData dataWithContentsOfFile:path];
            if ([RNWebPDecoder isWebPData:d]) {
                img = [RNWebPDecoder imageWithWebPData:d];
                if (img) {
                    NSData *jpg = UIImageJPEGRepresentation(img, 0.85f);
                    [jpg writeToFile:path atomically:YES];
                }
            }
        }
        if (img) {
            [_memCache setObject:img forKey:url cost:CGImageGetBytesPerRow(img.CGImage) * CGImageGetHeight(img.CGImage)];
            return img;
        }
    }

    // 3. Trigger download
    [self prefetchImageForURL:url];
    return nil;
}

- (void)prefetchImageForURL:(NSString *)url
{
    if (!url.length) return;
    @synchronized (_activeDownloads) {
        if ([_activeDownloads containsObject:url]) return;
        [_activeDownloads addObject:url];
    }

    RNHTTPRequest *req = [RNHTTPRequest requestWithURLString:url];
    req.connectTimeout = [RNFeedStore sharedStore].networkTimeout;
    req.readTimeout = [RNFeedStore sharedStore].networkTimeout;
    __weak typeof(self) weakSelf = self;
    req.onComplete = ^(NSInteger status, NSData *body, NSError *error) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;

        @synchronized (strongSelf->_activeDownloads) {
            [strongSelf->_activeDownloads removeObject:url];
        }

        if (status == 200 && body.length > 0) {
            NSString *key = [strongSelf cacheKeyForURL:url];
            NSString *path = [strongSelf->_cacheDir stringByAppendingPathComponent:key];

            NSData *finalData = body;
            UIImage *loaded = nil;
            if ([RNWebPDecoder isWebPData:body]) {
                loaded = [RNWebPDecoder imageWithWebPData:body];
                if (loaded) {
                    finalData = UIImageJPEGRepresentation(loaded, 0.85f);
                }
            } else {
                loaded = [UIImage imageWithData:body];
            }

            if (finalData.length > 0) {
                [finalData writeToFile:path atomically:YES];
            }

            if (loaded) {
                [strongSelf->_memCache setObject:loaded forKey:url cost:CGImageGetBytesPerRow(loaded.CGImage) * CGImageGetHeight(loaded.CGImage)];
                [[NSNotificationCenter defaultCenter] postNotificationName:RNImageDidLoadNotification
                                                                    object:nil
                                                                  userInfo:@{ @"url": url, @"path": path }];
            }
        }
    };
    [req start];
}

- (long long)cacheSizeInBytes
{
    long long total = 0;
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:_cacheDir];
    NSString *file;
    while ((file = [enumerator nextObject])) {
        NSString *fullPath = [_cacheDir stringByAppendingPathComponent:file];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
        total += [attrs fileSize];
    }
    return total;
}

- (void)clearCache
{
    [_memCache removeAllObjects];
    [[NSFileManager defaultManager] removeItemAtPath:_cacheDir error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:_cacheDir withIntermediateDirectories:YES attributes:nil error:NULL];
}

@end
