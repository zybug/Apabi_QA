//
//  ZYDownloader.m
//  download
//
//  Created by zy on 2017/9/4.
//  Copyright © 2017年 zy. All rights reserved.
//

#import "ZYDownloader.h"
#import "AFNetworking.h"
#import <CommonCrypto/CommonDigest.h>

typedef void(^ProgressCallBack)(ZYDownloaderTask *task);

@interface NSString(ZYMD5)

- (NSString *)md5;

@end

@implementation NSString(ZYMD5)

- (NSString *)md5 {
    const char* character = [self UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(character, (CC_LONG)strlen(character), result);
    NSMutableString *md5String = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
    {
        [md5String appendFormat:@"%02x",result[i]];
    }
    return md5String;
}

@end

@interface ZYDownloaderTask ()
{
    NSDate *_last_date;
    NSUInteger _last_file_received_size;
}
@property (nonatomic , strong , readwrite) NSURL *url;
@property (nonatomic , strong , readwrite) NSURL *imageUrl;
@property (nonatomic , assign , readwrite) TaskState state;
@property (nonatomic , strong , readwrite) NSString *fileName;
@property (nonatomic , strong , readwrite) NSString *fileType;
@property (nonatomic , strong , readwrite) NSString *filePath;
@property (nonatomic , assign , readwrite) NSUInteger bytesWritten;
@property (nonatomic , assign , readwrite) NSUInteger totalBytesWritten;
@property (nonatomic , assign , readwrite) NSUInteger totalBytesExpectedToWrite;
@property (nonatomic , strong , readwrite) NSString *speed;
@property (nonatomic , strong , readwrite) NSString *time;
@property (nonatomic , strong , readwrite) NSError *error;

@property (nonatomic , weak) ZYDownloader *manager;

/**
 downloadTask
 */
@property (nonatomic , strong) NSURLSessionDownloadTask *downloadTask;

/**
 保存文件名
 */
@property (nonatomic , strong) NSString *saveName;

/**
 缓存文件存储路径
 */
@property (nonatomic , strong) NSString *tmpPath;

@end

@implementation ZYDownloaderTask

-(instancetype)initWithURL:(NSString *)url{
    self = [super init];
    if (!self) {
        return nil;
    }
    _last_date = [NSDate date];
    _last_file_received_size = 0;
    self.url = [NSURL URLWithString:url];
    self.state = WatingDownload;
    self.fileName = [[[NSURL URLWithString:url] absoluteString] lastPathComponent];
    self.fileType = self.fileName.pathExtension;
    NSDateFormatter *tpDateformatter=[[NSDateFormatter alloc]init];
    [tpDateformatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    self.time = [tpDateformatter stringFromDate:[NSDate date]];
    self.saveName = [url md5];
    self.tmpPath = @"";
    return self;
}

-(void)setManager:(ZYDownloader *)manager{
    _manager = manager;
    _filePath = self.filePath;
}

-(NSString *)filePath{
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",self.saveName,self.fileType]];
}

-(void)setTotalBytesWritten:(NSUInteger)totalBytesWritten{
    _totalBytesWritten = totalBytesWritten;
    [self caculateSpeed];
}

/**
 下载速度计算
 */
-(void)caculateSpeed{
    NSDate *currentDate = [NSDate date];
    if ([currentDate timeIntervalSinceDate:_last_date] >= 1) {
        NSTimeInterval tpTime = [currentDate timeIntervalSinceDate:_last_date];
        NSUInteger tpData = _totalBytesWritten - _last_file_received_size;
        _last_date = currentDate;
        _last_file_received_size = _totalBytesWritten;
        NSUInteger tpReceivedDataSpeed = tpData/tpTime;
        NSString *tpSpeed;
        if (tpReceivedDataSpeed<1024.0) {
            tpSpeed = [NSString stringWithFormat:@"%.2f B/S",(float)tpReceivedDataSpeed];
        }else if (tpReceivedDataSpeed < 1024.0*1024.0){
            tpSpeed = [NSString stringWithFormat:@"%.2f K/S",tpReceivedDataSpeed/1024.0];
        }else{
            tpSpeed = [NSString stringWithFormat:@"%.2f M/S",tpReceivedDataSpeed/1024.0/1024.0];
        }
        self.speed = tpSpeed;
    }
}

@end




@interface ZYDownloader ()

// AFNetworking
@property (nonnull, nonatomic, strong) AFURLSessionManager *sessionManager;

@property (nonatomic, strong, readwrite) NSMutableArray <ZYDownloaderTask *> *downloadingTasks;
@property (nonatomic, strong, readwrite) NSMutableArray <ZYDownloaderTask *> *finishedTasks;
@property (nonatomic, strong, readwrite) NSMutableArray <ZYDownloaderTask *> *failedTasks;
/**
 任务下载列表：只负责任务的下载
 */
@property (nonatomic, strong) NSMutableArray <NSURLSessionDownloadTask *> *taskList;
@property (nonatomic, strong) NSString *tmpPath;
@property (nonatomic, copy) ProgressCallBack progressCallBack;

@end


@implementation ZYDownloader

+ (ZYDownloader *)downloader {
    static ZYDownloader *downloader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloader = [[ZYDownloader alloc] init];
        downloader.sessionManager = [[AFURLSessionManager alloc] init];
    });
    return downloader;
}

