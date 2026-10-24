#import "RNFeedListViewController.h"
#import "RNItemListViewController.h"
#import "RNSettingsViewController.h"
#import "RNFeedStore.h"
#import "RNImageLoader.h"
#import "RNTheme.h"
#import "RNUtils.h"
#import "RNCommon.h"

@interface RNFeedListViewController () <UIAlertViewDelegate> {
    UIBarButtonItem *_editBtn;
    UIBarButtonItem *_addBtn;
    UIBarButtonItem *_settingsBtn;
    BOOL _isDeletingRow;
}
@end

@implementation RNFeedListViewController

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (RNIsPad()) return YES;
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (RNIsPad()) return UIInterfaceOrientationMaskAll;
    return UIInterfaceOrientationMaskAll & ~UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = L(@"AppTitle");
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Feeds")
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:nil
                                                                            action:nil];

    // Nav buttons
    _editBtn = self.editButtonItem;
    _addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                            target:self
                                                            action:@selector(addFeed)];
    _settingsBtn = [[UIBarButtonItem alloc] initWithImage:[RNTheme gearImage]
                                                    style:UIBarButtonItemStyleBordered
                                                   target:self
                                                   action:@selector(openSettings)];

    self.navigationItem.leftBarButtonItem = _editBtn;
    self.navigationItem.rightBarButtonItems = @[ _addBtn, _settingsBtn ];

    // Pull to refresh
    Class refreshClass = NSClassFromString(@"UIRefreshControl");
    if (refreshClass && [self respondsToSelector:@selector(setRefreshControl:)]) {
        UIControl *rc = [[refreshClass alloc] init];
        [rc performSelector:@selector(setTintColor:) withObject:[RNTheme brandOrangeColor]];
        [rc addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
        [self performSelector:@selector(setRefreshControl:) withObject:rc];
    }

    if (!refreshClass) {
        NSMutableArray *buttons = [NSMutableArray arrayWithArray:self.navigationItem.rightBarButtonItems ?: @[]];
        UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                    target:self action:@selector(refreshWithoutControl)];
        [buttons addObject:refreshButton];
        self.navigationItem.rightBarButtonItems = buttons;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateData) name:RNFeedsDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateData) name:RNFeedDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateData) name:RNArticleReadStatusChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleImageLoaded:) name:RNImageDidLoadNotification object:nil];

    // Refresh on first launch if empty
    if ([RNFeedStore sharedStore].feeds.count > 0) {
        RNFeed *firstFeed = [[RNFeedStore sharedStore].feeds objectAtIndex:0];
        if (firstFeed.items.count == 0) {
            [[RNFeedStore sharedStore] refreshAllFeedsWithCompletion:NULL];
        }
    }

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.tableView addGestureRecognizer:lp];
}

- (UIImage *)defaultFeedIcon
{
    static UIImage *s_def = nil;
    if (!s_def) {
        CGSize size = CGSizeMake(24.0f, 24.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();

        UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 24, 24) cornerRadius:5.0f];
        [[RNTheme brandOrangeColor] setFill];
        [bg fill];

        [[UIColor whiteColor] setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(4.5f, 15.5f, 4.0f, 4.0f)] fill];

        CGContextSetLineWidth(ctx, 2.0f);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        [[UIColor whiteColor] setStroke];
        CGContextBeginPath(ctx);
        CGContextAddArc(ctx, 4.5f, 19.5f, 8.0f, -M_PI_2, 0.0f, 0);
        CGContextStrokePath(ctx);

        CGContextBeginPath(ctx);
        CGContextAddArc(ctx, 4.5f, 19.5f, 13.0f, -M_PI_2, 0.0f, 0);
        CGContextStrokePath(ctx);

        s_def = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return s_def;
}

- (UIImage *)scaledIconImage:(UIImage *)image toSize:(CGSize)size background:(BOOL)background
{
    if (!image) return nil;
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // Subtle gray background so white favicons don't disappear on light backgrounds
    if (background) {
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.75 alpha:1.0].CGColor);
        UIBezierPath *bgPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height) cornerRadius:4.0f];
        [bgPath fill];
    }
    
    UIBezierPath *clipPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height) cornerRadius:4.0f];
    [clipPath addClip];
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaled;
}

