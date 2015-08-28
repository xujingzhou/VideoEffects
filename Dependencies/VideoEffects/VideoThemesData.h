//
//  VideoThemesData.h
//  VideoEffects
//
//  Created by Johnny Xu(徐景周) on 8/11/14.
//  Copyright (c) 2014 Future Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoThemes.h"

// Effects
typedef enum
{
    kAnimationNone = 0,
    kAnimationFireworks,
    kAnimationSnow,
    kAnimationSnow2,
    kAnimationHeart,
    kAnimationRing,
    kAnimationStar,
    kAnimationMoveDot,
    kAnimationSky,
    kAnimationMeteor,
    kAnimationRain,
    kAnimationFlower,
    kAnimationFire,
    kAnimationSmoke,
    kAnimationSpark,
    kAnimationSteam,
    kAnimationBirthday,
    kAnimationBlackWhiteDot,
    kAnimationScrollScreen,
    kAnimationSpotlight,
    kAnimationScrollLine,
    kAnimationRipple,
    kAnimationImage,
    kAnimationImageArray,
    kAnimationVideoFrame,
    kAnimationTextStar,
    kAnimationTextSparkle,
    kAnimationTextScroll,
    kAnimationTextGradient,
    kAnimationFlashScreen,
    kAnimationVideoBorder,
    
} AnimationActionType;

// Themes
typedef enum
{
    kThemeNone = 0,
    
    kThemeMood,
    
    kThemeNostalgia,
    
    KThemeOldFilm,
    
} ThemesType;

@interface VideoThemesData : NSObject
{
    
}

+ (VideoThemesData *) sharedInstance;

- (VideoThemes*) getThemeByType:(ThemesType)themeType;

- (NSMutableDictionary*) getThemeData;
- (NSMutableDictionary*) getThemeFilter:(BOOL)fromSystemCamera;

@end
