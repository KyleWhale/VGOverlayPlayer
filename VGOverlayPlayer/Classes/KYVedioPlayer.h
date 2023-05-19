//
//  KYVedioPlayer.h
//  KYVedioPlayer
//
//  Created by kingly on 16/9/9.
//  Copyright © 2016年 https://github.com/kingly09/KYVedioPlayer kingly  inc . All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<Masonry/Masonry.h>)
#import <Masonry/Masonry.h>
#else
#import "Masonry.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@import MediaPlayer;
@import AVFoundation;
@import UIKit;


// 播放器的几种状态
typedef NS_ENUM(NSInteger, KYVedioPlayerState) {
   KYVedioPlayerStateFailed,        // 播放失败
   KYVedioPlayerStateBuffering,     // 缓冲中
   KYVedioPlayerStatusReadyToPlay,  // 将要播放
   KYVedioPlayerStatePlaying,       // 播放中
   KYVedioPlayerStateStopped,       //暂停播放
   KYVedioPlayerStateFinished       //播放完毕
};
// 枚举值，包含播放器左上角的关闭按钮的类型
typedef NS_ENUM(NSInteger, CloseBtnStyle){
    CloseBtnStylePop, //pop箭头<-
    CloseBtnStyleClose  //关闭（X）
};

@class KYVedioPlayer;
@protocol KYVedioPlayerDelegate <NSObject>
@optional
///播放器事件
//点击播放暂停按钮代理方法
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer clickedPlayOrPauseButton:(UIButton *)playOrPauseBtn;
//点击关闭按钮代理方法
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer clickedCloseButton:(UIButton *)closeBtn;
//点击分享按钮代理方法
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer isFullscreen:(BOOL)isFullscreen onClickShareBtn:(UIButton *)shareBtn;
//点击字幕按钮
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer isFullscreen:(BOOL)isFullscreen onClickSubtitleBtn:(UIButton *)subtitleBtn;
//去除广告
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer advertisementBtn:(UIButton *)subtitleBtn;
//锁屏
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer lockBtn:(UIButton *)lockBtn;
//点击收藏按钮代理方法
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer isFullscreen:(BOOL)isFullscreen onClickCollectionBtn:(UIButton *)collectionBtn;
//点击episode按钮
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer onEpisodeBtn:(UIButton *)collectionBtn;
//点击下一章按钮
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer onNextBtn:(UIButton *)collectionBtn;
//点击全屏按钮代理方法
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer clickedFullScreenButton:(UIButton *)fullScreenBtn;
//单击WMPlayer的代理方法
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer singleTaped:(UITapGestureRecognizer *)singleTap;
//双击WMPlayer的代理方法
-(void)kyvedioPlayer:(KYVedioPlayer *)kyvedioPlayer doubleTaped:(UITapGestureRecognizer *)doubleTap;

///播放状态
//播放失败的代理方法
-(void)kyvedioPlayerFailedPlay:(KYVedioPlayer *)kyvedioPlayer playerStatus:(KYVedioPlayerState)state;
//准备播放的代理方法
-(void)kyvedioPlayerReadyToPlay:(KYVedioPlayer *)kyvedioPlayer playerStatus:(KYVedioPlayerState)state;
//播放完毕的代理方法
-(void)kyplayerFinishedPlay:(KYVedioPlayer *)kyvedioPlayer;

//监听播放时间
-(void)kyplayerPlayCurrentTime:(KYVedioPlayer *)kyvedioPlayer;
//监听触摸时间
-(void)kyplayerPlayTouchClick;

@end


@interface KYVedioPlayer : UIView

/**
 *  播放器player
 */
@property (nonatomic,retain,nullable) AVPlayer       *player;
/**
 *playerLayer,可以修改frame
 */
@property (nonatomic,retain,nullable) AVPlayerLayer  *playerLayer;

/** 播放器的代理 */
@property (nonatomic, weak)id <KYVedioPlayerDelegate> delegate;
/**
 *  底部操作工具栏
 */
@property (nonatomic,retain ) UIView         *bottomView;
@property (nonatomic,retain ) CAGradientLayer * bottomLayer;
@property (nonatomic,retain ) CAGradientLayer * topLayer;

