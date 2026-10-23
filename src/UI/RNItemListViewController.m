#import "RNItemListViewController.h"
#import "RNArticleViewController.h"
#import "RNAddFeedViewController.h"
#import "RNFeedStore.h"
#import "RNImageLoader.h"
#import "RNTheme.h"
#import "RNUtils.h"
#import "RNCommon.h"

@interface RNItemListViewController () <RNAddFeedDelegate, UIAlertViewDelegate> {
    UISearchBar *_searchBar;
    NSArray *_allItems;
    NSArray *_filteredItems;
    BOOL _filterUnreadOnly;
    UISegmentedControl *_filterSegment;
}
@end

@implementation RNItemListViewController

- (instancetype)initWithFeed:(RNFeed *)feed
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _feed = feed;
        _mode = RNItemListModeNormal;
    }
    return self;
}

- (instancetype)initWithMode:(RNItemListMode)mode
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _mode = mode;
    }
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
    [self updateTitle];

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Articles")
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:nil
                                                                            action:nil];

    // Search bar
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    _searchBar.delegate = self;
    _searchBar.placeholder = L(@"SearchArticles");
    _searchBar.tintColor = [RNTheme brandDarkOrangeColor];
    [self updateTableHeader];

    // Pull to refresh (available in iOS 6)
    Class refreshClass = NSClassFromString(@"UIRefreshControl");
    if (refreshClass && [self respondsToSelector:@selector(setRefreshControl:)]) {
        UIControl *rc = [[refreshClass alloc] init];
        [rc performSelector:@selector(setTintColor:) withObject:[RNTheme brandOrangeColor]];
        [rc addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
        [self performSelector:@selector(setRefreshControl:) withObject:rc];
    }

    // Top buttons: Mark All Read / Edit
    UIBarButtonItem *markReadBtn = [[UIBarButtonItem alloc] initWithTitle:L(@"MarkAllAsRead")
                                                                    style:UIBarButtonItemStyleBordered
                                                                   target:self
                                                                   action:@selector(markAllRead)];
    if (_mode == RNItemListModeNormal && _feed) {
        UIBarButtonItem *editBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                 target:self
                                                                                 action:@selector(editCurrentFeed)];
        self.navigationItem.rightBarButtonItems = @[ markReadBtn, editBtn ];
    } else {
        self.navigationItem.rightBarButtonItem = markReadBtn;
    }

    if (!refreshClass) {
        NSMutableArray *buttons = [NSMutableArray arrayWithArray:self.navigationItem.rightBarButtonItems ?: @[]];
        UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                    target:self action:@selector(refreshWithoutControl)];
        [buttons addObject:refreshButton];
        self.navigationItem.rightBarButtonItems = buttons;
    }

    // Register notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scheduleReload) name:RNFeedDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scheduleReload) name:RNArticleReadStatusChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scheduleReload) name:RNArticleStarStatusChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleImageLoaded:) name:RNImageDidLoadNotification object:nil];

    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(goBackToFeeds)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];

    [self reloadData];
}

- (void)updateTableHeader
{
    if (_mode == RNItemListModeNormal && _feed.lastError.length > 0) {
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44 + 32)];
        header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _searchBar.frame = CGRectMake(0, 0, header.bounds.size.width, 44);
        _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [header addSubview:_searchBar];

        UIButton *errBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        errBtn.frame = CGRectMake(0, 44, header.bounds.size.width, 32);
        errBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        errBtn.backgroundColor = [UIColor colorWithRed:0.85f green:0.25f blue:0.25f alpha:0.95f];
        [errBtn setTitle:[NSString stringWithFormat:@"Error: %@ (Tap for info)", _feed.lastError] forState:UIControlStateNormal];
        errBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
        errBtn.titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
        [errBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [errBtn addTarget:self action:@selector(showErrorDetails) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:errBtn];

        self.tableView.tableHeaderView = header;
    } else {
        _searchBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
        _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.tableView.tableHeaderView = _searchBar;
    }
}

- (void)showErrorDetails
{
    if (!_feed.lastError.length) return;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Feed Sync Error"
                                                    message:[NSString stringWithFormat:@"URL:\n%@\n\nDiagnostic Error:\n%@", _feed.url, _feed.lastError]
                                                   delegate:self
                                          cancelButtonTitle:@"Dismiss"
                                          otherButtonTitles:@"Edit Feed", @"Retry", nil];
    alert.tag = 2000;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 2000) {
        if (buttonIndex == 1) { // Edit Feed
            [self editCurrentFeed];
        } else if (buttonIndex == 2) { // Retry
            _feed.lastError = nil;
            [self updateTableHeader];
            [[RNFeedStore sharedStore] refreshFeed:_feed completion:^(BOOL success, NSError *error) {
                [self reloadData];
            }];
        }
    }
}

- (void)editCurrentFeed
{
    if (!_feed) return;
    RNAddFeedViewController *editVC = [[RNAddFeedViewController alloc] initWithFeed:_feed];
    editVC.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:NULL];
}

