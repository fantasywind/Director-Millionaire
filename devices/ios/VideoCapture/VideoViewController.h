//
//  VideoViewController.h
//  VideoCapture
//
//  Created by Yen Shau shan on 13/11/9.
//  Copyright (c) 2013年 Yen Shau shan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface VideoViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (copy,   nonatomic) NSURL *movieURL;
//@property (strong, nonatomic) MPMoviePlayerController *movieController;

- (IBAction)takeVideo:(UIButton *)sender;
- (void)captureSession;
-(void) captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection;
- (NSData*) imageToBuffer: (CMSampleBufferRef)source;
@end
