//
//  MLReachability.m
//  MLReachability
//
//  Created by ML Day on 2019/1/21.
//  Copyright © 2019年 ML Day. All rights reserved.
//

#import "MLReachability.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netinet6/in6.h>
#import <ifaddrs.h>
#include <netdb.h>

 NSString * const MLNetworkingReachabilityDidChangeNotification = @"MLNetworkingReachabilityDidChangeNotification";
 NSString * const MLNetworkingReachabilityNotificationStatusItem = @"MLNetworkingReachabilityNotificationStatusItem";

// 外界直接使用的回调
typedef void(^MLNetworkReachabilitySattusBlock)(MLNetworkReachabilityStatus status);
// 该block 的返回值将赋值给 void *infor ， so info 指针指向了一个代码块的返回值
typedef MLReachability* (^MLNetworkReahAbilityStatusCallback)(MLNetworkReachabilityStatus status);


// 返回网络状态-本地化输出
NSString * MLStringFromNetworkingReachabilityStatus(MLNetworkReachabilityStatus status)
{
    switch (status) {
        case MLNetworkReachabilityStatusNotReachable:
            return NSLocalizedStringFromTable(@"Not Reachable", @"MLReachability", nill);
        case MLNetworkReachabilityStatusReachableViaWWAN:
            return NSLocalizedStringFromTable(@"Reachable via WWAN", @"MLReachability", nill);
        case MLNetworkReachabilityStatusReachableWiFi:
            return NSLocalizedStringFromTable(@"Reachable via WiFi", @"MLReachability", nill);
        default:
            return NSLocalizedStringFromTable(@"Unknown", @"MLReachability", nill);
    }
    
  
}


/***
 typedef CF_OPTIONS(uint32_t, SCNetworkReachabilityFlags) {
 
 // 此标志表示指定的节点名称或地址可以通过瞬态连接，例如PPP。
 kSCNetworkReachabilityFlagsTransientConnection        = 1<<0,
 // 此标志表示指定的节点名称或地址可以使用当前网络配置到达。
 kSCNetworkReachabilityFlagsReachable            = 1<<1,
 //此标志表示指定的节点名称或地址可以使用当前的网络配置，但a必须首先建立连接。
 kSCNetworkReachabilityFlagsConnectionRequired        = 1<<2,
 // 此标志表示指定的节点名称或地址可以使用当前的网络配置，但a必须首先建立连接。 任何流量指示指定的名称或地址将启动连接。
 kSCNetworkReachabilityFlagsConnectionOnTraffic        = 1<<3,
 // 此标志表示指定的节点名称或地址可以使用当前的网络配置，但a必须首先建立连接。 另外，一些需要用户干预的形式来确定这一点连接，例如提供密码，验证等
 kSCNetworkReachabilityFlagsInterventionRequired        = 1<<4,
 // 此标志表示指定的节点名称或地址可以使用当前的网络配置，但a必须首先建立连接。该连接将由“按需”建立CFSocketStream API。其他API不会建立连接。
 kSCNetworkReachabilityFlagsConnectionOnDemand
 API_AVAILABLE(macos(6.0),ios(3.0))        = 1<<5,
 // 此标志表示指定的节点名或地址是与当前网络接口相关联的系统
 kSCNetworkReachabilityFlagsIsLocalAddress        = 1<<16,
 // 此标志表示指定的网络流量节点名称或地址不会通过网关，但是直接路由到系统中的一个接口。
 kSCNetworkReachabilityFlagsIsDirect            = 1<<17,
 // 此标志表示指定的节点名称或地址可以通过EDGE，GPRS或其他“小区”连接到达。
 kSCNetworkReachabilityFlagsIsWWAN
 API_UNAVAILABLE(macos) API_AVAILABLE(ios(2.0))    = 1<<18,
 
 kSCNetworkReachabilityFlagsConnectionAutomatic    = kSCNetworkReachabilityFlagsConnectionOnTraffic
 };
 
 */

// 根据标志位，得出网络状态
// 没有声明 需要加static
static MLNetworkReachabilityStatus MLNetworkReachabilityStatusForFlags(SCNetworkConnectionFlags flags)
{
    
    // 是否可以获取网络
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    // 还未连接，需要进行连接
    BOOL neesdConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    
    //可以自动连接
    BOOL canConnectionAutomatically = (((flags &kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) || ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)));
    // 能够由用户交互进行连接
    BOOL canConnectWithoutUserInteraction = (canConnectionAutomatically &&(flags & kSCNetworkReachabilityFlagsConnectionRequired));
    
    BOOL isNetworkReachable = (isReachable && (!neesdConnection || canConnectWithoutUserInteraction));
    
    MLNetworkReachabilityStatus status = MLNetworkReachabilityStatusUnKnown;
    
    if (isNetworkReachable == NO) {
        status = MLNetworkReachabilityStatusNotReachable;
    }
