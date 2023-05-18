//
//  KYVedioPlayer.m
//  KYVedioPlayer
//
//  Created by kingly on 16/9/9.
//  Copyright © 2016年 https://github.com/kingly09/KYVedioPlayer kingly  inc . All rights reserved.
//

#import "KYVedioPlayer.h"

#define kHalfWidth self.frame.size.width * 0.5
#define kHalfHeight self.frame.size.height * 0.5

#define MYBUNDLE_NAME @"KYVedioPlayer.bundle"

#define MYBUNDLE_PATH [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:MYBUNDLE_NAME]

#define MYBUNDLE [NSBundle bundleWithPath: MYBUNDLE_PATH]


static void *PlayViewCMTimeValue = &PlayViewCMTimeValue;

static void *PlayViewStatusObservationContext = &PlayViewStatusObservationContext;

@interface KYVedioPlayer () <UIGestureRecognizerDelegate>
@property (nonatomic,assign)CGPoint firstPoint;
@property (nonatomic,assign)CGPoint secondPoint;
@property (nonatomic, strong)NSDateFormatter *dateFormatter;
//监听播放起状态的监听者
@property (nonatomic ,strong) id playbackTimeObserver;

//视频进度条的单击事件
@property (nonatomic, strong) UITapGestureRecognizer *tap;
@property (nonatomic, assign) CGPoint originalPoint;
@property (nonatomic, assign) BOOL isDragingSlider;//是否点击了按钮的响应事件
/**
 *  显示播放时间的UILabel
 */
@property (nonatomic,strong) UILabel        *leftTimeLabel;
@property (nonatomic,strong) UILabel        *rightTimeLabel;
/**
 * 亮度的进度条
 */
@property (nonatomic,strong) UISlider       *lightSlider;
@property (nonatomic,strong) UISlider       *progressSlider;
@property (nonatomic,strong) UISlider       *volumeSlider;
//系统滑条
@property (nonatomic,strong) UISlider       *systemSlider;
@property (nonatomic,strong) UITapGestureRecognizer* singleTap;  //单击

@property (nonatomic,strong) UIProgressView *loadingProgress;    //loading

@end

@implementation KYVedioPlayer

@synthesize isPlaying;

- (instancetype)init{
    self = [super init];
    if (self){
        [self initPlayer];
    }
    return self;
}

/**
 *  storyboard、xib的初始化方法
 */
- (void)awakeFromNib
{
    [super awakeFromNib];
    [self initPlayer];
}
/**
 *  initWithFrame的初始化方法
 */
-(instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self initPlayer];
    }
    return self;
}
/**
 *  初始化KYVedioPlayer的控件，添加手势，添加通知，添加kvo等
 */
