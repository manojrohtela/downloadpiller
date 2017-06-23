//
//  DownloadFacade.m
//  DownloadPrototypeApp
//
//  Created by Jorge Luis Herlein on 19/6/17.
//  Copyright © 2017 Jorge Luis Herlein. All rights reserved.
//

#import "DownloadFacade.h"
#import "ProductManager.h"

@implementation DownloadFacade

- (void) unlockCityWithPrefix:(NSString*)cityPrefix{
    [[ProductManager sharedInstance] downloadProductforCityPrefix:cityPrefix];
}

- (BOOL) cityIsUnlocked:(NSString*)cityPrefix{
    BOOL result = [[ProductManager sharedInstance]checkProductStatusForCityPrefix:cityPrefix];
    return result;
}

@end