#if TARGET_OS_IPHONE
    else if((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0)
    {
        // 蜂窝网络
        status = MLNetworkReachabilityStatusReachableViaWWAN;
    }
#endif
    else{
        // wifi
        status = MLNetworkReachabilityStatusReachableWiFi;
    }
    
    return status;
}







static void MLPostReachabilityStatusChange(SCNetworkConnectionFlags flags, MLNetworkReahAbilityStatusCallback block)
{
    
    // 获取当前网络状态
   MLNetworkReachabilityStatus status = MLNetworkReachabilityStatusForFlags(flags);
   // 切换为主线程
    dispatch_async(dispatch_get_main_queue(), ^{
       
        MLReachability *instance = nil;
        if (block) {
            instance =  block(status);
        }
        // 通知
        [[NSNotificationCenter defaultCenter] postNotificationName:MLNetworkingReachabilityDidChangeNotification object:instance userInfo:@{MLNetworkingReachabilityNotificationStatusItem : @(status)}];
        
    });
    
}

static void SC_NetworkReachabilityCallBack(
                                    SCNetworkReachabilityRef            target,
                                    SCNetworkReachabilityFlags            flags,
                                    void                 *    __nullable    info
                                    )
{
    
    MLPostReachabilityStatusChange(flags, (__bridge MLNetworkReahAbilityStatusCallback)info);
    
}



// 当监听循环启动后 将用户的数据块 增加一块内存进行使用
static const void* SCNContext_Retain(const void *info) // 系统内部调用回调函数
{
    return  Block_copy(info);
}

// 当监听循环停止后，释放之前增加的一块内存区域
static void SCNContext_Release(const void *info)
{
    Block_release(info);
}




@interface MLReachability ()

@property (readonly, nonatomic, assign) SCNetworkReachabilityRef networkReachability;
@property (readwrite, nonatomic, assign) MLNetworkReachabilityStatus networkReachabilityStatus;
@property (readwrite, nonatomic, copy) MLNetworkReachabilitySattusBlock networkReachabilityStatusBlock;

@end



@implementation MLReachability



+(instancetype)shared
{
    static MLReachability * _instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [self manager];
    });
    return _instance;
}

+ (instancetype)manager
{
    
// 如果是iphone设备 target version最低支持9.0
// 如果是macOS设备 target version 最低支持10.11
    // 使用ipv6的套接字地址
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 90000) ||(defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && ____MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
    // 使用ipv6的套接字地址
    struct sockaddr_in6 address;
    // 初始化
    bzero(&address, sizeof(address));
    // 指定ipv4
    address.sin6_family = AF_INET6;
    address.sin6_len = sizeof(address);
#else
    // 使用ipv4的套接字地址
    struct sockaddr_in address;
    // 初始化
    bzero(&address, sizeof(address));
    // 指定ipv4
    address.sin_family = AF_INET;
    address.sin_len = sizeof(address);

#endif

    return [self managerForAddress:&address];

}

+ (instancetype)managerForDomain:(NSString *)domain;
{
    // 创建 Reachability
   SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [domain UTF8String]);

    MLReachability  *instance =  [[self alloc] initWithReachability:reachability];
    
    CFRelease(reachability);
 
    return  instance;
}
+ (instancetype)managerForAddress:(const void *)address;
{
    // 创建 reachability
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)address);

    MLReachability  *instance =  [[self alloc] initWithReachability:reachability];
    
    CFRelease(reachability);

    return  instance;
}
- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachabillity
{
    self = [super init];
    if (self) {
        // 增加引用计数
   
        _networkReachability = CFRetain(reachabillity);
        self.networkReachabilityStatus = MLNetworkReachabilityStatusUnKnown;
    }
    return  self;
}


- (instancetype)init
{

    // 不能使用 init 进行实例化对象
    @throw [NSException exceptionWithName:NSGenericException reason:@"`-init` unavailable. Use `-initWithReachability:` instead" userInfo:nil];
    
    return nil;
}

- (void)dealloc
{
    // 停止监听
    [self stopMonitoring];
    //释放之前的 CFRetain(CFTypeRef cf)
    if (_networkReachability != NULL) {
        CFRelease(_networkReachability);
    }

}


