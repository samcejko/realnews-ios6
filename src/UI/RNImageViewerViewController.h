#import <UIKit/UIKit.h>

@interface RNImageViewerViewController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSString *imageURLString;

- (instancetype)initWithImage:(UIImage *)image;
- (instancetype)initWithImageURLString:(NSString *)urlString;

@end
