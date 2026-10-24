#import "RNAddFeedViewController.h"
#import "RNFeedStore.h"
#import "RNFeedDiscovery.h"
#import "RNCommon.h"
#import "RNTheme.h"

@interface RNAddFeedViewController () <UIActionSheetDelegate> {
    UITextField *_urlField;
    UITextField *_titleField;
    UITextField *_catField;
    NSString *_enteredURL;
    NSString *_enteredTitle;
    NSString *_enteredCategory;
    UITableViewCell *_urlCell;
    UITableViewCell *_titleCell;
    UITableViewCell *_catCell;
    UITableViewCell *_iconBackgroundCell;
    UISwitch *_iconBackgroundSwitch;
    UIActivityIndicatorView *_spinner;
    NSArray *_presets;
    NSArray *_lastDiscovered;
}
@end

@implementation RNAddFeedViewController

- (instancetype)initWithFeed:(RNFeed *)feedToEdit
{
    self = [self init];
    if (self) {
        _feedToEdit = feedToEdit;
        _enteredURL = [feedToEdit.url copy];
        _enteredTitle = [feedToEdit.title copy];
        _enteredCategory = [feedToEdit.category copy];
    }
    return self;
}

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _presets = @[
            @{ @"title": @"ČT24 - Hlavní zprávy", @"url": @"https://ct24.ceskatelevize.cz/rss/hlavni-zpravy", @"cat": @"Zprávy" },
            @{ @"title": @"iROZHLAS - Domov", @"url": @"https://www.irozhlas.cz/rss/irozhlas/zpravy-domov", @"cat": @"Zprávy" },
            @{ @"title": @"BBC Global News Podcast", @"url": @"https://podcasts.files.bbci.co.uk/p02nq0gn.rss", @"cat": @"Podcasty" },
            @{ @"title": @"BBC News - World", @"url": @"https://feeds.bbci.co.uk/news/world/rss.xml", @"cat": @"News" },
            @{ @"title": @"NASA Breaking News", @"url": @"https://www.nasa.gov/news-release/feed/", @"cat": @"Science" },
            @{ @"title": @"Hacker News", @"url": @"https://news.ycombinator.com/rss", @"cat": @"Tech" },
            @{ @"title": @"Ars Technica", @"url": @"https://feeds.arstechnica.com/arstechnica/index", @"cat": @"Tech" }
        ];
    }
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
    self.title = _feedToEdit ? (L(@"EditFeed") ?: @"Edit Feed") : L(@"AddFeed");
    self.tableView.backgroundColor = RetroGroupedBackground();

    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                               target:self
                                                                               action:@selector(cancel)];
    self.navigationItem.leftBarButtonItem = cancelBtn;

    UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                             target:self
                                                                             action:@selector(save)];
    self.navigationItem.rightBarButtonItem = saveBtn;

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];

    _urlCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    _urlCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _urlField = [[UITextField alloc] initWithFrame:CGRectMake(16, 11, self.view.bounds.size.width - 32, 24)];
    _urlField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _urlField.font = [UIFont systemFontOfSize:16.0f];
    _urlField.clearButtonMode = UITextFieldViewModeNever;
    _urlField.placeholder = L(@"FeedURLPlaceholder");
    _urlField.keyboardType = UIKeyboardTypeURL;
    _urlField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _urlField.autocorrectionType = UITextAutocorrectionTypeNo;
    _urlField.delegate = self;
    [_urlField addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingChanged];

    UIButton *findBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    findBtn.frame = CGRectMake(0, 0, 52, 26);
    [findBtn setTitle:L(@"FindFeed") forState:UIControlStateNormal];
    findBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    findBtn.backgroundColor = [UIColor colorWithRed:0.25f green:0.55f blue:0.85f alpha:1.0f];
    findBtn.layer.cornerRadius = 4.0f;
    RetroStyleButton(findBtn);
    [findBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [findBtn addTarget:self action:@selector(discoverFeedTapped) forControlEvents:UIControlEventTouchUpInside];
    _urlField.rightView = findBtn;
    _urlField.rightViewMode = UITextFieldViewModeAlways;
    [_urlCell.contentView addSubview:_urlField];

    _titleCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    _titleCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _titleField = [[UITextField alloc] initWithFrame:CGRectMake(16, 11, self.view.bounds.size.width - 32, 24)];
    _titleField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _titleField.font = [UIFont systemFontOfSize:16.0f];
    _titleField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _titleField.placeholder = L(@"FeedTitleOptional");
    _titleField.delegate = self;
    [_titleField addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [_titleCell.contentView addSubview:_titleField];

    _catCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    _catCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _catField = [[UITextField alloc] initWithFrame:CGRectMake(16, 11, self.view.bounds.size.width - 32, 24)];
    _catField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _catField.font = [UIFont systemFontOfSize:16.0f];
    _catField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _catField.placeholder = L(@"CategoryOptional");
    _catField.delegate = self;
    [_catField addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [_catCell.contentView addSubview:_catField];

    _iconBackgroundCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    _iconBackgroundCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _iconBackgroundCell.textLabel.text = L(@"FaviconBackground");
    _iconBackgroundCell.textLabel.font = [UIFont systemFontOfSize:16.0f];
    _iconBackgroundSwitch = RetroMakeSwitch();
    _iconBackgroundSwitch.on = _feedToEdit ? _feedToEdit.iconBackgroundEnabled : YES;
    _iconBackgroundSwitch.accessibilityLabel = L(@"FaviconBackground");
    _iconBackgroundCell.accessoryView = _iconBackgroundSwitch;

    if (_feedToEdit) {
        _urlField.text = _enteredURL;
        _titleField.text = _enteredTitle;
        _catField.text = _enteredCategory;
    } else {
        [_urlField becomeFirstResponder];
    }
}

- (void)fieldChanged:(UITextField *)sender
{
    if (sender == _urlField) {
        _enteredURL = _urlField.text;
    } else if (sender == _titleField) {
        _enteredTitle = _titleField.text;
    } else if (sender == _catField) {
        _enteredCategory = _catField.text;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    // Grouped cells change width after creation; derive field widths from the
    // final content bounds so the Find button stays on screen on iPad/iPhone.
    NSArray *cells = @[_urlCell, _titleCell, _catCell];
    NSArray *fields = @[_urlField, _titleField, _catField];
    for (NSUInteger index = 0; index < cells.count; index++) {
        UITableViewCell *cell = [cells objectAtIndex:index];
        UITextField *field = [fields objectAtIndex:index];
        field.frame = CGRectMake(16, (cell.contentView.bounds.size.height - 24) * .5f,
                                 MAX(40, cell.contentView.bounds.size.width - 32), 24);
    }
}

- (void)cancel
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

- (void)discoverFeedTapped
{
    NSString *input = [_urlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!input.length) return;
    if (![input hasPrefix:@"http://"] && ![input hasPrefix:@"https://"]) {
        input = [NSString stringWithFormat:@"https://%@", input];
        _urlField.text = input;
    }

    [_urlField resignFirstResponder];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_spinner];
    [_spinner startAnimating];

    [RNFeedDiscovery discoverFeedsForURL:input completion:^(NSArray *feeds, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_spinner stopAnimating];
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                                   target:self
                                                                                                   action:@selector(save)];

            if (feeds.count == 1) {
                RNDiscoveredFeed *f = [feeds objectAtIndex:0];
                self->_urlField.text = f.url;
                if (!self->_titleField.text.length && f.title.length) {
                    self->_titleField.text = f.title;
                }
                UIAlertView *alert = [[RetroAlertView alloc] initWithTitle:L(@"FeedFound")
                                                                message:[NSString stringWithFormat:@"%@\n(%@)", f.title, f.url]
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            } else if (feeds.count > 1) {
                self->_lastDiscovered = feeds;
                UIActionSheet *sheet = [[RetroActionSheet alloc] initWithTitle:L(@"ChooseFeed")
                                                                   delegate:self
                                                          cancelButtonTitle:nil
                                                     destructiveButtonTitle:nil
                                                          otherButtonTitles:nil];
                for (RNDiscoveredFeed *f in feeds) {
                    [sheet addButtonWithTitle:f.title.length ? f.title : f.url];
                }
                [sheet addButtonWithTitle:L(@"Cancel")];
                sheet.cancelButtonIndex = feeds.count;
                [sheet showInView:self.view];
            } else {
                UIAlertView *alert = [[RetroAlertView alloc] initWithTitle:L(@"NoFeedFound")
                                                                message:L(@"NoFeedFoundMessage")
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
        });
    }];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex >= 0 && buttonIndex < (NSInteger)_lastDiscovered.count) {
        RNDiscoveredFeed *f = [_lastDiscovered objectAtIndex:buttonIndex];
        _urlField.text = f.url;
        if (!_titleField.text.length && f.title.length) {
            _titleField.text = f.title;
        }
    }
}

