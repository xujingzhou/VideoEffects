//
//  ExportEffects
//  VideoEffects
//
//  Created by Johnny Xu(徐景周) on 5/30/15.
//  Copyright (c) 2015 Future Studio. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ExportEffects.h"
#import "VideoThemesData.h"
#import "CustomVideoCompositor.h"
#import "GifAnimationLayer.h"

#define DefaultOutputVideoName @"outputMovie.mp4"
#define DefaultOutputAudioName @"outputAudio.caf"

@interface ExportEffects ()
{
}

@property (strong, nonatomic) NSTimer *timerEffect;
@property (strong, nonatomic) AVAssetExportSession *exportSession;

@property (strong, nonatomic) GPUImageMovie *movieFile;
@property (strong, nonatomic) GPUImageOutput<GPUImageInput> *filter;
@property (strong, nonatomic) GPUImageMovieWriter *movieWriter;

@property (strong, nonatomic) NSTimer *timerFilter;
@property (strong, nonatomic) NSMutableDictionary *themesDic;

@end

@implementation ExportEffects
{

}

+ (ExportEffects *)sharedInstance
{
    static ExportEffects *sharedInstance = nil;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedInstance = [[ExportEffects alloc] init];
    });
    
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    
    if (self)
    {
        _timerEffect = nil;
        _exportSession = nil;
        _filenameBlock = nil;
        _timerFilter = nil;
        
        self.themeCurrentType = kThemeNone;
        self.themesDic = [[VideoThemesData sharedInstance] getThemeData];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_exportSession)
    {
        _exportSession = nil;
    }
    
    if (_timerEffect)
    {
        [_timerEffect invalidate];
        _timerEffect = nil;
    }
    
    if (_movieFile)
    {
        _movieFile = nil;
    }
    
    if (_movieWriter)
    {
        _movieWriter = nil;
    }
    
    if (_exportSession)
    {
        _exportSession = nil;
    }
    
    if (_timerFilter)
    {
        [_timerFilter invalidate];
        _timerFilter = nil;
    }
}

#pragma mark Utility methods
- (NSString*)getOutputFilePath
{
    NSString* mp4OutputFile = [NSTemporaryDirectory() stringByAppendingPathComponent:DefaultOutputVideoName];
    return mp4OutputFile;
}

- (NSString*)getTempOutputFilePath
{
    NSString *path = NSTemporaryDirectory();
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    formatter.dateFormat = @"yyyyMMddHHmmssSSS";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mov"];
    return fileName;
}

#pragma mark - writeExportedVideoToAssetsLibrary
- (void)writeExportedVideoToAssetsLibrary:(NSString *)outputPath
{
    __unsafe_unretained typeof(self) weakSelf = self;
    NSURL *exportURL = [NSURL fileURLWithPath:outputPath];
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:exportURL])
    {
        [library writeVideoAtPathToSavedPhotosAlbum:exportURL completionBlock:^(NSURL *assetURL, NSError *error)
         {
             NSString *message;
             if (!error)
             {
                 message = GBLocalizedString(@"MsgSuccess");
             }
             else
             {
                 message = [error description];
             }
             
             NSLog(@"%@", message);
             
             // Output path
             self.filenameBlock = ^(void) {
                 return outputPath;
             };
             
             if (weakSelf.finishVideoBlock)
             {
                 weakSelf.finishVideoBlock(YES, message);
             }
         }];
    }
    else
    {
        NSString *message = GBLocalizedString(@"MsgFailed");;
        NSLog(@"%@", message);
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (_finishVideoBlock)
        {
            _finishVideoBlock(NO, message);
        }
    }
    
    library = nil;
}

#pragma mark - GPUImage
- (void) pause
{
    if (_movieFile.progress < 1.0)
    {
        [_movieWriter cancelRecording];
    }
    else if (_exportSession.progress < 1.0)
    {
        [_exportSession cancelExport];
    }
}

