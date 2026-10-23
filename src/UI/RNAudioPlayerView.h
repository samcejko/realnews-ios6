#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class RNAudioPlayerView;

@protocol RNAudioPlayerViewDelegate <NSObject>
@optional
- (void)audioPlayerView:(RNAudioPlayerView *)playerView didChangePlaybackState:(BOOL)isPlaying;
@end

@interface RNAudioPlayerView : UIView

@property (nonatomic, weak) id<RNAudioPlayerViewDelegate> delegate;
@property (nonatomic, copy) NSString *audioURLString;
@property (nonatomic, copy) NSString *trackTitle;
@property (nonatomic, readonly) BOOL isPlaying;

- (void)loadAudioURLString:(NSString *)urlString title:(NSString *)title;
- (void)play;
- (void)pause;
- (void)stop;

@end
