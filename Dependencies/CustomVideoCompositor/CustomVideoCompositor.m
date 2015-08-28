//
//  CustomVideoCompositor
//  VideoEffects
//
//  Created by Johnny Xu(徐景周) on 5/30/15.
//  Copyright (c) 2015 Future Studio. All rights reserved.
//
@import  UIKit;
#import "CustomVideoCompositor.h"
#import <CoreImage/CoreImage.h>

@interface CustomVideoCompositor()


@end

@implementation CustomVideoCompositor

- (instancetype)init
{
    return self;
}

#pragma mark - startVideoCompositionRequest
- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
    NSMutableArray *videoArray = [[NSMutableArray alloc] init];
    CVPixelBufferRef destination = [request.renderContext newPixelBuffer];
    if (request.sourceTrackIDs.count > 0)
    {
        for (NSUInteger i = 0; i < [request.sourceTrackIDs count]; ++i)
        {
            CVPixelBufferRef videoBufferRef = [request sourceFrameByTrackID:[[request.sourceTrackIDs objectAtIndex:i] intValue]];
            if (videoBufferRef)
            {
                [videoArray addObject:(__bridge id)(videoBufferRef)];
            }
        }
        
        for (NSUInteger i = 0; i < [videoArray count]; ++i)
        {
            CVPixelBufferRef video = (__bridge CVPixelBufferRef)([videoArray objectAtIndex:i]);
            CVPixelBufferLockBaseAddress(video, kCVPixelBufferLock_ReadOnly);
        }
        CVPixelBufferLockBaseAddress(destination, 0);
        
        [self renderBuffer:videoArray toBuffer:destination];
        
        CVPixelBufferUnlockBaseAddress(destination, 0);
        for (NSUInteger i = 0; i < [videoArray count]; ++i)
        {
            CVPixelBufferRef video = (__bridge CVPixelBufferRef)([videoArray objectAtIndex:i]);
            CVPixelBufferUnlockBaseAddress(video, kCVPixelBufferLock_ReadOnly);
        }
    }
    
    [request finishWithComposedVideoFrame:destination];
    CVBufferRelease(destination);
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext
{
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

- (NSDictionary *)sourcePixelBufferAttributes
{
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

#pragma mark - renderBuffer
- (void)renderBuffer:(NSMutableArray *)videoBufferRefArray toBuffer:(CVPixelBufferRef)destination
{
    size_t width = CVPixelBufferGetWidth(destination);
    size_t height = CVPixelBufferGetHeight(destination);
    NSMutableArray *imageRefArray = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < [videoBufferRefArray count]; ++i)
    {
        CVPixelBufferRef videoFrame = (__bridge CVPixelBufferRef)([videoBufferRefArray objectAtIndex:i]);
        CGImageRef imageRef = [self createSourceImageFromBuffer:videoFrame];
        if (imageRef)
        {
            if ([self shouldRightRotate90ByTrackID:i+1])
            {
                // Right rotation 90
                imageRef = CGImageRotated(imageRef, M_PI_2);
            }
            
            [imageRefArray addObject:(__bridge id)(imageRef)];
        }
        CGImageRelease(imageRef);
    }
    
    if ([imageRefArray count] < 2)
    {
        NSLog(@"imageRefArray is empty.");
        return;
    }
    
    CGContextRef gc = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(destination), width, height, 8, CVPixelBufferGetBytesPerRow(destination), CGImageGetColorSpace((CGImageRef)imageRefArray[0]), CGImageGetBitmapInfo((CGImageRef)imageRefArray[0]));
    
    CGRect rectVideo = CGRectZero;
    rectVideo.size = CGSizeMake(width, height);
    
    // Background video
    CGContextDrawImage(gc, rectVideo, (CGImageRef)imageRefArray[0]);
    
    
    // Face detection
    NSMutableArray *faceRects = [[NSMutableArray alloc] init];
//    CIImage* image = [CIImage imageWithCGImage:(CGImageRef)imageRefArray[0]];
//    NSDictionary  *opts = [NSDictionary dictionaryWithObject:CIDetectorAccuracyHigh
//                                                      forKey:CIDetectorAccuracy];
//    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
//                                              context:nil
//                                              options:opts];
//    
//    NSArray* features = [detector featuresInImage:image];
//    for (CIFaceFeature *face in features)
//    {
//        CGRect faceRect = face.bounds;
//        NSLog(@"faceRect.x: %f, faceRect.y: %f, faceRect.width: %f, faceRect.height: %f", faceRect.origin.x, faceRect.origin.y, faceRect.size.width, faceRect.size.height);
//        
//        [faceRects addObject:[NSValue valueWithCGRect:faceRect]];
//    }
    
    
    // Foreground video
    [self addPath:gc width:width height:height faceRects:faceRects needCalc:YES];
    CGContextClip(gc);
    CGContextDrawImage(gc, rectVideo, (CGImageRef)imageRefArray[1]);
    
    if ([self shouldDisplayInnerBorder])
    {
        [self addPath:gc width:width height:height faceRects:faceRects needCalc:NO];
        CGContextDrawPath(gc, kCGPathStroke);
        if (!CGContextIsPathEmpty(gc))
        {
            CGContextClip(gc);
        }
    }
    
    CGContextRelease(gc);
}