- (void)save
{
    NSString *url = [_urlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *title = [_titleField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *cat = [_catField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (!url.length) {
        UIAlertView *alert = [[RetroAlertView alloc] initWithTitle:L(@"Error")
                                                        message:L(@"EnterFeedURL")
                                                       delegate:nil
                                              cancelButtonTitle:L(@"Done")
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    BOOL inferredScheme = ![url hasPrefix:@"http://"] && ![url hasPrefix:@"https://"];
    if (inferredScheme) {
        url = [NSString stringWithFormat:@"https://%@", url];
    }

    if (_feedToEdit) {
        _feedToEdit.url = url;
        _feedToEdit.title = title.length ? title : url;
        _feedToEdit.category = cat;
        _feedToEdit.iconBackgroundEnabled = _iconBackgroundSwitch.on;
        [[RNFeedStore sharedStore] save];
        [[RNFeedStore sharedStore] refreshFeed:_feedToEdit completion:nil];
        if ([self.delegate respondsToSelector:@selector(addFeedDidFinishWithSuccess:)]) {
            [self.delegate addFeedDidFinishWithSuccess:YES];
        }
        [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
        return;
    }

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_spinner];
    [_spinner startAnimating];

    void (^onAddFailure)(NSError *) = ^(NSError *finalError) {
        // If https failed and user didn't explicitly specify https, try http
        if (inferredScheme && [url hasPrefix:@"https://"]) {
            NSString *httpUrl = [NSString stringWithFormat:@"http://%@", [url substringFromIndex:8]];
            [[RNFeedStore sharedStore] addFeedWithURL:httpUrl title:title category:cat completion:^(RNFeed *httpFeed, NSError *httpError) {
                if (httpFeed) {
                    httpFeed.iconBackgroundEnabled = self->_iconBackgroundSwitch.on;
                    [[RNFeedStore sharedStore] save];
                    [self->_spinner stopAnimating];
                    if ([self.delegate respondsToSelector:@selector(addFeedDidFinishWithSuccess:)]) {
                        [self.delegate addFeedDidFinishWithSuccess:YES];
                    }
                    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
                    return;
                }
                [self finishAddWithError:finalError ?: httpError];
            }];
            return;
        }
        [self finishAddWithError:finalError];
    };

    [[RNFeedStore sharedStore] addFeedWithURL:url title:title category:cat completion:^(RNFeed *feed, NSError *error) {
        if (feed) {
            feed.iconBackgroundEnabled = self->_iconBackgroundSwitch.on;
            [[RNFeedStore sharedStore] save];
            [self->_spinner stopAnimating];
            if ([self.delegate respondsToSelector:@selector(addFeedDidFinishWithSuccess:)]) {
                [self.delegate addFeedDidFinishWithSuccess:YES];
            }
            [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
        } else {
            // Attempt autodiscovery before failing!
            [RNFeedDiscovery discoverFeedsForURL:url completion:^(NSArray *discovered, NSError *discError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (discovered.count > 0) {
                        RNDiscoveredFeed *first = [discovered objectAtIndex:0];
                        self->_urlField.text = first.url;
                        if (!title.length && first.title.length) self->_titleField.text = first.title;

                        [[RNFeedStore sharedStore] addFeedWithURL:first.url title:first.title category:cat completion:^(RNFeed *discoveredFeed, NSError *finalError) {
                            if (discoveredFeed) {
                                discoveredFeed.iconBackgroundEnabled = self->_iconBackgroundSwitch.on;
                                [[RNFeedStore sharedStore] save];
                                [self->_spinner stopAnimating];
                                if ([self.delegate respondsToSelector:@selector(addFeedDidFinishWithSuccess:)]) {
                                    [self.delegate addFeedDidFinishWithSuccess:YES];
                                }
                                [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
                            } else {
                                onAddFailure(finalError);
                            }
                        }];
                    } else {
                        onAddFailure(error);
                    }
                });
            }];
        }
    }];
}

- (void)finishAddWithError:(NSError *)error
{
    [self->_spinner stopAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                           target:self
                                                                                           action:@selector(save)];
    UIAlertView *alert = [[RetroAlertView alloc] initWithTitle:L(@"FeedError")
                                                    message:error.localizedDescription
                                                   delegate:nil
                                          cancelButtonTitle:L(@"Done")
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _feedToEdit ? 1 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 4;
    return _presets.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return RetroSectionHeader([self tableView:tableView titleForHeaderInSection:section], tableView.bounds.size.width);
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [self tableView:tableView titleForHeaderInSection:section].length ? 32.0 : 10.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) return L(@"FeedDetails");
    return @"Popular Feeds (Tap to use)";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            if (_enteredURL) _urlField.text = _enteredURL;
            return _urlCell;
        }
        if (indexPath.row == 1) {
            if (_enteredTitle) _titleField.text = _enteredTitle;
            return _titleCell;
        }
        if (indexPath.row == 3) return _iconBackgroundCell;
        if (_enteredCategory) _catField.text = _enteredCategory;
        return _catCell;
    }

    static NSString *PresetId = @"PresetCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PresetId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:PresetId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSDictionary *p = [_presets objectAtIndex:indexPath.row];
    cell.textLabel.text = [p objectForKey:@"title"];
    cell.detailTextLabel.text = [p objectForKey:@"url"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        NSDictionary *p = [_presets objectAtIndex:indexPath.row];
        _enteredURL = [p objectForKey:@"url"];
        _enteredTitle = [p objectForKey:@"title"];
        _enteredCategory = [p objectForKey:@"cat"];
        _urlField.text = _enteredURL;
        _titleField.text = _enteredTitle;
        _catField.text = _enteredCategory;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _urlField) {
        [_titleField becomeFirstResponder];
    } else if (textField == _titleField) {
        [_catField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
        [self save];
    }
    return YES;
}

@end
