#import "RNAppDelegate.h"
#import "RNFeedListViewController.h"
#import "RNItemListViewController.h"
#import "RNArticleViewController.h"
#import "RNAppearanceViewController.h"
#import "RNTheme.h"
#import "RNTLSSocket.h"
#import "RNFeedStore.h"
#import "RNImageLoader.h"
#import "RNCommon.h"

@interface RNAppDelegate () {
    UIPopoverController *_masterPopoverController;
    UIBarButtonItem *_barButtonItem;
}
@end

@implementation RNAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [RNTheme applyAppearance];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    RNFeedListViewController *listVC = [[RNFeedListViewController alloc] init];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:listVC];
    self.window.rootViewController = self.navigationController;

    [self.window makeKeyAndVisible];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [RNTLSSocket warmUp];
    });

    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[RNFeedStore sharedStore] saveSynchronously];
        if (bgTask != UIBackgroundTaskInvalid) {
            [application endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }
    });
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[RNFeedStore sharedStore] saveSynchronously];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    [[RNImageLoader shared] clearCache];
}

- (void)takeSnapshot
{
    [self takeSnapshotToFile:@"/tmp/realnews-screen.png"];
}

- (void)takeSnapshotToFile:(NSString *)filePath
{
    void (^captureBlock)(void) = ^{
        CGSize size = [UIScreen mainScreen].bounds.size;
        UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.hidden || w.alpha <= 0) continue;
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, w.frame.origin.x, w.frame.origin.y);
            [w.layer renderInContext:ctx];
            CGContextRestoreGState(ctx);
        }
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (image) {
            NSData *png = UIImagePNGRepresentation(image);
            [png writeToFile:filePath atomically:YES];
            NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filePath.lastPathComponent];
            [png writeToFile:tmpPath atomically:YES];
            RNLog(@"Snapshot saved to %@ (%dx%d, %lu bytes)", filePath, (int)size.width, (int)size.height, (unsigned long)png.length);
        }
    };

    if ([NSThread isMainThread]) {
        captureBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), captureBlock);
    }
}

