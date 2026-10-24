#import <Foundation/Foundation.h>
#import "RNUtils.h"
#import "RNFeed.h"
#include <assert.h>
#include <math.h>

int main(void) {
    @autoreleasepool {
        [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:7200]];
        NSString *published = @"Thu, 22 Oct 2026 14:00:00 +0300";
        NSString *updated = @"2026-10-22T16:00:00Z";
        NSDate *date = [RNUtils parseDateString:published];
        NSDate *later = [RNUtils parseDateString:updated];
        assert(date && later && fabs([later timeIntervalSinceDate:date] - 18000) < 1);
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale currentLocale];
        formatter.timeZone = [NSTimeZone localTimeZone];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        NSString *a = [RNUtils displayMetadataValue:published forKey:@"pubDate"];
        NSString *b = [RNUtils displayMetadataValue:updated forKey:@"updated"];
        assert([a isEqualToString:[formatter stringFromDate:date]]);
        assert([b isEqualToString:[formatter stringFromDate:later]] && ![a isEqualToString:b]);
        assert([[RNUtils displayMetadataValue:@"not a date" forKey:@"pubDate"] isEqualToString:@"not a date"]);
        assert([[RNUtils displayMetadataValue:published forKey:@"description"] isEqualToString:published]);
        NSArray *rawDates = @[published,updated];
        NSString *joinedDates = [@[a,b] componentsJoinedByString:@", "];
        assert([[RNUtils displayMetadataValue:rawDates forKey:@"dc:date"] isEqualToString:joinedDates]);
        RNFeed *legacy = [[RNFeed alloc] initWithDictionary:@{@"url":@"https://example.com/rss"}];
        assert(legacy.iconBackgroundEnabled);
        legacy.iconBackgroundEnabled = NO;
        RNFeed *reopened = [[RNFeed alloc] initWithDictionary:[legacy toDictionary]];
        assert(!reopened.iconBackgroundEnabled);
        reopened.iconBackgroundEnabled = YES;
        RNFeed *enabled = [[RNFeed alloc] initWithDictionary:[reopened toDictionary]];
        assert(enabled.iconBackgroundEnabled);
        puts("Feedback date conversion, distinct date fields, invalid values, and favicon migration/persistence passed");
    }
    return 0;
}