- (void)addFeedDidFinishWithSuccess:(BOOL)success
{
    [self updateTitle];
    [self reloadData];
}

- (void)scheduleReload
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadData) object:nil];
    [self performSelector:@selector(reloadData) withObject:nil afterDelay:0.1];
}

- (void)goBackToFeeds
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)updateTitle
{
    if (_mode == RNItemListModeAllUnread) {
        self.title = L(@"AllUnread");
    } else if (_mode == RNItemListModeStarred) {
        self.title = L(@"Starred");
    } else {
        self.title = _feed.title.length ? _feed.title : L(@"Articles");
    }
}

- (void)refreshWithoutControl
{
    [self handleRefresh:nil];
}

- (void)handleRefresh:(id)rc
{
    if (_mode == RNItemListModeNormal && _feed) {
        [[RNFeedStore sharedStore] refreshFeed:_feed completion:^(BOOL success, NSError *error) {
            if ([rc respondsToSelector:@selector(endRefreshing)]) [rc performSelector:@selector(endRefreshing)];
            [self reloadData];
        }];
    } else {
        [[RNFeedStore sharedStore] refreshAllFeedsWithCompletion:^{
            if ([rc respondsToSelector:@selector(endRefreshing)]) [rc performSelector:@selector(endRefreshing)];
            [self reloadData];
        }];
    }
}

- (void)markAllRead
{
    if (_feed) {
        [[RNFeedStore sharedStore] markAllItemsAsReadInFeed:_feed];
    } else {
        for (RNFeedItem *it in _allItems) {
            [[RNFeedStore sharedStore] markItem:it asRead:YES];
        }
    }
    [self reloadData];
}

- (void)reloadData
{
    if (_mode == RNItemListModeAllUnread) {
        _allItems = [[RNFeedStore sharedStore] allUnreadItems];
    } else if (_mode == RNItemListModeStarred) {
        _allItems = [[RNFeedStore sharedStore] starredItems];
    } else if (_feed) {
        _allItems = [_feed.items copy];
    } else {
        _allItems = @[];
    }

    [self updateTableHeader];
    [self filterContentForSearchText:_searchBar.text];
    [self.tableView reloadData];
}

- (void)handleImageLoaded:(NSNotification *)note
{
    [self.tableView reloadData];
}

- (void)filterContentForSearchText:(NSString *)searchText
{
    if (!searchText.length) {
        _filteredItems = [_allItems copy];
        return;
    }

    NSPredicate *pred = [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@ OR summary CONTAINS[cd] %@ OR author CONTAINS[cd] %@", searchText, searchText, searchText];
    _filteredItems = [_allItems filteredArrayUsingPredicate:pred];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self filterContentForSearchText:searchText];
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _filteredItems.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 74.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellId = @"ArticleCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        // Custom iOS 6 styling
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0f];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.lineBreakMode = UILineBreakModeTailTruncation;

        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
        cell.detailTextLabel.textColor = [RNTheme subtitleColor];
        cell.detailTextLabel.numberOfLines = 1;
    }

    RNFeedItem *item = [_filteredItems objectAtIndex:indexPath.row];

    cell.textLabel.text = item.title.length ? item.title : @"(Untitled)";
    if (!item.isRead) {
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0f];
        cell.textLabel.textColor = [UIColor blackColor];
    } else {
        cell.textLabel.font = [UIFont systemFontOfSize:15.0f];
        cell.textLabel.textColor = [UIColor colorWithWhite:0.35f alpha:1.0f];
    }

    // Detail: Date, Author, Star
    NSMutableString *det = [NSMutableString string];
    if (item.isFavorite) {
        [det appendString:@"[Starred] "];
    }
    if (item.displayDate.length) {
        [det appendFormat:@"%@  ", item.displayDate];
    }
    if (item.author.length) {
        [det appendFormat:@"by %@", item.author];
    }
    cell.detailTextLabel.text = det;

    // Thumbnail icon if available
    if (item.thumbnailURL.length) {
        UIImage *thumb = [[RNImageLoader shared] imageForURL:item.thumbnailURL];
        if (thumb) {
            cell.imageView.image = thumb;
            cell.imageView.layer.cornerRadius = 4.0f;
            cell.imageView.layer.masksToBounds = YES;
        } else {
            cell.imageView.image = nil;
        }
    } else {
        cell.imageView.image = nil;
    }

    return cell;
}

- (void)openArticleAtIndex:(NSInteger)index
{
    if (index >= 0 && index < (NSInteger)_filteredItems.count) {
        RNFeedItem *item = [_filteredItems objectAtIndex:index];
        [[RNFeedStore sharedStore] markItem:item asRead:YES];
        RNArticleViewController *articleVC = [[RNArticleViewController alloc] initWithItems:_filteredItems currentIndex:index];
        [self.navigationController pushViewController:articleVC animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self openArticleAtIndex:indexPath.row];
}

@end