#pragma mark - createSourceImageFromBuffer
- (CGImageRef)createSourceImageFromBuffer:(CVPixelBufferRef)buffer
{
    size_t width = CVPixelBufferGetWidth(buffer);
    size_t height = CVPixelBufferGetHeight(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    void *data = CVPixelBufferGetBaseAddress(buffer);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, height * stride, NULL);
    CGImageRef image = CGImageCreate(width, height, 8, 32, stride, rgb, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast, provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(rgb);
    
    return image;
}

#pragma mark - CGImageRotated
CGImageRef CGImageRotated(CGImageRef originalCGImage, double radians)
{
    CGSize imageSize = CGSizeMake(CGImageGetWidth(originalCGImage), CGImageGetHeight(originalCGImage));
    CGSize rotatedSize;
    if (radians == M_PI_2 || radians == -M_PI_2)
    {
        rotatedSize = CGSizeMake(imageSize.height, imageSize.width);
    }
    else
    {
        rotatedSize = imageSize;
    }
    
    double rotatedCenterX = rotatedSize.width / 2.f;
    double rotatedCenterY = rotatedSize.height / 2.f;
    
//    //bitmap context properties
//    CGSize size = imageSize;
//    NSUInteger bytesPerPixel = 4;
//    NSUInteger bytesPerRow = bytesPerPixel * size.width;
//    NSUInteger bitsPerComponent = 8;
//    
//    //create bitmap context
//    unsigned char *rawData = malloc(size.height * size.width * 4);
//    memset(rawData, 0, size.height * size.width * 4);
//    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//    CGContextRef rotatedContext = CGBitmapContextCreate(rawData, size.width, size.height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

    
    UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, 1.f);
    CGContextRef rotatedContext = UIGraphicsGetCurrentContext();
    if (radians == 0.f || radians == M_PI)
    {
        // 0 or 180 degrees
        CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
        if (radians == 0.0f)
        {
            CGContextScaleCTM(rotatedContext, 1.f, -1.f);
        }
        else
        {
            CGContextScaleCTM(rotatedContext, -1.f, 1.f);
        }
        CGContextTranslateCTM(rotatedContext, -rotatedCenterX, -rotatedCenterY);
    }
    else if (radians == M_PI_2 || radians == -M_PI_2)
    {
        // +/- 90 degrees
        CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
        CGContextRotateCTM(rotatedContext, radians);
        CGContextScaleCTM(rotatedContext, 1.f, -1.f);
        CGContextTranslateCTM(rotatedContext, -rotatedCenterY, -rotatedCenterX);
    }
    
    CGRect drawingRect = CGRectMake(0.f, 0.f, imageSize.width, imageSize.height);
    CGContextDrawImage(rotatedContext, drawingRect, originalCGImage);
    CGImageRef rotatedCGImage = CGBitmapContextCreateImage(rotatedContext);
    
    UIGraphicsEndImageContext();
    
//    CGColorSpaceRelease(colorSpace);
//    CGContextRelease(rotatedContext);
//    free(rawData);
    
    return rotatedCGImage;
}