- (void)initializeVideoFilter:(NSURL*)inputMovieURL fromSystemCamera:(BOOL)fromSystemCamera
{
    // 1.
    _movieFile = [[GPUImageMovie alloc] initWithURL:inputMovieURL];
    _movieFile.runBenchmark = NO;
    _movieFile.playAtActualSpeed = YES;
    
    // 2. Add filter effect
    _filter = nil;
    NSUInteger themesCount = [[[VideoThemesData sharedInstance] getThemeData] count];
    if (self.themeCurrentType != kThemeNone && themesCount >= self.themeCurrentType)
    {
        GPUImageOutput<GPUImageInput> *filterCurrent = [[[VideoThemesData sharedInstance] getThemeFilter:fromSystemCamera] objectForKey:[NSNumber numberWithInt:self.themeCurrentType]];
        _filter = filterCurrent;
    }
    
    // 3.
    if ((NSNull*)_filter != [NSNull null] && _filter != nil)
    {
        [_movieFile addTarget:_filter];
    }
}

- (void)buildVideoFilter:(NSString*)videoFilePath fromSystemCamera:(BOOL)fromSystemCamera finishBlock:(GenericCallback)finishBlock
{
    if (self.themeCurrentType == kThemeNone)
    {
        NSLog(@"Theme is empty!");
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (finishBlock)
        {
            finishBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
        return;
    }
    
//    if (isStringEmpty(videoFilePath))
//    {
//        NSLog(@"videoFilePath is empty!");
//        
//        // Output path
//        self.filenameBlock = ^(void) {
//            return @"";
//        };
//        
//        if (finishBlock)
//        {
//            finishBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
//        }
//        return;
//    }
    
    self.themesDic = [[VideoThemesData sharedInstance] getThemeData];
    
    // 2.
    NSURL *inputVideoURL = getFileURL(videoFilePath);
    [self initializeVideoFilter:inputVideoURL fromSystemCamera:fromSystemCamera];
    
    // 3. Movie output temp file
    NSString *pathToTempMov = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tempMovie.mov"];
    unlink([pathToTempMov UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    NSURL *outputTempMovieURL = [NSURL fileURLWithPath:pathToTempMov];
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputVideoURL options:nil];
    NSArray *assetVideoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (assetVideoTracks.count <= 0)
    {
        NSLog(@"Video track is empty!");
        return;
    }
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    // If this if from system camera, it will rotate 90c, and swap width and height
    CGSize sizeVideo = CGSizeMake(videoAssetTrack.naturalSize.width, videoAssetTrack.naturalSize.height);
    if (fromSystemCamera)
    {
        sizeVideo = CGSizeMake(videoAssetTrack.naturalSize.height, videoAssetTrack.naturalSize.width);
    }
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:outputTempMovieURL size:sizeVideo];
    
    if ((NSNull*)_filter != [NSNull null] && _filter != nil)
    {
        [_filter addTarget:_movieWriter];
    }
    else
    {
        [_movieFile addTarget:_movieWriter];
    }
    
    // 4. Configure this for video from the movie file, where we want to preserve all video frames and audio samples
    _movieWriter.shouldPassthroughAudio = YES;
    _movieFile.audioEncodingTarget = _movieWriter;
    [_movieFile enableSynchronizedEncodingUsingMovieWriter:_movieWriter];
    
    // 5.
    [_movieWriter startRecording];
    [_movieFile startProcessing];
    
    // 6. Progress monitor
    _timerFilter = [NSTimer scheduledTimerWithTimeInterval:0.3f
                                                    target:self
                                                  selector:@selector(retrievingFilterProgress)
                                                  userInfo:nil
                                                   repeats:YES];
    
    __weak typeof(self) weakSelf = self;
    // 7. Filter finished
    [weakSelf.movieWriter setCompletionBlock:^{
        
        if ((NSNull*)_filter != [NSNull null] && _filter != nil)
        {
            [_filter removeTarget:weakSelf.movieWriter];
        }
        else
        {
            [_movieFile removeTarget:weakSelf.movieWriter];
        }
        
        [_movieWriter finishRecordingWithCompletionHandler:^{
            
            // Closer timer
            [_timerFilter invalidate];
            _timerFilter = nil;
            
            if (finishBlock)
            {
                finishBlock(YES, pathToTempMov);
            }
        }];
        
    }];
    
    // 8. Filter failed
    [weakSelf.movieWriter  setFailureBlock: ^(NSError* error){
        
        if ((NSNull*)_filter != [NSNull null] && _filter != nil)
        {
            [_filter removeTarget:weakSelf.movieWriter];
        }
        else
        {
            [_movieFile removeTarget:weakSelf.movieWriter];
        }
        
//        [_movieWriter finishRecordingWithCompletionHandler:^{
            
            // Closer timer
            [_timerFilter invalidate];
            _timerFilter = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                self.filenameBlock = ^(void) {
                    return @"";
                };
                
                if (finishBlock)
                {
                    finishBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
                }
            });
            
            NSLog(@"Add filter effect failed! - %@", error.description);
            return;
//        }];
        
    }];
}

