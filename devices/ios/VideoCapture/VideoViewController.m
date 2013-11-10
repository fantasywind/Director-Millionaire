//
//  VideoViewController.m
//  VideoCapture
//
//  Created by Yen Shau shan on 13/11/9.
//  Copyright (c) 2013年 Yen Shau shan. All rights reserved.
//

#import "VideoViewController.h"

@interface VideoViewController ()

@end

@implementation VideoViewController


- (void)viewDidLoad {
    
    [super viewDidLoad];
    
}

- (void)captureSession
{
    // make input device
    NSError *deviceError;
    AVCaptureDevice *cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&deviceError];
    
    // make output device
    AVCaptureVideoDataOutput *outputDevice = [[AVCaptureVideoDataOutput alloc] init];
    [outputDevice setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    // initialize capture session
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    [captureSession addInput:inputDevice];
    [captureSession addOutput:outputDevice];
    
    // make preview layer and add so that camera's view is displayed on screen
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:previewLayer];
    
    // go!
    [captureSession startRunning];
}

-(void) captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
    CGSize imageSize = CVImageBufferGetEncodedSize( imageBuffer );
    // also in the 'mediaSpecific' dict of the sampleBuffer
    
    //NSData *data =
    
    NSLog( @"frame captured at %.fx%.f", imageSize.width, imageSize.height );
}

- (NSData*) imageToBuffer: (CMSampleBufferRef) source {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(source);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    void *src_buff = CVPixelBufferGetBaseAddress(imageBuffer);
    
    NSData *data = [NSData dataWithBytes:src_buff length:bytesPerRow * height];
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    return data;
}

- (void)viewDidAppear:(BOOL)animated {
    
    [self captureSession];
    
}

- (IBAction)takeVideo:(UIButton *)sender {
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeMovie, nil];
    
    [self presentViewController:picker animated:YES completion:NULL];
    
}


@end

