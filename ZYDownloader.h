//
//  ZYDownloader.h
//  download
//
//  Created by zy on 2017/9/4.
//  Copyright © 2017年 zy. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger,TaskState) {
    WillDownload = 0,
    WatingDownload = 1,
    Downloading = 2,
    Suspended = 3,
    Completed = 4,
    Failed = 5
};

@interface ZYDownloaderTask : NSObject

@property (nonatomic, strong, readonly) NSURL * _Nullable url;
@property (nonatomic, assign, readonly) TaskState state;
@property (nonatomic, strong, readonly) NSString * _Nullable fileName;
@property (nonatomic, strong, readonly) NSString * _Nullable fileType;
@property (nonatomic, strong, readonly) NSString * _Nullable filePath;
@property (nonatomic, assign, readonly) NSUInteger bytesWritten;
@property (nonatomic, assign, readonly) NSUInteger totalBytesWritten;
@property (nonatomic, assign, readonly) NSUInteger totalBytesExpectedToWrite;
@property (nonatomic, strong, readonly) NSString * _Nullable speed;
@property (nonatomic, strong, readonly) NSString * _Nullable time;
@property (nonatomic, strong, readonly) NSError * _Nullable error;

-(instancetype _Nonnull )initWithURL:(NSString *_Nullable)url;

@end

@interface ZYDownloader : NSObject

/**
 正在执行中的任务：等待下载、将要下载、正在下载 */
@property (nonatomic , strong , readonly) NSMutableArray <ZYDownloaderTask *> * _Nullable downloadingTasks;

/**
 下载完成的任务 */
@property (nonatomic , strong , readonly) NSMutableArray <ZYDownloaderTask *> * _Nullable finishedTasks;

/**
 下载失败的任务 */
@property (nonatomic , strong , readonly) NSMutableArray <ZYDownloaderTask *> * _Nullable failedTasks;

// 下载中心
+ (ZYDownloader *_Nullable)downloader;


-(void)downloadProgressCallBack:(void(^_Nullable)(ZYDownloaderTask * _Nullable task))callBack;


// 添加下载任务
- (void)addDownloadTasks:(NSString *_Nonnull)url;
// 暂停某个任务
- (void)stopDownloadTask:(NSString * _Nonnull)url;
// 开始某个任务
- (void)startDownloadTask:(NSString *_Nonnull)url;
// 删除某个任务
- (void)cancelDownloadTask:(NSString *_Nonnull)url;

@end