- (instancetype)init {
    if (self = [super init]) {
        self.finishedTasks = [NSMutableArray array];
        self.downloadingTasks = [NSMutableArray array];
        self.failedTasks = [NSMutableArray array];
        
        self.taskList = [NSMutableArray array];
        self.sessionManager = [[AFURLSessionManager alloc]init];
        
        __weak typeof(self)WeakSelf = self;
        [self.sessionManager setDownloadTaskDidWriteDataBlock:^(NSURLSession * _Nonnull session, NSURLSessionDownloadTask * _Nonnull downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            if (WeakSelf.downloadingTasks.count > 0) {
                for (int i = 0; i<self.downloadingTasks.count; i++) {
                    ZYDownloaderTask *tpTask = [WeakSelf.downloadingTasks objectAtIndex:i];
                    NSURLSessionDownloadTask *_downloadTask = [tpTask valueForKey:@"downloadTask"];
                    if (_downloadTask == downloadTask) {
                        [tpTask setValue:[NSNumber numberWithUnsignedInteger:bytesWritten] forKey:@"bytesWritten"];
                        [tpTask setValue:[NSNumber numberWithUnsignedInteger:totalBytesWritten] forKey:@"totalBytesWritten"];
                        NSUInteger expectedToWrite = [[tpTask valueForKey:@"totalBytesExpectedToWrite"]unsignedIntegerValue];
                        if (expectedToWrite < totalBytesExpectedToWrite) {
                            [tpTask setValue:[NSNumber numberWithUnsignedInteger:totalBytesExpectedToWrite] forKey:@"totalBytesExpectedToWrite"];
                        }
                        //保存下载信息到文件
                        [WeakSelf saveTask:tpTask];
                        if (WeakSelf.progressCallBack) {
                            WeakSelf.progressCallBack(tpTask);
                        }
                    }
                }
            }
        }];
    }
    return self;
}

-(void)downloadProgressCallBack:(void(^)(ZYDownloaderTask *task))callBack{
    self.progressCallBack = callBack;
}