- (void)handleImageLoaded:(NSNotification *)note
{
    if (_isDeletingRow) return;
    NSString *url = [note.userInfo objectForKey:@"url"];
    if (!url.length) return;
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        NSIndexPath *ip = [self.tableView indexPathForCell:cell];
        if (ip && ip.section == 1 && ip.row < (NSInteger)[RNFeedStore sharedStore].feeds.count) {
            RNFeed *f = [[RNFeedStore sharedStore].feeds objectAtIndex:ip.row];
            if ([[f effectiveIconURL] isEqualToString:url]) {
                UIImage *img = [[RNImageLoader shared] imageForURL:url];
                if (img) {
                    cell.imageView.image = [self scaledIconImage:img toSize:CGSizeMake(24.0f, 24.0f) background:f.iconBackgroundEnabled];
                    [cell setNeedsLayout];
                }
            }
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)refreshWithoutControl
{
    [self handleRefresh:nil];
}

- (void)handleRefresh:(id)rc
{
    [[RNFeedStore sharedStore] refreshAllFeedsWithCompletion:^{
        if ([rc respondsToSelector:@selector(endRefreshing)]) [rc performSelector:@selector(endRefreshing)];
        [self updateData];
    }];
}

- (void)updateData
{
    if (_isDeletingRow) return;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performReloadData) object:nil];
    [self performSelector:@selector(performReloadData) withObject:nil afterDelay:0.1];
}

- (void)performReloadData
{
    if (_isDeletingRow) return;
    [self.tableView reloadData];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint p = [gesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
    if (indexPath && indexPath.section == 1 && indexPath.row < (NSInteger)[RNFeedStore sharedStore].feeds.count) {
        RNFeed *feed = [[RNFeedStore sharedStore].feeds objectAtIndex:indexPath.row];
        [self editFeed:feed];
    }
}

- (void)editFeed:(RNFeed *)feed
{
    RNAddFeedViewController *addVC = [[RNAddFeedViewController alloc] initWithFeed:feed];
    addVC.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:addVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:NULL];
}

- (void)addFeed
{
    RNAddFeedViewController *addVC = [[RNAddFeedViewController alloc] init];
    addVC.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:addVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:NULL];
}

- (void)openSettings
{
    RNSettingsViewController *setVC = [[RNSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:setVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:NULL];
}

- (void)addFeedDidFinishWithSuccess:(BOOL)success
{
    [self.tableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2; // Section 0: All Unread & Starred; Section 1: Feeds
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 2;
    return [RNFeedStore sharedStore].feeds.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 0) ? 44.0f : 56.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        static NSString *QuickId = @"QuickCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:QuickId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:QuickId];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        }

        if (indexPath.row == 0) {
            cell.textLabel.text = L(@"AllUnread");
            NSInteger unread = [[RNFeedStore sharedStore] totalUnreadCount];
            cell.accessoryView = [RNTheme badgeViewWithCount:unread];
        } else {
            cell.textLabel.text = L(@"Starred");
            NSInteger starred = [[RNFeedStore sharedStore] starredItems].count;
            cell.accessoryView = (starred > 0) ? [RNTheme badgeViewWithCount:starred] : nil;
        }
        cell.imageView.image = nil;
        return cell;
    }

    static NSString *FeedId = @"FeedCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:FeedId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:FeedId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0f];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
        cell.detailTextLabel.textColor = [RNTheme subtitleColor];
    }

    RNFeed *feed = [[RNFeedStore sharedStore].feeds objectAtIndex:indexPath.row];
    cell.textLabel.text = feed.title.length ? feed.title : feed.url;

    NSString *iconURL = [feed effectiveIconURL];
    if (iconURL.length > 0) {
        UIImage *img = [[RNImageLoader shared] imageForURL:iconURL];
        if (img) {
            cell.imageView.image = [self scaledIconImage:img toSize:CGSizeMake(24.0f, 24.0f) background:feed.iconBackgroundEnabled];
        } else {
            cell.imageView.image = [self defaultFeedIcon];
        }
    } else {
        cell.imageView.image = [self defaultFeedIcon];
    }

    if (feed.lastError.length) {
        cell.detailTextLabel.numberOfLines = 2;
        cell.detailTextLabel.lineBreakMode = UILineBreakModeTailTruncation;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Error: %@", feed.lastError];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    } else if (feed.lastUpdated) {
        cell.detailTextLabel.numberOfLines = 1;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Updated %@", [RNUtils relativeDateStringFromDate:feed.lastUpdated]];
        cell.detailTextLabel.textColor = [RNTheme subtitleColor];
    } else {
        cell.detailTextLabel.numberOfLines = 1;
        cell.detailTextLabel.text = feed.url;
        cell.detailTextLabel.textColor = [RNTheme subtitleColor];
    }

    cell.accessoryView = [RNTheme badgeViewWithCount:feed.unreadCount];
    return cell;
}

