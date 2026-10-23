#import "RNWebPDecoder.h"
#import "webp/decode.h"

@implementation RNWebPDecoder

+ (BOOL)isWebPData:(NSData *)data
{
    if (!data || data.length < 12) return NO;
    const uint8_t *b = (const uint8_t *)data.bytes;
    if (b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F' &&
        b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P') {
        return YES;
    }
    return NO;
}

+ (UIImage *)imageWithWebPData:(NSData *)data
{
    if (!data || data.length == 0) return nil;

    int width = 0, height = 0;
    if (!WebPGetInfo((const uint8_t *)data.bytes, (size_t)data.length, &width, &height)) {
        return nil;
    }
    if (width <= 0 || height <= 0) return nil;

    uint8_t *rgba = WebPDecodeRGBA((const uint8_t *)data.bytes, (size_t)data.length, &width, &height);
    if (!rgba) return nil;

    // Premultiply alpha for CoreGraphics compatibility
    int totalPixels = width * height;
    for (int i = 0; i < totalPixels; i++) {
        uint8_t a = rgba[4 * i + 3];
        if (a != 255) {
            rgba[4 * i + 0] = (uint8_t)(((uint16_t)rgba[4 * i + 0] * a) / 255);
            rgba[4 * i + 1] = (uint8_t)(((uint16_t)rgba[4 * i + 1] * a) / 255);
            rgba[4 * i + 2] = (uint8_t)(((uint16_t)rgba[4 * i + 2] * a) / 255);
        }
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, rgba, width * height * 4, (CGDataProviderReleaseDataCallback)WebPFree);
    CGImageRef imageRef = CGImageCreate(width, height, 8, 32, 4 * width, colorSpace, bitmapInfo, provider, NULL, NO, kCGRenderingIntentDefault);

    UIImage *image = nil;
    if (imageRef) {
        image = [UIImage imageWithCGImage:imageRef scale:1.0f orientation:UIImageOrientationUp];
        CGImageRelease(imageRef);
    }

    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);

    return image;
}

+ (NSData *)convertWebPToJPEG:(NSData *)data quality:(CGFloat)quality
{
    UIImage *img = [self imageWithWebPData:data];
    if (!img) return nil;
    return UIImageJPEGRepresentation(img, quality > 0 ? quality : 0.85f);
}

@end