static CGFloat startX = 50, startY = 50, signX = 1, signY = 1;
- (void)addPath:(CGContextRef)gc width:(CGFloat)width height:(CGFloat)height faceRects:(NSMutableArray*)faceRects needCalc:(BOOL)needCalc
{
//    CGContextSaveGState(gc);
//    CGSize shadowOffset = CGSizeMake (-15,  20);
//    CGContextSetShadow (gc, shadowOffset, 5);
    
    CGFloat whiteColor[4] = {1.0, 1.0, 1.0, 1.0};
    CGContextSetStrokeColor(gc, whiteColor);
    CGContextSetLineWidth(gc, 2);
    CGContextSetShouldAntialias(gc, YES);
    
    CGContextBeginPath(gc);
    if (faceRects && [faceRects count] > 1)
    {
        for (int i = 0; i < [faceRects count]; ++i)
        {
            CGRect faceRect = [faceRects[i] CGRectValue];
            CGPathRef strokeRect = [UIBezierPath bezierPathWithRoundedRect:faceRect cornerRadius:10.f].CGPath;
            CGContextAddPath(gc, strokeRect);
        }
    }
    else
    {
        CGFloat minValue = MIN(width, height);
        CGFloat ovalWidth = minValue * 2/3;
        if (needCalc)
        {
            CGFloat offsetX = 5, offsetY = 3;
            startX = startX - signX*offsetX;
            if (startX <= 0)
            {
                signX = -signX;
                startX = 0;
            }
            else if ((startX + ovalWidth) >= width)
            {
                signX = -signX;
                startX = width - ovalWidth;
            }
            
            startY = startY - signY*offsetY;
            if (startY <= 0)
            {
                signY = -signY;
                startY = 0;
            }
            else if ((startY + ovalWidth) >= height)
            {
                signY = -signY;
                startY = height - ovalWidth;
            }
        }
        
        if ([self shouldDisplayPloygon])
        {
            CGPathRef strokeRect = [self pathForPolygon:CGRectMake(startX, startY, ovalWidth, ovalWidth)].CGPath;
            CGContextAddPath(gc, strokeRect);
        }
        else
        {
            CGPathRef strokeRect = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(startX, startY, ovalWidth, ovalWidth)].CGPath;
            CGContextAddPath(gc, strokeRect);
        }
    }
    
//    CGContextRestoreGState(gc);
}

#pragma mark - pathForPolygon
- (UIBezierPath *)pathForPolygon:(CGRect)bounds
{
    NSInteger numberOfEdges = 16;
    CGFloat innerRadiusRatio = 0.75;
    CGFloat inset = 1.0f;
    return [self pathForPolygon:inset withBounds:bounds withNumberOfEdges:numberOfEdges withInnerRadiusRatio:innerRadiusRatio];
}

- (UIBezierPath *)pathForPolygon:(CGFloat)inset withBounds:(CGRect)bounds withNumberOfEdges:(NSInteger)numberOfEdges withInnerRadiusRatio:(CGFloat)innerRadiusRatio
{
    CGPoint center = CGPointMake(CGRectGetMinX(bounds) + CGRectGetWidth(bounds)/2, CGRectGetMinY(bounds) + CGRectGetHeight(bounds)/2);
    CGFloat outerRadius = MIN(bounds.size.width, bounds.size.height) / 2.0 - inset;
    CGFloat innerRadius = outerRadius * innerRadiusRatio;
    CGFloat angle = M_PI * 2.0 / (numberOfEdges * 2);
    UIBezierPath *path = [UIBezierPath bezierPath];
    
    for (NSInteger cc = 0; cc < numberOfEdges; cc++)
    {
        CGPoint p0 = CGPointMake(center.x + outerRadius * cos(angle * (cc*2)), center.y + outerRadius * sin(angle * (cc*2)));
        CGPoint p1 = CGPointMake(center.x + innerRadius * cos(angle * (cc*2+1)), center.y + innerRadius * sin(angle * (cc*2+1)));
        
        if (cc == 0)
        {
            [path moveToPoint: p0];
        }
        else
        {
            [path addLineToPoint: p0];
        }
        
        [path addLineToPoint: p1];
    }
    [path closePath];
    
    return path;
}