-(void)initPlayer{

    self.seekTime = 0.00;
    self.isAutoDismissBottomView = YES;  //自动隐藏
    self.backgroundColor = UIColor.blackColor;

    //添加loading视图
    self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [self addSubview:self.loadingView];

    //添加顶部视图
    self.topView = [[UIView alloc]init];
    [self addSubview:self.topView];
    
    self.topLayer = [CAGradientLayer layer];
    self.topLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.width,[self screenFit:40]);
    self.topLayer.startPoint = CGPointMake(0.5, 0);
    self.topLayer.endPoint = CGPointMake(0.5, 1);
    self.topLayer.colors = @[(__bridge id)[self hexColor:0x000000].CGColor, (__bridge id)[self hexColor:0x000000 alpha:0].CGColor];
    self.topLayer.locations = @[@(0), @(1.0f)];
    [self.topView.layer addSublayer:self.topLayer];

    //添加底部视图
    self.bottomView = [[UIView alloc]init];
    [self addSubview:self.bottomView];
    self.bottomLayer = [CAGradientLayer layer];
    self.bottomLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.width,[self screenFit:40]);
    self.bottomLayer.startPoint = CGPointMake(0.5, 1);
    self.bottomLayer.endPoint = CGPointMake(0.5, 0);
    self.bottomLayer.colors = @[(__bridge id)[self hexColor:0x000000].CGColor, (__bridge id)[self hexColor:0x000000 alpha:0].CGColor];
    self.bottomLayer.locations = @[@(0), @(1.0f)];
    [self.bottomView.layer addSublayer:self.bottomLayer];

    //添加暂停和开启按钮
    self.playOrPauseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playOrPauseBtn.showsTouchWhenHighlighted = YES;
    [self.playOrPauseBtn addTarget:self action:@selector(PlayOrPause:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.playOrPauseBtn setImage:[UIImage imageNamed:@"video_pause_icon" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [self.playOrPauseBtn setImage:[UIImage imageNamed:@"video_play_icon" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateSelected];

    [self.bottomView addSubview:self.playOrPauseBtn];
    
    self.nextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.nextBtn.showsTouchWhenHighlighted = YES;
    [self.nextBtn addTarget:self action:@selector(nextClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.nextBtn setImage:[UIImage imageNamed:@"video_tap_next" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    self.nextBtn.hidden = YES;
    [self.bottomView addSubview:self.nextBtn];
    

    //创建亮度的进度条
    self.lightSlider = [[UISlider alloc]initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.lightSlider.hidden = YES;
    self.lightSlider.minimumValue = 0;
    self.lightSlider.maximumValue = 1;
    //进度条的值等于当前系统亮度的值,范围都是0~1
    self.lightSlider.value = [UIScreen mainScreen].brightness;
    [self addSubview:self.lightSlider];

    MPVolumeView *volumeView = [[MPVolumeView alloc]init];
    [self addSubview:volumeView];
    volumeView.frame = CGRectMake(-1000, -100, 100, 100);
    [volumeView sizeToFit];

    self.systemSlider = [[UISlider alloc]init];
    self.systemSlider.backgroundColor = [UIColor clearColor];
    for (UIControl *view in volumeView.subviews) {
        if ([view.superclass isSubclassOfClass:[UISlider class]]) {
            self.systemSlider = (UISlider *)view;
        }
    }
    self.systemSlider.autoresizesSubviews = NO;
    self.systemSlider.autoresizingMask = UIViewAutoresizingNone;
    [self addSubview:self.systemSlider];

    //设置声音滑块
    self.volumeSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.volumeSlider.tag = 1000;
    self.volumeSlider.hidden = YES;
    self.volumeSlider.minimumValue = self.systemSlider.minimumValue;
    self.volumeSlider.maximumValue = self.systemSlider.maximumValue;
    self.volumeSlider.value = self.systemSlider.value;
    [self.volumeSlider addTarget:self action:@selector(updateSystemVolumeValue:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.volumeSlider];

    //进度条
    self.progressSlider = [[UISlider alloc]init];
    self.progressSlider.minimumValue = 0.0;
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"ic_dot" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] ?: [UIImage imageNamed:@"ic_dot" inBundle:MYBUNDLE compatibleWithTraitCollection:nil]  forState:UIControlStateNormal];
    self.progressSlider.maximumTrackTintColor = [UIColor clearColor];
    self.progressSlider.value = 0.0;//指定初始值
    //进度条的拖拽事件
    [self.progressSlider addTarget:self action:@selector(stratDragSlide:)  forControlEvents:UIControlEventValueChanged];
    //进度条的点击事件
    [self.progressSlider addTarget:self action:@selector(updateProgress:) forControlEvents:UIControlEventTouchUpInside];
    //给进度条添加单击手势
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionTapGesture:)];
    self.tap.delegate = self;
    [self.progressSlider addGestureRecognizer:self.tap];
    self.progressSlider.backgroundColor = [UIColor clearColor];
    [self.bottomView addSubview:self.progressSlider];

    //loadingProgress
    self.loadingProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.loadingProgress.progressTintColor = [UIColor clearColor];
    self.loadingProgress.trackTintColor    = [UIColor lightGrayColor];
    [self.bottomView addSubview:self.loadingProgress];
    [self.loadingProgress setProgress:0.0 animated:NO];

    //全屏按钮
    self.fullScreenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fullScreenBtn.showsTouchWhenHighlighted = YES;
    [self.fullScreenBtn addTarget:self action:@selector(fullScreenAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.fullScreenBtn setImage:[UIImage imageNamed:@"video_play_full" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [self.bottomView addSubview:self.fullScreenBtn];

    //左边时间
    self.leftTimeLabel = [[UILabel alloc]init];
    self.leftTimeLabel.textAlignment = NSTextAlignmentLeft;
    self.leftTimeLabel.textColor = [UIColor whiteColor];
    self.leftTimeLabel.backgroundColor = [UIColor clearColor];
    self.leftTimeLabel.font = [UIFont systemFontOfSize:10];
    [self.bottomView addSubview:self.leftTimeLabel];

    //右边时间
    self.rightTimeLabel = [[UILabel alloc]init];
    self.rightTimeLabel.textAlignment = NSTextAlignmentRight;
    self.rightTimeLabel.textColor = [UIColor whiteColor];
    self.rightTimeLabel.backgroundColor = [UIColor clearColor];
    self.rightTimeLabel.font = [UIFont systemFontOfSize:10];
    [self.bottomView addSubview:self.rightTimeLabel];


    //关闭按钮
    _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeBtn.showsTouchWhenHighlighted = YES;
    [_closeBtn addTarget:self action:@selector(colseTheVideo:) forControlEvents:UIControlEventTouchUpInside];
    [_closeBtn setImage:[UIImage imageNamed:@"other_white_back" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [self.topView addSubview:_closeBtn];
    
    //分享按钮
    _shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _shareBtn.showsTouchWhenHighlighted = YES;
    [_shareBtn setImage:[UIImage imageNamed:@"video_share" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    
    [_shareBtn addTarget:self action:@selector(onClickShareBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.topView addSubview:_shareBtn];
    
    _subtitleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _subtitleBtn.showsTouchWhenHighlighted = YES;
    [_subtitleBtn setImage:[UIImage imageNamed:@"video_play_subtitle" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [_subtitleBtn addTarget:self action:@selector(onSubtitleClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.topView addSubview:_subtitleBtn];
    
    _collectionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _collectionBtn.showsTouchWhenHighlighted = YES;
    [_collectionBtn setImage:[UIImage imageNamed:@"video_white_collection" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [_collectionBtn setImage:[UIImage imageNamed:@"video_collection_show" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateSelected];
    [_collectionBtn addTarget:self action:@selector(onCollectionClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.topView addSubview:_collectionBtn];

    //标题
    self.titleLabel = [[UILabel alloc]init];
    self.titleLabel.textAlignment = NSTextAlignmentLeft;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.hidden = YES;
    [self.topView addSubview:self.titleLabel];
    
    self.showView = [[UIView alloc]init];
    self.showView.alpha = 0;
    [self addSubview:self.showView];
    
    _lockBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _lockBtn.showsTouchWhenHighlighted = YES;
    [_lockBtn setImage:[UIImage imageNamed:@"video_show_unlock" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [_lockBtn setImage:[UIImage imageNamed:@"video_show_lock" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateSelected];
    [_lockBtn addTarget:self action:@selector(onUnlockClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.showView addSubview:_lockBtn];
    
    _adBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _adBtn.showsTouchWhenHighlighted = YES;
    [_adBtn setTitle:@"AD" forState:UIControlStateNormal];
    [_adBtn addTarget:self action:@selector(adClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.showView addSubview:_adBtn];
    
    _showPlayBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _showPlayBtn.showsTouchWhenHighlighted = YES;
    [_showPlayBtn setImage:[UIImage imageNamed:@"video_show_plause" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [_showPlayBtn setImage:[UIImage imageNamed:@"video_play_pause" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateSelected];
    [_showPlayBtn addTarget:self action:@selector(PlayOrPause:) forControlEvents:UIControlEventTouchUpInside];
    [self.showView addSubview:_showPlayBtn];
    
    _advanceBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _advanceBtn.showsTouchWhenHighlighted = YES;
    [_advanceBtn setImage:[UIImage imageNamed:@"video_play_advance" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [_advanceBtn addTarget:self action:@selector(advanceClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.showView addSubview:_advanceBtn];
    
    _retreatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _retreatBtn.showsTouchWhenHighlighted = YES;
    [_retreatBtn setImage:[UIImage imageNamed:@"video_play_retreat" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
    [_retreatBtn addTarget:self action:@selector(retreatClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.showView addSubview:_retreatBtn];
    
    self.playShowView = [[UIView alloc]init];
    self.playShowView.hidden = YES;
    [self addSubview:self.playShowView];
    
    self.showImageView = [[UIImageView alloc]init];
    self.showImageView.image = [UIImage imageNamed:@"video_advance_icon" inBundle:MYBUNDLE compatibleWithTraitCollection:nil];
    [self.playShowView addSubview:self.showImageView];
    
    self.showTimeLabel = [[UILabel alloc]init];
    self.showTimeLabel.textColor = [UIColor whiteColor];
    self.showTimeLabel.backgroundColor = [UIColor clearColor];
    self.showTimeLabel.font = [UIFont boldSystemFontOfSize:14];
    self.showTimeLabel.textAlignment = NSTextAlignmentCenter;
    self.showTimeLabel.text = @"00:00/00:00";
    [self.playShowView addSubview:self.showTimeLabel];

    [self makeConstraints];


    self.singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    self.singleTap.numberOfTapsRequired = 1; // 单击
    self.singleTap.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:self.singleTap];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appwillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (CGFloat)screenScale {
    
    CGFloat width = [UIScreen mainScreen].bounds.size.width < [UIScreen mainScreen].bounds.size.height ? [UIScreen mainScreen].bounds.size.width : [UIScreen mainScreen].bounds.size.height;
    CGFloat height = [UIScreen mainScreen].bounds.size.height > [UIScreen mainScreen].bounds.size.width ? [UIScreen mainScreen].bounds.size.height : [UIScreen mainScreen].bounds.size.width;
    CGFloat widthScale = width/375.f;
    CGFloat heightScale = height/667.f;
    CGFloat scale = ((widthScale <= heightScale) ? widthScale : heightScale);
    return scale < 1 ? 1 : scale;
}

- (CGFloat)screenFit:(CGFloat)num {
    return [self screenScale]*num;
}

- (UIColor *)hexColor:(int)rgbValue {
    return [self hexColor:rgbValue alpha:1];
}

- (UIColor *)hexColor:(int)rgbValue alpha:(CGFloat)alpha {
    return [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0
                           green:((float)((rgbValue & 0xFF00) >> 8))/255.0
                            blue:((float)(rgbValue & 0xFF))/255.0 alpha:alpha];
}

/**
 * 设置 autoLayout
 **/
-(void)makeConstraints{

    [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
    }];
    [self.loadingView startAnimating];

    [self.playOrPauseBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(0);
        make.height.mas_equalTo(40);
        make.bottom.equalTo(self.bottomView).with.offset(0);
        make.width.mas_equalTo(40);

    }];

    [self.topView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(0);
        make.right.equalTo(self).with.offset(0);
        make.height.mas_equalTo(40);
        make.top.equalTo(self).with.offset(0);
    }];

    [self.bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(0);
        make.right.equalTo(self).with.offset(0);
        make.height.mas_equalTo(40);
        make.bottom.equalTo(self).with.offset(0);

    }];
    //让子视图自动适应父视图的方法
    [self setAutoresizesSubviews:NO];

    [self.progressSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.leftTimeLabel.mas_right);
        make.right.equalTo(self.rightTimeLabel.mas_left);
        make.centerY.equalTo(self.leftTimeLabel);
    }];

    [self.loadingProgress mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.progressSlider);
        make.right.equalTo(self.progressSlider);
        make.center.equalTo(self.progressSlider);
        make.height.mas_equalTo(1.5);
    }];
    [self.bottomView sendSubviewToBack:self.loadingProgress];

    [self.fullScreenBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomView).with.offset(0);
        make.height.mas_equalTo(40);
        make.bottom.equalTo(self.bottomView).with.offset(0);
        make.width.mas_equalTo(40);

    }];

    [self.leftTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(40);
        make.centerY.equalTo(self.playOrPauseBtn);
        make.width.mas_offset(35);
    }];

    [self.rightTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomView).with.offset(-40);
        make.centerY.equalTo(self.playOrPauseBtn);
        make.width.mas_offset(35);
    }];

    [self.closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.topView).with.offset(10);
        make.bottom.top.equalTo(self.topView);
        make.width.mas_equalTo(30);

    }];
    
    [self.collectionBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.topView).with.offset(-10);
        make.height.mas_equalTo(30);
        make.centerY.equalTo(self.topView);
        make.width.mas_equalTo(30);

    }];
    
    [self.subtitleBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.collectionBtn.mas_left).with.offset(-8);
        make.height.mas_equalTo(30);
        make.centerY.equalTo(self.topView);
        make.width.mas_equalTo(30);

    }];
    
    [self.shareBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.subtitleBtn.mas_left).with.offset(-8);
        make.height.mas_equalTo(30);
        make.centerY.equalTo(self.topView);
        make.width.mas_equalTo(30);

    }];

    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.closeBtn.mas_right).with.offset(10);
        make.right.equalTo(self.shareBtn.mas_left).offset(-10);
        make.centerY.equalTo(self.closeBtn);

    }];
    
    [self.showView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.centerY.equalTo(self);
        make.height.mas_offset(60);
    }];
    
    [self.lockBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.showView).offset(30);
        make.centerY.equalTo(self.showView).offset(-19);
        make.height.width.mas_offset(30);
    }];
    
    [self.adBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.showView).offset(30);
        make.centerY.equalTo(self.showView).offset(19);
        make.height.width.mas_offset(30);
    }];
    
    [self.showPlayBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.showView);
        make.height.width.mas_offset(44);
    }];
    
    [self.retreatBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.showPlayBtn.mas_left).offset(-66);
        make.centerY.equalTo(self.showView);
        make.height.width.mas_offset(44);
    }];
    
    [self.advanceBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.showPlayBtn.mas_right).offset(66);
        make.centerY.equalTo(self.showView);
        make.height.width.mas_offset(44);
    }];
    
    [self.playShowView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
        make.height.mas_offset(70);
        make.width.mas_offset([self screenFit:90]);
    }];
    
    [self.showImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.playShowView);
        make.centerX.equalTo(self.playShowView);
        make.height.mas_offset(42);
    }];
    
    [self.showTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.playShowView);
        make.top.equalTo(self.showImageView.mas_bottom).offset(6);
    }];
    [self.nextBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.playOrPauseBtn);
        make.left.equalTo(self.playOrPauseBtn.mas_right).offset(6);
        make.height.width.mas_offset(40);
    }];

    [self bringSubviewToFront:self.loadingView];
    [self bringSubviewToFront:self.bottomView];
}