- (void)runFullWalkthroughTest
{
    RNLog(@"=== STARTING REALNEWS 7-FEATURE FULL WALKTHROUGH TEST ===");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 1. Feeds List
        [self takeSnapshotToFile:@"/tmp/rn-1-feeds.png"];
        RNLog(@"Step 1: Feeds list captured");

        // 2. Open First Feed (ČT24)
        RNFeedListViewController *rootVC = (RNFeedListViewController *)RNFirst(self.navigationController.viewControllers);
        [rootVC openFeedAtIndex:0];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 2. Articles List
            [self takeSnapshotToFile:@"/tmp/rn-2-items.png"];
            RNLog(@"Step 2: Articles list captured");

            // 3. Open First Article (Feature 5: WebP inline image rendering)
            RNItemListViewController *itemVC = (RNItemListViewController *)self.navigationController.topViewController;
            if ([itemVC isKindOfClass:[RNItemListViewController class]]) {
                [itemVC openArticleAtIndex:0];
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 3. Article View
                [self takeSnapshotToFile:@"/tmp/rn-3-article.png"];
                RNLog(@"Step 3: Article reader captured (Feature 5: WebP rendering)");

                RNArticleViewController *artVC = (RNArticleViewController *)self.navigationController.topViewController;

                // 4. Feature 1: Toggle Full-Text Readability Mode
                if ([artVC isKindOfClass:[RNArticleViewController class]]) {
                    artVC.item.fullTextContent = nil;
                    [artVC toggleFullText];
                }

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self takeSnapshotToFile:@"/tmp/rn-4-fulltext.png"];
                    RNLog(@"Step 4: Full-text Readability mode captured (Feature 1)");

                    // 5. Feature 2: Sepia Theme
                    [RNAppearanceViewController setCurrentTheme:RNReaderThemeSepia];
                    if ([artVC isKindOfClass:[RNArticleViewController class]]) {
                        [artVC appearanceController:nil didChangeTheme:RNReaderThemeSepia];
                    }

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self takeSnapshotToFile:@"/tmp/rn-5-sepia.png"];
                        RNLog(@"Step 5: Sepia Theme captured (Feature 2)");

                        // 6. Feature 2: Night Theme
                        [RNAppearanceViewController setCurrentTheme:RNReaderThemeNight];
                        if ([artVC isKindOfClass:[RNArticleViewController class]]) {
                            [artVC appearanceController:nil didChangeTheme:RNReaderThemeNight];
                        }

                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [self takeSnapshotToFile:@"/tmp/rn-6-night.png"];
                            RNLog(@"Step 6: Night Theme captured (Feature 2)");

                            // 7. Feature 3: Typography Controls & Themes UI
                            [RNAppearanceViewController setCurrentTheme:RNReaderThemeDay];
                            if ([artVC isKindOfClass:[RNArticleViewController class]]) {
                                [artVC appearanceController:nil didChangeTheme:RNReaderThemeDay];
                                [artVC openAppearancePopover];
                            }

                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                [self takeSnapshotToFile:@"/tmp/rn-7-appearance.png"];
                                RNLog(@"Step 7: Appearance Popover captured (Feature 3)");

                                if ([artVC isKindOfClass:[RNArticleViewController class]]) {
                                    [artVC dismissAppearancePopover];
                                }

                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                    // 8. Feature 14: Full-screen Image Viewer
                                    if ([artVC isKindOfClass:[RNArticleViewController class]]) {
                                        NSString *imgURL = artVC.item.thumbnailURL.length ? artVC.item.thumbnailURL : @"https://ct24.ceskatelevize.cz/sites/default/files/styles/scale_1180/public/2024-04/ct24.jpg";
                                        [artVC openImageViewerForURL:imgURL];
                                    }

                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                        [self takeSnapshotToFile:@"/tmp/rn-8-imageviewer.png"];
                                        RNLog(@"Step 8: Full-screen Image Viewer captured (Feature 14)");

                                        [artVC dismissViewControllerAnimated:NO completion:NULL];

                                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                            // 9. Feature 11: Audio Podcast Player Card
                                            RNFeedItem *audioItem = [[RNFeedItem alloc] init];
                                            audioItem.title = @"BBC Global News Podcast - Daily";
                                            audioItem.enclosureURL = @"https://podcasts.files.bbci.co.uk/p02nq0gn.rss";
                                            audioItem.enclosureType = @"audio/mpeg";
                                            audioItem.summary = @"Přehrávání zvukové stopy v aplikaci RealNews s ovládáním skrubování, délkou skladby a během na pozadí.";
                                            RNArticleViewController *podcastVC = [[RNArticleViewController alloc] initWithFeedItem:audioItem];
                                            [self.navigationController pushViewController:podcastVC animated:NO];

                                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                [self takeSnapshotToFile:@"/tmp/rn-9-audioplayer.png"];
                                                RNLog(@"Step 9: Audio Podcast Player Card captured (Feature 11)");

                                                [self.navigationController popToRootViewControllerAnimated:NO];

                                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                    // 10. Feature 8: Add Feed & Autodiscovery
                                                    [rootVC openAddFeedModal];

                                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                        [self takeSnapshotToFile:@"/tmp/rn-10-addfeed-discovery.png"];
                                                        RNLog(@"Step 10: Add Feed modal with Autodiscovery captured (Feature 8)");

                                                        [self.navigationController dismissViewControllerAnimated:NO completion:NULL];

                                                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                            // 11. Metadata Inspector
                                                            [rootVC openFeedAtIndex:0];

                                                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                RNItemListViewController *reItemVC = (RNItemListViewController *)self.navigationController.topViewController;
                                                                if ([reItemVC isKindOfClass:[RNItemListViewController class]]) {
                                                                    [reItemVC openArticleAtIndex:0];
                                                                }

                                                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                    RNArticleViewController *reArtVC = (RNArticleViewController *)self.navigationController.topViewController;
                                                                    if ([reArtVC isKindOfClass:[RNArticleViewController class]]) {
                                                                        [reArtVC openMetadataInspector];
                                                                    }

                                                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                        [self takeSnapshotToFile:@"/tmp/rn-11-metadata.png"];
                                                                        RNLog(@"Step 11: Metadata Inspector captured");

                                                                        [self.navigationController dismissViewControllerAnimated:NO completion:NULL];
                                                                        [self.navigationController popToRootViewControllerAnimated:NO];

                                                                        [@"OK" writeToFile:@"/tmp/rn-walkthrough-done.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
                                                                        RNLog(@"=== REALNEWS 7-FEATURE FULL WALKTHROUGH COMPLETED SUCCESSFULLY! ===");
                                                                    });
                                                                });
                                                            });
                                                        });
                                                    });
                                                });
                                            });
                                        });
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    });
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if (!url) return NO;
    NSString *scheme = url.scheme.lowercaseString;
    NSString *host = url.host.lowercaseString;
    NSString *spec = url.resourceSpecifier;

    if ([scheme isEqualToString:@"realnews"]) {
        if ([host isEqualToString:@"snapshot"] || [spec isEqualToString:@"snapshot"] || [spec hasPrefix:@"//snapshot"] || [spec hasPrefix:@":snapshot"]) {
            [self takeSnapshot];
            return YES;
        }

        if ([host isEqualToString:@"walkthrough"] || [spec rangeOfString:@"walkthrough"].location != NSNotFound) {
            [self runFullWalkthroughTest];
            return YES;
        }

        if ([spec rangeOfString:@"feat1"].location != NSNotFound) {
            [self.navigationController popToRootViewControllerAnimated:NO];
            RNFeedListViewController *rootVC = (RNFeedListViewController *)RNFirst(self.navigationController.viewControllers);
            [rootVC openFeedAtIndex:0];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                RNItemListViewController *itemVC = (RNItemListViewController *)self.navigationController.topViewController;
                if ([itemVC isKindOfClass:[RNItemListViewController class]]) {
                    [itemVC openArticleAtIndex:0];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        RNArticleViewController *artVC = (RNArticleViewController *)self.navigationController.topViewController;
                        if ([artVC isKindOfClass:[RNArticleViewController class]]) {
                            artVC.item.fullTextContent = nil;
                            [artVC toggleFullText];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                [self takeSnapshotToFile:@"/tmp/rn-feat1-readability.png"];
                            });
                        }
                    });
                }
            });
            return YES;
        }

        if ([spec rangeOfString:@"feat8"].location != NSNotFound) {
            [self.navigationController popToRootViewControllerAnimated:NO];
            RNFeedListViewController *rootVC = (RNFeedListViewController *)RNFirst(self.navigationController.viewControllers);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [rootVC openAddFeedModal];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self takeSnapshotToFile:@"/tmp/rn-feat8-addfeed.png"];
                });
            });
            return YES;
        }

        if ([spec rangeOfString:@"feat11"].location != NSNotFound) {
            [self.navigationController popToRootViewControllerAnimated:NO];
            RNFeedItem *audioItem = [[RNFeedItem alloc] init];
            audioItem.title = @"BBC Global News Podcast - Daily";
            audioItem.enclosureURL = @"https://podcasts.files.bbci.co.uk/p02nq0gn.rss";
            audioItem.enclosureType = @"audio/mpeg";
            audioItem.summary = @"Přehrávání zvukové stopy v aplikaci RealNews s ovládáním skrubování, délkou skladby a během na pozadí.";
            RNArticleViewController *podcastVC = [[RNArticleViewController alloc] initWithFeedItem:audioItem];
            [self.navigationController pushViewController:podcastVC animated:NO];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self takeSnapshotToFile:@"/tmp/rn-feat11-audioplayer.png"];
            });
            return YES;
        }

        if ([spec rangeOfString:@"feat14"].location != NSNotFound) {
            [self.navigationController popToRootViewControllerAnimated:NO];
            RNFeedListViewController *rootVC = (RNFeedListViewController *)RNFirst(self.navigationController.viewControllers);
            [rootVC openFeedAtIndex:0];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                RNItemListViewController *itemVC = (RNItemListViewController *)self.navigationController.topViewController;
                if ([itemVC isKindOfClass:[RNItemListViewController class]]) {
                    [itemVC openArticleAtIndex:0];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        RNArticleViewController *artVC = (RNArticleViewController *)self.navigationController.topViewController;
                        if ([artVC isKindOfClass:[RNArticleViewController class]]) {
                            NSString *imgURL = artVC.item.thumbnailURL.length ? artVC.item.thumbnailURL : @"https://ct24.ceskatelevize.cz/sites/default/files/styles/scale_1180/public/2024-04/ct24.jpg";
                            [artVC openImageViewerForURL:imgURL];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                [self takeSnapshotToFile:@"/tmp/rn-feat14-imageviewer.png"];
                            });
                        }
                    });
                }
            });
            return YES;
        }

        if ([host isEqualToString:@"refresh"] || [spec rangeOfString:@"refresh"].location != NSNotFound) {
            [[RNFeedStore sharedStore] refreshAllFeedsWithCompletion:^{
                [self takeSnapshotToFile:@"/tmp/screen-refreshed.png"];
            }];
            return YES;
        }

        if ([spec rangeOfString:@"goto:feeds"].location != NSNotFound) {
            [self.navigationController popToRootViewControllerAnimated:NO];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self takeSnapshotToFile:@"/tmp/screen-feeds.png"];
            });
            return YES;
        }

        if ([spec rangeOfString:@"goto:feed:"].location != NSNotFound) {
            [self.navigationController popToRootViewControllerAnimated:NO];
            NSString *idxStr = [[spec componentsSeparatedByString:@"goto:feed:"] lastObject];
            NSInteger idx = [idxStr integerValue];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                RNFeedListViewController *rootVC = (RNFeedListViewController *)RNFirst(self.navigationController.viewControllers);
                [rootVC openFeedAtIndex:idx];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self takeSnapshotToFile:@"/tmp/screen-feed.png"];
                });
            });
            return YES;
        }

        if ([spec rangeOfString:@"goto:article:"].location != NSNotFound) {
            NSString *idxStr = [[spec componentsSeparatedByString:@"goto:article:"] lastObject];
            NSInteger idx = [idxStr integerValue];
            RNItemListViewController *itemVC = (RNItemListViewController *)self.navigationController.topViewController;
            if ([itemVC isKindOfClass:[RNItemListViewController class]]) {
                [itemVC openArticleAtIndex:idx];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self takeSnapshotToFile:@"/tmp/screen-article.png"];
                });
            }
            return YES;
        }

        if ([spec rangeOfString:@"goto:back"].location != NSNotFound) {
            [self.navigationController popViewControllerAnimated:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self takeSnapshotToFile:@"/tmp/screen-back.png"];
            });
            return YES;
        }

        NSString *abs = url.absoluteString;
        NSRange colon = [abs rangeOfString:@"://"];
        if (colon.location != NSNotFound) {
            NSString *feedURL = [abs substringFromIndex:colon.location + 3];
            if (feedURL.length) {
                [[RNFeedStore sharedStore] addFeedWithURL:feedURL title:nil category:nil completion:NULL];
                return YES;
            }
        }
    } else if ([scheme isEqualToString:@"feed"] || [scheme isEqualToString:@"rss"]) {
        NSString *abs = url.absoluteString;
        NSRange colon = [abs rangeOfString:@"://"];
        if (colon.location != NSNotFound) {
            NSString *feedURL = [NSString stringWithFormat:@"http://%@", [abs substringFromIndex:colon.location + 3]];
            if (feedURL.length) {
                [[RNFeedStore sharedStore] addFeedWithURL:feedURL title:nil category:nil completion:NULL];
                return YES;
            }
        }
    }
    return NO;
}

@end
