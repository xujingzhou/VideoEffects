//
//  VideoThemes
//  VideoEffects
//
//  Created by Johnny Xu(徐景周) on 7/23/14.
//  Copyright (c) 2014 Future Stuido. All rights reserved.
//

#import "VideoThemes.h"

@implementation VideoThemes

@synthesize ID = _ID;
@synthesize thumbImageName = _thumbImageName;
@synthesize name = _name;
@synthesize textStar = _textStar;
@synthesize textSparkle = _textSparkle;
@synthesize textGradient = _textGradient;
@synthesize bgMusicFile = _bgMusicFile;
@synthesize imageFile = _imageFile;
@synthesize scrollText = _scrollText;
@synthesize animationImages = _animationImages;
@synthesize keyFrameTimes = _keyFrameTimes;
@synthesize filter = _filter;
@synthesize animationActions = _animationActions;

@synthesize imageVideoBorder = _imageVideoBorder;
@synthesize bgVideoFile = _bgVideoFile;

- (id)init
{
	if (self = [super init])
    {
        _ID = -1;
        _thumbImageName = nil;
        _name = nil;
        _textStar = nil;
        _textSparkle = nil;
        _textGradient = nil;
        _scrollText = nil;
        _bgMusicFile = nil;
        _imageFile = nil;
        _animationImages = nil;
        _keyFrameTimes = nil;
        _filter = nil;
        _animationActions = nil;
        
        _imageVideoBorder = nil;
        _bgVideoFile = nil;
	}
    
	return self;
}

- (void)dealloc
{
    if (_thumbImageName)
    {
        _thumbImageName = nil;
    }
    
    if (_name)
    {
        _name = nil;
    }
    
    if (_textStar)
    {
        _textStar = nil;
    }
    
    if (_textSparkle)
    {
        _textSparkle = nil;
    }
    
    if (_textGradient)
    {
        _textGradient = nil;
    }
    
    if (_bgMusicFile)
    {
        _bgMusicFile = nil;
    }
    
    if (_animationImages)
    {
        _animationImages = nil;
    }
    
    if (_keyFrameTimes)
    {
        _keyFrameTimes = nil;
    }
    
    if (_scrollText)
    {
        _scrollText = nil;
    }
    
    if (_animationActions)
    {
        _animationActions = nil;
    }
    
    if (_filter)
    {
        _filter = nil;
    }
    
    if (_imageVideoBorder)
    {
        _imageVideoBorder = nil;
    }
    
    if (_bgVideoFile)
    {
        _bgVideoFile = nil;
    }
}

@end
