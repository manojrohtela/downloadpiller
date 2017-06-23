//
//  ProductManager.m
//  DownloadPrototypeApp
//
//  Created by Jorge Luis Herlein on 19/6/17.
//  Copyright © 2017 Jorge Luis Herlein. All rights reserved.
//

#import "ProductManager.h"
#import "DownloadManager.h"

@implementation ProductManager

static ProductManager *productManager;

//Singleton. Shared Instance
+ (ProductManager*)sharedInstance{
    if (productManager == nil) {
        productManager = [[ProductManager alloc] init];
    }
    return productManager;
}

-(id)init {
    //Notification subscription 
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary* unlockedProductsDict = [NSMutableDictionary dictionary];
    if (![userDefaults objectForKey:@"unlockedPrefixes"]){
        [userDefaults setObject:unlockedProductsDict forKey:@"unlockedPrefixes"];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadFinished:) name:@"downloadFinishedForCityPrefix"object:nil];
    [[NSUserDefaults standardUserDefaults]synchronize];
    return self;
}

-(void) dealloc{
    //Removes notification subscription.
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"downloadFinishedForCityPrefix" object:nil];
}

-(void)downloadProductforCityPrefix:(NSString*)cityPrefix{
    [self registerDownload:cityPrefix withStatus:@"downloading"];
    [self downloadContentForCity:cityPrefix];
}

-(void)registerDownload:(NSString*)cityPrefix withStatus:(NSString*)status{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary* dict = [[userDefaults objectForKey:@"unlockedPrefixes"]mutableCopy];
    [dict setValue:status forKey:cityPrefix];
    [userDefaults setObject:dict forKey:@"unlockedPrefixes"];
    [userDefaults synchronize];
    
}

//Recibir notificacion con el resultado de la compra (ok, error, etc) para determinar si iniciar o no la compra.
-(void)downloadContentForCity:(NSString*)cityPrefix{
    [[DownloadManager sharedInstance] downloadContentForCityPrefix:cityPrefix];
}

-(void)downloadFinished:(NSNotification*)notification{
    NSString* cityPrefix = notification.object;
    [self registerDownload:cityPrefix withStatus:@"unlocked"];
}

-(BOOL)checkProductStatusForCityPrefix:(NSString*)cityPrefix{
    NSDictionary* unlockedPrefixesDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"unlockedPrefixes"];
    
    for (id key in unlockedPrefixesDict){
        if ([key isEqualToString:cityPrefix]){
            NSString* cityStatus = [unlockedPrefixesDict objectForKey:key];
            if ([cityStatus isEqualToString:@"unlocked"]){
                return true;
            }else if ([cityStatus isEqualToString:@"downloading"]){
                //Need to download content. Error in previous session.
                [self downloadContentForCity:cityPrefix];
            }
            return false;
        }
    }
    return false;
}


@end