#pragma mark - 重置播放器 或 销毁
/**
 * 重置播放器
 */
- (void)resetKYVedioPlayer{

    self.currentItem = nil;
    self.seekTime = 0;
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 关闭定时器
    if ([self.autoDismissTimer isValid]) {
        [self.autoDismissTimer invalidate];
        self.autoDismissTimer = nil;
    }
    // 暂停
    [self.player pause];
    // 移除原来的layer
    [self.playerLayer removeFromSuperlayer];
    // 替换PlayerItem为nil
    [self.player replaceCurrentItemWithPlayerItem:nil];
    // 把player置为nil
    self.playerLayer = nil;
    self.player = nil;

}

#pragma mark - UIPanGestureRecognizer手势方法
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        if (((UITapGestureRecognizer*)gestureRecognizer).numberOfTapsRequired == 2) {
            if (self.isLockScreen == YES)
                return NO;
        }
        return YES;
    }

    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        if (self.isLockScreen) { return NO; }
        return YES;
    }
    
    return NO;
}


-(void)dealloc{

    NSLog(@"KYVedioPlayer dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    [self.player pause];

    [self.player removeTimeObserver:self.playbackTimeObserver];

    //移除观察者
    [_currentItem removeObserver:self forKeyPath:@"status"];
    [_currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [_currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [_currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];


    [self.playerLayer removeFromSuperlayer];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    self.player = nil;
    self.currentItem = nil;
    self.playOrPauseBtn = nil;
    self.playerLayer = nil;

    self.autoDismissTimer = nil;

}

#pragma mark - lazy 加载失败的label
-(UILabel *)loadFailedLabel{
    if (_loadFailedLabel==nil) {
        _loadFailedLabel = [[UILabel alloc]init];
        _loadFailedLabel.textColor = [UIColor whiteColor];
        _loadFailedLabel.textAlignment = NSTextAlignmentCenter;
        _loadFailedLabel.text = @"Video loading failed";
        _loadFailedLabel.hidden = YES;
        [self addSubview:_loadFailedLabel];

        [_loadFailedLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.width.equalTo(self);
            make.height.equalTo(@30);

        }];
    }
    return _loadFailedLabel;
}

#pragma mark  - 私有方法
/**
 * layoutSubviews
 **/
-(void)layoutSubviews{
    [super layoutSubviews];
    self.playerLayer.frame = self.bounds;
}
/**
 * 获取视频长度
 **/
- (double)duration{
    AVPlayerItem *playerItem = self.player.currentItem;
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return CMTimeGetSeconds([[playerItem asset] duration]);
    }
    else{
        return 0.f;
    }
}
/**
 * 设置进度条的颜色
 **/
-(void)setProgressColor:(UIColor *)progressColor{

    if (progressColor == nil) {

        progressColor = [UIColor redColor];
    }
    if (self.progressSlider!=nil) {
           self.progressSlider.minimumTrackTintColor = progressColor;
    }
}
/**
 * 设置当前播放的时间
 **/
- (void)setCurrentTime:(double)time{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.player seekToTime:CMTimeMakeWithSeconds(time, self.currentItem.currentTime.timescale)];

    });
}

/**
 *  重写URLString的setter方法，处理自己的逻辑，
 */
- (void)setURLString:(NSString *)URLString{
    _URLString = URLString;
    //设置player的参数
    self.currentItem = [self getPlayItemWithURLString:URLString];

    self.player = [AVPlayer playerWithPlayerItem:_currentItem];
    self.player.usesExternalPlaybackWhileExternalScreenIsActive=YES;
    //AVPlayerLayer
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = self.layer.bounds;
    //视频的默认填充模式，AVLayerVideoGravityResizeAspect
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;//AVLayerVideoGravityResize;
    [self.layer insertSublayer:_playerLayer atIndex:0];
    self.state = KYVedioPlayerStateBuffering;
    // 静音模式下播放声音
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
}
/**
 *  判断是否是网络视频 还是 本地视频
 **/
