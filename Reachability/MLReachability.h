//
//  MLReachability.h
//  MLReachability
//
//  Created by ML Day on 2019/1/21.
//  Copyright © 2019年 ML Day. All rights reserved.
//

#import <Foundation/Foundation.h>
// 网络监测头文件
#import <SystemConfiguration/SystemConfiguration.h>

typedef NS_ENUM(NSInteger, MLNetworkReachabilityStatus) {
    MLNetworkReachabilityStatusUnKnown = -1, // 未知网络
    MLNetworkReachabilityStatusNotReachable = 0, // 未连接
    MLNetworkReachabilityStatusReachableViaWWAN = 1, // 移动蜂窝网
    MLNetworkReachabilityStatusReachableWiFi = 2, // wifi 网络
};
NS_ASSUME_NONNULL_BEGIN

@interface MLReachability : NSObject

// 当前网络状态
@property (readonly, nonatomic, assign) MLNetworkReachabilityStatus networkReachabilityStatus;

@property (readonly, nonatomic, assign, getter= isReachable) BOOL reachable;

@property (readonly, nonatomic, assign, getter= isReachableViaWWAN) BOOL reachableViaWWAN;
@property (readonly, nonatomic, assign, getter = isReachableViaWiFi) BOOL reachableViaWiFi;
// 单利实例化监听者
+ (instancetype)shared;
// 创建一个默认的使用的是ipv4的套接字地址，默认
+ (instancetype)manager;
// 通过域名或者ip实例化一个监听者
+ (instancetype)managerForDomain:(NSString *)domain;
// 通过 ipv6 sockaddr_in6 的套接字实例化一个监听者
+ (instancetype)managerForAddress:(const void *)address;
// 使用系统的 SCNetworkReachabilityRef 初始化一个监听者
- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachabillity;
// 不能实例化监听者
+ (instancetype)new;
// 不能实例化监听者
- (instancetype)init;
// 开始监听网络
- (void)startMonitoring;
// 停止监听网络
- (void)stopMonitoring;
// 网络连接状态
- (NSString *)localizedNetworkReachabilityStatusString;
// 当网络发送变化时的回调
- (void)setReachabilityStatusChangeBlock:(nullable void(^)(MLNetworkReachabilityStatus status))block;

@end


// 网络状态发送改变通知key
FOUNDATION_EXPORT NSString * const MLNetworkingReachabilityDidChangeNotification;

FOUNDATION_EXPORT NSString * const MLNetworkingReachabilityNotificationStatusItem;


// 返回当前的网络状态
FOUNDATION_EXPORT NSString * MLStringFromNetworkingReachabilityStatus(MLNetworkReachabilityStatus status);



NS_ASSUME_NONNULL_END
