#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, RNReaderTheme) {
    RNReaderThemeDay = 0,
    RNReaderThemeSepia = 1,
    RNReaderThemeNight = 2
};

@class RNAppearanceViewController;

@protocol RNAppearanceDelegate <NSObject>
@optional
- (void)appearanceController:(RNAppearanceViewController *)controller didChangeTheme:(RNReaderTheme)theme;
- (void)appearanceController:(RNAppearanceViewController *)controller didChangeFontFamily:(NSString *)fontFamily;
- (void)appearanceController:(RNAppearanceViewController *)controller didChangeFontSize:(NSInteger)fontSize;
@end

@interface RNAppearanceViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) id<RNAppearanceDelegate> delegate;

+ (RNReaderTheme)currentTheme;
+ (void)setCurrentTheme:(RNReaderTheme)theme;
+ (NSString *)themeNameForTheme:(RNReaderTheme)theme;

+ (NSString *)currentFontFamily;
+ (void)setCurrentFontFamily:(NSString *)fontFamily;

+ (NSInteger)currentFontSize;
+ (void)setCurrentFontSize:(NSInteger)size;

@end
