//
//  DownloadManager.m
//  Trip Guider
//
//  Created by Jorge Luis Herlein on 10/4/17.
//  Copyright © 2017 eTips. All rights reserved.
//

#import "DownloadManager.h"
#import "ZipArchive.h"
//#import "AppDelegate.h"

@interface DownloadManager ()
//Dictionaries for downloads control.
@property NSMutableDictionary *downloadsProgressDictionary;
@property NSMutableDictionary *downloadsDataDictionary;

@property (nonatomic) NSURLSession *session;
@property (nonatomic, strong) dispatch_queue_t unzippingQueue;
@end

@implementation DownloadManager

static DownloadManager *downloadManager;

//Singleton. Shared Instance
+ (DownloadManager*)sharedInstance{
    if (downloadManager == nil) {
        downloadManager = [[DownloadManager alloc] init];
    }
    return downloadManager;
}

-(id)init {
    //Unzip queue to process multiple downloads.
    self.unzippingQueue = dispatch_queue_create("Unzipping Queue",DISPATCH_QUEUE_SERIAL);
    
    self.downloadsProgressDictionary = [NSMutableDictionary dictionary];
    self.downloadsDataDictionary = [NSMutableDictionary dictionary];
    
    //URL Session init
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.etips.DownloadPrototypeApp.BackgroundSession"];
    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
  
    return self;
}

//Public method. Downloads all packages for a city prefix by delegating tasks to other methods of this class.
//Step 1: Get all packages to download for the current city prefix.
- (void) downloadContentForCityPrefix:(NSString*)prefix{
    
    //PERFORM HTTP REQUEST WITH HEADERS
    NSURL *url = [NSURL URLWithString:[@"https://api.etips.es/test2/" stringByAppendingString:prefix]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:@"simpsoniatest"forHTTPHeaderField: @"X-USER"];
    [request addValue:@"83y32hd82gGD2d"forHTTPHeaderField:@"X-PASSWORD"];
    
    NSURLSessionDataTask *dataTask;
    dataTask = [self.session dataTaskWithRequest:request];
    [dataTask setTaskDescription:[@"packagesRequest-" stringByAppendingString:prefix]];
    [dataTask resume];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:
      ^(NSData * _Nullable data,
        NSURLResponse * _Nullable response,
        NSError * _Nullable error) {
          NSDictionary *jsonDict = [NSDictionary dictionary];
          if (data){
              jsonDict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
              [self getFilesSizeForJsonElements:jsonDict cityPrefix:prefix];
              
              //Save json to file in downloads/{prefix} directory
              NSString *directoryForJson = [[self downloadableContentPath]stringByAppendingPathComponent:prefix];;
              //Creates directory if needed
              if ([[NSFileManager defaultManager] fileExistsAtPath:directoryForJson] == NO){
                  NSError *error;
                  if ([[NSFileManager defaultManager] createDirectoryAtPath:directoryForJson withIntermediateDirectories:NO attributes:nil error:&error] == NO){
                      NSLog(@"Error: Unable to create directory: %@", error);
                  }
              }
              
              NSString *jsonPath = [directoryForJson stringByAppendingPathComponent:@"packages.json"];
              if (![jsonPath isEqualToString:@""]){
                  [data writeToFile:jsonPath atomically:YES];
              }
          }
      }] resume];
}

//Returns dictionary with the packages associated to a city prefix
- (NSDictionary *) getPackagesForCityPrefix:(NSString*)cityPrefix{
    NSDictionary* dict = [self.downloadsDataDictionary objectForKey:cityPrefix];
    return dict;
}

