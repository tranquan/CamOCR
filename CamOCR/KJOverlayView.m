//
//  KJOverlayView.m
//  CamOCR
//
//  Created by Samael on 7/28/14.
//  Copyright (c) 2014 Samael. All rights reserved.
//

#import "KJOverlayView.h"
#import <QuartzCore/QuartzCore.h>

CGFloat const AnchorPointRadius = 4;
CGFloat const CenterPointRadius = 4;
CGFloat LineR = 0, LineG = 1, LineB = 0;
NSInteger AnchorPosition;
CGPoint AnchorPoint;

@implementation KJOverlayView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}

- (void)awakeFromNib
{
    self.opaque = NO;
    
    UILongPressGestureRecognizer *pressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
    pressGesture.minimumPressDuration = 0.45;
    [self addGestureRecognizer:pressGesture];
}

- (void)resetPoints
{
    self.pTopLeft = CGPointMake(CGRectGetMidX(self.bounds) - 80, CGRectGetMidY(self.bounds) - 24 - 32);
    self.pTopRight = CGPointMake(CGRectGetMidX(self.bounds) + 80, CGRectGetMidY(self.bounds) - 24 - 32);
    self.pBottomLeft = CGPointMake(CGRectGetMidX(self.bounds) - 80, CGRectGetMidY(self.bounds) + 24 - 32);
    self.pBottomRight = CGPointMake(CGRectGetMidX(self.bounds) + 80, CGRectGetMidY(self.bounds) + 24 - 32);
    [self setNeedsDisplay];
}

- (CGRect)focusRect
{
    return CGRectMake(self.pTopLeft.x, self.pTopLeft.y,
                      self.pTopRight.x-self.pTopLeft.x,
                      self.pBottomLeft.y-self.pTopLeft.y);
}

- (void)drawRect:(CGRect)rect
{
    // get context
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);

    // draw shadow
    CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0.0 alpha:0.6].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, self.bounds.size.width, self.pTopLeft.y));
    CGContextFillRect(context, CGRectMake(0, self.pTopLeft.y, self.pTopLeft.x, self.pBottomLeft.y-self.pTopLeft.y));
    CGContextFillRect(context, CGRectMake(self.pTopRight.x, self.pTopRight.y,
                                          self.bounds.size.width-self.pTopRight.x, self.pBottomLeft.y-self.pTopLeft.y));
    CGContextFillRect(context, CGRectMake(0, self.pBottomLeft.y, self.bounds.size.width, self.bounds.size.height-self.pBottomLeft.y));
    
    // draw frame
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:LineR green:LineG blue:LineB alpha:1].CGColor);
    
    CGContextMoveToPoint(context, self.pBottomLeft.x, self.pTopLeft.y);
    CGContextStrokeRect(context, CGRectMake(self.pTopLeft.x, self.pTopLeft.y,
                                            self.pTopRight.x-self.pTopLeft.x,
                                            self.pBottomLeft.y-self.pTopLeft.y));
    
    // draw anchor points
    CGContextSetFillColorWithColor(context, [UIColor greenColor].CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(self.pTopLeft.x-AnchorPointRadius, self.pTopLeft.y-AnchorPointRadius,
                                                   AnchorPointRadius+AnchorPointRadius, AnchorPointRadius+AnchorPointRadius));
    CGContextFillEllipseInRect(context, CGRectMake(self.pTopRight.x-AnchorPointRadius, self.pTopRight.y-AnchorPointRadius,
                                                   AnchorPointRadius+AnchorPointRadius, AnchorPointRadius+AnchorPointRadius));
    CGContextFillEllipseInRect(context, CGRectMake(self.pBottomLeft.x-AnchorPointRadius, self.pBottomLeft.y-AnchorPointRadius,
                                                   AnchorPointRadius+AnchorPointRadius, AnchorPointRadius+AnchorPointRadius));
    CGContextFillEllipseInRect(context, CGRectMake(self.pBottomRight.x-AnchorPointRadius, self.pBottomRight.y-AnchorPointRadius,
                                                   AnchorPointRadius+AnchorPointRadius, AnchorPointRadius+AnchorPointRadius));
    // draw center point
    CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
    CGContextFillEllipseInRect(context, CGRectMake((self.pTopLeft.x+self.pTopRight.x)/2-4, (self.pTopLeft.y+self.pBottomLeft.y)/2-4,
                                                   AnchorPointRadius+AnchorPointRadius, AnchorPointRadius+AnchorPointRadius));
    
    // draw text
    if (self.textResult.length > 0) {
        CGContextSetFillColorWithColor(context, [UIColor yellowColor].CGColor);
        CGContextSetTextMatrix(context, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
        CGContextSelectFont(context, "Helvetica", 12.0, kCGEncodingMacRoman);
        CGContextSetCharacterSpacing(context, 1.7);
        CGContextSetTextDrawingMode(context, kCGTextFill);
        CGContextShowTextAtPoint(context, self.pBottomLeft.x, self.pBottomLeft.y + 24, self.textResult.UTF8String, 12);
    }
}

