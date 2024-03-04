/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVSplashScreen.h"
#import <Cordova/CDVViewController.h>
#import <Cordova/CDVScreenOrientationDelegate.h>
#import "CDVViewController+SplashScreen.h"

#define kSplashScreenDurationDefault 3000.0f
#define kFadeDurationDefault 500.0f

@implementation CDVSplashScreen

- (void)pluginInitialize
{
    NSLog(@"[RAD] splashscreen - pluginInitialize+++++");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoad) name:CDVPageDidLoadNotification object:nil];

    [self createSplashView];
}

- (void)createSplashView
{
    NSLog(@"[RAD] createSplashView ++++++.");
    UIView* parentView = self.viewController.view;
    
    CGRect webViewBounds = self.viewController.view.bounds;
    webViewBounds.origin = self.viewController.view.bounds.origin;
    UIView* view = [[UIView alloc] initWithFrame:webViewBounds];
    [view setAlpha:0];

    NSString* launchStoryboardName = @"SplashScreen";
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:launchStoryboardName bundle:[NSBundle mainBundle]];
    UIViewController* vc = [storyboard instantiateViewControllerWithIdentifier:@"SplashScreenController"];
    _splashView = vc.view;
    
    [self _show];
}

- (void)show:(CDVInvokedUrlCommand*)command
{
    [self _show];
}

- (void)_show
{
    NSLog(@"[RAD] splashscreen - _show+++++");
//    [self setVisible:YES];
    UIView* parentView = self.viewController.view;
    parentView.userInteractionEnabled = NO;  // disable user interaction while splashscreen is shown
    [parentView addSubview:_splashView];
}

- (void)hide:(CDVInvokedUrlCommand*)command
{
    [self _hide];
}

- (void)_hide
{
    NSLog(@"[RAD] splashscreen - _hide+++++");
//    return;
    id fadeSplashScreenDuration = [self.commandDelegate.settings objectForKey:[@"FadeSplashScreenDuration" lowercaseString]];
    CGFloat fadeDuration = fadeSplashScreenDuration == nil ? kFadeDurationDefault : [fadeSplashScreenDuration floatValue];
    fadeDuration = fadeDuration < 250 ? 250 : fadeDuration;
    fadeDuration = fadeDuration / 1000;
    [UIView animateWithDuration:fadeDuration animations:^{
        [self->_splashView setAlpha:0];
    }];
    [_splashView removeFromSuperview];
//    _splashView = nil;

    UIView* parentView = self.viewController.view;
    parentView.userInteractionEnabled = YES;  // disable user interaction while splashscreen is shown
}

- (void)pageDidLoad
{
    NSLog(@"[RAD] splashscreen - pageDidLoad+++++");
    id autoHideSplashScreenValue = [self.commandDelegate.settings objectForKey:[@"AutoHideSplashScreen" lowercaseString]];

    // if value is missing, default to yes
    if ((autoHideSplashScreenValue == nil) || [autoHideSplashScreenValue boolValue]) {
        // hide
    }
}

- (CDV_iOSDevice) getCurrentDevice
{
    CDV_iOSDevice device;

    UIScreen* mainScreen = [UIScreen mainScreen];
    CGFloat mainScreenHeight = mainScreen.bounds.size.height;
    CGFloat mainScreenWidth = mainScreen.bounds.size.width;

    int limit = MAX(mainScreenHeight,mainScreenWidth);

    device.iPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    device.iPhone = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
    device.retina = ([mainScreen scale] == 2.0);
    device.iPhone4 = (device.iPhone && limit == 480.0);
    device.iPhone5 = (device.iPhone && limit == 568.0);
    // note these below is not a true device detect, for example if you are on an
    // iPhone 6/6+ but the app is scaled it will prob set iPhone5 as true, but
    // this is appropriate for detecting the runtime screen environment
    device.iPhone6 = (device.iPhone && limit == 667.0);
    device.iPhone6Plus = (device.iPhone && limit == 736.0);
    device.iPhoneX  = (device.iPhone && limit == 812.0);

    return device;
}