//Step 2: Get sizes for all packages given a city prefix to keep track of global download progress.
// Performs http requests for each package to get the size in bytes of each one. Size data is stored in class property "downloadsDataDictionary"
-(void)getFilesSizeForJsonElements:(NSDictionary*)jsonDict cityPrefix:(NSString*)cityPrefix{
    NSMutableArray* elementsToDownload = [NSMutableArray array];
    
    NSInteger worldElements = [(NSArray*) jsonDict[@"world"] count];
    NSInteger tilesmapElements = [(NSArray*) jsonDict[@"tilesmap"] count];
    NSInteger mapboxElements = [(NSArray*) jsonDict[@"mapbox"] count];
    
    //Extract World elements from Json
    for (int i=0; i<worldElements; i++){
        [elementsToDownload addObject: [[jsonDict objectForKey:@"world"]objectAtIndex:i]];
    }
    
    //Extract tilesmap elements from Json
    for (int i=0; i<tilesmapElements; i++){
        [elementsToDownload addObject: [[jsonDict objectForKey:@"tilesmap"]objectAtIndex:i]];
    }
    
    //Extract mapbox elements from Json
    for (int i=0; i<mapboxElements; i++){
        [elementsToDownload addObject: [[jsonDict objectForKey:@"mapbox"]objectAtIndex:i]];
    }
    
    [self.downloadsDataDictionary setObject:elementsToDownload forKey:cityPrefix];
    
    //Inits progress info in dictionary for future use.
    short totalItems = [elementsToDownload count];
    NSMutableDictionary* tempDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithDouble:0],  @"totalBytesExpected",
                                     [NSNumber numberWithDouble:0],  @"downloadedBytes",
                                     [NSNumber numberWithShort:totalItems],  @"packagesToDownload",
                                     [NSNumber numberWithInt:0],  @"sizeRequestsPerformed",
                                     [NSNumber numberWithFloat:0],  @"downloadedPackages", nil];
    
    [self.downloadsProgressDictionary setObject:tempDict forKey:cityPrefix];
    
    //Sends notification with the total of packages to dowloand for the current city prefix
    NSString* totalItemsString = [@(totalItems) stringValue];
    NSDictionary* totalItemsDict = [NSDictionary dictionaryWithObjectsAndKeys:totalItemsString,cityPrefix, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"packagesExpectedToDownload" object:totalItemsDict userInfo:nil];
    
    //Requests to get size of packages that will be downloaded
    for (NSDictionary* dict in elementsToDownload){
        NSString* longURL = [dict objectForKey:@"url"];
        NSString* itemPrefix = [dict objectForKey:@"prefix"];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:longURL]];
        request.HTTPMethod = @"GET";
        
        NSURLSessionDownloadTask *sizeInfoTask;
        
        sizeInfoTask = [self.session downloadTaskWithRequest:request];
        
        NSArray* sizeDescription = [NSArray arrayWithObjects:@"sizerequest",cityPrefix,itemPrefix, nil];
        
        [sizeInfoTask setTaskDescription:[sizeDescription componentsJoinedByString:@","]];
        
        [sizeInfoTask resume];
    }
}


//Step 3: Download all packages for the current city prefix.
//Called after getting all packages sizes for the current city prefix
- (void)performDownloadsForCityPrefix:(NSString*)cityPrefix{
    
    NSDictionary* itemsDict = [self.downloadsDataDictionary objectForKey:cityPrefix];
    for (NSDictionary* dict in itemsDict){
        NSString* itemPrefix = [dict objectForKey:@"prefix"];
        NSString* fileURL = [dict objectForKey:@"url"];
        NSArray* downloadDescription = [NSArray arrayWithObjects:cityPrefix,itemPrefix, nil];
        [self downloadFileFromURL:fileURL withDescription:downloadDescription];
    }
}

//Download file from url
//Downloads a single file given it's url.
- (void) downloadFileFromURL:(NSString*)urlString withDescription:(NSArray*)description{
    
    NSURL* dowloadURL = [NSURL URLWithString:urlString];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:dowloadURL];
    
    NSURLSessionDownloadTask *downloadTask;
    
    downloadTask = [self.session downloadTaskWithRequest:request];

    [downloadTask setTaskDescription:[description componentsJoinedByString:@","]];
    
    [downloadTask resume];
    
}


#pragma mark - NSURLSessionDownloadDelegate Delegate Methods

