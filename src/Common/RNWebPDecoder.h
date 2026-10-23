#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RNWebPDecoder : NSObject

+ (BOOL)isWebPData:(NSData *)data;
+ (UIImage *)imageWithWebPData:(NSData *)data;
+ (NSData *)convertWebPToJPEG:(NSData *)data quality:(CGFloat)quality;

@end