-(void)saveTask:(ZYDownloaderTask *)task{
    if (task.state == WatingDownload || task.state == Downloading) {
        //下载中
        NSString *path = [self.tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist",[task valueForKey:@"saveName"]]];
        NSMutableDictionary *tpDic = [NSMutableDictionary dictionary];
        [tpDic setValue:[task.url absoluteString] forKey:@"url"];
        [tpDic setValue:task.fileName forKey:@"fileName"];
        [tpDic setValue:task.fileType forKey:@"fileType"];
        [tpDic setValue:[NSNumber numberWithUnsignedInteger:task.totalBytesWritten] forKey:@"totalBytesWritten"];
        [tpDic setValue:[NSNumber numberWithUnsignedInteger:task.totalBytesExpectedToWrite] forKey:@"totalBytesExpectedToWrite"];
        [tpDic setValue:[task valueForKey:@"saveName"] forKey:@"saveName"];
        [tpDic setValue:[task valueForKey:@"tmpPath"] forKey:@"tmpPath"];
        [tpDic setValue:task.time forKey:@"time"];
        [tpDic writeToFile:path atomically:YES];
    }else if (task.state == Completed){
        //下载完成
        NSString *path = [self.tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist",[task valueForKey:@"saveName"]]];
        if ([[NSFileManager defaultManager]fileExistsAtPath:path]) {
            [[NSFileManager defaultManager]removeItemAtPath:path error:nil];
        }
        
        NSMutableArray *array = [NSMutableArray array];
        for (ZYDownloaderTask *task in self.finishedTasks) {
            NSMutableDictionary *tpDic = [NSMutableDictionary dictionary];
            [tpDic setValue:[task.url absoluteString] forKey:@"url"];
            [tpDic setValue:task.fileName forKey:@"fileName"];
            [tpDic setValue:task.fileType forKey:@"fileType"];
            [tpDic setValue:[NSNumber numberWithUnsignedInteger:task.totalBytesWritten] forKey:@"totalBytesWritten"];
            [tpDic setValue:[NSNumber numberWithUnsignedInteger:task.totalBytesExpectedToWrite] forKey:@"totalBytesExpectedToWrite"];
            [tpDic setValue:[task valueForKey:@"saveName"] forKey:@"saveName"];
            [tpDic setValue:[task valueForKey:@"tmpPath"] forKey:@"tmpPath"];
            [tpDic setValue:task.time forKey:@"time"];
            [array addObject:tpDic];
        }
        NSString *tpPath = [self.tmpPath stringByAppendingPathComponent:@"FinishedTask.plist"];
        [array writeToFile:tpPath atomically:YES];
    }else if (task.state == Failed){
        //下载失败 -- 删除文件、tmp和plist
        if ([[NSFileManager defaultManager]fileExistsAtPath:task.filePath]) {
            [[NSFileManager defaultManager]removeItemAtPath:task.filePath error:nil];
        }
        NSString *tmpPath = [task valueForKey:@"tmpPath"];
        if (tmpPath && tmpPath.length >0) {
            if ([[NSFileManager defaultManager]fileExistsAtPath:[NSHomeDirectory() stringByAppendingPathComponent:tmpPath]]) {
                [[NSFileManager defaultManager]removeItemAtPath:[NSHomeDirectory() stringByAppendingPathComponent:tmpPath] error:nil];
            }
        }
        NSString *path = [self.tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist",[task valueForKey:@"saveName"]]];
        if ([[NSFileManager defaultManager]fileExistsAtPath:path]) {
            [[NSFileManager defaultManager]removeItemAtPath:path error:nil];
        }
        NSMutableArray *array = [NSMutableArray array];
        for (ZYDownloaderTask *task in self.failedTasks) {
            NSMutableDictionary *tpDic = [NSMutableDictionary dictionary];
            [tpDic setValue:[task.url absoluteString] forKey:@"url"];
            [tpDic setValue:task.fileName forKey:@"fileName"];
            [tpDic setValue:task.fileType forKey:@"fileType"];
            [tpDic setValue:[NSNumber numberWithUnsignedInteger:task.totalBytesWritten] forKey:@"totalBytesWritten"];
            [tpDic setValue:[NSNumber numberWithUnsignedInteger:task.totalBytesExpectedToWrite] forKey:@"totalBytesExpectedToWrite"];
            [tpDic setValue:[task valueForKey:@"saveName"] forKey:@"saveName"];
            [tpDic setValue:[task valueForKey:@"tmpPath"] forKey:@"tmpPath"];
            [tpDic setValue:task.time forKey:@"time"];
            [array addObject:tpDic];
        }
        NSString *tpPath = [self.tmpPath stringByAppendingPathComponent:@"FailedTask.plist"];
        [array writeToFile:tpPath atomically:YES];
    }
}

- (void)addDownloadTasks:(NSString *)url {
    ZYDownloaderTask *task = [[ZYDownloaderTask alloc] initWithURL:url];
    [self downloadTask:task];
}

- (void)startDownloadTask:(NSString *)url {
   
}

- (void)stopDownloadTask:(NSString *)url {
    
}

- (void)cancelDownloadTask:(NSString *)url {
   
}



-(void)downloadTask:(ZYDownloaderTask *)task{
    NSURLSessionDownloadTask *downloadTask = [self _task:task progress:^(NSProgress *downloadProgress) {
        
    } destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        return [NSURL fileURLWithPath:task.filePath];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        if (task.state == Suspended) {
            //暂停任务
            
        }else if(task.state == Downloading){
            [task setValue:error forKey:@"error"];
            if (error) {
                //下载出错
                
            }else{
                //正常下载
            }
            [self.downloadingTasks removeObject:task];
            [self saveTask:task];
        }
        if (task.state != WatingDownload) {
            
        }
    }];
    [task setValue:[NSNumber numberWithUnsignedInteger:Downloading] forKey:@"state"];
    [downloadTask resume];
}


-(NSURLSessionDownloadTask *)_task:(ZYDownloaderTask *)task
                            progress:(void(^)(NSProgress *downloadProgress))downloadProgressBlock destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                   completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler{
    NSURLSessionDownloadTask *downloadTask = nil;
    NSData *resumeData = nil;
    NSString *tmpPath = [task valueForKey:@"tmpPath"];
    if (tmpPath && tmpPath.length>0) {
        //已在缓存中，则从缓存中继续下载；
        NSData *tmpData = [NSData dataWithContentsOfFile:[NSTemporaryDirectory() stringByAppendingPathComponent:tmpPath]];
        if (tmpData) {
            NSMutableDictionary *resumeDataDict = [NSMutableDictionary dictionary];
            NSMutableURLRequest *newResumeRequest = [NSMutableURLRequest requestWithURL:task.url];
            [newResumeRequest addValue:[NSString stringWithFormat:@"bytes=%ld-",tmpData.length] forHTTPHeaderField:@"Range"];
            NSData *newResumeRequestData = [NSKeyedArchiver archivedDataWithRootObject:newResumeRequest];
            [resumeDataDict setValue:[task.url absoluteString] forKey:@"NSURLSessionDownloadURL"];
            [resumeDataDict setObject:[NSNumber numberWithInteger:tmpData.length]forKey:@"NSURLSessionResumeBytesReceived"];
            [resumeDataDict setObject:newResumeRequestData forKey:@"NSURLSessionResumeCurrentRequest"];
            [resumeDataDict setObject:[[NSHomeDirectory() stringByAppendingPathComponent:tmpPath] lastPathComponent]forKey:@"NSURLSessionResumeInfoTempFileName"];
            resumeData = [NSPropertyListSerialization dataWithPropertyList:resumeDataDict format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
        }
    }
    if (resumeData && resumeData.length > 0) {
        //在缓存中，则断点下载
        downloadTask = [self.sessionManager downloadTaskWithResumeData:resumeData progress:^(NSProgress * _Nonnull downloadProgress) {
            downloadProgressBlock(downloadProgress);
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return destination(targetPath,response);
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            completionHandler(response,filePath,error);
        }];
        [task setValue:downloadTask forKey:@"downloadTask"];
    }else{
        //不在缓存中，则重新下载；
        NSURLRequest *request = [NSURLRequest requestWithURL:task.url];
        downloadTask = [self.sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
            downloadProgressBlock(downloadProgress);
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return destination(targetPath,response);
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            completionHandler(response,filePath,error);
        }];
        [task setValue:downloadTask forKey:@"downloadTask"];
    };
    return downloadTask;
}


@end
