#import "RNArticleViewController.h"
#import "RNMetadataViewController.h"
#import "RNAppearanceViewController.h"
#import "RNReadabilityExtractor.h"
#import "RNAudioPlayerView.h"
#import "RNImageViewerViewController.h"
#import "RNImageLoader.h"
#import "RNWebPDecoder.h"
#import "RNFeedStore.h"
#import "RNUtils.h"
#import "RNTheme.h"
#import "RNCommon.h"

@interface RNArticleViewController () {
    UIWebView *_webView;
    RNAudioPlayerView *_audioPlayerView;
    UIPopoverController *_appearancePopover;
    UIBarButtonItem *_prevButton;
    UIBarButtonItem *_nextButton;
    UIBarButtonItem *_starButton;
    UIBarButtonItem *_appearanceButton;
    UIBarButtonItem *_fullTextButton;
    UIBarButtonItem *_actionButton;
    UIBarButtonItem *_metaButton;
    UIActivityIndicatorView *_fullTextSpinner;
    BOOL _isFullTextMode;
}
@end

@implementation RNArticleViewController

- (instancetype)initWithFeedItem:(RNFeedItem *)item
{
    self = [super init];
    if (self) {
        _item = item;
        _items = item ? @[ item ] : @[];
        _currentIndex = 0;
        _isFullTextMode = NO;
    }
    return self;
}

- (instancetype)initWithItems:(NSArray *)items currentIndex:(NSInteger)index
{
    self = [super init];
    if (self) {
        _items = items;
        _currentIndex = index;
        if (index >= 0 && index < (NSInteger)items.count) {
            _item = [items objectAtIndex:index];
        }
        _isFullTextMode = NO;
    }
    return self;
}

- (RNAudioPlayerView *)audioPlayerView
{
    return _audioPlayerView;
}

- (void)updateTitle
{
    NSString *t = _item.title.length ? _item.title : L(@"Articles");
    self.title = t;

    CGFloat titleWidth = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 360.0f : 140.0f;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, titleWidth, 40)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.35f];
    titleLabel.shadowOffset = CGSizeMake(0, -1);
    titleLabel.textAlignment = UITextAlignmentCenter;
    titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    titleLabel.text = t;
    self.navigationItem.titleView = titleLabel;
}