//中间快进显示条
@property (nonatomic,retain ) UIView         *showView;
@property (nonatomic,retain ) UIButton       *lockBtn;
@property (nonatomic,retain ) UIButton       *adBtn;
@property (nonatomic,retain ) UIButton       *showPlayBtn;
@property (nonatomic,retain ) UIButton       *advanceBtn;
@property (nonatomic,retain ) UIButton       *retreatBtn;

@property (nonatomic,retain ) UIButton       *nextBtn;

@property (nonatomic,retain ) UIView         *playShowView;
@property (nonatomic,strong) UIImageView        *showImageView;
@property (nonatomic,strong) UILabel        *showTimeLabel;
/// 是否锁定旋转
@property (nonatomic, assign) BOOL isLockScreen;

/**
 *  顶部操作工具栏
 */
@property (nonatomic,retain ) UIView         *topView;

/**
 *  显示播放视频的title
 */
@property (nonatomic,strong) UILabel        *titleLabel;
/**
 ＊  播放器状态
 */
@property (nonatomic, assign) KYVedioPlayerState   state;
/**
 ＊  播放器左上角按钮的类型
 */
@property (nonatomic, assign) CloseBtnStyle   closeBtnStyle;
/**
 *  定时器
 */
@property (nonatomic, retain,nullable) NSTimer        *autoDismissTimer;
/**
 *  BOOL值判断是否自动隐藏底部视图,默认是自动隐藏
 */
@property (nonatomic,assign ) BOOL            isAutoDismissBottomView;
/**
 *  BOOL值判断当前的状态
 */
@property (nonatomic,assign ) BOOL            isFullscreen;
/**
 *  控制全屏的按钮
 */
@property (nonatomic,retain ) UIButton       *fullScreenBtn;
/**
 *  播放暂停按钮
 */
@property (nonatomic,retain,nullable) UIButton       *playOrPauseBtn;
/**
 *  左上角关闭按钮
 */
@property (nonatomic,retain ) UIButton       *closeBtn;
/**
 *  右上角 分享按钮
 */
@property (nonatomic,retain ) UIButton      *shareBtn;
//收藏
@property (nonatomic,retain ) UIButton      *collectionBtn;
//字幕
@property (nonatomic,retain ) UIButton      *subtitleBtn;

/**
 *  显示加载失败的UILabel
 */
@property (nonatomic,strong) UILabel        *loadFailedLabel;
/**
 *  当前播放的item
 */
@property (nonatomic, retain,nullable)   AVPlayerItem   *currentItem;
/**
 *  菊花（加载框）
 */
@property (nonatomic,strong) UIActivityIndicatorView *loadingView;
/**
 *  BOOL值判断当前的播放状态
 */
@property (nonatomic,assign ) BOOL       isPlaying;
/**
 *  设置播放视频的USRLString，可以是本地的路径也可以是http的网络路径
 */
@property (nonatomic,copy) NSString       *URLString;
/**
 *  跳到time处播放
 *  @param seekTime这个时刻，这个时间点
 */
@property (nonatomic, assign) double  seekTime;
/**
 *  进度条的颜色
 *  @param progressColor
 */
@property (nonatomic,strong)  UIColor *progressColor;
/**
 *  播放
 */
- (void)play;

/**
 * 暂停
 */
- (void)pause;

/**
 *  获取正在播放的时间点
 *
 *  @return double的一个时间点
 */
- (double)currentTime;

/**
 * 重置播放器
 */
- (void)resetKYVedioPlayer;
/**
 *  全屏显示播放
 ＊ @param interfaceOrientation 方向
 ＊ @param player 当前播放器
 ＊ @param fatherView 当前父视图
 **/
-(void)showFullScreenWithInterfaceOrientation:(UIInterfaceOrientation )interfaceOrientation player:(KYVedioPlayer *)player withFatherView:(UIView *)fatherView;
/**
 *  小屏幕显示播放
 ＊ @param player 当前播放器
 ＊ @param fatherView 当前父视图
 ＊ @param playerFrame 小屏幕的Frame
 **/
-(void)showSmallScreenWithPlayer:(KYVedioPlayer *)player withFatherView:(UIView *)fatherView withFrame:(CGRect )playerFrame;

- (void)colseTheVideo:(UIButton *)sender;
- (void)fullScreenAction:(UIButton *)sender;
- (void)reloadPlayerWith:(BOOL)isFullscreen;

@end

NS_ASSUME_NONNULL_END
