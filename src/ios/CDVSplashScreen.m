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
#import "CDVSplashScreenADLoader.h"

#define kSplashScreenDurationDefault 3000.0f
#define kFadeDurationDefault 500.0f

@implementation CDVSplashScreen

- (void)pluginInitialize
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoad) name:CDVPageDidLoadNotification object:nil];

    [self createSplashView];
}

- (void)createSplashView
{
    NSString* launchStoryboardName = @"SplashScreen";
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:launchStoryboardName bundle:[NSBundle mainBundle]];
    UIViewController* vc = [storyboard instantiateViewControllerWithIdentifier:@"SplashScreenController"];
    _splashView = vc.view;
    _destroyed = NO;
    
    [self _show];
}

- (void)destroySplashView
{
    _destroyed = YES;
    [(CDVViewController *)self.viewController setEnabledAutorotation:[(CDVViewController *)self.viewController shouldAutorotateDefaultValue]];

    [_splashView removeFromSuperview];
    _splashView = nil;

    self.viewController.view.userInteractionEnabled = YES;  // re-enable user interaction upon completion
    @try {
        [self.viewController.view removeObserver:self forKeyPath:@"frame"];
        [self.viewController.view removeObserver:self forKeyPath:@"bounds"];
    }
    @catch (NSException *exception) {
        // When reloading the page from a remotely connected Safari, there
        // are no observers, so the removeObserver method throws an exception,
        // that we can safely ignore.
        // Alternatively we can check whether there are observers before calling removeObserver
    }
}

- (void)settingAd:(CDVInvokedUrlCommand*)command
{
    CDVSplashScreenADLoader *loader = [[CDVSplashScreenADLoader alloc] init];
    NSArray *args = command.arguments; // JavaScript에서 전달된 arguments를 받음
    [loader downloadSplashScreenAD:args];

}

- (void)removeAd:(CDVInvokedUrlCommand*)command
{   
    CDVSplashScreenADLoader *loader = [[CDVSplashScreenADLoader alloc] init];
    [loader removeplashScreenAD];
}

- (void)info:(CDVInvokedUrlCommand*)command {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *id = [defaults objectForKey:@"displayedSplashId"];
    NSString *isAdDisplayed = [defaults objectForKey:@"isAdDisplayed"];
    
    
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    if (id != nil) {
        [result setObject:id forKey:@"id"];
    }
    if (isAdDisplayed != nil) {
        BOOL isAdDisplayedBool = [isAdDisplayed boolValue];  // NSString을 BOOL로 변환
        [result setObject:[NSNumber numberWithBool:isAdDisplayedBool] forKey:@"isAdDisplayed"];
    }
    
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)show:(CDVInvokedUrlCommand*)command
{
    [self _show];
}

- (void)_show
{
    // [self printWithTime:@"[SplashScreen] show"];
    UIView* parentView = self.viewController.view;
    parentView.userInteractionEnabled = NO;  // disable user interaction while splashscreen is shown
    [parentView addSubview:_splashView];
}

- (void)hide:(CDVInvokedUrlCommand*)command
{
    [self _hide:YES];
}

- (void)_hide:(BOOL)force
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *delayTime = [defaults objectForKey:@"SplashDelayTime"];

    id fadeSplashScreenDuration = [self.commandDelegate.settings objectForKey:[@"FadeSplashScreenDuration" lowercaseString]];
    float fadeDuration = fadeSplashScreenDuration == nil ? kFadeDurationDefault : [fadeSplashScreenDuration floatValue];

    id splashDurationString = [self.commandDelegate.settings objectForKey: [@"SplashScreenDelay" lowercaseString]];
    float splashDuration = splashDurationString == nil ? kSplashScreenDurationDefault : [splashDurationString floatValue];
    
    float splashDelayTime = delayTime == nil ? 0 : [delayTime floatValue];

    id autoHideSplashScreenValue = [self.commandDelegate.settings objectForKey:[@"AutoHideSplashScreen" lowercaseString]];
    BOOL autoHideSplashScreen = true;

    if (autoHideSplashScreenValue != nil) {
        autoHideSplashScreen = [autoHideSplashScreenValue boolValue];
    }

    if (!autoHideSplashScreen) {
        // CB-10412 SplashScreenDelay does not make sense if the splashscreen is hidden manually
        splashDuration = 0;
    }

    if (fadeDuration < 30)
    {
        // [CB-9750] This value used to be in decimal seconds, so we will assume that if someone specifies 10
        // they mean 10 seconds, and not the meaningless 10ms
        fadeDuration *= 1000;
    }
    
    float effectiveSplashDuration;

    // [CB-10562] AutoHideSplashScreen may be "true" but we should still be able to hide the splashscreen manually.
    if (!autoHideSplashScreen || force) {
        effectiveSplashDuration = splashDelayTime;
    } else {
        effectiveSplashDuration = splashDuration - fadeDuration;
    }
    
    __weak __typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (uint64_t) effectiveSplashDuration * NSEC_PER_MSEC), dispatch_get_main_queue(), CFBridgingRelease(CFBridgingRetain(^(void) {
        if (!self->_destroyed) {
            [UIView transitionWithView:self.viewController.view
                duration:(fadeDuration / 1000)
                options:UIViewAnimationOptionTransitionNone
                animations:^(void) {
                    // hide
                    if (self->_splashView != nil) {
                        // [self printWithTime:@"[SplashScreen] hide"];
                        [self->_splashView setAlpha:0];
                    }
                }
                completion:^(BOOL finished) {
                    // Always destroy views, otherwise you could have an
                    // invisible splashscreen that is overlayed over your active views
                    // which causes that no touch events are passed
                    if (!self->_destroyed) {
                        // destroy
                        [weakSelf destroySplashView];
                    }
                }
            ];
        }
    })));
}

- (void)pageDidLoad
{
    id autoHideSplashScreenValue = [self.commandDelegate.settings objectForKey:[@"AutoHideSplashScreen" lowercaseString]];

    // if value is missing, default to yes
    if ((autoHideSplashScreenValue == nil) || [autoHideSplashScreenValue boolValue]) {
        // hide
        [self _hide:NO];
    }
}

- (void)printWithTime:(NSString*)title
{
    NSDate *nowGMTDateRaw = [NSDate date];
    
    NSDateFormatter *dateFormatterGMT = [[NSDateFormatter alloc] init];
    [dateFormatterGMT setDateFormat:@"kk:mm:ss.SSS"];
    NSTimeZone *gmtTimeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    [dateFormatterGMT setTimeZone:gmtTimeZone];
    
    NSString *nowGMTString = @"";
    nowGMTString = [dateFormatterGMT stringFromDate:nowGMTDateRaw];
    NSLog(@"%@ - [time : %@]", title, nowGMTString);
}

@end