- (void)setItem:(RNFeedItem *)item
{
    _item = item;
    _isFullTextMode = NO;
    if ([self isViewLoaded]) {
        [self updateTitle];
        [self updateAudioPlayerState];
        [self loadArticleContent];
        [self updateBarButtons];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    // Audio player banner view (pinned at top)
    _audioPlayerView = [[RNAudioPlayerView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 70)];
    _audioPlayerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _audioPlayerView.delegate = self;
    _audioPlayerView.hidden = YES;
    [self.view addSubview:_audioPlayerView];

    // Main web view
    _webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _webView.delegate = self;
    _webView.scalesPageToFit = YES;
    _webView.dataDetectorTypes = UIDataDetectorTypeLink;
    [self.view addSubview:_webView];

    [self setupNavigationItems];
    [self updateAudioPlayerState];
    [self loadArticleContent];

    // Swipe right to go back
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(goBack)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];

    if (_item && !_item.isRead) {
        [[RNFeedStore sharedStore] markItem:_item asRead:YES];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleImageDidLoadNotification:)
                                                 name:RNImageDidLoadNotification
                                               object:nil];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    if (!_audioPlayerView.hidden) {
        _audioPlayerView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 70);
        _webView.frame = CGRectMake(0, 70, self.view.bounds.size.width, self.view.bounds.size.height - 70);
    } else {
        _webView.frame = self.view.bounds;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
    if (_appearancePopover && _appearancePopover.isPopoverVisible) {
        [_appearancePopover dismissPopoverAnimated:NO];
        _appearancePopover = nil;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_audioPlayerView stop];
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

- (void)setupNavigationItems
{
    [self updateTitle];

    // Right navbar: Full-text toggle button + Metadata inspector
    _fullTextButton = [[UIBarButtonItem alloc] initWithTitle:(_isFullTextMode ? @"Původní" : @"Celý text")
                                                       style:(_isFullTextMode ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered)
                                                      target:self
                                                      action:@selector(toggleFullText)];

    _metaButton = [[UIBarButtonItem alloc] initWithTitle:L(@"Metadata")
                                                   style:UIBarButtonItemStyleBordered
                                                  target:self
                                                  action:@selector(openMetadataInspector)];

    self.navigationItem.rightBarButtonItems = @[ _metaButton, _fullTextButton ];

    // Bottom toolbar: [Back Arrow] [flex] [Up Arrow] [Down Arrow] [flex] [aA] [flex] [Star] [flex] [Action]
    UIBarButtonItem *tbBackBtn = [[UIBarButtonItem alloc] initWithImage:[RNTheme leftArrowImage]
                                                                  style:UIBarButtonItemStyleBordered
                                                                 target:self
                                                                 action:@selector(goBack)];

    _prevButton = [[UIBarButtonItem alloc] initWithImage:[RNTheme upArrowImage]
                                                   style:UIBarButtonItemStyleBordered
                                                  target:self
                                                  action:@selector(goToPreviousArticle)];

    _nextButton = [[UIBarButtonItem alloc] initWithImage:[RNTheme downArrowImage]
                                                   style:UIBarButtonItemStyleBordered
                                                  target:self
                                                  action:@selector(goToNextArticle)];

    _appearanceButton = [[UIBarButtonItem alloc] initWithTitle:@"aA"
                                                         style:UIBarButtonItemStyleBordered
                                                        target:self
                                                        action:@selector(openAppearancePopover)];

    _starButton = [[UIBarButtonItem alloc] initWithImage:(_item.isFavorite ? [RNTheme starImageFilled] : [RNTheme starImageEmpty])
                                                   style:UIBarButtonItemStyleBordered
                                                  target:self
                                                  action:@selector(toggleStar)];

    _actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                  target:self
                                                                  action:@selector(showActionSheet)];

    UIBarButtonItem *flex1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flex2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flex3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flex4 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    self.toolbarItems = @[ tbBackBtn, flex1, _prevButton, _nextButton, flex2, _appearanceButton, flex3, _starButton, flex4, _actionButton ];
    [self updateBarButtons];
}

- (void)goBack
{
    [_audioPlayerView stop];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)updateBarButtons
{
    _starButton.image = (_item.isFavorite ? [RNTheme starImageFilled] : [RNTheme starImageEmpty]);
    _prevButton.enabled = (_currentIndex > 0);
    _nextButton.enabled = (_currentIndex < (NSInteger)_items.count - 1);
    _fullTextButton.title = (_isFullTextMode ? @"Původní" : @"Celý text");
    _fullTextButton.style = (_isFullTextMode ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered);
}

- (void)updateAudioPlayerState
{
    BOOL hasAudio = (_item.enclosureURL.length > 0 &&
                     ([_item.enclosureType hasPrefix:@"audio/"] ||
                      [_item.enclosureURL.lowercaseString hasSuffix:@".mp3"] ||
                      [_item.enclosureURL.lowercaseString hasSuffix:@".m4a"] ||
                      [_item.enclosureURL.lowercaseString hasSuffix:@".aac"] ||
                      [_item.enclosureURL.lowercaseString hasSuffix:@".wav"] ||
                      [_item.enclosureURL.lowercaseString hasSuffix:@".ogg"]));

    if (hasAudio) {
        _audioPlayerView.hidden = NO;
        [_audioPlayerView loadAudioURLString:_item.enclosureURL title:_item.title];
        _webView.frame = CGRectMake(0, 70, self.view.bounds.size.width, self.view.bounds.size.height - 70);
    } else {
        _audioPlayerView.hidden = YES;
        [_audioPlayerView stop];
        _webView.frame = self.view.bounds;
    }
}

- (void)goToPreviousArticle
{
    if (_currentIndex > 0) {
        _currentIndex--;
        _item = [_items objectAtIndex:_currentIndex];
        _isFullTextMode = NO;
        [[RNFeedStore sharedStore] markItem:_item asRead:YES];
        [self updateTitle];
        [self updateAudioPlayerState];
        [self loadArticleContent];
        [self updateBarButtons];
    }
}