- (void)openFeedAtIndex:(NSInteger)index
{
    if (index >= 0 && index < (NSInteger)[RNFeedStore sharedStore].feeds.count) {
        RNFeed *feed = [[RNFeedStore sharedStore].feeds objectAtIndex:index];
        RNItemListViewController *itemVC = [[RNItemListViewController alloc] initWithFeed:feed];
        [self.navigationController pushViewController:itemVC animated:YES];
    }
}

- (void)openQuickFeedAtIndex:(NSInteger)index
{
    RNItemListMode m = (index == 0) ? RNItemListModeAllUnread : RNItemListModeStarred;
    RNItemListViewController *itemVC = [[RNItemListViewController alloc] initWithMode:m];
    [self.navigationController pushViewController:itemVC animated:YES];
}

- (void)openSettingsModal
{
    [self openSettings];
}

- (void)openAddFeedModal
{
    [self addFeed];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1 && indexPath.row < (NSInteger)[RNFeedStore sharedStore].feeds.count) {
        RNFeed *feed = [[RNFeedStore sharedStore].feeds objectAtIndex:indexPath.row];
        [self editFeed:feed];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableView.isEditing && indexPath.section == 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if (indexPath.row < (NSInteger)[RNFeedStore sharedStore].feeds.count) {
            RNFeed *feed = [[RNFeedStore sharedStore].feeds objectAtIndex:indexPath.row];
            [self editFeed:feed];
        }
        return;
    }

    if (indexPath.section == 0) {
        [self openQuickFeedAtIndex:indexPath.row];
    } else {
        if (indexPath.row < (NSInteger)[RNFeedStore sharedStore].feeds.count) {
            RNFeed *feed = [[RNFeedStore sharedStore].feeds objectAtIndex:indexPath.row];
            if (feed.lastError.length) {
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                NSString *firstBtn = (feed.items.count > 0) ? @"Open Articles" : L(@"Done");
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:feed.title.length ? feed.title : @"Feed Error"
                                                                message:feed.lastError
                                                               delegate:self
                                                      cancelButtonTitle:firstBtn
                                                      otherButtonTitles:@"Edit Feed", @"Retry", nil];
                alert.tag = 1000 + indexPath.row;
                [alert show];
                return;
            }
        }
        [self openFeedAtIndex:indexPath.row];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag >= 1000) {
        NSInteger feedIdx = alertView.tag - 1000;
        if (feedIdx >= 0 && feedIdx < (NSInteger)[RNFeedStore sharedStore].feeds.count) {
            RNFeed *feed = [[RNFeedStore sharedStore].feeds objectAtIndex:feedIdx];
            if (buttonIndex == 0) {
                if (feed.items.count > 0) {
                    [self openFeedAtIndex:feedIdx];
                }
            } else if (buttonIndex == 1) { // Edit Feed
                [self editFeed:feed];
            } else if (buttonIndex == 2) { // Retry
                feed.lastError = nil;
                [self.tableView reloadData];
                [[RNFeedStore sharedStore] refreshFeed:feed completion:^(BOOL success, NSError *error) {
                    [self updateData];
                }];
            }
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 1);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.section == 1) {
        _isDeletingRow = YES;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performReloadData) object:nil];
        RNFeed *feed = [[RNFeedStore sharedStore].feeds objectAtIndex:indexPath.row];
        [[RNFeedStore sharedStore] removeFeed:feed];
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
        [tableView endUpdates];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self->_isDeletingRow = NO;
        });
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 1);
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    if (sourceIndexPath.section == 1 && destinationIndexPath.section == 1) {
        [[RNFeedStore sharedStore] moveFeedAtIndex:sourceIndexPath.row toIndex:destinationIndexPath.row];
    }
}

@end