#pragma mark - drawBorderInFrame
- (void)drawBorderInFrames:(NSArray *)frames withContextRef:(CGContextRef)contextRef
{
    if (!frames || [frames count] < 1)
    {
        NSLog(@"drawBorderInFrames is empty.");
        return;
    }
    
    if ([self shouldDisplayInnerBorder])
    {
        // Fill background
        CGContextSetFillColorWithColor(contextRef, [UIColor whiteColor].CGColor);
        CGContextFillRect(contextRef, [frames[0] CGRectValue]);
        
        // Draw
        CGContextBeginPath(contextRef);
        CGFloat lineWidth = 5;
        for (int i = 1; i < [frames count]; ++i)
        {
            CGRect innerVideoRect = [frames[i] CGRectValue];
            if (!CGRectIsEmpty(innerVideoRect))
            {
                CGContextAddRect(contextRef, CGRectInset(innerVideoRect, lineWidth, lineWidth));
            }
        }
        CGContextClip(contextRef);
    }
}

#pragma mark - getCroppedRect
- (CGRect)getCroppedRect
{
    NSArray *pointsPath = [self getPathPoints];
    return getCroppedBounds(pointsPath);
}

#pragma mark - NSUserDefaults
#pragma mark - PathPoints
- (NSArray *)getPathPoints
{
    NSArray *arrayResult = nil;
    NSString *flag = @"ArrayPathPoints";
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSData *dataPathPoints = [userDefaultes objectForKey:flag];
    if (dataPathPoints)
    {
        arrayResult = [NSKeyedUnarchiver unarchiveObjectWithData:dataPathPoints];
//        if (arrayResult && [arrayResult count] > 0)
//        {
//             NSLog(@"points has content.");
//        }
    }
    else
    {
//        NSLog(@"getPathPoints is empty.");
    }
    
    return arrayResult;
}

- (NSArray *)getArrayRects
{
    NSString *flag = @"arrayRect";
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSData *dataRect = [userDefaultes objectForKey:flag];
    NSArray *arrayResult = nil;
    if (dataRect)
    {
        arrayResult = [NSKeyedUnarchiver unarchiveObjectWithData:dataRect];
        if (arrayResult && [arrayResult count] > 0)
        {
//            CGRect innerVideoRect = [arrayResult[0] CGRectValue];
//            if (!CGRectIsEmpty(innerVideoRect))
//            {
//                NSLog(@"[arrayResult[0] CGRectValue: %@", NSStringFromCGRect(innerVideoRect));
//            }
        }
        else
        {
            NSLog(@"getArrayRects is empty!");
        }
    }
    
    return arrayResult;
}

- (void)setArrayRects:(NSMutableArray *)arrayRect
{
    // Embeded Video Frame
    NSString *flag = @"arrayRect";
    NSData *dataRect = [NSKeyedArchiver archivedDataWithRootObject:arrayRect];
    [[NSUserDefaults standardUserDefaults] setObject:dataRect forKey:flag];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - OutputBGColor
- (UIColor *)getOutputBGColor
{
    NSString *flag = @"OutputBGColor";
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSData *objColor = [userDefaultes objectForKey:flag];
    UIColor *bgColor = nil;
    if (objColor)
    {
        bgColor = [NSKeyedUnarchiver unarchiveObjectWithData:objColor];
    }
    return bgColor;
}

#pragma mark - shouldDisplayInnerBorder
- (BOOL)shouldDisplayInnerBorder
{
    NSString *flag = @"ShouldDisplayInnerBorder";
//    NSLog(@"shouldDisplayInnerBorder: %@", [[[NSUserDefaults standardUserDefaults] objectForKey:shouldDisplayInnerBorder] boolValue]?@"Yes":@"No");
    
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:flag] boolValue])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

#pragma mark - ShouldDisplayPloygon
- (BOOL)shouldDisplayPloygon
{
    NSString *flag = @"ShouldDisplayPloygon";
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    if ([[userDefaultes objectForKey:flag] boolValue])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

#pragma mark - shouldRightRotate90ByTrackID
- (BOOL)shouldRightRotate90ByTrackID:(NSInteger)trackID
{
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    NSString *identifier = [NSString stringWithFormat:@"TrackID_%ld", (long)trackID];
    BOOL result = [[userDefaultes objectForKey:identifier] boolValue];
//    NSLog(@"shouldRightRotate90ByTrackID %@ : %@", identifier, result?@"Yes":@"No");
    
    if (result)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

@end