#pragma mark - Export Video
- (void)addEffectToVideo:(NSString *)videoFilePath withAudioFilePath:(NSString *)audioFilePath
{
    if (isStringEmpty(videoFilePath))
    {
        NSLog(@"videoFilePath is empty!");
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (self.finishVideoBlock)
        {
            self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
        
        return;
    }
    
    BOOL systemCamera = NO;
    NSURL *videoURL = getFileURL(videoFilePath);
    AVAsset *videoAsset = [AVAsset assetWithURL:videoURL];
    if (videoAsset)
    {
        UIInterfaceOrientation videoOrientation = orientationForTrack(videoAsset);
        NSLog(@"videoOrientation: %ld", (long)videoOrientation);
        if (videoOrientation == UIInterfaceOrientationPortrait)
        {
            // Right rotation 90 degree
            [self setShouldRightRotate90:YES withTrackID:TrackIDCustom];
            
            systemCamera = YES;
        }
        else
        {
            [self setShouldRightRotate90:NO withTrackID:TrackIDCustom];
            
            systemCamera = NO;
        }
    }
    else
    {
        NSLog(@"videoAsset is empty!");
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (self.finishVideoBlock)
        {
            self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
        
        return;
    }

    // Filter
    [self buildVideoFilter:videoFilePath fromSystemCamera:systemCamera finishBlock:^(BOOL success, id result) {
        
        if (success)
        {
            NSLog(@"buildVideoFilter success.");
            
            NSString *filterVideoFile = result;
            NSMutableArray *videoFileArray = [NSMutableArray arrayWithCapacity:2];
            [videoFileArray addObject:videoFilePath];
            [videoFileArray addObject:filterVideoFile];
            
            [self exportVideo:videoFileArray withAudioFilePath:audioFilePath];
        }
        else
        {
            self.filenameBlock = ^(void) {
                return @"";
            };
            
            if (self.finishVideoBlock)
            {
                self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
            }
        }
    }];
}

#pragma mark - addAudioMixToComposition
- (void)addAudioMixToComposition:(AVMutableComposition *)composition withAudioMix:(AVMutableAudioMix *)audioMix withAsset:(AVURLAsset*)audioAsset
{
    NSInteger i;
    NSArray *tracksToDuck = [composition tracksWithMediaType:AVMediaTypeAudio];
    
    // 1. Clip commentary duration to composition duration.
    CMTimeRange commentaryTimeRange = CMTimeRangeMake(kCMTimeZero, audioAsset.duration);
    if (CMTIME_COMPARE_INLINE(CMTimeRangeGetEnd(commentaryTimeRange), >, [composition duration]))
        commentaryTimeRange.duration = CMTimeSubtract([composition duration], commentaryTimeRange.start);
    
    // 2. Add the commentary track.
    AVMutableCompositionTrack *compositionCommentaryTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:TrackIDCustom];
    AVAssetTrack * commentaryTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    [compositionCommentaryTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, commentaryTimeRange.duration) ofTrack:commentaryTrack atTime:commentaryTimeRange.start error:nil];
    
    // 3. Fade in for bgMusic
    CMTime fadeTime = CMTimeMake(1, 1);
    CMTimeRange startRange = CMTimeRangeMake(kCMTimeZero, fadeTime);
    NSMutableArray *trackMixArray = [NSMutableArray array];
    AVMutableAudioMixInputParameters *trackMixComentray = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:commentaryTrack];
    [trackMixComentray setVolumeRampFromStartVolume:0.0f toEndVolume:0.5f timeRange:startRange];
    [trackMixArray addObject:trackMixComentray];
    
    // 4. Fade in & Fade out for original voices
    for (i = 0; i < [tracksToDuck count]; i++)
    {
        CMTimeRange timeRange = [[tracksToDuck objectAtIndex:i] timeRange];
        if (CMTIME_COMPARE_INLINE(CMTimeRangeGetEnd(timeRange), ==, kCMTimeInvalid))
        {
            break;
        }
        
        CMTime halfSecond = CMTimeMake(1, 2);
        CMTime startTime = CMTimeSubtract(timeRange.start, halfSecond);
        CMTime endRangeStartTime = CMTimeAdd(timeRange.start, timeRange.duration);
        CMTimeRange endRange = CMTimeRangeMake(endRangeStartTime, halfSecond);
        if (startTime.value < 0)
        {
            startTime.value = 0;
        }
        
        [trackMixComentray setVolumeRampFromStartVolume:0.5f toEndVolume:0.2f timeRange:CMTimeRangeMake(startTime, halfSecond)];
        [trackMixComentray setVolumeRampFromStartVolume:0.2f toEndVolume:0.5f timeRange:endRange];
        [trackMixArray addObject:trackMixComentray];
    }
    
    audioMix.inputParameters = trackMixArray;
}