-(AVPlayerItem *)getPlayItemWithURLString:(NSString *)url{
    if ([url containsString:@"http"]) {
        AVPlayerItem *playerItem=[AVPlayerItem playerItemWithURL:[NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        return playerItem;
    }else{
        AVAsset *movieAsset  = [[AVURLAsset alloc]initWithURL:[NSURL fileURLWithPath:url] options:nil];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
        return playerItem;
    }

}

/**
 *  设置播放的状态
 *  @param state KYVedioPlayerState
 */
- (void)setState:(KYVedioPlayerState )state
{
    _state = state;
    // 控制菊花显示、隐藏
    if (state == KYVedioPlayerStateBuffering) {
        [self.loadingView startAnimating];
    }else if(state == KYVedioPlayerStatePlaying){
        [self.loadingView stopAnimating];
    }else if(state == KYVedioPlayerStatusReadyToPlay){
        [self.loadingView stopAnimating];
    }
    else{
        [self.loadingView stopAnimating];
    }
}
/**
 *  重写AVPlayerItem方法，处理自己的逻辑，
 */
-(void)setCurrentItem:(AVPlayerItem *)currentItem{
    if (_currentItem==currentItem) {
        return;
    }
    if (_currentItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_currentItem];
        [_currentItem removeObserver:self forKeyPath:@"status"];
        [_currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [_currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [_currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        _currentItem = nil;
    }
    _currentItem = currentItem;
    if (_currentItem) {
        [_currentItem addObserver:self
                       forKeyPath:@"status"
                          options:NSKeyValueObservingOptionNew
                          context:PlayViewStatusObservationContext];

        [_currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        // 缓冲区空了，需要等待数据
        [_currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options: NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        // 缓冲区有足够数据可以播放了
        [_currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options: NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];


        [self.player replaceCurrentItemWithPlayerItem:_currentItem];
        // 添加视频播放结束通知
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:_currentItem];
    }
}

/**
 *  通过颜色来生成一个纯色图片
 */
- (UIImage *)buttonImageFromColor:(UIColor *)color{

    CGRect rect = self.bounds;
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext(); return img;
}

#pragma mark - 播放 或者 暂停
- (void)PlayOrPause:(UIButton *)sender{
//    if (self.player.rate != 1.f) {
    if (self.playOrPauseBtn.selected) {
        if ([self currentTime] == [self duration])
            [self setCurrentTime:0.f];
        sender.selected = NO;
        [self.player play];
    } else {
        sender.selected = YES;
        [self.player pause];
    }
    self.showPlayBtn.selected = sender.selected;
    self.playOrPauseBtn.selected = sender.selected;
    if ([self.delegate respondsToSelector:@selector(kyvedioPlayer:clickedPlayOrPauseButton:)]) {
        [self.delegate kyvedioPlayer:self clickedPlayOrPauseButton:sender];
    }
}

-(void)nextClick:(UIButton *)sender{
    if ([self.delegate respondsToSelector:@selector(kyvedioPlayer:onNextBtn:)]) {
        [self.delegate kyvedioPlayer:self onNextBtn:sender];
    }
}

//锁屏
- (void)onUnlockClick:(UIButton*)sender {
    sender.selected = !sender.selected;
    self.isLockScreen = sender.selected;
    self.topView.hidden    = self.isLockScreen;
    self.bottomView.hidden = self.isLockScreen;
    self.adBtn.hidden = self.isLockScreen;
    self.retreatBtn.hidden = self.isLockScreen;
    self.advanceBtn.hidden = self.isLockScreen;
    self.showPlayBtn.hidden = self.isLockScreen;
    if (self.delegate && [self.delegate respondsToSelector:@selector(kyvedioPlayer:lockBtn:)]) {
        [self.delegate kyvedioPlayer:self lockBtn:sender];
    }
}

//去除广告
-(void)adClick:(UIButton*)sender{
    if (self.delegate && [self.delegate respondsToSelector:@selector(kyvedioPlayer:advertisementBtn:)]) {
        [self.delegate kyvedioPlayer:self advertisementBtn:sender];
    }
}

//快进
-(void)advanceClick:(UIButton*)sender{
    
    [self seekToTimeToPlay:CMTimeGetSeconds(self.player.currentTime)+10];
}

//快退
-(void)retreatClick:(UIButton*)sender{
    
    [self seekToTimeToPlay:CMTimeGetSeconds(self.player.currentTime)-10];
}

#pragma mark - 更新系统音量
- (void)updateSystemVolumeValue:(UISlider *)slider{
    self.systemSlider.value = slider.value;
}

#pragma mark - 进度条的相关事件 progressSlider
/**
 *   开始点击sidle
 **/
- (void)stratDragSlide:(UISlider *)slider{
    self.isDragingSlider = YES;
    self.isDragingSlider = NO;

}
/**
 *   更新播放进度
 **/
- (void)updateProgress:(UISlider *)slider{
    self.isDragingSlider = NO;
    [self.player seekToTime:CMTimeMakeWithSeconds(slider.value, _currentItem.currentTime.timescale)];

}
/**
 *  视频进度条的点击事件
 **/
- (void)actionTapGesture:(UITapGestureRecognizer *)sender {
    CGPoint touchLocation = [sender locationInView:self.progressSlider];
    CGFloat value = (self.progressSlider.maximumValue - self.progressSlider.minimumValue) * (touchLocation.x/self.progressSlider.frame.size.width);
    [self.progressSlider setValue:value animated:YES];

    [self.player seekToTime:CMTimeMakeWithSeconds(self.progressSlider.value, self.currentItem.currentTime.timescale)];
    if (self.player.rate != 1.f) {
        if ([self currentTime] == [self duration])
            [self setCurrentTime:0.f];
        self.showPlayBtn.selected = NO;
        self.playOrPauseBtn.selected = NO;
        [self.player play];
    }
}

#pragma mark  -  点击全屏按钮 和 点击缩小按钮
/**
 *   点击全屏按钮 和 点击缩小按钮
 **/
-(void)fullScreenAction:(UIButton *)sender{
    if (sender.isSelected) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(kyvedioPlayer:onEpisodeBtn:)]) {
          [self.delegate kyvedioPlayer:self onEpisodeBtn:sender];
        }
        return;
    }
    sender.selected = !sender.selected;
    
    if (sender.isSelected) {
        [self ht_reloadPlayerWith:YES];
    }

    if (self.delegate&&[self.delegate respondsToSelector:@selector(kyvedioPlayer:clickedFullScreenButton:)]) {
        [self.delegate kyvedioPlayer:self clickedFullScreenButton:sender];
    }
}

#pragma mark - 点击关闭按钮
/**
 *   点击关闭按钮
 **/
-(void)colseTheVideo:(UIButton *)sender{
    if (self.delegate && [self.delegate respondsToSelector:@selector(kyvedioPlayer:clickedCloseButton:)]) {
        [self.delegate kyvedioPlayer:self clickedCloseButton:sender];
    }
    if (self.isFullscreen == YES) {
        [self ht_reloadPlayerWith:NO];
    }
}

- (void)ht_reloadPlayerWith:(BOOL)isFullscreen {
    if (isFullscreen) {
        //全屏显示
//        self.showView.alpha = 1.0;
        self.bottomView.alpha = 0.0;
        self.closeBtn.alpha = 0.0;
        self.topView.alpha = 0.0;
        self.showView.alpha = 0.0;
        self.nextBtn.hidden = NO;
        self.titleLabel.hidden = NO;
        [self.fullScreenBtn setImage:[UIImage imageNamed:@""] forState:UIControlStateNormal];
        self.fullScreenBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [self.fullScreenBtn setTitle:@"Episode" forState:UIControlStateNormal];
        [self.topView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self).with.offset(0);
            make.right.equalTo(self).with.offset(0);
            make.height.mas_equalTo(48);
            make.top.equalTo(self).with.offset(0);
        }];
        
        [self.closeBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.topView).with.offset(50);
            make.top.bottom.equalTo(self.topView);
            make.width.mas_equalTo(30);

        }];
        
        [self.collectionBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.topView).with.offset(-75);
            make.height.width.mas_equalTo(30);
            make.centerY.equalTo(self.topView);
        }];
        
        if (@available(iOS 16.0, *)) {
            self.topLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.height,[self screenFit:60]);
            self.bottomLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.height,[self screenFit:80]);
        } else {
            self.topLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.width,[self screenFit:60]);
            self.bottomLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.width,[self screenFit:80]);
        }
        
        [self.bottomView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self).with.offset(0);
            make.right.equalTo(self).with.offset(0);
            make.height.mas_equalTo(80);
            make.bottom.equalTo(self).with.offset(0);

        }];
        
        [self.playOrPauseBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bottomView).with.offset(30);
            make.height.mas_equalTo(40);
            make.bottom.equalTo(self.bottomView).with.offset(-16);
            make.width.mas_equalTo(40);
        }];
        
        [self.leftTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bottomView).with.offset(30);
            make.bottom.equalTo(self.playOrPauseBtn.mas_top).with.offset(-12);
            make.width.mas_equalTo(35);
        }];
        
        [self.rightTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.bottomView).with.offset(-30);
            make.bottom.equalTo(self.playOrPauseBtn.mas_top).with.offset(-12);
            make.width.mas_equalTo(35);
        }];
        
        [self.fullScreenBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.bottomView).with.offset(-30);
            make.height.mas_equalTo(40);
            make.width.mas_equalTo([self screenFit:60]);
            make.centerY.equalTo(self.playOrPauseBtn);

        }];
    } else {
        self.showView.alpha = 0.0;
        [self.fullScreenBtn setImage:[UIImage imageNamed:@"video_play_full" inBundle:MYBUNDLE compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
        [self.fullScreenBtn setTitle:@"" forState:UIControlStateNormal];
        self.nextBtn.hidden = YES;
        self.titleLabel.hidden = YES;
//        self.fullScreenBtn.hidden = NO;
        [self.topView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.top.right.equalTo(self);
            make.height.mas_equalTo(40);
        }];
        
        [self.closeBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.topView).with.offset(10);
            make.width.mas_equalTo(30);
            make.top.bottom.equalTo(self.topView);
        }];

        [self.collectionBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.topView).with.offset(-10);
            make.width.height.mas_equalTo(30);
            make.centerY.equalTo(self.topView);
        }];
        
        if (@available(iOS 16.0, *)) {
            self.topLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.height,[self screenFit:40]);
            self.bottomLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.height,[self screenFit:40]);
        } else {
            self.topLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.width,[self screenFit:40]);
            self.bottomLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.width,[self screenFit:40]);
        }
        
        [self.bottomView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self).with.offset(0);
            make.right.equalTo(self).with.offset(0);
            make.height.mas_equalTo(40);
            make.bottom.equalTo(self).with.offset(0);

        }];
        
        [self.playOrPauseBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bottomView).with.offset(0);
            make.height.mas_equalTo(40);
            make.bottom.equalTo(self.bottomView).with.offset(0);
            make.width.mas_equalTo(40);

        }];
        
        [self.leftTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.bottomView).with.offset(40);
            make.centerY.equalTo(self.playOrPauseBtn);
            make.width.mas_offset(35);
        }];

        [self.rightTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.bottomView).with.offset(-40);
            make.centerY.equalTo(self.playOrPauseBtn);
            make.width.mas_offset(35);
        }];
        [self.fullScreenBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.bottomView).with.offset(0);
            make.height.mas_equalTo(40);
            make.bottom.equalTo(self.bottomView).with.offset(0);
            make.width.mas_equalTo(40);

        }];
    }
}

