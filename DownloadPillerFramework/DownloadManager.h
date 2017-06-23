//
//  DownloadManager.h
//  Trip Guider
//
//  Created by Jorge Luis Herlein on 10/4/17.
//  Copyright © 2017 eTips. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DownloadManager : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>

+ (DownloadManager*)sharedInstance;

//Downloads all packages for a city prefix.
- (void) downloadContentForCityPrefix:(NSString*)prefix;

//Returns string path to Downloads directory where all packages are downloaded.
- (NSString *)downloadableContentPath;

//Returns dictionary with the packages associated to a city prefix
- (NSDictionary *) getPackagesForCityPrefix:(NSString*)cityPrefix;

@end
