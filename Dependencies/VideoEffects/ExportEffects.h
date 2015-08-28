//
//  ExportEffects
//  VideoEffects
//
//  Created by Johnny Xu(徐景周) on 5/30/15.
//  Copyright (c) 2015 Future Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "VideoThemesData.h"

typedef NSString *(^JZOutputFilenameBlock)();
typedef void (^JZFinishVideoBlock)(BOOL success, id result);
typedef void (^JZExportProgressBlock)(NSNumber *percentage, NSString *title);

#define TrackIDCustom 1

@interface ExportEffects : NSObject

@property (copy, nonatomic) JZFinishVideoBlock finishVideoBlock;
@property (copy, nonatomic) JZExportProgressBlock exportProgressBlock;
@property (copy, nonatomic) JZOutputFilenameBlock filenameBlock;

@property (assign, nonatomic) ThemesType themeCurrentType;

+ (ExportEffects *)sharedInstance;

- (void)addEffectToVideo:(NSString *)videoFilePath withAudioFilePath:(NSString *)audioFilePath;
- (void)writeExportedVideoToAssetsLibrary:(NSString *)outputPath;

@end
