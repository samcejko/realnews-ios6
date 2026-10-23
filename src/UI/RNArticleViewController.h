#import <UIKit/UIKit.h>
#import "RNFeedItem.h"
#import "RNAudioPlayerView.h"
#import "RNAppearanceViewController.h"

@interface RNArticleViewController : UIViewController <UIWebViewDelegate, UIActionSheetDelegate, RNAppearanceDelegate, RNAudioPlayerViewDelegate>

@property (nonatomic, strong) RNFeedItem *item;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, readonly) RNAudioPlayerView *audioPlayerView;

- (instancetype)initWithFeedItem:(RNFeedItem *)item;
- (instancetype)initWithItems:(NSArray *)items currentIndex:(NSInteger)index;

- (void)openMetadataInspector;
- (void)openAppearancePopover;
- (void)dismissAppearancePopover;
- (void)toggleFullText;
- (void)openImageViewerForURL:(NSString *)urlString;
- (void)goBack;
- (void)goToNextArticle;
- (void)goToPreviousArticle;

@end