- (void)addAsset:(AVAsset *)asset toComposition:(AVMutableComposition *)composition withTrackID:(CMPersistentTrackID)trackID withRecordAudio:(BOOL)recordAudio withTimeRange:(CMTimeRange)timeRange
{
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:trackID];
    AVAssetTrack *assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    [videoTrack insertTimeRange:timeRange ofTrack:assetVideoTrack atTime:kCMTimeZero error:nil];
    [videoTrack setPreferredTransform:assetVideoTrack.preferredTransform];
    
    if (recordAudio)
    {
        AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:trackID];
        if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0)
        {
            AVAssetTrack *assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            [audioTrack insertTimeRange:timeRange ofTrack:assetAudioTrack atTime:kCMTimeZero error:nil];
        }
        else
        {
            NSLog(@"Reminder: video hasn't audio!");
        }
    }
}

- (void)exportVideo:(NSArray *)videoFilePathArray withAudioFilePath:(NSString *)audioFilePath
{
    if (!videoFilePathArray || [videoFilePathArray count] < 1)
    {
        NSLog(@"videoFilePath is empty!");
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (self.finishVideoBlock)
        {
            self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
        
        return;
    }
    
    CGFloat duration = 0;
    CMTime totalDuration = kCMTimeZero;
    CMTimeRange bgVideoTimeRange = kCMTimeRangeZero;
    NSMutableArray *assetArray = [[NSMutableArray alloc] initWithCapacity:2];
    AVMutableComposition *composition = [AVMutableComposition composition];
    for (int i = 0; i < [videoFilePathArray count]; ++i)
    {
        NSString *videoPath = [videoFilePathArray objectAtIndex:i];
        NSURL *videoURL = getFileURL(videoPath);
        AVAsset *videoAsset = [AVAsset assetWithURL:videoURL];
        
        if (i == 0)
        {
            // BG video duration
            bgVideoTimeRange = [[[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject] timeRange];
        }
        
        if (videoAsset)
        {
            [self addAsset:videoAsset toComposition:composition withTrackID:i+1 withRecordAudio:NO withTimeRange:bgVideoTimeRange];
            [assetArray addObject:videoAsset];
            
            // Max duration
            duration = MAX(duration, CMTimeGetSeconds(videoAsset.duration));
            totalDuration = CMTimeAdd(totalDuration, videoAsset.duration);
        }
    }
    
    if ([assetArray count] < 1)
    {
        NSLog(@"assetArray is empty!");
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (self.finishVideoBlock)
        {
            self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
        
        return;
    }
    
    // Music effect
    AVMutableAudioMix *audioMix = nil;
    if (!isStringEmpty(audioFilePath))
    {
        NSString *fileName = [audioFilePath lastPathComponent];
        NSLog(@"%@",fileName);
        
        NSURL *bgMusicURL = [[NSBundle mainBundle] URLForResource:fileName withExtension:nil];
        AVURLAsset *assetMusic = [[AVURLAsset alloc] initWithURL:bgMusicURL options:nil];
        if (assetMusic)
        {
            audioMix = [AVMutableAudioMix audioMix];
            [self addAudioMixToComposition:composition withAudioMix:audioMix withAsset:assetMusic];
        }
    }
    else
    {
        // BG video music
        AVAssetTrack *assetAudioTrack = nil;
        AVAsset *audioAsset = [assetArray objectAtIndex:0];
        if ([[audioAsset tracksWithMediaType:AVMediaTypeAudio] count] > 0)
        {
            assetAudioTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
            if (assetAudioTrack)
            {
                AVMutableCompositionTrack *compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
                [compositionAudioTrack insertTimeRange:bgVideoTimeRange ofTrack:assetAudioTrack atTime:kCMTimeZero error:nil];
            }
        }
        else
        {
            NSLog(@"Reminder: embeded BG video hasn't audio!");
        }
    }
    
    // BG video
    AVAssetTrack *firstVideoTrack = [[assetArray[0] tracksWithMediaType:AVMediaTypeVideo] firstObject];
    CGSize videoSize = firstVideoTrack.naturalSize;
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    BOOL shouldRotate = [self shouldRightRotate90ByTrackID:TrackIDCustom];
    if (shouldRotate)
    {
        videoSize = CGSizeMake(firstVideoTrack.naturalSize.height, firstVideoTrack.naturalSize.width);
    }
    videoComposition.renderSize = CGSizeMake(videoSize.width, videoSize.height);
    
    videoComposition.frameDuration = CMTimeMakeWithSeconds(1.0 / firstVideoTrack.nominalFrameRate, firstVideoTrack.naturalTimeScale);
    instruction.timeRange = [composition.tracks.firstObject timeRange];
    
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] initWithCapacity:1];
    for (int i = 0; i < [assetArray count]; ++i)
    {
        AVMutableVideoCompositionLayerInstruction *videoLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];
        videoLayerInstruction.trackID = i + 1;
        
        [layerInstructionArray addObject:videoLayerInstruction];
    }
    
    instruction.layerInstructions = layerInstructionArray;
    videoComposition.instructions = @[ instruction ];
    videoComposition.customVideoCompositorClass = [CustomVideoCompositor class];

    // Animation
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    int limitMinLen = 100;
    CGSize videoSizeResult = CGSizeZero;
    if (videoSize.width >= limitMinLen || videoSize.height >= limitMinLen)
    {
        // Assign a output size
        parentLayer.frame = CGRectMake(0, 0, videoSize.width, videoSize.height);
        videoSizeResult = videoSize;
    }
    else
    {
        NSLog(@"videoSize is empty!");
        
        // Output path
        self.filenameBlock = ^(void) {
            return @"";
        };
        
        if (self.finishVideoBlock)
        {
            self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
        }
        
        return;
    }
    
    videoLayer.frame = parentLayer.frame;
    [parentLayer addSublayer:videoLayer];
    
    VideoThemes *themeCurrent = nil;
    if (self.themeCurrentType != kThemeNone && [self.themesDic count] >= self.themeCurrentType)
    {
        themeCurrent = [self.themesDic objectForKey:[NSNumber numberWithInt:self.themeCurrentType]];
    }
    
    // Animation effects
    NSMutableArray *animatedLayers = [[NSMutableArray alloc] initWithCapacity:[[themeCurrent animationActions] count]];
    if ([self shouldDisplayGhost])
    {
        NSString *imageName = @"ghost.gif";
        UIImage *image = [UIImage imageNamed:imageName];
        CGFloat imageFactor = image.size.width / image.size.height;
        CGFloat widthFactor = videoSize.width / image.size.width;
        CGFloat heightFactor = videoSize.height / image.size.height;
        CGFloat imageWidth  = image.size.width;
        CGFloat imageHeight = image.size.height;
        if (widthFactor <= 1)
        {
            imageWidth  = videoSize.width;
            imageHeight = imageWidth / imageFactor;
        }
        else if (heightFactor <= 1)
        {
            imageHeight = videoSize.height;
            imageWidth = imageHeight * imageFactor;
        }
        
        CGRect gifFrame = CGRectMake((videoSize.width - imageWidth)/2, (videoSize.height - imageHeight)/2, imageWidth, imageHeight);
        NSLog(@"gifFrame: %@", NSStringFromCGRect(gifFrame));
        NSString *gifPath = getFilePath(imageName);
        CALayer *animatedLayer = nil;
        CFTimeInterval beginTime = 2.0f;
        animatedLayer = [GifAnimationLayer layerWithGifFilePath:gifPath withFrame:gifFrame withAniBeginTime:beginTime];
        if (animatedLayer && [animatedLayer isKindOfClass:[GifAnimationLayer class]])
        {
            animatedLayer.opacity = 0.0f;
            
            CAKeyframeAnimation *animation = [[CAKeyframeAnimation alloc] init];
            [animation setKeyPath:@"contents"];
            animation.calculationMode = kCAAnimationDiscrete;
            animation.autoreverses = NO;
            animation.repeatCount = 1;
            animation.beginTime = beginTime;
            
            NSDictionary *gifDic = [(GifAnimationLayer*)animatedLayer getValuesAndKeyTimes];
            NSMutableArray *keyTimes = [gifDic objectForKey:@"keyTimes"];
            NSMutableArray *imageArray = [NSMutableArray arrayWithCapacity:[keyTimes count]];
            for (int i = 0; i < [keyTimes count]; ++i)
            {
                CGImageRef image = [(GifAnimationLayer*)animatedLayer copyImageAtFrameIndex:i];
                if (image)
                {
                    [imageArray addObject:(__bridge id)image];
                }
            }
            
            animation.values   = imageArray;
            animation.keyTimes = keyTimes;
            animation.duration = [(GifAnimationLayer*)animatedLayer getTotalDuration];
            animation.removedOnCompletion = YES;
            animation.delegate = self;
            [animation setValue:@"stop" forKey:@"TAG"];
            
            [animatedLayer addAnimation:animation forKey:@"contents"];
            
            CABasicAnimation *fadeOutAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
            fadeOutAnimation.fromValue = @0.6f;
            fadeOutAnimation.toValue = @0.3f;
            fadeOutAnimation.additive = YES;
            fadeOutAnimation.removedOnCompletion = YES;
            fadeOutAnimation.beginTime = beginTime;
            fadeOutAnimation.duration = animation.beginTime + animation.duration + 2;
            fadeOutAnimation.fillMode = kCAFillModeBoth;
            [animatedLayer addAnimation:fadeOutAnimation forKey:@"opacityOut"];
            
            [animatedLayers addObject:(id)animatedLayer];
            [parentLayer addSublayer:animatedLayer];
        }
    }
    
    videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
    NSLog(@"videoSizeResult width: %f, Height: %f", videoSizeResult.width, videoSizeResult.height);
    
    if (animatedLayers)
    {
        [animatedLayers removeAllObjects];
        animatedLayers = nil;
    }
    
    // Export
    NSString *exportPath = [self getOutputFilePath];
    NSURL *exportURL = [NSURL fileURLWithPath:[self returnFormatString:exportPath]];
    // Delete old file
    unlink([exportPath UTF8String]);
    
    _exportSession = [AVAssetExportSession exportSessionWithAsset:composition presetName:AVAssetExportPresetMediumQuality];
    _exportSession.outputURL = exportURL;
    _exportSession.outputFileType = AVFileTypeMPEG4;
    _exportSession.shouldOptimizeForNetworkUse = YES;
    
    if (audioMix)
    {
        _exportSession.audioMix = audioMix;
    }

    if (videoComposition)
    {
        _exportSession.videoComposition = videoComposition;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Progress monitor
        _timerEffect = [NSTimer scheduledTimerWithTimeInterval:0.3f
                                                        target:self
                                                      selector:@selector(retrievingExportProgress)
                                                      userInfo:nil
                                                       repeats:YES];
    });
    
    __block typeof(self) blockSelf = self;
    [_exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
        switch ([_exportSession status])
        {
            case AVAssetExportSessionStatusCompleted:
            {
                // Close timer
                [blockSelf.timerEffect invalidate];
                blockSelf.timerEffect = nil;
                
                // Save video to Album
                [self writeExportedVideoToAssetsLibrary:exportPath];
                
                NSLog(@"Export Successful: %@", exportPath);
                break;
            }
                
            case AVAssetExportSessionStatusFailed:
            {
                // Close timer
                [blockSelf.timerEffect invalidate];
                blockSelf.timerEffect = nil;
                
                // Output path
                self.filenameBlock = ^(void) {
                    return @"";
                };
                
                if (self.finishVideoBlock)
                {
                    self.finishVideoBlock(NO, GBLocalizedString(@"MsgConvertFailed"));
                }
                
                NSLog(@"Export failed: %@, %@", [[blockSelf.exportSession error] localizedDescription], [blockSelf.exportSession error]);
                break;
            }
                
            case AVAssetExportSessionStatusCancelled:
            {
                NSLog(@"Canceled: %@", blockSelf.exportSession.error);
                break;
            }
            default:
                break;
        }
    }];
}