#pragma mark - 点击分享按钮
/**
  点击分享按钮

 */
-(void)onClickShareBtn:(UIButton *)sender{
    if (self.delegate && [self.delegate respondsToSelector:@selector(kyvedioPlayer:isFullscreen:onClickShareBtn:)]) {
      [self.delegate kyvedioPlayer:self isFullscreen:self.isFullscreen onClickShareBtn:sender];
    }
}

-(void)onSubtitleClick:(UIButton *)sender{
    if (self.delegate && [self.delegate respondsToSelector:@selector(kyvedioPlayer:isFullscreen:onClickSubtitleBtn:)]) {
      [self.delegate kyvedioPlayer:self isFullscreen:self.isFullscreen onClickSubtitleBtn:sender];
    }
}

-(void)onCollectionClick:(UIButton *)sender{
    if (self.delegate && [self.delegate respondsToSelector:@selector(kyvedioPlayer:isFullscreen:onClickCollectionBtn:)]) {
      [self.delegate kyvedioPlayer:self isFullscreen:self.isFullscreen onClickCollectionBtn:sender];
    }
}

#pragma mark - 单击播放器 手势方法
- (void)handleSingleTap:(UITapGestureRecognizer *)sender{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(autoDismissBottomView:) object:nil];
    if (self.delegate&&[self.delegate respondsToSelector:@selector(kyvedioPlayer:singleTaped:)]) {
        [self.delegate kyvedioPlayer:self singleTaped:sender];
    }
    if (_isAutoDismissBottomView == YES) {  //每5秒 自动隐藏底部视图
        if ([self.autoDismissTimer isValid]) {
            [self.autoDismissTimer invalidate];
            self.autoDismissTimer = nil;
        }
        self.autoDismissTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(autoDismissBottomView:) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.autoDismissTimer forMode:NSDefaultRunLoopMode];
    }

    [UIView animateWithDuration:0.5 animations:^{
        if (self.bottomView.alpha == 0.0) {
            self.bottomView.alpha = 1.0;
            self.closeBtn.alpha = 1.0;
            self.topView.alpha = 1.0;
            if (self.isFullscreen) {
                self.showView.alpha = 1.0;
            }
        }else{
            self.bottomView.alpha = 0.0;
            self.closeBtn.alpha = 0.0;
            self.topView.alpha = 0.0;
            self.showView.alpha = 0.0;
        }
    } completion:^(BOOL finish){

    }];
}

/**
 * 隐藏 底部视图
 **/
-(void)autoDismissBottomView:(NSTimer *)timer{

//    if (self.player.rate==.0f&&self.currentTime != self.duration) {//暂停状态
//
//    }else if(self.player.rate==1.0f){
        if (self.bottomView.alpha==1.0) {
            [UIView animateWithDuration:0.5 animations:^{
                self.bottomView.alpha = 0.0;
                self.closeBtn.alpha = 0.0;
                self.topView.alpha = 0.0;
                self.showView.alpha = 0.0;

            } completion:^(BOOL finish){

            }];
        }
//    }
}
#pragma mark - 双击播放器 手势方法
- (void)handleDoubleTap:(UITapGestureRecognizer *)doubleTap{
    if (self.delegate&&[self.delegate respondsToSelector:@selector(kyvedioPlayer:doubleTaped:)]) {
        [self.delegate kyvedioPlayer:self doubleTaped:doubleTap];
    }
    if (self.player.rate != 1.f) {
        if ([self currentTime] == self.duration)
            [self setCurrentTime:0.f];
        [self.player play];
        self.showPlayBtn.selected = NO;
        self.playOrPauseBtn.selected = NO;
    } else {
        [self.player pause];
        self.showPlayBtn.selected = YES;
        self.playOrPauseBtn.selected = YES;
    }
    [UIView animateWithDuration:0.5 animations:^{
        self.bottomView.alpha = 1.0;
        self.topView.alpha = 1.0;
        self.closeBtn.alpha = 1.0;
        if (self.isFullscreen) {
            self.showView.alpha = 1.0;
        }
    } completion:^(BOOL finish){

    }];
}

