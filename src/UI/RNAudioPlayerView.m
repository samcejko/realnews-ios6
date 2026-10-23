#import "RNAudioPlayerView.h"
#import "RNTheme.h"
#import <QuartzCore/QuartzCore.h>

@interface RNAudioPlayerView () {
    AVPlayer *_player;
    id _timeObserver;
    UIButton *_playPauseBtn;
    UISlider *_scrubber;
    UILabel *_titleLabel;
    UILabel *_elapsedLabel;
    UILabel *_durationLabel;
    BOOL _isScrubbing;
    Float64 _durationSeconds;
    CAGradientLayer *_gradientLayer;
}
@end

@implementation RNAudioPlayerView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.clipsToBounds = YES;

        // Dark brushed metal / slate gradient
        _gradientLayer = [CAGradientLayer layer];
        _gradientLayer.colors = @[
            (id)[UIColor colorWithWhite:0.28f alpha:1.0f].CGColor,
            (id)[UIColor colorWithWhite:0.16f alpha:1.0f].CGColor,
            (id)[UIColor colorWithWhite:0.12f alpha:1.0f].CGColor
        ];
        _gradientLayer.locations = @[ @0.0f, @0.5f, @1.0f ];
        _gradientLayer.frame = self.bounds;
        [self.layer addSublayer:_gradientLayer];

        // Bottom border line
        UIView *bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - 1, frame.size.width, 1)];
        bottomBorder.backgroundColor = [UIColor colorWithWhite:0.08f alpha:1.0f];
        bottomBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:bottomBorder];

        // Top highlight line
        UIView *topHighlight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 1)];
        topHighlight.backgroundColor = [UIColor colorWithWhite:0.42f alpha:1.0f];
        topHighlight.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:topHighlight];

        // Play/Pause button
        _playPauseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _playPauseBtn.frame = CGRectMake(10, (frame.size.height - 40) / 2, 40, 40);
        _playPauseBtn.backgroundColor = [UIColor colorWithWhite:0.22f alpha:1.0f];
        _playPauseBtn.layer.cornerRadius = 20.0f;
        _playPauseBtn.layer.borderColor = [UIColor colorWithWhite:0.45f alpha:1.0f].CGColor;
        _playPauseBtn.layer.borderWidth = 1.0f;
        _playPauseBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18.0f];
        [_playPauseBtn setImage:[RNTheme playImage] forState:UIControlStateNormal];
        [_playPauseBtn addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_playPauseBtn];

        // Title label
        CGFloat contentLeft = 60.0f;
        CGFloat contentWidth = frame.size.width - contentLeft - 15.0f;
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(contentLeft, 8, contentWidth, 18)];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.8f];
        _titleLabel.shadowOffset = CGSizeMake(0, -1);
        _titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
        _titleLabel.text = @"Audio Příloha / Podcast";
        [self addSubview:_titleLabel];

        // Scrubber slider
        _scrubber = [[UISlider alloc] initWithFrame:CGRectMake(contentLeft, 26, contentWidth, 22)];
        _scrubber.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _scrubber.minimumValue = 0.0f;
        _scrubber.maximumValue = 1.0f;
        _scrubber.value = 0.0f;
        [_scrubber addTarget:self action:@selector(scrubberTouchDown) forControlEvents:UIControlEventTouchDown];
        [_scrubber addTarget:self action:@selector(scrubberValueChanged) forControlEvents:UIControlEventValueChanged];
        [_scrubber addTarget:self action:@selector(scrubberTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self addSubview:_scrubber];

        // Time labels
        _elapsedLabel = [[UILabel alloc] initWithFrame:CGRectMake(contentLeft, 48, 60, 14)];
        _elapsedLabel.backgroundColor = [UIColor clearColor];
        _elapsedLabel.font = [UIFont systemFontOfSize:11.0f];
        _elapsedLabel.textColor = [UIColor colorWithWhite:0.75f alpha:1.0f];
        _elapsedLabel.text = @"0:00";
        [self addSubview:_elapsedLabel];

        _durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(frame.size.width - 75, 48, 60, 14)];
        _durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _durationLabel.backgroundColor = [UIColor clearColor];
        _durationLabel.font = [UIFont systemFontOfSize:11.0f];
        _durationLabel.textColor = [UIColor colorWithWhite:0.75f alpha:1.0f];
        _durationLabel.textAlignment = UITextAlignmentRight;
        _durationLabel.text = @"--:--";
        [self addSubview:_durationLabel];

        [self configureAudioSession];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _gradientLayer.frame = self.bounds;
}

