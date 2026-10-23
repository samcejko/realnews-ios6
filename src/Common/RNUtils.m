#import "RNUtils.h"

@implementation RNUtils

+ (NSDate *)parseDateString:(NSString *)dateString
{
    if (!dateString.length) return nil;
    NSString *trimmed = [dateString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    static NSArray *formatters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLocale *enLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        NSArray *formats = @[
            @"EEE, dd MMM yyyy HH:mm:ss Z",
            @"EEE, dd MMM yyyy HH:mm:ss zzz",
            @"EEE, dd MMM yyyy HH:mm:ss",
            @"dd MMM yyyy HH:mm:ss Z",
            @"yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            @"yyyy-MM-dd'T'HH:mm:ss'Z'",
            @"yyyy-MM-dd'T'HH:mm:ss",
            @"yyyy-MM-dd HH:mm:ss",
            @"yyyy-MM-dd"
        ];
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:formats.count];
        for (NSString *fmt in formats) {
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setLocale:enLocale];
            [df setDateFormat:fmt];
            [arr addObject:df];
        }
        formatters = [arr copy];
    });
    
    for (NSDateFormatter *df in formatters) {
        NSDate *d = [df dateFromString:trimmed];
        if (d) return d;
    }
    return nil;
}

+ (NSString *)relativeDateStringFromDate:(NSDate *)date
{
    if (!date) return @"";
    NSTimeInterval delta = -[date timeIntervalSinceNow];
    if (delta < 0) delta = 0;
    
    if (delta < 60) {
        return @"Just now";
    } else if (delta < 3600) {
        int m = (int)(delta / 60);
        return [NSString stringWithFormat:@"%dm ago", m];
    } else if (delta < 86400) {
        int h = (int)(delta / 3600);
        return [NSString stringWithFormat:@"%dh ago", h];
    } else if (delta < 86400 * 7) {
        int d = (int)(delta / 86400);
        return [NSString stringWithFormat:@"%dd ago", d];
    } else {
        static NSDateFormatter *df = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            df = [[NSDateFormatter alloc] init];
            [df setDateStyle:NSDateFormatterShortStyle];
            [df setTimeStyle:NSDateFormatterNoStyle];
        });
        return [df stringFromDate:date];
    }
}

+ (NSString *)stripHTML:(NSString *)html
{
    if (!html.length) return @"";
    NSRange r;
    NSString *s = [html copy];
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound) {
        s = [s stringByReplacingCharactersInRange:r withString:@" "];
    }
    s = [self unescapeHTML:s];
    s = [self cleanString:s];
    return s;
}

+ (NSString *)unescapeHTML:(NSString *)html
{
    if (!html.length) return @"";
    NSMutableString *s = [html mutableCopy];
    [s replaceOccurrencesOfString:@"&amp;" withString:@"&" options:NSLiteralSearch range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:NSLiteralSearch range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&#39;" withString:@"'" options:NSLiteralSearch range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&apos;" withString:@"'" options:NSLiteralSearch range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&lt;" withString:@"<" options:NSLiteralSearch range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&gt;" withString:@">" options:NSLiteralSearch range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&nbsp;" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, s.length)];
    return [s copy];
}

+ (NSString *)formatBytes:(long long)bytes
{
    if (bytes <= 0) return @"";
    double b = (double)bytes;
    if (b < 1024.0) return [NSString stringWithFormat:@"%lld B", bytes];
    if (b < 1024.0 * 1024.0) return [NSString stringWithFormat:@"%.1f KB", b / 1024.0];
    if (b < 1024.0 * 1024.0 * 1024.0) return [NSString stringWithFormat:@"%.1f MB", b / (1024.0 * 1024.0)];
    return [NSString stringWithFormat:@"%.2f GB", b / (1024.0 * 1024.0 * 1024.0)];
}

+ (NSString *)cleanString:(NSString *)str
{
    if (!str.length) return @"";
    NSArray *components = [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"length > 0"];
    NSArray *filtered = [components filteredArrayUsingPredicate:p];
    return [filtered componentsJoinedByString:@" "];
}

@end
