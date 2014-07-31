//
//  KJViewController.m
//  CamOCR
//
//  Created by Samael on 7/27/14.
//  Copyright (c) 2014 Samael. All rights reserved.
//

#import "KJViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <mach/mach.h>

#import "KJCamPreviewView.h"
#import "KJOverlayView.h"
#import "Tesseract.h"

@interface KJViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, TesseractDelegate>

// UI
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet KJCamPreviewView *previewView;
@property (nonatomic, weak) IBOutlet KJOverlayView *overlayView;
@property (nonatomic, weak) IBOutlet UIButton *btnDict;
@property (nonatomic, weak) IBOutlet UIButton *btnReset;
@property (nonatomic, weak) IBOutlet UIButton *btnTesseract;

// Session management
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput *videoDataOutput;

// Ultilities
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;

// Tesseract
@property (nonatomic) UIImage *textImage;
@property (atomic, assign) BOOL tesseractReady;
@property (atomic, assign) BOOL tesseractRunning;

@end

@implementation KJViewController

- (BOOL)isSessionRunningAndDeviceAuthorized
{
    return [[self session] isRunning] && [self isDeviceAuthorized];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupCaptureSession];
    [self setupTesseract];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.overlayView resetPoints];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    logMemUsage();
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    return ![self lockInterfaceRotation];
}

#pragma mark - Actions

- (IBAction)btnDictClicked:(id)sender {
    
}

- (IBAction)btnResetClicked:(id)sender {
    [self.overlayView resetPoints];
}

- (IBAction)btnTesseractClicked:(id)sender {
    self.tesseractRunning = !self.tesseractRunning;
    if (self.tesseractRunning) {
        [self.btnTesseract setTitle:@"Pause" forState:UIControlStateNormal];
    } else {
        [self.btnTesseract setTitle:@"Start" forState:UIControlStateNormal];
    }
    [self.btnTesseract setNeedsDisplay];
}

#pragma mark - Tesseract

- (void)setupTesseract
{
    [[Tesseract sharedInstanced] setLanguage:@"chi_sim"];
    [[Tesseract sharedInstanced] setDelegate:self];
    self.tesseractReady = YES;
    self.tesseractRunning = YES;
}

- (void)recognizeImageWithTesseract
{
    if (self.textImage) {
        self.tesseractReady = NO;
        [[Tesseract sharedInstanced] setImage:self.textImage];
        if ([[Tesseract sharedInstanced] recognize]) {
            NSString *text = [[Tesseract sharedInstanced] recognizedText];
            NSInteger mean = [[Tesseract sharedInstanced] meanTextConfidence];
            NSArray *words = [[Tesseract sharedInstanced] allWordConfidences];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.overlayView.textResult = text;
                self.overlayView.meanConf = [NSString stringWithFormat:@"%ld", (long)mean];
                self.overlayView.wordConfs = [words componentsJoinedByString:@", "];
                if (mean > 50) {
                    self.overlayView.textGoodResult = text;
                }
                [self.overlayView setNeedsDisplay];
            });
        }
        self.tesseractReady = YES;
    }
}

#pragma mark Tesseract Delegate

- (BOOL)shouldCancelImageRecognitionForTesseract:(Tesseract *)tesseract
{
//    DLog(@"progress: %d", tesseract.progress);
    return NO;
}

#pragma mark - AVCapture