#pragma mark - NSNotification 消息通知接收
/**
 *  接收播放完成的通知
 **/
- (void)moviePlayDidEnd:(NSNotification *)notification {
    self.state            = KYVedioPlayerStateFinished;
    if (self.delegate&&[self.delegate respondsToSelector:@selector(kyplayerFinishedPlay:)]) {
        [self.delegate kyplayerFinishedPlay:self];
    }
    
    [self.player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        [self.progressSlider setValue:0.0 animated:YES];
        self.showPlayBtn.selected = YES;
        self.playOrPauseBtn.selected = YES;
    }];
    [UIView animateWithDuration:0.5 animations:^{
        self.bottomView.alpha = 1.0;
        self.topView.alpha = 1.0;
    } completion:^(BOOL finish){
        
    }];
}

- (void)appwillResignActive:(NSNotification *)note
{
    NSLog(@"appwillResignActive");
}

- (void)appBecomeActive:(NSNotification *)note
{
    NSLog(@"appBecomeActive");
}
/**
 * 进入后台
 **/
- (void)appDidEnterBackground:(NSNotification*)note
{
    if (self.playOrPauseBtn.isSelected==NO) {//如果是播放中，则继续播放
        NSArray *tracks = [self.currentItem tracks];
        for (AVPlayerItemTrack *playerItemTrack in tracks) {
            if ([playerItemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicVisual]) {
                playerItemTrack.enabled = YES;
            }
        }
        self.playerLayer.player = nil;
        [self.player play];
        self.state = KYVedioPlayerStatePlaying;
    }else{
        self.state = KYVedioPlayerStateStopped;
    }
}
/**
 *  进入前台
 **/
- (void)appWillEnterForeground:(NSNotification*)note
{
    if (self.playOrPauseBtn.isSelected==NO) {//如果是播放中，则继续播放
        NSArray *tracks = [self.currentItem tracks];
        for (AVPlayerItemTrack *playerItemTrack in tracks) {
            if ([playerItemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicVisual]) {
                playerItemTrack.enabled = YES;
            }
        }
        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.playerLayer.frame = self.bounds;
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;//AVLayerVideoGravityResize;
        [self.layer insertSublayer:_playerLayer atIndex:0];
        [self.player play];
        self.state = KYVedioPlayerStatePlaying;

    }else{
        self.state = KYVedioPlayerStateStopped;
    }
}

#pragma mark - 对外方法
/**
 *  播放
 */
- (void)play{
    if (!self.playOrPauseBtn.selected) {
        return;
    }
    [self autoPlayOrPause:self.playOrPauseBtn];
}

- (void)autoPlayOrPause:(UIButton *)sender {
//    if (self.player.rate != 1.f) {
    if (self.playOrPauseBtn.selected) {
        if ([self currentTime] == [self duration])
            [self setCurrentTime:0.f];
        sender.selected = NO;
        [self.player play];
    } else {
        sender.selected = YES;
        [self.player pause];
    }
    self.showPlayBtn.selected = sender.selected;
    self.playOrPauseBtn.selected = sender.selected;
}

/**
 * 暂停
 */
- (void)pause{
    if (self.playOrPauseBtn.selected) {
        return;
    }
     [self autoPlayOrPause:self.playOrPauseBtn];
}
/**
 * 是否正在播放中
 * @return BOOL YES 正在播放 NO 不在播放中
 **/
- (BOOL)isPlaying {
    if (_player && _player.rate != 0) {
        return YES;
    }
    return NO;
}
/**
 *  获取正在播放的时间点
 *
 *  @return double的一个时间点
 */
- (double)currentTime{
    if (self.player) {
        return CMTimeGetSeconds([self.player currentTime]);
    }else{
        return 0.0;
    }
}

#pragma mark - KVO 监听
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    /* AVPlayerItem "status" property value observer. */
    if (context == PlayViewStatusObservationContext)
    {
        if ([keyPath isEqualToString:@"status"]) {
            AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            switch (status)
            {
                    /* Indicates that the status of the player is not yet known because
                     it has not tried to load new media resources for playback */
                case AVPlayerStatusUnknown:
                {
                    [self.loadingProgress setProgress:0.0 animated:NO];
                    self.state = KYVedioPlayerStateBuffering;
                    [self.loadingView startAnimating];
                }
                    break;

                case AVPlayerStatusReadyToPlay:
                {
                    self.state = KYVedioPlayerStatusReadyToPlay;
                    // 双击的 Recognizer
                    UITapGestureRecognizer* doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
                    doubleTap.numberOfTapsRequired = 2; // 双击
                    [self.singleTap requireGestureRecognizerToFail:doubleTap];//如果双击成立，则取消单击手势（双击的时候不回走单击事件）
                    [self addGestureRecognizer:doubleTap];
                    
                    /* Once the AVPlayerItem becomes ready to play, i.e.
                     [playerItem status] == AVPlayerItemStatusReadyToPlay,
                     its duration can be fetched from the item. */
                    if (CMTimeGetSeconds(_currentItem.duration)) {

                        double _x = CMTimeGetSeconds(_currentItem.duration);
                        if (!isnan(_x)) {
                            self.progressSlider.maximumValue = CMTimeGetSeconds(self.player.currentItem.duration);
                        }
                    }
                    //监听播放状态
                    [self initTimer];

                    if (_isAutoDismissBottomView == YES) {  //每5秒 自动隐藏底部视图
                        if (self.autoDismissTimer==nil) {
                            self.autoDismissTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(autoDismissBottomView:) userInfo:nil repeats:YES];
                            [[NSRunLoop currentRunLoop] addTimer:self.autoDismissTimer forMode:NSDefaultRunLoopMode];
                        }
                    }

                    if (self.delegate && [self.delegate respondsToSelector:@selector(kyvedioPlayerReadyToPlay:playerStatus:)]) {
                        [self.delegate kyvedioPlayerReadyToPlay:self playerStatus:KYVedioPlayerStatusReadyToPlay];
                    }
                    [self.loadingView stopAnimating];
                    self.loadFailedLabel.hidden = YES;
                    // 跳到xx秒播放视频
                    if (self.seekTime > 0) {
                        [self seekToTimeToPlay:self.seekTime];
                        self.seekTime = 0.00;
                    }
                }
                    break;

                case AVPlayerStatusFailed:
                {
                    self.state = KYVedioPlayerStateFailed;
                    if (self.delegate&&[self.delegate respondsToSelector:@selector(kyvedioPlayerFailedPlay:playerStatus:)]) {
                        [self.delegate kyvedioPlayerFailedPlay:self playerStatus:KYVedioPlayerStateFailed];
                    }
                    NSError *error = [self.player.currentItem error];
                    if (error) {
                        self.loadFailedLabel.hidden = NO;
                        [self bringSubviewToFront:self.loadFailedLabel];
                        [self.loadingView stopAnimating];
                    }
                    NSLog(@"视频加载失败===%@",error.description);
                }
                    break;
            }

        }else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            // 计算缓冲进度
            NSTimeInterval timeInterval = [self availableDuration];
            CMTime duration             = self.currentItem.duration;
            CGFloat totalDuration       = CMTimeGetSeconds(duration);
            //缓冲颜色
            self.loadingProgress.progressTintColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.7];
            [self.loadingProgress setProgress:timeInterval / totalDuration animated:NO];
        } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            if (self.playOrPauseBtn.selected) { // 暂停
                return;
            }
            [self.loadingView startAnimating];
            // 当缓冲是空的时候
            if (self.currentItem.playbackBufferEmpty) {
                self.state = KYVedioPlayerStateBuffering;
                [self loadedTimeRanges];
            }
        } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            [self.loadingView stopAnimating];
            // 当缓冲好的时候
            if (self.currentItem.playbackLikelyToKeepUp && self.state == KYVedioPlayerStateBuffering){
                self.state = KYVedioPlayerStatePlaying;
            }
        }
    }
}
/**
 *  缓冲回调
 */
