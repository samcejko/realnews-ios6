#import "RNMetadataViewController.h"
#import "RNCommon.h"
#import "RNTheme.h"

@interface RNMetadataViewController () {
    RNFeedItem *_item;
    NSMutableArray *_keys;
    NSMutableArray *_values;
}
@end

@implementation RNMetadataViewController

- (instancetype)initWithFeedItem:(RNFeedItem *)item
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _item = item;
        _keys = [NSMutableArray array];
        _values = [NSMutableArray array];

        // Standard fields
        if (item.title.length) [self addKey:@"title" value:item.title];
        if (item.link.length) [self addKey:@"link" value:item.link];
        if (item.author.length) [self addKey:@"author" value:item.author];
        if (item.publishDateString.length) [self addKey:@"pubDate" value:item.publishDateString];
        if (item.identifier.length) [self addKey:@"guid / id" value:item.identifier];
        if (item.enclosureURL.length) {
            [self addKey:@"enclosure" value:[NSString stringWithFormat:@"%@ (%@)", item.enclosureURL, item.enclosureType ?: @"file"]];
        }

        // All extra/custom fields found in XML
        NSArray *sortedExtraKeys = [_item.extraData.allKeys sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *k in sortedExtraKeys) {
            if ([k.lowercaseString isEqualToString:@"title"] || [k.lowercaseString isEqualToString:@"link"]) continue;
            id val = [_item.extraData objectForKey:k];
            if ([val isKindOfClass:[NSArray class]]) {
                [self addKey:k value:[(NSArray *)val componentsJoinedByString:@", "]];
            } else {
                [self addKey:k value:[NSString stringWithFormat:@"%@", val]];
            }
        }
    }
    return self;
}

- (void)addKey:(NSString *)key value:(NSString *)value
{
    if (key.length && value.length) {
        [_keys addObject:key];
        [_values addObject:value];
    }
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
    self.title = L(@"AllFields");
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];

    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                             target:self
                                                                             action:@selector(dismissSelf)];
    self.navigationItem.rightBarButtonItem = doneBtn;
}

- (void)dismissSelf
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _keys.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [_keys objectAtIndex:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *val = [_values objectAtIndex:indexPath.section];
    CGFloat width = tableView.bounds.size.width - 40.0f;
    UIFont *font = [UIFont systemFontOfSize:14.0f];
    CGSize sz = [val sizeWithFont:font constrainedToSize:CGSizeMake(width, 2000.0f) lineBreakMode:UILineBreakModeWordWrap];
    return MAX(44.0f, sz.height + 20.0f);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellId = @"MetaCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        cell.textLabel.font = [UIFont systemFontOfSize:14.0f];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }

    NSString *val = [_values objectAtIndex:indexPath.section];
    cell.textLabel.text = val;

    if ([val hasPrefix:@"http://"] || [val hasPrefix:@"https://"] || [val hasPrefix:@"magnet:"]) {
        cell.textLabel.textColor = [UIColor colorWithRed:0 green:0.4 blue:0.8 alpha:1.0];
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    } else {
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *val = [_values objectAtIndex:indexPath.section];
    NSString *key = [_keys objectAtIndex:indexPath.section];

    if ([val hasPrefix:@"http://"] || [val hasPrefix:@"https://"]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:val]];
    } else {
        // Copy to clipboard
        [[UIPasteboard generalPasteboard] setString:val];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:key
                                                        message:[NSString stringWithFormat:@"Copied to clipboard:\n%@", val]
                                                       delegate:nil
                                              cancelButtonTitle:L(@"Done")
                                              otherButtonTitles:nil];
        [alert show];
    }
}

@end
