#import <UIKit/UIKit.h>
// Shared, code-drawn iOS 6 controls. Native UIKit is retained on iOS 5/6.
UISwitch *RetroMakeSwitch(void);
UIColor *RetroGroupedBackground(void);
UIView *RetroSectionHeader(NSString *title, CGFloat width);
@interface RetroAlertView : UIAlertView
@end
@interface RetroActionSheet : UIActionSheet
@end