- (void)loadedTimeRanges
{
    self.state = KYVedioPlayerStateBuffering;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.playOrPauseBtn.selected == NO) {
            [self play];
        }
        [self.loadingView stopAnimating];
    });
}
#pragma  mark - 定时器 监听播放状态
-(void)initTimer{
    double interval = .1f;
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration))
    {
        return;
    }
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration))
    {
        CGFloat width = CGRectGetWidth([self.progressSlider bounds]);
        interval = 0.5f * duration / width;
    }
    __weak typeof(self) weakSelf = self;
    self.playbackTimeObserver =  [weakSelf.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC)  queue:dispatch_get_main_queue() /* If you pass NULL, the main queue is used. */
                                                                          usingBlock:^(CMTime time){
        [weakSelf syncScrubber];
    }];
}
- (void)syncScrubber{
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)){
        self.progressSlider.minimumValue = 0.0;
        return;
    }
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration)){
        float minValue = [self.progressSlider minimumValue];
        float maxValue = [self.progressSlider maximumValue];
        double nowTime = CMTimeGetSeconds([self.player currentTime]);
        self.leftTimeLabel.text = [self convertTime:nowTime];
        self.rightTimeLabel.text = [self convertTime:duration];
        if (self.isDragingSlider==YES) {//拖拽slider中，不更新slider的值
        }else if(self.isDragingSlider==NO){
            [self.progressSlider setValue:(maxValue - minValue) * nowTime / duration + minValue];
        }
        if (self.delegate&&[self.delegate respondsToSelector:@selector(kyplayerPlayCurrentTime:)]) {
            [self.delegate kyplayerPlayCurrentTime:self];
        }
    }
}
/**
 *  跳到time处播放
 *  @param seekTime这个时刻，这个时间点
 */
- (void)seekToTimeToPlay:(double)time{
    if (self.player&&self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
        if (time>[self duration]) {
            time = [self duration];
        }
        if (time<=0) {
            time=0.0;
        }
        //        int32_t timeScale = self.player.currentItem.asset.duration.timescale;
        //currentItem.asset.duration.timescale计算的时候严重堵塞主线程，慎用
        /* A timescale of 1 means you can only specify whole seconds to seek to. The timescale is the number of parts per second. Use 600 for video, as Apple recommends, since it is a product of the common video frame rates like 50, 60, 25 and 24 frames per second*/

        [self.player seekToTime:CMTimeMakeWithSeconds(time, _currentItem.currentTime.timescale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {

        }];
    }
}
- (CMTime)playerItemDuration{
    AVPlayerItem *playerItem = _currentItem;
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return([playerItem duration]);
    }
    return(kCMTimeInvalid);
}
/**
 * 把秒转换成格式
 **/
- (NSString *)convertTime:(CGFloat)second{
//    NSDate *d = [NSDate dateWithTimeIntervalSince1970:second];
//    if (second/3600 >= 1) {
//        [[self dateFormatter] setDateFormat:@"HH:mm:ss"];
//    } else {
//        [[self dateFormatter] setDateFormat:@"mm:ss"];
//    }
//    NSString *newTime = [[self dateFormatter] stringFromDate:d];
//    return newTime;
    NSInteger interval = second;
    NSInteger hours = interval / 60 / 60;
    NSInteger minutes = (NSInteger)(interval / 60) % 60;
    NSInteger seconds = (NSInteger)interval % 60;
    NSString *hoursStr, *minutesStr, *secondsStr;
    if (hours < 10) {
        hoursStr = [NSString stringWithFormat:@"0%@", @(hours)];
    } else {
        hoursStr = [@(hours) stringValue];
    }
    if (minutes < 10) {
        minutesStr = [NSString stringWithFormat:@"0%@", @(minutes)];
    } else {
        minutesStr = [@(minutes) stringValue];
    }
    if (seconds < 10) {
        secondsStr = [NSString stringWithFormat:@"0%@", @(seconds)];
    } else {
        secondsStr = [@(seconds) stringValue];
    }
    NSString *intervalString;
    if (hours > 1) {
        intervalString = [NSString stringWithFormat:@"%@:%@:%@", hoursStr, minutesStr, secondsStr];
    } else {
        intervalString = [NSString stringWithFormat:@"%@:%@", minutesStr, secondsStr];
    }
    return intervalString;
}
/**
 *  计算缓冲进度
 *
 *  @return 缓冲进度
 */
- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [_currentItem loadedTimeRanges];
    CMTimeRange timeRange     = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds        = CMTimeGetSeconds(timeRange.start);
    float durationSeconds     = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result     = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}
/**
 * 时间转换格式
 **/
- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
    }
    return _dateFormatter;
}
#pragma mark - UITouch

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    if (self.isLockScreen) {
        return;
    }
    for(UITouch *touch in event.allTouches) {
        self.firstPoint = [touch locationInView:self];
    }
    self.volumeSlider.value = self.systemSlider.value;
    //记录下第一个点的位置,用于moved方法判断用户是调节音量还是调节视频
    self.originalPoint = self.firstPoint;
    if (self.isFullscreen) {
        if (self.delegate&&[self.delegate respondsToSelector:@selector(kyplayerPlayTouchClick)]) {
            [self.delegate kyplayerPlayTouchClick];
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    if (self.isLockScreen) {
        return;
    }
    for(UITouch *touch in event.allTouches) {
        self.secondPoint = [touch locationInView:self];
    }

    //判断是左右滑动还是上下滑动
    CGFloat verValue =fabs(self.originalPoint.y - self.secondPoint.y);
    CGFloat horValue = fabs(self.originalPoint.x - self.secondPoint.x);
    //如果竖直方向的偏移量大于水平方向的偏移量,那么是调节音量或者亮度
    if (verValue > horValue) {//上下滑动
        //判断是全屏模式还是正常模式
        if (self.isFullscreen) {//全屏下
            //判断刚开始的点是左边还是右边,左边控制音量
            if (self.originalPoint.x <= kHalfHeight) {//全屏下:point在view的左边(控制音量)

                /* 手指上下移动的计算方式,根据y值,刚开始进度条在0位置,当手指向上移动600个点后,当手指向上移动N个点的距离后,
                 当前的进度条的值就是N/600,600随开发者任意调整,数值越大,那么进度条到大1这个峰值需要移动的距离也变大,反之越小 */
                self.systemSlider.value += (self.firstPoint.y - self.secondPoint.y)/600.0;
                self.volumeSlider.value = self.systemSlider.value;
            }else{//全屏下:point在view的右边(控制亮度)
                //右边调节屏幕亮度
                self.lightSlider.value += (self.firstPoint.y - self.secondPoint.y)/600.0;
                [[UIScreen mainScreen] setBrightness:self.lightSlider.value];

            }
        }else{//非全屏

            //判断刚开始的点是左边还是右边,左边控制音量
            if (self.originalPoint.x <= kHalfWidth) {//非全屏下:point在view的左边(控制音量)

                /* 手指上下移动的计算方式,根据y值,刚开始进度条在0位置,当手指向上移动600个点后,当手指向上移动N个点的距离后,
                 当前的进度条的值就是N/600,600随开发者任意调整,数值越大,那么进度条到大1这个峰值需要移动的距离也变大,反之越小 */
                _systemSlider.value += (self.firstPoint.y - self.secondPoint.y)/600.0;
                self.volumeSlider.value = _systemSlider.value;
            }else{//非全屏下:point在view的右边(控制亮度)
                //右边调节屏幕亮度
                self.lightSlider.value += (self.firstPoint.y - self.secondPoint.y)/600.0;
                [[UIScreen mainScreen] setBrightness:self.lightSlider.value];

            }
        }
    }else{//左右滑动,调节视频的播放进度
        if (horValue < 15) {
            return;
        }
        //视频进度不需要除以600是因为self.progressSlider没设置最大值,它的最大值随着视频大小而变化
        //要注意的是,视频的一秒时长相当于progressSlider.value的1,视频有多少秒,progressSlider的最大值就是多少
        if (self.isFullscreen) {
            self.bottomView.alpha = 0.0;
            self.closeBtn.alpha = 0.0;
            self.topView.alpha = 0.0;
            self.showView.alpha = 0.0;
            self.playShowView.hidden = NO;
            self.showTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.leftTimeLabel.text,self.rightTimeLabel.text];
            if (self.firstPoint.x - self.secondPoint.x>0) {
                self.showImageView.image = [UIImage imageNamed:@"video_retreat_icon" inBundle:MYBUNDLE compatibleWithTraitCollection:nil];
            } else {
                self.showImageView.image = [UIImage imageNamed:@"video_advance_icon" inBundle:MYBUNDLE compatibleWithTraitCollection:nil];
            }
        }
        
        self.progressSlider.value -= (self.firstPoint.x - self.secondPoint.x);
        [self.player seekToTime:CMTimeMakeWithSeconds(self.progressSlider.value, self.currentItem.currentTime.timescale)];
        double time = CMTimeGetSeconds(CMTimeMakeWithSeconds(self.progressSlider.value, self.currentItem.currentTime.timescale));
        self.leftTimeLabel.text = [self convertTime:time];
        self.showTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.leftTimeLabel.text,self.rightTimeLabel.text];
        //滑动太快可能会停止播放,所以这里自动继续播放
        if (self.player.rate != 1.f) {
            if ([self currentTime] == [self duration])
                [self setCurrentTime:0.f];
            self.showPlayBtn.selected = NO;
            self.playOrPauseBtn.selected = NO;
            [self.player play];
        }
    }

    self.firstPoint = self.secondPoint;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    if (self.isLockScreen) {
        return;
    }
    self.firstPoint = self.secondPoint = CGPointZero;
    self.playShowView.hidden = YES;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event{
    self.playShowView.hidden = YES;
}
#pragma mark - 全屏显示播放 和 缩小显示播放器
/**
 *  全屏显示播放
 ＊ @param interfaceOrientation 方向
 ＊ @param player 当前播放器
 ＊ @param fatherView 当前父视图
 **/
-(void)showFullScreenWithInterfaceOrientation:(UIInterfaceOrientation )interfaceOrientation player:(KYVedioPlayer *)player withFatherView:(UIView *)fatherView{

    [player removeFromSuperview];
    if (@available(iOS 16.0, *)) {
        player.frame = CGRectMake(0, 0, [[UIScreen mainScreen]bounds].size.height, [[UIScreen mainScreen]bounds].size.width);
        player.playerLayer.frame =  CGRectMake(0,0, [[UIScreen mainScreen]bounds].size.height,[[UIScreen mainScreen]bounds].size.width);

        [player.bottomView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(80);
            make.top.mas_equalTo(player.frame.size.height-80);
            make.width.mas_equalTo([[UIScreen mainScreen]bounds].size.height);
        }];
        [player.topView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(60);
            make.left.equalTo(player).with.offset(0);
            make.width.mas_equalTo([[UIScreen mainScreen]bounds].size.height);
        }];
    } else {
        player.frame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height);
        player.playerLayer.frame = player.bounds;

        [player.bottomView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(80);
            make.top.mas_equalTo(player.frame.size.height-80);
            make.width.mas_equalTo(player.frame.size.width);
        }];
        [player.topView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(60);
            make.left.equalTo(player).with.offset(0);
            make.width.mas_equalTo(player.frame.size.width);
        }];
    }
    
    if (@available(iOS 16.0, *)) {
        self.topLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.height,[self screenFit:60]);
        self.bottomLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.height,[self screenFit:80]);
    } else {
        self.topLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.width,[self screenFit:60]);
        self.bottomLayer.frame = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.width,[self screenFit:80]);
    }
    [player.closeBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(player.topView).with.offset(5);
//        make.height.mas_equalTo(40);
        make.top.bottom.equalTo(player.topView);
        make.width.mas_equalTo(30);
    }];
    [player.titleLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(player.topView).with.offset(58);
        make.right.equalTo(self.shareBtn.mas_left).with.offset(-10);
        make.center.equalTo(player.topView);
        make.top.equalTo(player.topView).with.offset(0);

    }];
    if (player.loadingView.animating) {
        [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
        }];
    }
    [player.loadFailedLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(player);
        make.width.equalTo(player);
        make.height.equalTo(@30);
    }];
   [fatherView addSubview:player];
    player.fullScreenBtn.selected = YES;
    [player bringSubviewToFront:player.bottomView];

}
/**
 *  小屏幕显示播放
 ＊ @param player 当前播放器
 ＊ @param fatherView 当前父视图
 ＊ @param playerFrame 小屏幕的Frame
 **/
-(void)showSmallScreenWithPlayer:(KYVedioPlayer *)player withFatherView:(UIView *)fatherView withFrame:(CGRect )playerFrame{

    [player removeFromSuperview];
    [UIView animateWithDuration:0.5f animations:^{
//        player.transform = CGAffineTransformIdentity;
        player.frame =CGRectMake(playerFrame.origin.x, playerFrame.origin.y, playerFrame.size.width, playerFrame.size.height);
//        player.frame =CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, playerFrame.size.height);
        player.playerLayer.frame =  player.bounds;
        [fatherView addSubview:player];
        
        [player.bottomView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(player).with.offset(0);
            make.right.equalTo(player).with.offset(0);
            make.height.mas_equalTo(40);
            make.bottom.equalTo(player).with.offset(0);
        }];


        [player.topView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(player).with.offset(0);
            make.right.equalTo(player).with.offset(0);
            make.height.mas_equalTo(40);
            make.top.equalTo(player).with.offset(0);
        }];


        [player.closeBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(player.topView).with.offset(5);
//            make.height.mas_equalTo(40);
            make.top.bottom.equalTo(player.topView);
            make.width.mas_equalTo(30);
        }];


        [player.titleLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(player.topView).with.offset(45);
            make.right.equalTo(player.topView).with.offset(-45);
            make.center.equalTo(player.topView);
            make.top.equalTo(player.topView).with.offset(0);
        }];
        if (player.loadingView.animating) {
            [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.center.equalTo(self);
            }];
        }
        [player.loadFailedLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(player);
            make.width.equalTo(player);
            make.height.equalTo(@30);
        }];

    }completion:^(BOOL finished) {
        player.isFullscreen = NO;
        player.fullScreenBtn.selected = NO;

    }];
}


@end