#pragma Mark -


- (BOOL)isReachableViaWWAN
{
    return self.networkReachabilityStatus == MLNetworkReachabilityStatusReachableViaWWAN;
}

- (BOOL)isReachableViaWiFi
{
    return self.networkReachabilityStatus == MLNetworkReachabilityStatusReachableWiFi;
}

- (BOOL)isReachable
{
    return [self isReachableViaWiFi] || [self isReachableViaWWAN];
}


#pragma mark - 开始监听网络
/**
 // 常量__SCNetworkReachability结构体指针
 // typedef const struct CF_BRIDGED_TYPE(id) __SCNetworkReachability * SCNetworkReachabilityRef;
 
 // 初始化结构体

 typedef struct {
 CFIndex        version; 要传递的结构类型的版本号
 void *        __nullable info;指向用户指定数据块的C指针, 这块内存需要进行释放
 const void    * __nonnull (* __nullable retain)(const void *info); 用于为信息字段添加保留的回调
 void        (* __nullable release)(const void *info); 用于删除先前添加的保留的calllback
 CFStringRef    __nonnull (* __nullable copyDescription)(const void *info); 用于提供描述的回调
 信息字段。
 } SCNetworkReachabilityContext;

 
 */



- (void)startMonitoring
{

     __weak typeof(self)weakSelf = self;
    
    MLNetworkReahAbilityStatusCallback callback = ^(MLNetworkReachabilityStatus status){
      __weak typeof(self)strongSelf = weakSelf;
        strongSelf.networkReachabilityStatus = status;
        // 因为 weakSelf 传递给外界，如果不做一个强引用会除了blcok会被释放
        if (strongSelf.networkReachabilityStatusBlock) {
            strongSelf.networkReachabilityStatusBlock(status);
        }
    
        return strongSelf;
    };

    // 初始化结构体
    SCNetworkReachabilityContext context = {
      0,
    (__bridge void * _Nullable)(callback), // void * 空指针指向一个block的返回值的地址，该返回值可由自己进行定义 相当于参数
     SCNContext_Retain,
     SCNContext_Release,
     NULL,
    };
    
    // 设置回调
    SCNetworkReachabilitySetCallback(self.networkReachability, SC_NetworkReachabilityCallBack, &context);

    // 启动监听循环
    SCNetworkReachabilityScheduleWithRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
    // 初始化的调用 优先级设置 在所有优先级较高的队列之后调用
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        SCNetworkConnectionFlags flags;
        if (SCNetworkReachabilityGetFlags(self.networkReachability, &flags)) {
            MLPostReachabilityStatusChange(flags, callback);
        }
    });
 
    
}


- (void)stopMonitoring
{
    
    if (self.networkReachability == nil) {
        return;
    }
    // 停止监听循环
    SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
}

// 外界可以进行设置 nil
 -(void)setReachabilityStatusChangeBlock:(void (^)(MLNetworkReachabilityStatus))block
{
    self.networkReachabilityStatusBlock = block;
}

// 本地化输出
- (NSString *)localizedNetworkReachabilityStatusString
{
    return MLStringFromNetworkingReachabilityStatus(self.networkReachabilityStatus);
}


+ (NSSet<NSString *> *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    if ([key isEqualToString:@"reachable"] || [key isEqualToString:@"reachableViaWWAN"] || [key isEqualToString:@"reachableViaWiFi"]) {
        return [NSSet setWithObjects:@"networkReachabilityStatus", nil];
    }
    return  [super keyPathsForValuesAffectingValueForKey:key];
}




- (void)demo
{
    // 使用ipv4的套接字地址
    struct sockaddr_in address;
    // 初始化
    bzero(&address, sizeof(address));
    address.sin_family = AF_INET;//  IPv4地址族
    address.sin_len = sizeof(address);
    
   SCNetworkReachabilityRef reachability =  SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&address);

    // 注意：
    // 在AF中当这个结构创建初始化后再传递的时候Retain了一份作为管类进行全局使用
    // 在delloc中对自己Retain的 进行释放 Release
    
    /**
     -initWithReachability:
         _networkReachability = CFRetain(reachabillity);
     
     - (void)dealloc
          CFRelease(_networkReachability);
     */
    
    // 释放，自己管理内存
    CFRelease(reachability);
    
}

