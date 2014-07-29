//
//  KJCamPreviewView.h
//  CamOCR
//
//  Created by Samael on 7/27/14.
//  Copyright (c) 2014 Samael. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVCaptureSession;

@interface KJCamPreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

- (void)initPreview;

@end