// Bytes written. Calculates new progress.
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    
    NSArray *taskDescription = [downloadTask.taskDescription componentsSeparatedByString:@","];
    
    //If task is a download task (not a size request one)
    if (![[taskDescription objectAtIndex:0] isEqualToString:@"sizerequest"]){
        NSLog(@"Descargando");
        //Calculates new progress for current city prefix download.
//        NSString *cityPrefix = [taskDescription objectAtIndex:0];
//        double totalBytesExpectedDict = [[[self.downloadsProgressDictionary objectForKey:cityPrefix]objectForKey:@"totalBytesExpected"] doubleValue];
//        double downloadedBytesDict = [[[self.downloadsProgressDictionary objectForKey:cityPrefix]objectForKey:@"downloadedBytes"] doubleValue];
//        downloadedBytesDict = downloadedBytesDict+bytesWritten;
//        
//        //Updates total of bytes downloaded for future progress calculations.
//        [[self.downloadsProgressDictionary objectForKey:cityPrefix] setObject:[NSNumber numberWithDouble:downloadedBytesDict] forKey:@"downloadedBytes"];
//        
//        double progress =  downloadedBytesDict/ totalBytesExpectedDict;
//        
//        //Console log
//        NSLog(@"Download Progress: %lf", progress);
        
        //Informs the delegate about the new progress value.
        
//        if([_delegate respondsToSelector:@selector(downloadingProgress:)]){
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [_delegate downloadingProgress:progress];
//            });
//        }
    }else{
        
        [downloadTask cancel];
        //Get the size for the package and stores data in "downloadsProgressDictionary" property.
        double itemSize = totalBytesExpectedToWrite;
        NSString* cityPrefix = [taskDescription objectAtIndex:1];
        NSString* oldTotalSizeValue = [[self.downloadsProgressDictionary objectForKey:cityPrefix]objectForKey:@"totalBytesExpected"];
        itemSize = itemSize + [oldTotalSizeValue doubleValue];
        [[self.downloadsProgressDictionary objectForKey:cityPrefix] setObject:[NSNumber numberWithDouble:itemSize] forKey:@"totalBytesExpected"];
        
        int sizeRequestsNumber = [[[self.downloadsProgressDictionary objectForKey:cityPrefix] objectForKey:@"sizeRequestsPerformed"]intValue];
        int sizeRequestsToPerform = [[[self.downloadsProgressDictionary objectForKey:cityPrefix] objectForKey:@"packagesToDownload"]intValue];
        
        sizeRequestsNumber++;
        [[self.downloadsProgressDictionary objectForKey:cityPrefix] setObject:[NSNumber numberWithFloat:sizeRequestsNumber] forKey:@"sizeRequestsPerformed"];
        
        if (sizeRequestsNumber == sizeRequestsToPerform){
            [self performDownloadsForCityPrefix:cityPrefix];
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    NSArray *taskDescription = [task.taskDescription componentsSeparatedByString:@","];
    if ((![[taskDescription objectAtIndex:0] isEqualToString:@"sizerequest"]) && error){
        NSLog(@"--ERROR--");
    }
}

// Download task finished. Download task can be a download package task, or a size request.
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    
    NSArray *taskDescription = [downloadTask.taskDescription componentsSeparatedByString:@","];
    
    //If task is a package download task
    if (![[taskDescription objectAtIndex:0] isEqualToString:@"sizerequest"]){
        //Unzips file into the appropriate directory in Application Support/Downloads.
        NSString *cityPrefix = [taskDescription objectAtIndex:0];
        NSString *filename = [taskDescription objectAtIndex:1];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString* destinationFolderPath = [[[self downloadableContentPath] stringByAppendingPathComponent:cityPrefix]stringByAppendingPathComponent:filename];
        NSString* zipPath = [destinationFolderPath stringByAppendingPathComponent:filename];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:zipPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:zipPath error:nil];
        }
        
        if ([fileManager fileExistsAtPath:destinationFolderPath] == NO){
            NSError *error;
            if ([fileManager createDirectoryAtPath:destinationFolderPath withIntermediateDirectories:YES attributes:nil error:&error] == NO){
                NSLog(@"Error: Unable to create directory: %@", error);
            }
        }
        
        //Moves file to Dowloads folder
        [fileManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:zipPath] error:nil];
        
        //Unzip downloaded file
        [self unzipDownloadedFile:zipPath toDestinationPath:destinationFolderPath forCityPrefix:cityPrefix];
        
        NSLog(@"Package Download Finished");
    }
}

//Returns string path to Downloads directory where all packages are downloaded.
- (NSString *)downloadableContentPath{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *directory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Downloads"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:directory] == NO)
    {
        NSError *error;
        if ([fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error] == NO)
        {
            NSLog(@"Error: Unable to create directory: %@", error);
        }
    }
    return directory;
}

//Unzips file into "Downloads" folder
- (void) unzipDownloadedFile:(NSString*)zipPath toDestinationPath:(NSString*)destinationPath forCityPrefix:(NSString*)cityPrefix{
    
    dispatch_async(_unzippingQueue, ^{
        
        [ZipArchive unzipFileAtPath:zipPath toDestination:destinationPath progressHandler:nil completionHandler:^(NSString *path, BOOL succeeded, NSError *error) {
            if (succeeded){
                NSLog(@"File Unzipped Succesfully");
                [[NSFileManager defaultManager] removeItemAtPath:zipPath error:nil];
                
                NSInteger packagesToDownload = [[[self.downloadsProgressDictionary objectForKey:cityPrefix] objectForKey:@"packagesToDownload"]integerValue];
                NSInteger downloadedPackages = [[[self.downloadsProgressDictionary objectForKey:cityPrefix] objectForKey:@"downloadedPackages"]integerValue];
                
                downloadedPackages++;
                [[self.downloadsProgressDictionary objectForKey:cityPrefix] setObject:[@(downloadedPackages)stringValue] forKey:@"downloadedPackages"];
                
                //Sends notification informing that a new package for the current city prefix was unzipped succesfully.
                NSString* downloadedPackagesString = [@(downloadedPackages) stringValue];
                NSDictionary* packageStatusDict = [NSDictionary dictionaryWithObjectsAndKeys:downloadedPackagesString,cityPrefix, nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"packageDownloadedForCityPrefix" object:packageStatusDict userInfo:nil];
                
                if (packagesToDownload == downloadedPackages){
                    
                    //If all packages were unzipped, sends notification informing that the download for the currect city prefix has finished
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadFinishedForCityPrefix" object:cityPrefix userInfo:nil];
                    NSLog(@"Download Finished for City Prefix: %@", cityPrefix);
                    
                }
            }else{
                NSLog(@"Unzip error");
                //Perform some error recovery.
//                if([_delegate respondsToSelector:@selector(didFailDownloadingWithError:)]){
//                    [_delegate didFailDownloadingWithError:error];
//                }
            }
        }];
    });
}

@end