- (void)demo2
{
    
    /**
     初始化方式一：
     从这个接口可以得知，需要两个传入的参数,
     所有需要对这两个参数进行初始化，传入接口中。
     
     @param allocator 推荐使用默认 kCFAllocatorDefault
     @param address 套接字的地址结构
     @return SCNetworkReachabilityRef 这个类的实例
     */
    SCNetworkReachabilityRef __nullable
    SCNetworkReachabilityCreateWithAddress        (
                                                   CFAllocatorRef            __nullable    allocator, //创建对指定网络的引用地址。 此引用可以在以后用于监视目标主机的可达性。
                                                   const struct sockaddr                *address // 本地主机地址
                                                   )                API_AVAILABLE(macos(10.3), ios(2.0));
    
    // 初始化方式二：
    SCNetworkReachabilityRef __nullable
    SCNetworkReachabilityCreateWithName        (
                                                CFAllocatorRef            __nullable    allocator,
                                                const char                    *nodename // 域名或者ip地址
                                                )                API_AVAILABLE(macos(10.3), ios(2.0));
    // 初始化方式三：
    SCNetworkReachabilityRef __nullable
    SCNetworkReachabilityCreateWithAddressPair    (
                                                   CFAllocatorRef            __nullable    allocator,
                                                   const struct sockaddr        * __nullable    localAddress,
                                                   const struct sockaddr        * __nullable    remoteAddress
                                                   )                API_AVAILABLE(macos(10.3), ios(2.0));
    
    
    
    // 启动运行循环
    Boolean
    SCNetworkReachabilityScheduleWithRunLoop    (
                                                 SCNetworkReachabilityRef    target,
                                                 CFRunLoopRef            runLoop,
                                                 CFStringRef            runLoopMode
                                                 )                API_AVAILABLE(macos(10.3), ios(2.0));
    
    // 结束运行循环
    Boolean
    SCNetworkReachabilityUnscheduleFromRunLoop    (
                                                   SCNetworkReachabilityRef    target,
                                                   CFRunLoopRef            runLoop,
                                                   CFStringRef            runLoopMode
                                                   )                API_AVAILABLE(macos(10.3), ios(2.0));

    
    
    /*!
     @function SCNetworkReachabilitySetCallback
     @discussion Assigns a client to a target, which receives callbacks
     when the reachability of the target changes.
     @param target The network reference associated with the address or
     name to be checked for reachability.
     @param callout The function to be called when the reachability of the
     target changes.  If NULL, the current client for the target
     is removed.
     @param context The SCNetworkReachabilityContext associated with
     the callout.  The value may be NULL.
     @result Returns TRUE if the notification client was successfully set.
     */
    Boolean
    SCNetworkReachabilitySetCallback        (
                                             SCNetworkReachabilityRef            target,
                                             // 函数指针
                                             SCNetworkReachabilityCallBack    __nullable    callout,
                                             // 该值和callout是有关联的，该参数是可以为空的，如果设置为NULL 也不影响函数的回调
                                             SCNetworkReachabilityContext    * __nullable    context
                                             )                API_AVAILABLE(macos(10.3), ios(2.0));
    
    
    // 函数类型
    typedef void (*SCNetworkReachabilityCallBack)    (
                                                      SCNetworkReachabilityRef            target,
                                                      SCNetworkReachabilityFlags            flags,
                                                      // 指针，指向一块内存区域
                                                      void                 *    __nullable    info
                                                      );
    
    //1.通过回调函数可以分析
    //2.flags 网络状态的标志位
    //3. info 是一个空指针类型
        // 3.1在设置回调函数时，需要传入一个 SCNetworkReachabilityContext 类型的指针
            //3.2 SCNetworkReachabilityContext 是一个结构体
                 /*
                  typedef struct {
                  // 版本信息
                  CFIndex        version;
                  // 指针类型，指向了一块内存地址
                  void *        __nullable info;
                   // 函数指针，对于iOS,RAC,相当于增加了一个引用计数，对于内存来说，相当于对这块内存进行拷贝
                  const void    * __nonnull (* __nullable retain)(const void *info);
                  // 对上出内存拷贝进行释放
                  void        (* __nullable release)(const void *info);
                  // 描述信息
                  CFStringRef    __nonnull (* __nullable copyDescription)(const void *info);
                  } SCNetworkReachabilityContext;
                  */
    
    // SCNetworkReachabilityContext 这个结构体为何要这样设计？
    
     // 如果 info 指针指向的是一块局部的变量，那么这个快内存出了方法体会很快被释放。
     // 而 info 需要在callout回调函数中去使用。
    
    // 为什么不用全局变量进行传递？
    // 因为在回调函数中是异步，当在使用全局变量时，指针指向的不一定是同一块内存区域
    
    
}

@end
