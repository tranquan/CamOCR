//
//  KJOverlayView.h
//  CamOCR
//
//  Created by Samael on 7/28/14.
//  Copyright (c) 2014 Samael. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface KJOverlayView : UIView

@property (nonatomic, assign) CGPoint pTopLeft;
@property (nonatomic, assign) CGPoint pTopRight;
@property (nonatomic, assign) CGPoint pBottomLeft;
@property (nonatomic, assign) CGPoint pBottomRight;

@property (nonatomic) UIFont *textFont;
@property (nonatomic) NSString *textGoodResult;
@property (nonatomic) NSString *textResult;
@property (nonatomic) NSString *meanConf;
@property (nonatomic) NSString *wordConfs;

- (void)resetPoints;
- (CGRect)focusRect;

@end
