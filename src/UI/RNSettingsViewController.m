#import "RNSettingsViewController.h"
#import "RNFeedStore.h"
#import "RNImageLoader.h"
#import "RNUtils.h"
#import "RNTheme.h"
#import "RNCommon.h"

@interface RNSettingsViewController () {
    long long _cacheSize;
}
@end

@implementation RNSettingsViewController

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
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
    self.title = L(@"Settings");
    self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];

    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                             target:self
                                                                             action:@selector(done)];
    self.navigationItem.rightBarButtonItem = doneBtn;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _cacheSize = [[RNImageLoader shared] cacheSizeInBytes];
    [self.tableView reloadData];
}

- (void)done
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 2; // Cache size, Clear cache
    if (section == 1) return 2; // Retention days, Max items
    if (section == 2) return 1; // Network Timeout
    return 2; // About, Repo
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) return @"Storage & Cache";
    if (section == 1) return @"Article Retention";
    if (section == 2) return @"Network";
    return @"About RealNews";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellId = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellId];
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor darkTextColor];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Image Cache Size";
            cell.detailTextLabel.text = [RNUtils formatBytes:_cacheSize];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = L(@"ClearCache");
            cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            cell.detailTextLabel.text = @"";
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = L(@"KeepArticles");
            NSInteger days = [RNFeedStore sharedStore].retentionDays;
            cell.detailTextLabel.text = (days == 0) ? L(@"DaysForever") : [NSString stringWithFormat:@"%ld days", (long)days];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        } else {
            cell.textLabel.text = L(@"MaxItemsPerFeed");
            NSInteger max = [RNFeedStore sharedStore].maxItemsPerFeed;
            cell.detailTextLabel.text = (max == 0) ? @"Unlimited" : [NSString stringWithFormat:@"%ld", (long)max];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @"Network Timeout";
        NSInteger timeout = [RNFeedStore sharedStore].networkTimeout;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld seconds", (long)timeout];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    } else {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Version";
            cell.detailTextLabel.text = @"1.0.5 (iOS 6)";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"Cydia Repository";
            cell.detailTextLabel.text = @"repo.samcejko.eu";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 1) {
        // Clear Cache
        [[RNFeedStore sharedStore] clearAllCache];
        _cacheSize = 0;
        [self.tableView reloadData];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:L(@"ClearCache")
                                                        message:L(@"CacheCleared")
                                                       delegate:nil
                                              cancelButtonTitle:L(@"Done")
                                              otherButtonTitles:nil];
        [alert show];
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            // Retention Sheet
            UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:L(@"KeepArticles")
                                                            delegate:self
                                                   cancelButtonTitle:L(@"Cancel")
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:L(@"Days7"), L(@"Days14"), L(@"Days30"), L(@"DaysForever"), nil];
            as.tag = 100;
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && cell) {
                [as showFromRect:cell.bounds inView:cell animated:YES];
            } else {
                [as showInView:self.view];
            }
        } else {
            // Max items sheet
            UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:L(@"MaxItemsPerFeed")
                                                            delegate:self
                                                   cancelButtonTitle:L(@"Cancel")
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:@"25 items", @"50 items", @"100 items", @"Unlimited", nil];
            as.tag = 200;
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && cell) {
                [as showFromRect:cell.bounds inView:cell animated:YES];
            } else {
                [as showInView:self.view];
            }
        }
    } else if (indexPath.section == 2) {
        // Network Timeout sheet
        UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Network Timeout"
                                                        delegate:self
                                               cancelButtonTitle:L(@"Cancel")
                                          destructiveButtonTitle:nil
                                               otherButtonTitles:@"1 second", @"2 seconds", @"3 seconds", @"5 seconds", @"10 seconds", nil];
        as.tag = 300;
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && cell) {
            [as showFromRect:cell.bounds inView:cell animated:YES];
        } else {
            [as showInView:self.view];
        }
    } else if (indexPath.section == 3 && indexPath.row == 1) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://repo.samcejko.eu/"]];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == 100) {
        if (buttonIndex == 0) [RNFeedStore sharedStore].retentionDays = 7;
        else if (buttonIndex == 1) [RNFeedStore sharedStore].retentionDays = 14;
        else if (buttonIndex == 2) [RNFeedStore sharedStore].retentionDays = 30;
        else if (buttonIndex == 3) [RNFeedStore sharedStore].retentionDays = 0;
        [[RNFeedStore sharedStore] save];
        [self.tableView reloadData];
    } else if (actionSheet.tag == 200) {
        if (buttonIndex == 0) [RNFeedStore sharedStore].maxItemsPerFeed = 25;
        else if (buttonIndex == 1) [RNFeedStore sharedStore].maxItemsPerFeed = 50;
        else if (buttonIndex == 2) [RNFeedStore sharedStore].maxItemsPerFeed = 100;
        else if (buttonIndex == 3) [RNFeedStore sharedStore].maxItemsPerFeed = 0;
        [[RNFeedStore sharedStore] save];
        [self.tableView reloadData];
    } else if (actionSheet.tag == 300) {
        // Network Timeout: 0=1s, 1=2s, 2=3s, 3=5s, 4=10s
        NSInteger timeoutValues[] = {1, 2, 3, 5, 10};
        if (buttonIndex >= 0 && buttonIndex < 5) {
            [RNFeedStore sharedStore].networkTimeout = timeoutValues[buttonIndex];
            [[RNFeedStore sharedStore] save];
            [self.tableView reloadData];
        }
    }
}

@end