- (void)configureAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
}

- (void)loadAudioURLString:(NSString *)urlString title:(NSString *)title
{
    [self stop];

    _audioURLString = [urlString copy];
    _trackTitle = [title copy];
    _titleLabel.text = title.length ? title : @"Přehrávání audia";
    _elapsedLabel.text = @"0:00";
    _durationLabel.text = @"--:--";
    _scrubber.value = 0.0f;
    _durationSeconds = 0;

    if (!urlString.length) return;

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    _player = [AVPlayer playerWithPlayerItem:item];

    __weak typeof(self) weakSelf = self;
    _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2)
                                                          queue:dispatch_get_main_queue()
                                                     usingBlock:^(CMTime time) {
        [weakSelf updatePlaybackProgress:time];
    }];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
}

- (void)updatePlaybackProgress:(CMTime)time
{
    if (_isScrubbing) return;

    Float64 currentSec = CMTimeGetSeconds(time);
    AVPlayerItem *currentItem = _player.currentItem;
    if (currentItem && CMTimeCompare(currentItem.duration, kCMTimeZero) > 0) {
        Float64 dur = CMTimeGetSeconds(currentItem.duration);
        if (isfinite(dur) && dur > 0) {
            _durationSeconds = dur;
            _scrubber.value = (float)(currentSec / dur);
            _durationLabel.text = [self formatTimeString:dur];
        }
    }

    _elapsedLabel.text = [self formatTimeString:currentSec];
}

- (NSString *)formatTimeString:(Float64)totalSec
{
    if (!isfinite(totalSec) || totalSec < 0) return @"--:--";
    int sec = (int)totalSec;
    int m = sec / 60;
    int s = sec % 60;
    int h = m / 60;
    if (h > 0) {
        m = m % 60;
        return [NSString stringWithFormat:@"%d:%02d:%02d", h, m, s];
    }
    return [NSString stringWithFormat:@"%d:%02d", m, s];
}

- (void)playerItemDidReachEnd:(NSNotification *)note
{
    [_player seekToTime:kCMTimeZero];
    _scrubber.value = 0.0f;
    _elapsedLabel.text = @"0:00";
    [_playPauseBtn setImage:[RNTheme playImage] forState:UIControlStateNormal];
    _isPlaying = NO;
    if ([self.delegate respondsToSelector:@selector(audioPlayerView:didChangePlaybackState:)]) {
        [self.delegate audioPlayerView:self didChangePlaybackState:NO];
    }
}

- (void)togglePlayPause
{
    if (_isPlaying) {
        [self pause];
    } else {
        [self play];
    }
}

- (void)play
{
    if (!_player) return;
    [self configureAudioSession];
    [_player play];
    [_playPauseBtn setImage:[RNTheme pauseImage] forState:UIControlStateNormal];
    _isPlaying = YES;
    if ([self.delegate respondsToSelector:@selector(audioPlayerView:didChangePlaybackState:)]) {
        [self.delegate audioPlayerView:self didChangePlaybackState:YES];
    }
}

- (void)pause
{
    if (!_player) return;
    [_player pause];
    [_playPauseBtn setImage:[RNTheme playImage] forState:UIControlStateNormal];
    _isPlaying = NO;
    if ([self.delegate respondsToSelector:@selector(audioPlayerView:didChangePlaybackState:)]) {
        [self.delegate audioPlayerView:self didChangePlaybackState:NO];
    }
}

- (void)stop
{
    if (_timeObserver && _player) {
        [_player removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    if (_player) {
        [_player pause];
        _player = nil;
    }
    [_playPauseBtn setImage:[RNTheme playImage] forState:UIControlStateNormal];
    _isPlaying = NO;
}

#pragma mark - Scrubber

- (void)scrubberTouchDown
{
    _isScrubbing = YES;
}

- (void)scrubberValueChanged
{
    if (_durationSeconds > 0) {
        Float64 targetSec = _scrubber.value * _durationSeconds;
        _elapsedLabel.text = [self formatTimeString:targetSec];
    }
}

- (void)scrubberTouchUp
{
    _isScrubbing = NO;
    if (_player && _durationSeconds > 0) {
        Float64 targetSec = _scrubber.value * _durationSeconds;
        CMTime targetTime = CMTimeMakeWithSeconds(targetSec, 1);
        [_player seekToTime:targetTime];
    }
}

- (void)dealloc
{
    [self stop];
}

@end
