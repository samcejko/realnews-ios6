#import <UIKit/UIKit.h>
#import "RNFeed.h"

@protocol RNAddFeedDelegate <NSObject>
- (void)addFeedDidFinishWithSuccess:(BOOL)success;
@end

@interface RNAddFeedViewController : UITableViewController <UITextFieldDelegate, UIActionSheetDelegate>

@property (nonatomic, weak) id<RNAddFeedDelegate> delegate;
@property (nonatomic, strong) RNFeed *feedToEdit;

- (instancetype)initWithFeed:(RNFeed *)feedToEdit;

@end
