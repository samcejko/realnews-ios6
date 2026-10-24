#import <Foundation/Foundation.h>

@interface RNUtils : NSObject

+ (NSDate *)parseDateString:(NSString *)dateString;
+ (NSString *)displayMetadataValue:(id)value forKey:(NSString *)key;
+ (NSString *)relativeDateStringFromDate:(NSDate *)date;
+ (NSString *)stripHTML:(NSString *)html;
+ (NSString *)unescapeHTML:(NSString *)html;
+ (NSString *)formatBytes:(long long)bytes;
+ (NSString *)cleanString:(NSString *)str;

@end