// Convert 'space' char
- (NSString *)returnFormatString:(NSString *)str
{
    return [str stringByReplacingOccurrencesOfString:@" " withString:@""];
}

#pragma mark - Export Progress Callback
- (void)retrievingFilterProgress
{
    if (_movieFile && _exportProgressBlock)
    {
        NSString *title = GBLocalizedString(@"Processing");
        self.exportProgressBlock([NSNumber numberWithFloat:_movieFile.progress], title);
    }    
}

- (void)retrievingExportProgress
{
    if (_exportSession && _exportProgressBlock)
    {
        self.exportProgressBlock([NSNumber numberWithFloat:_exportSession.progress], nil);
    }
}

#pragma mark - NSUserDefaults
#pragma mark - setShouldRightRotate90
- (void)setShouldRightRotate90:(BOOL)shouldRotate withTrackID:(NSInteger)trackID
{
    NSString *identifier = [NSString stringWithFormat:@"TrackID_%ld", (long)trackID];
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    if (shouldRotate)
    {
        [userDefaultes setBool:YES forKey:identifier];
    }
    else
    {
        [userDefaultes setBool:NO forKey:identifier];
    }
    
    [userDefaultes synchronize];
}

- (BOOL)shouldRightRotate90ByTrackID:(NSInteger)trackID
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *identifier = [NSString stringWithFormat:@"TrackID_%ld", (long)trackID];
    BOOL result = [[userDefaultes objectForKey:identifier] boolValue];
    NSLog(@"shouldRightRotate90ByTrackID %@ : %@", identifier, result?@"Yes":@"No");
    
    if (result)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

#pragma mark - shouldDisplayTextEffects
- (BOOL)shouldDisplayTextEffects
{
    NSString *flag = @"ShouldDisplayTextEffects";
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:flag] boolValue])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

#pragma mark - shouldDisplayGhost
- (BOOL)shouldDisplayGhost
{
    NSString *flag = @"ShouldDisplayGhost";
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:flag] boolValue])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

@end
