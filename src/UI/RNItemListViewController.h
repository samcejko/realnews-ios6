#import <UIKit/UIKit.h>
#import "RNFeed.h"

typedef NS_ENUM(NSInteger, RNItemListMode) {
    RNItemListModeNormal = 0,
    RNItemListModeAllUnread,
    RNItemListModeStarred
};

@interface RNItemListViewController : UITableViewController <UISearchBarDelegate>

@property (nonatomic, strong) RNFeed *feed;
@property (nonatomic) RNItemListMode mode;

- (instancetype)initWithFeed:(RNFeed *)feed;
- (instancetype)initWithMode:(RNItemListMode)mode;

- (void)openArticleAtIndex:(NSInteger)index;

@end
