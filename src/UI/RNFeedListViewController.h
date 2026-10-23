#import <UIKit/UIKit.h>
#import "RNAddFeedViewController.h"

@interface RNFeedListViewController : UITableViewController <RNAddFeedDelegate>

- (void)openFeedAtIndex:(NSInteger)index;
- (void)openQuickFeedAtIndex:(NSInteger)index;
- (void)openSettingsModal;
- (void)openAddFeedModal;

@end