- (void)handlePress:(UILongPressGestureRecognizer *)gesture
{
    CGPoint touch = [gesture locationInView:self];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        
        CGFloat distance = 20;
        int anchor = -1;
        if ([self distanceFromPoint:touch toPoint:self.pTopLeft] < distance) {
            anchor = 1;
            AnchorPoint = self.pTopLeft;
        }
        else if ([self distanceFromPoint:touch toPoint:self.pTopRight] < distance) {
            anchor = 2;
            AnchorPoint = self.pTopRight;
        }
        else if ([self distanceFromPoint:touch toPoint:self.pBottomLeft] < distance) {
            anchor = 3;
            AnchorPoint = self.pBottomLeft;
        }
        else if ([self distanceFromPoint:touch toPoint:self.pBottomRight] < distance) {
            anchor = 4;
            AnchorPoint = self.pBottomRight;
        }
        else if ([self distanceFromPoint:touch toPoint:[self centerPoint]] < distance) {
            anchor = 5;
            AnchorPoint = [self centerPoint];
        }
        
        if (anchor > 0) {
            LineR = 1; LineG = 0; LineB = 0;
            AnchorPosition = anchor;
            [self setNeedsDisplay];
        }
    }
    else if (gesture.state == UIGestureRecognizerStateChanged) {
        
        if (AnchorPoint.x > 0 && AnchorPoint.y > 0) {
            
            if (AnchorPosition == 5)
            {
                float dx = touch.x - AnchorPoint.x;
                float dy = touch.y - AnchorPoint.y;
                
                AnchorPoint = touch;
                self.pTopLeft = CGPointMake(self.pTopLeft.x+dx, self.pTopLeft.y+dy);
                self.pTopRight = CGPointMake(self.pTopRight.x+dx, self.pTopRight.y+dy);
                self.pBottomLeft = CGPointMake(self.pBottomLeft.x+dx, self.pBottomLeft.y+dy);
                self.pBottomRight = CGPointMake(self.pBottomRight.x+dx, self.pBottomRight.y+dy);
                
                [self setNeedsDisplay];
            }
            else
            {
                float dx = touch.x - AnchorPoint.x;
                float dy = touch.y - AnchorPoint.y;
                CGRect guide = CGRectMake(self.pTopLeft.x, self.pTopLeft.y,
                                          self.pTopRight.x-self.pTopLeft.x,
                                          self.pBottomLeft.y-self.pTopLeft.y);
                
                if (AnchorPoint.x < CGRectGetMidX(guide)) dx = -dx;
                if (AnchorPoint.y < CGRectGetMidY(guide)) dy = -dy;
                
                if ((self.pTopRight.x+dx) - (self.pTopLeft.x-dx) > 80 &&
                    (self.pBottomLeft.y+dy) - (self.pTopLeft.y-dy) > 36)
                {
                    AnchorPoint = touch;
                    self.pTopLeft = CGPointMake(self.pTopLeft.x-dx, self.pTopLeft.y-dy);
                    self.pTopRight = CGPointMake(self.pTopRight.x+dx, self.pTopRight.y-dy);
                    self.pBottomLeft = CGPointMake(self.pBottomLeft.x-dx, self.pBottomLeft.y+dy);
                    self.pBottomRight = CGPointMake(self.pBottomRight.x+dx, self.pBottomRight.y+dy);
                    
                    [self setNeedsDisplay];
                }
            }
        }
    }
    else {
        LineR = 0; LineG = 1; LineB = 0;
        AnchorPosition = -1;
        AnchorPoint = CGPointMake(-1000, -1000);
        [self setNeedsDisplay];
    }
}

#pragma Helpers

- (CGPoint)centerPoint
{
    return CGPointMake((self.pTopLeft.x+self.pTopRight.x)/2, (self.pTopLeft.y+self.pBottomLeft.y)/2);
}

- (CGFloat)distanceFromPoint:(CGPoint)p1 toPoint:(CGPoint)p2
{
    return sqrtf((p2.x-p1.x)*(p2.x-p1.x) + (p2.y-p1.y)*(p2.y-p1.y));
}

@end