- (void)setupCaptureSession
{
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [self setSession:session];
    
    [self.previewView initPreview];
    [self.previewView setSession:session];
    [self checkDeviceAuthorizationStatus];
    
    dispatch_queue_t sessionQueue = dispatch_queue_create("session_queue", DISPATCH_QUEUE_SERIAL);
    [self setSessionQueue:sessionQueue];
    
    dispatch_async(sessionQueue, ^{

        // add video record
        NSError *error = nil;
        AVCaptureDevice *videoDevice = [KJViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if (error) {
            DLog(@"error: %@", error.description);
        }

        // set resolution
        if ([session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
            [session setSessionPreset:AVCaptureSessionPresetPhoto];
        }
        
        // input from camera
        if ([session canAddInput:videoDeviceInput]) {
            [session addInput:videoDeviceInput];
            [self setVideoDeviceInput:videoDeviceInput];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
            });
        }
        
        // add video data output
        dispatch_queue_t videoDataQueue = dispatch_queue_create("video_data_queue", NULL);
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        [videoDataOutput setSampleBufferDelegate:self queue:videoDataQueue];
        [videoDataOutput setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]}];
        if ([session canAddOutput:videoDataOutput]) {
            [session addOutput:videoDataOutput];
            AVCaptureConnection *connection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
            if (connection) {
                [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            }
            [self setVideoDataOutput:videoDataOutput];
        }
        
        [session startRunning];
    });
}

#pragma mark - Device Configuration

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *device = [self.videoDeviceInput device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode]) {
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode]) {
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        }
        else {
            DLog(@"%@", error.description);
        }
    });
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if ([device hasFlash] && [device isFlashModeSupported:flashMode]) {
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        }
        else {
            DLog("%@", error.description);
        }
    }
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}

#pragma mark - VideoDataOutputSampleBuffer Delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if (!self.tesseractRunning) return;
    
    static float ImageScreenRatio = 1.0;
    static bool MapToWidth = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
        float ScreenRat = ((float)self.view.bounds.size.height) / self.view.bounds.size.width;
        float ImageRat = ((float)image.size.height) / image.size.width;
        if (ImageRat > ScreenRat) {
            MapToWidth = YES;
            ImageScreenRatio = image.size.width / self.view.bounds.size.width;
        }
        else {
            ImageScreenRatio = image.size.height / self.view.bounds.size.height;
        }
    });
    
    static int c = 1;
    if (c++ % 33 == 0) {
        c = 1;
        UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
        CGRect rect = self.overlayView.focusRect;
        rect.origin.x *= ImageScreenRatio;
        rect.origin.y *= ImageScreenRatio;
        rect.size.width *= ImageScreenRatio;
        rect.size.height *= ImageScreenRatio;
        if (MapToWidth) {
            rect.origin.y += (image.size.height - (self.view.bounds.size.height * ImageScreenRatio))/2;
        }
        else {
            rect.origin.x += (image.size.width - (self.view.bounds.size.width * ImageScreenRatio))/2;
        }
        
        CGImageRef smallImgRef = CGImageCreateWithImageInRect(image.CGImage, rect);
        UIImage *smallImage = [UIImage imageWithCGImage:smallImgRef];
        CGImageRelease(smallImgRef);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.imageView setImage:smallImage];
        });
        
        if (self.tesseractReady) {
            self.textImage = [UIImage imageWithCGImage:smallImage.CGImage scale:2 orientation:UIImageOrientationUp];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                [self recognizeImageWithTesseract];
            });
        }
    }
}

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    uint8_t *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

#pragma mark - Helpers

- (void)checkDeviceAuthorizationStatus
{
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {

        [self setDeviceAuthorized:granted];
        
        if (!granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"AVCam!" message:@"AVCam doesn't have permission to use Camera" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            });
        }
    }];
}

vm_size_t usedMemory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0; // size in bytes
}

vm_size_t freeMemory(void) {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;
    
    host_page_size(host_port, &pagesize);
    (void) host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
    return vm_stat.free_count * pagesize;
}

void logMemUsage(void) {
    static long prevMemUsage = 0;
    long curMemUsage = usedMemory();
    long memUsageDiff = curMemUsage - prevMemUsage;
    
    if (memUsageDiff > 100000 || memUsageDiff < -100000) {
        prevMemUsage = curMemUsage;
        NSLog(@"Memory used %7.1f (%+5.0f), free %7.1f kb", curMemUsage/1000.0f, memUsageDiff/1000.0f, freeMemory()/1000.0f);
    }
}

@end
