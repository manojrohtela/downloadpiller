//
//  DownloadFacade.h
//  DownloadPrototypeApp
//
//  Created by Jorge Luis Herlein on 19/6/17.
//  Copyright © 2017 Jorge Luis Herlein. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DownloadFacade : NSObject

- (void) unlockCityWithPrefix:(NSString*)cityPrefix;

- (BOOL) cityIsUnlocked:(NSString*)cityPrefix;

@end
