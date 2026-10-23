#import "RNImageViewerViewController.h"
#import "RNImageLoader.h"
#import "RNCommon.h"

@interface RNImageViewerViewController () {
    UIScrollView *_scrollView;
    UIImageView *_imageView;
    UIToolbar *_topToolbar;
    UIToolbar *_bottomToolbar;
    UIActivityIndicatorView *_spinner;
    UILabel *_infoLabel;
    BOOL _barsHidden;
}
@end

@implementation RNImageViewerViewController

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self) {
        _image = image;
        self.wantsFullScreenLayout = YES;
    }
    return self;
}

- (instancetype)initWithImageURLString:(NSString *)urlString
{
    self = [super init];
    if (self) {
        _imageURLString = [urlString copy];
        self.wantsFullScreenLayout = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.delegate = self;
    _scrollView.minimumZoomScale = 1.0f;
    _scrollView.maximumZoomScale = 4.0f;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_scrollView];

    _imageView = [[UIImageView alloc] init];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_scrollView addSubview:_imageView];

    // Single tap to toggle toolbars
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    singleTap.cancelsTouchesInView = NO;
    singleTap.delaysTouchesBegan = YES;
    [self.view addGestureRecognizer:singleTap];

    // Double tap to zoom
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.view addGestureRecognizer:doubleTap];

    // Top translucent toolbar
    _topToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    _topToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _topToolbar.barStyle = UIBarStyleBlackTranslucent;

    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithTitle:L(@"Close")
                                                                 style:UIBarButtonItemStyleDone
                                                                target:self
                                                                action:@selector(closeTapped)];

    UIBarButtonItem *flex1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    _infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
    _infoLabel.backgroundColor = [UIColor clearColor];
    _infoLabel.textColor = [UIColor whiteColor];
    _infoLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    _infoLabel.textAlignment = UITextAlignmentCenter;
    UIBarButtonItem *titleItem = [[UIBarButtonItem alloc] initWithCustomView:_infoLabel];

    UIBarButtonItem *flex2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    _topToolbar.items = @[ closeBtn, flex1, titleItem, flex2 ];
    [self.view addSubview:_topToolbar];

    // Bottom translucent toolbar
    _bottomToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 44, self.view.bounds.size.width, 44)];
    _bottomToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _bottomToolbar.barStyle = UIBarStyleBlackTranslucent;

    UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc] initWithTitle:@"Uložit do fotek"
                                                                style:UIBarButtonItemStyleBordered
                                                               target:self
                                                               action:@selector(saveToPhotosTapped)];

    UIBarButtonItem *copyBtn = [[UIBarButtonItem alloc] initWithTitle:@"Kopírovat"
                                                                style:UIBarButtonItemStyleBordered
                                                               target:self
                                                               action:@selector(copyImageTapped)];

    UIBarButtonItem *safariBtn = [[UIBarButtonItem alloc] initWithTitle:@"Safari"
                                                                  style:UIBarButtonItemStyleBordered
                                                                 target:self
                                                                 action:@selector(openInSafariTapped)];

    UIBarButtonItem *bflex1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *bflex2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    _bottomToolbar.items = @[ saveBtn, bflex1, copyBtn, bflex2, safariBtn ];
    [self.view addSubview:_bottomToolbar];

    // Activity spinner
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _spinner.center = self.view.center;
    _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    if (_image) {
        [self displayImage:_image];
    } else if (_imageURLString.length > 0) {
        [self loadImageFromURLString:_imageURLString];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self centerImageView];
}

- (void)loadImageFromURLString:(NSString *)urlString
{
    UIImage *cached = [[RNImageLoader shared] imageForURL:urlString];
    if (cached) {
        [self displayImage:cached];
        return;
    }

    [_spinner startAnimating];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleImageLoadedNotification:)
                                                 name:RNImageDidLoadNotification
                                               object:nil];
    [[RNImageLoader shared] prefetchImageForURL:urlString];
}

- (void)handleImageLoadedNotification:(NSNotification *)note
{
    NSString *url = [note.userInfo objectForKey:@"url"];
    if ([url isEqualToString:_imageURLString]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:RNImageDidLoadNotification object:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_spinner stopAnimating];
            UIImage *img = [[RNImageLoader shared] imageForURL:self->_imageURLString];
            if (img) {
                [self displayImage:img];
            }
        });
    }
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

- (void)displayImage:(UIImage *)image
{
    _image = image;
    _imageView.image = image;
    _imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    _scrollView.contentSize = image.size;
    _infoLabel.text = [NSString stringWithFormat:@"%dx%d", (int)image.size.width, (int)image.size.height];

    // Calculate initial scale to fit screen
    CGSize boundsSize = self.view.bounds.size;
    CGFloat scaleWidth = boundsSize.width / image.size.width;
    CGFloat scaleHeight = boundsSize.height / image.size.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight);
    if (minScale > 1.0f) minScale = 1.0f;

    _scrollView.minimumZoomScale = minScale;
    _scrollView.maximumZoomScale = MAX(minScale * 4.0f, 3.0f);
    _scrollView.zoomScale = minScale;

    [self centerImageView];
}

- (void)centerImageView
{
    CGSize boundsSize = _scrollView.bounds.size;
    CGRect frameToCenter = _imageView.frame;

    if (frameToCenter.size.width < boundsSize.width) {
        frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2.0f;
    } else {
        frameToCenter.origin.x = 0;
    }

    if (frameToCenter.size.height < boundsSize.height) {
        frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2.0f;
    } else {
        frameToCenter.origin.y = 0;
    }

    _imageView.frame = frameToCenter;
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return _imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    [self centerImageView];
}

#pragma mark - Gestures & Actions

- (void)handleSingleTap:(UITapGestureRecognizer *)tap
{
    _barsHidden = !_barsHidden;
    [UIView animateWithDuration:0.25 animations:^{
        self->_topToolbar.alpha = self->_barsHidden ? 0.0f : 1.0f;
        self->_bottomToolbar.alpha = self->_barsHidden ? 0.0f : 1.0f;
    }];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)tap
{
    if (_scrollView.zoomScale > _scrollView.minimumZoomScale) {
        [_scrollView setZoomScale:_scrollView.minimumZoomScale animated:YES];
    } else {
        CGPoint point = [tap locationInView:_imageView];
        CGFloat newScale = MIN(_scrollView.maximumZoomScale, _scrollView.zoomScale * 2.5f);
        CGSize scrollViewSize = _scrollView.bounds.size;

        CGFloat w = scrollViewSize.width / newScale;
        CGFloat h = scrollViewSize.height / newScale;
        CGFloat x = point.x - (w / 2.0f);
        CGFloat y = point.y - (h / 2.0f);

        CGRect rectToZoomTo = CGRectMake(x, y, w, h);
        [_scrollView zoomToRect:rectToZoomTo animated:YES];
    }
}

- (void)closeTapped
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)saveToPhotosTapped
{
    if (!_image) return;
    UIImageWriteToSavedPhotosAlbum(_image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if (!error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uloženo"
                                                        message:@"Obrázek byl úspěšně uložen do složky Obrázky."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Chyba"
                                                        message:error.localizedDescription
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)copyImageTapped
{
    if (!_image) return;
    [UIPasteboard generalPasteboard].image = _image;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Zkopírováno"
                                                    message:@"Obrázek byl zkopírován do schránky."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)openInSafariTapped
{
    if (_imageURLString.length) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:_imageURLString]];
    }
}

@end
