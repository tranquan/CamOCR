//
//  KJCamPreviewView.m
//  CamOCR
//
//  Created by Samael on 7/27/14.
//  Copyright (c) 2014 Samael. All rights reserved.
//

#import "KJCamPreviewView.h"
#import <AVFoundation/AVFoundation.h>

@implementation KJCamPreviewView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {

    }
    return self;
}

- (void)initPreview
{
    AVCaptureVideoPreviewLayer *avLayer = (AVCaptureVideoPreviewLayer*)[self layer];
    avLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    avLayer.bounds = self.bounds;
    avLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}

+ (Class)layerClass
{
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session
{
    return [(AVCaptureVideoPreviewLayer*)[self layer] session];
}

- (void)setSession:(AVCaptureSession *)session
{
    [(AVCaptureVideoPreviewLayer *)[self layer] setSession:session];
}

@end
