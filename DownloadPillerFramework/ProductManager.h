//
//  ProductManager.h
//  DownloadPrototypeApp
//
//  Created by Jorge Luis Herlein on 19/6/17.
//  Copyright © 2017 Jorge Luis Herlein. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ProductManager : NSObject

+ (ProductManager*)sharedInstance;

-(void)downloadProductforCityPrefix:(NSString*)cityPrefix;

-(BOOL)checkProductStatusForCityPrefix:(NSString*)cityPrefix;

@end
