// CDVSplashScreenADLoader.m
#import <Cordova/CDV.h>
#import "CDVSplashScreenADLoader.h"

@implementation CDVSplashScreenADLoader

- (void)fetchAndStoreSplashScreenImage:(id<CDVCommandDelegate>)commandDelegate {
    NSString *imageDomain = [commandDelegate.settings objectForKey:[@"SplashScreenImageDomain" lowercaseString]];
    NSString *apiURLString = [commandDelegate.settings objectForKey:[@"SplashScreenImageUrl" lowercaseString]];
    NSURL *apiURL = [NSURL URLWithString:apiURLString];
    
    NSLog( @"[RAD] apiURLString:%@", apiURLString );
    
    // HTTP 요청 객체 생성 및 헤더 설정
   NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:apiURL];
    [request setValue:@"ios" forHTTPHeaderField:@"x-hogangnono-platform"];
    
    // 타임아웃 시간을 5초로 설정
    request.timeoutInterval = 5.0;

   
        
    // API 호출
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error fetching splash screen image URL: %@", error);
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"JSON error: %@", jsonError);
            return;
        }
        
        NSArray *adItems = responseDict[@"data"][@"adItems"];
        NSLog( @"[RAD] adItems:%@", adItems );
       if (adItems && adItems.count > 0) {
           NSDictionary *firstAdItem = adItems[0]; // 첫 번째 광고 항목 사용
           
           // NSUserDefaults에서 이전 광고 항목의 id와 updatedAt 값을 가져옴
           NSDictionary *previousAdItem = [[NSUserDefaults standardUserDefaults] objectForKey:@"SplashAdItem"];
           NSString *previousId = [NSString stringWithFormat:@"%@", previousAdItem[@"id"]];
           NSString *previousUpdateAt = [NSString stringWithFormat:@"%@", previousAdItem[@"updatedAt"]];
           NSString *previousFilePath = [[NSUserDefaults standardUserDefaults] objectForKey:@"SplashScreenImageLocalPath"];
           
           // NSUserDefaults에서 이전 광고 항목의 id와 updatedAt 값을 가져옴
           NSString *currentId = [NSString stringWithFormat:@"%@", firstAdItem[@"id"]];
           NSString *currentUpdateAt = [NSString stringWithFormat:@"%@", firstAdItem[@"updatedAt"]];

           
           // id와 updatedAt 값 모두 변경사항이 없으면 이미지 다운로드 하지 않음
           if ([currentId isEqualToString:previousId] && [currentUpdateAt isEqualToString:previousUpdateAt] && [self fileExistsAtPath:previousFilePath]) {
               NSLog(@"[RAD] No update in adItems based on id and updatedAt. Skipping image download.");
               return;
           } else {
               // 변경사항이 있으면 현재 광고 항목을 NSUserDefaults에 저장
               [[NSUserDefaults standardUserDefaults] setObject:firstAdItem forKey:@"SplashAdItem"];
               [[NSUserDefaults standardUserDefaults] synchronize];
               
               // 이미지 다운로드 진행
               NSString *key = firstAdItem[@"image"][@"key"];
               NSString *imageURLString = [NSString stringWithFormat:@"%@/%@", imageDomain , key];
               NSURL *imageURL = [NSURL URLWithString:imageURLString];
               [self downloadImage:imageURL];
           }
       }

    }];
    [task resume];
}

- (void)downloadImage:(NSURL *)imageUrl {
    NSURLSessionDownloadTask *downloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:imageUrl completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[RAD] Error downloading image: %@", error);
            return;
        }
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *cacheDirectory = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
        NSString *fileName = @"splashAd.png";
        NSURL *fileURL = [cacheDirectory URLByAppendingPathComponent:fileName];
        
        // 기존 파일 삭제
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            [fileManager removeItemAtURL:fileURL error:nil];
        }
        
        NSError *moveError = nil;
        if ([fileManager moveItemAtURL:location toURL:fileURL error:&moveError]) {
            NSLog(@"[RAD] Image successfully saved: %@", fileURL);
            // 파일 경로를 UserDefaults에 저장
            [[NSUserDefaults standardUserDefaults] setObject:[fileURL path] forKey:@"SplashScreenImageLocalPath"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else {
            NSLog(@"[RAD] Could not save image: %@", moveError);
        }
    }];
    [downloadTask resume];
}

- (BOOL)fileExistsAtPath:(NSString *)filePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:filePath];
}

@end