- (void)goToNextArticle
{
    if (_currentIndex < (NSInteger)_items.count - 1) {
        _currentIndex++;
        _item = [_items objectAtIndex:_currentIndex];
        _isFullTextMode = NO;
        [[RNFeedStore sharedStore] markItem:_item asRead:YES];
        [self updateTitle];
        [self updateAudioPlayerState];
        [self loadArticleContent];
        [self updateBarButtons];
    }
}

- (void)toggleStar
{
    if (!_item) return;
    [[RNFeedStore sharedStore] toggleFavoriteForItem:_item];
    [self updateBarButtons];
}

#pragma mark - Feature 1: Full-Text Article Extractor

- (void)toggleFullText
{
    if (!_item) return;

    if (_isFullTextMode) {
        // Switch back to original feed view
        _isFullTextMode = NO;
        [self updateBarButtons];
        [self loadArticleContent];
        return;
    }

    // Switch to Full-text Readability mode
    if (_item.fullTextContent.length > 0) {
        _isFullTextMode = YES;
        [self updateBarButtons];
        [self loadArticleContent];
        return;
    }

    // Fetch full text
    if (!_item.link.length) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Chyba"
                                                        message:@"Tento článek neobsahuje odkaz na webovou stránku."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    _fullTextButton.enabled = NO;
    _fullTextButton.title = @"Načítání...";

    __weak typeof(self) weakSelf = self;
    [RNReadabilityExtractor extractArticleFromURL:_item.link completion:^(RNReadabilityResult *result, NSError *error) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf->_fullTextButton.enabled = YES;
            if (result && result.contentHTML.length > 0) {
                strongSelf->_item.fullTextContent = result.contentHTML;
                if (!strongSelf->_item.leadImageURL.length && result.leadImageURL.length) {
                    strongSelf->_item.leadImageURL = result.leadImageURL;
                }
                strongSelf->_isFullTextMode = YES;
                [strongSelf updateBarButtons];
                [strongSelf loadArticleContent];
            } else {
                [strongSelf updateBarButtons];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Chyba extrakce"
                                                                message:@"Nepodařilo se extrahovat celý článek z webové stránky."
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
        });
    }];
}

#pragma mark - Features 2 & 3: Appearance (Themes & Typography)

- (void)openAppearancePopover
{
    RNAppearanceViewController *appVC = [[RNAppearanceViewController alloc] init];
    appVC.delegate = self;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (_appearancePopover && _appearancePopover.isPopoverVisible) {
            [_appearancePopover dismissPopoverAnimated:YES];
            _appearancePopover = nil;
            return;
        }
        _appearancePopover = [[UIPopoverController alloc] initWithContentViewController:appVC];
        [_appearancePopover presentPopoverFromBarButtonItem:_appearanceButton
                                   permittedArrowDirections:UIPopoverArrowDirectionAny
                                                   animated:YES];
    } else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:appVC];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:nav animated:YES completion:NULL];
    }
}

- (void)dismissAppearancePopover
{
    if (_appearancePopover && _appearancePopover.isPopoverVisible) {
        [_appearancePopover dismissPopoverAnimated:NO];
        _appearancePopover = nil;
    }
}

- (void)appearanceController:(RNAppearanceViewController *)controller didChangeTheme:(RNReaderTheme)theme
{
    NSString *themeName = [RNAppearanceViewController themeNameForTheme:theme];
    NSString *js = [NSString stringWithFormat:@"setTheme('%@');", themeName];
    [_webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)appearanceController:(RNAppearanceViewController *)controller didChangeFontFamily:(NSString *)fontFamily
{
    NSString *js = [NSString stringWithFormat:@"setFontFamily(\"%@\");", fontFamily];
    [_webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)appearanceController:(RNAppearanceViewController *)controller didChangeFontSize:(NSInteger)fontSize
{
    NSString *js = [NSString stringWithFormat:@"setFontSize(%ld);", (long)fontSize];
    [_webView stringByEvaluatingJavaScriptFromString:js];
}

#pragma mark - Feature 14: Fullscreen Image Viewer

- (void)openImageViewerForURL:(NSString *)urlString
{
    if (!urlString.length) return;
    [self dismissAppearancePopover];
    RNImageViewerViewController *viewer = [[RNImageViewerViewController alloc] initWithImageURLString:urlString];
    viewer.modalPresentationStyle = UIModalPresentationFullScreen;
    viewer.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:viewer animated:YES completion:NULL];
}

#pragma mark - Content Loading & WebP Handling

- (void)handleImageDidLoadNotification:(NSNotification *)note
{
    NSString *url = [note.userInfo objectForKey:@"url"];
    NSString *path = [note.userInfo objectForKey:@"path"];
    if (url.length && path.length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *js = [NSString stringWithFormat:@"updateImageSrc('%@', 'file://%@');", url, path];
            [self->_webView stringByEvaluatingJavaScriptFromString:js];
        });
    }
}