- (UIInterfaceOrientation)getCurrentOrientation
{
    UIInterfaceOrientation iOrientation = [UIApplication sharedApplication].statusBarOrientation;
    UIDeviceOrientation dOrientation = [UIDevice currentDevice].orientation;

    bool landscape;

    if (dOrientation == UIDeviceOrientationUnknown || dOrientation == UIDeviceOrientationFaceUp || dOrientation == UIDeviceOrientationFaceDown) {
        // If the device is laying down, use the UIInterfaceOrientation based on the status bar.
        landscape = UIInterfaceOrientationIsLandscape(iOrientation);
    } else {
        // If the device is not laying down, use UIDeviceOrientation.
        landscape = UIDeviceOrientationIsLandscape(dOrientation);

        // There's a bug in iOS!!!! http://openradar.appspot.com/7216046
        // So values needs to be reversed for landscape!
        if (dOrientation == UIDeviceOrientationLandscapeLeft)
        {
            iOrientation = UIInterfaceOrientationLandscapeRight;
        }
        else if (dOrientation == UIDeviceOrientationLandscapeRight)
        {
            iOrientation = UIInterfaceOrientationLandscapeLeft;
        }
        else if (dOrientation == UIDeviceOrientationPortrait)
        {
            iOrientation = UIInterfaceOrientationPortrait;
        }
        else if (dOrientation == UIDeviceOrientationPortraitUpsideDown)
        {
            iOrientation = UIInterfaceOrientationPortraitUpsideDown;
        }
    }

    return iOrientation;
}

- (void)setVisible:(BOOL)visible
{
    [self setVisible:visible andForce:NO];
}

- (void)setVisible:(BOOL)visible andForce:(BOOL)force
{
    return;
    NSLog(@"[RAD] setVisible++++ %b", visible);
    if (visible != _visible || force)
    {
        _visible = visible;

        id fadeSplashScreenValue = [self.commandDelegate.settings objectForKey:[@"FadeSplashScreen" lowercaseString]];
        id fadeSplashScreenDuration = [self.commandDelegate.settings objectForKey:[@"FadeSplashScreenDuration" lowercaseString]];

        float fadeDuration = fadeSplashScreenDuration == nil ? kFadeDurationDefault : [fadeSplashScreenDuration floatValue];

        id splashDurationString = [self.commandDelegate.settings objectForKey: [@"SplashScreenDelay" lowercaseString]];
        float splashDuration = splashDurationString == nil ? kSplashScreenDurationDefault : [splashDurationString floatValue];

        id autoHideSplashScreenValue = [self.commandDelegate.settings objectForKey:[@"AutoHideSplashScreen" lowercaseString]];
        BOOL autoHideSplashScreen = true;

        if (autoHideSplashScreenValue != nil) {
            autoHideSplashScreen = [autoHideSplashScreenValue boolValue];
        }

        if (!autoHideSplashScreen) {
            // CB-10412 SplashScreenDelay does not make sense if the splashscreen is hidden manually
            splashDuration = 0;
        }


        if (fadeSplashScreenValue == nil)
        {
            fadeSplashScreenValue = @"true";
        }

        if (![fadeSplashScreenValue boolValue])
        {
            fadeDuration = 0;
        }
        else if (fadeDuration < 30)
        {
            // [CB-9750] This value used to be in decimal seconds, so we will assume that if someone specifies 10
            // they mean 10 seconds, and not the meaningless 10ms
            fadeDuration *= 1000;
        }

        if (_visible)
        {
            // unused show
        }
        else
        {
            // 기존 hide 참고
            __weak __typeof(self) weakSelf = self;
            float effectiveSplashDuration;

            // [CB-10562] AutoHideSplashScreen may be "true" but we should still be able to hide the splashscreen manually.
            if (!autoHideSplashScreen || force) {
                effectiveSplashDuration = (fadeDuration) / 1000;
            } else {
                effectiveSplashDuration = (splashDuration - fadeDuration) / 1000;
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (uint64_t) effectiveSplashDuration * NSEC_PER_SEC), dispatch_get_main_queue(), CFBridgingRelease(CFBridgingRetain(^(void) {
                if (!_destroyed) {
                    [UIView transitionWithView:self.viewController.view
                                    duration:(fadeDuration / 1000)
                                    options:UIViewAnimationOptionTransitionNone
                                    animations:^(void) {
                                        // hide
                                    }
                                    completion:^(BOOL finished) {
                                        // Always destroy views, otherwise you could have an
                                        // invisible splashscreen that is overlayed over your active views
                                        // which causes that no touch events are passed
                                        if (!_destroyed) {
                                            // destroy
                                            // TODO: It might also be nice to have a js event happen here -jm
                                        }
                                    }
                    ];
                }
            })));
        }
    }
}

@end
