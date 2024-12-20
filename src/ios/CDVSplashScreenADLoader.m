#import <Cordova/CDV.h>
#import "CDVSplashScreenADLoader.h"

@implementation CDVSplashScreenADLoader

- (void)downloadSplashScreenAD:(NSArray *)args {
    // args 배열의 길이 검사
    if (args.count < 1) {
        NSLog(@"[SplashScreen] Error: Expected at least 1 arguments, but received %lu.", (unsigned long)args.count);
        return;
    }
    
    NSDictionary *options = args[0];
    NSString *id = options[@"id"];
    NSString *updatedAt = options[@"updatedAt"];
    NSString *begin = options[@"begin"];
    NSString *end = options[@"end"];
    NSString *imageUrl = options[@"url"];
    NSNumber *delayTime = options[@"delayTime"];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *previousSplashId = [defaults objectForKey:@"SplashId"];
    NSString *previousUpdatedAt = [defaults objectForKey:@"SplashUpdatedAt"];
    
    // 문서 디렉토리 경로 구하기
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *savePath = [documentsDirectory stringByAppendingPathComponent:@"splashAd.png"];
        
    // 파일 존재 여부 확인
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isFileExists = [fileManager fileExistsAtPath:savePath];
    
    // key가 변경되지 않고  파일이 있으면 이미지를 다운로드 하지 않음
    if (id == previousSplashId &&  [previousUpdatedAt isEqualToString:updatedAt] && isFileExists) {
        NSLog(@"[SplashScreen] The splash screen ad with id %@ is already downloaded and the file exists. Skipping download.", id);
        return;
    }
    
    
    // NSURLSessionConfiguration을 사용하여 타임아웃 설정
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.timeoutIntervalForRequest = 5;
    configuration.timeoutIntervalForResource = 50;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSURL *url = [NSURL URLWithString:imageUrl];
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[SplashScreen] Error downloading image: %@", error.localizedDescription);
        } else {
            NSError *moveError = nil;
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            // 동일한 이름의 파일이 이미 존재하는지 확인
            if ([fileManager fileExistsAtPath:savePath]) {
                NSLog(@"[SplashScreen]  existing file: %@", savePath);
                NSError *fileError;
                [fileManager removeItemAtPath:savePath error:&fileError];
                if (fileError) {
                    NSLog(@"[SplashScreen] Error removing existing file: %@", fileError.localizedDescription);
                    return;
                }
            }
            
            // 파일 시스템에 이미지 데이터 저장
            [fileManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:savePath] error:&moveError];
            if (moveError) {
                NSLog(@"[SplashScreen] Error saving image to path: %@, error: %@", savePath, moveError.localizedDescription);
            } else {
                NSLog(@"[SplashScreen] Image successfully downloaded and saved to: %@", savePath);
                // 다운로드가 성공적으로 완료된 후 NSUserDefaults 업데이트
                [defaults setObject:id forKey:@"SplashId"];
                [defaults setObject:updatedAt forKey:@"SplashUpdatedAt"];
                [defaults setObject:begin forKey:@"SplashBegin"];
                [defaults setObject:end forKey:@"SplashEnd"];
                [defaults setObject:delayTime forKey:@"SplashDelayTime"];
                [defaults synchronize];
            }
        }
    }];
    
    [downloadTask resume];
}


- (void)removeplashScreenAD {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // NSUserDefaults에서 광고 관련 정보 삭제
    [defaults removeObjectForKey:@"SplashId"];
    [defaults removeObjectForKey:@"SplashUpdatedAt"];
    [defaults removeObjectForKey:@"SplashBegin"];
    [defaults removeObjectForKey:@"SplashEnd"];
    [defaults removeObjectForKey:@"SplashDelayTime"];

    [defaults removeObjectForKey:@"displayedSplashId"];
    [defaults removeObjectForKey:@"isAdDisplayed"];    
    
    [defaults synchronize]; // 변경사항 적용

    // 문서 디렉토리 경로 구하기
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *savePath = [documentsDirectory stringByAppendingPathComponent:@"splashAd.png"];

    // 파일 삭제
    NSFileManager *fileManager = [NSFileManager defaultManager];    
    if ([fileManager fileExistsAtPath:savePath]) {
        NSError *error;
        [fileManager removeItemAtPath:savePath error:&error];
        if (error) {
            NSLog(@"[SplashScreen] Error removing ad image: %@", error.localizedDescription);
        } else {
            NSLog(@"[SplashScreen] Ad image successfully removed.");
        }
    }
}

@end