- (void)loadArticleContent
{
    if (!_item) {
        [_webView loadHTMLString:@"<html><body style='font-family:Helvetica;padding:20px;text-align:center;color:#888;'>No article selected.</body></html>" baseURL:nil];
        return;
    }

    NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"reader_template" ofType:@"html"];
    NSString *htmlTemplate = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:NULL];
    if (!htmlTemplate.length) {
        htmlTemplate = @"<html><head><meta name='viewport' content='width=device-width, initial-scale=1.0'/></head><body class='__THEME_CLASS__'><h1>__TITLE__</h1>__BADGE__<p>__CONTENT__</p>__EXTRADATA__</body></html>";
    }

    // Appearance injection
    RNReaderTheme theme = [RNAppearanceViewController currentTheme];
    NSString *themeClass = [NSString stringWithFormat:@"theme-%@", [RNAppearanceViewController themeNameForTheme:theme]];
    NSString *fontFamily = [RNAppearanceViewController currentFontFamily];
    NSInteger fontSize = [RNAppearanceViewController currentFontSize];

    NSString *title = _item.title.length ? _item.title : @"(No Title)";

    // Full-text badge
    NSString *badgeHTML = _isFullTextMode ? @"<div class='fulltext-badge'>Celý článek (Readability)</div>" : @"";

    // Meta bar
    NSMutableString *meta = [NSMutableString string];
    if (_item.author.length) {
        [meta appendFormat:@"<span class='author'>%@</span>", [RNUtils cleanString:_item.author]];
    }
    if (_item.publishDateString.length) {
        if (meta.length) [meta appendString:@" &bull; "];
        [meta appendString:_item.displayDate];
    }
    if (_item.link.length) {
        if (meta.length) [meta appendString:@" &bull; "];
        [meta appendFormat:@"<a href='%@'>Zdroj</a>", _item.link];
    }

    // Enclosure (images)
    NSMutableString *enclosureHTML = [NSMutableString string];
    if (_item.enclosureURL.length && [_item.enclosureType hasPrefix:@"image/"]) {
        [enclosureHTML appendFormat:@"<div class='article-content'><img src='%@' alt='' onerror=\"this.style.display='none'\"/></div>", _item.enclosureURL];
    }

    // Content: Either full extracted text or original feed summary/content
    NSString *content = @"";
    if (_isFullTextMode && _item.fullTextContent.length > 0) {
        content = _item.fullTextContent;
    } else {
        content = _item.content.length ? _item.content : (_item.summary.length ? _item.summary : @"");
    }

    // Extra metadata table (RealNews hallmark feature)
    NSMutableString *extraHTML = [NSMutableString string];
    if (_item.extraData.count > 0) {
        [extraHTML appendString:@"<div class='extradata-section'>"];
        [extraHTML appendString:@"<div class='extradata-title'>Feed Metadata & All Fields</div>"];
        [extraHTML appendString:@"<table class='extradata'>"];

        NSArray *keys = [_item.extraData.allKeys sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *k in keys) {
            if ([k.lowercaseString isEqualToString:@"title"] || [k.lowercaseString isEqualToString:@"link"]) continue;
            id val = [_item.extraData objectForKey:k];
            NSString *valStr = [RNUtils displayMetadataValue:val forKey:k];

            [extraHTML appendString:@"<tr>"];
            [extraHTML appendFormat:@"<td class='key'>%@</td>", k];

            if ([valStr hasPrefix:@"http://"] || [valStr hasPrefix:@"https://"] || [valStr hasPrefix:@"magnet:"]) {
                [extraHTML appendFormat:@"<td class='val'><a href='%@'>%@</a></td>", valStr, valStr];
            } else {
                [extraHTML appendFormat:@"<td class='val'>%@</td>", valStr];
            }
            [extraHTML appendString:@"</tr>"];
        }
        [extraHTML appendString:@"</table></div>"];
    }

    NSString *rendered = [htmlTemplate stringByReplacingOccurrencesOfString:@"__THEME_CLASS__" withString:themeClass];
    rendered = [rendered stringByReplacingOccurrencesOfString:@"__FONT_FAMILY__" withString:fontFamily];
    rendered = [rendered stringByReplacingOccurrencesOfString:@"__FONT_SIZE__" withString:[NSString stringWithFormat:@"%ld", (long)fontSize]];
    rendered = [rendered stringByReplacingOccurrencesOfString:@"__TITLE__" withString:title];
    rendered = [rendered stringByReplacingOccurrencesOfString:@"__BADGE__" withString:badgeHTML];
    rendered = [rendered stringByReplacingOccurrencesOfString:@"__METABAR__" withString:meta];
    rendered = [rendered stringByReplacingOccurrencesOfString:@"__AUDIO_PLAYER__" withString:@""];
    rendered = [rendered stringByReplacingOccurrencesOfString:@"__ENCLOSURE__" withString:enclosureHTML];
    rendered = [rendered stringByReplacingOccurrencesOfString:@"__CONTENT__" withString:content];
    rendered = [rendered stringByReplacingOccurrencesOfString:@"__EXTRADATA__" withString:extraHTML];

    // Scan for images and substitute cached files (converting WebP to JPEG on-the-fly)
    NSRegularExpression *imgRegex = [NSRegularExpression regularExpressionWithPattern:@"<img[^>]+src=[\"']([^\"']+)[\"']"
                                                                              options:NSRegularExpressionCaseInsensitive
                                                                                error:NULL];
    NSArray *matches = [imgRegex matchesInString:rendered options:0 range:NSMakeRange(0, rendered.length)];
    for (NSTextCheckingResult *m in matches) {
        if (m.numberOfRanges > 1) {
            NSString *imgUrl = [rendered substringWithRange:[m rangeAtIndex:1]];
            NSString *cachedPath = [[RNImageLoader shared] cachedFilePathForURL:imgUrl];
            if (cachedPath.length > 0) {
                rendered = [rendered stringByReplacingOccurrencesOfString:imgUrl withString:[NSString stringWithFormat:@"file://%@", cachedPath]];
            } else {
                [[RNImageLoader shared] prefetchImageForURL:imgUrl];
            }
        }
    }

    NSURL *baseURL = _item.link.length ? [NSURL URLWithString:_item.link] : nil;
    [_webView loadHTMLString:rendered baseURL:baseURL];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = request.URL;
    NSString *scheme = url.scheme.lowercaseString;

    // Feature 14: Tap image in webview -> fullscreen image viewer
    if ([scheme isEqualToString:@"realnews-img"]) {
        NSString *raw = [url.resourceSpecifier stringByReplacingOccurrencesOfString:@"//" withString:@""];
        NSString *imgUrl = [raw stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (imgUrl.length > 0) {
            [self openImageViewerForURL:imgUrl];
        }
        return NO;
    }

    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
            [[UIApplication sharedApplication] openURL:url];
            return NO;
        }
    }
    return YES;
}

#pragma mark - Actions & Modals

- (void)showActionSheet
{
    if (!_item) return;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:L(@"Cancel")
                                          destructiveButtonTitle:nil
                                               otherButtonTitles:L(@"OpenInSafari"), L(@"CopyLink"), L(@"AllFields"), @"Změnit vzhled", nil];
    [sheet showFromBarButtonItem:_actionButton animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        if (_item.link.length) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:_item.link]];
        }
    } else if (buttonIndex == 1) {
        if (_item.link.length) {
            [[UIPasteboard generalPasteboard] setString:_item.link];
        }
    } else if (buttonIndex == 2) {
        [self openMetadataInspector];
    } else if (buttonIndex == 3) {
        [self openAppearancePopover];
    }
}

- (void)openMetadataInspector
{
    if (!_item) return;
    RNMetadataViewController *metaVC = [[RNMetadataViewController alloc] initWithFeedItem:_item];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:metaVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:NULL];
}

@end
