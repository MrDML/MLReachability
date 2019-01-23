//
//  ViewController.m
//  MLReachability
//
//  Created by ML Day on 2019/1/21.
//  Copyright © 2019年 ML Day. All rights reserved.
//

#import "ViewController.h"
#import "MLReachability.h"

@interface ViewController ()

@end

static char* const  _flag = "1";
static char* const  __flag = "2";
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
 
   __weak MLReachability *reachability = [MLReachability shared];
    
    [reachability startMonitoring];
    
     NSString * info =  [reachability localizedNetworkReachabilityStatusString];
    
    printf("%s\n",[info UTF8String]);
//    char _flag[1024] = "1";
    
  
    [reachability addObserver:self forKeyPath:@"reachable" options:NSKeyValueObservingOptionNew context:_flag];
    

//    char __flag[1024] = "2";
   
    [reachability addObserver:self forKeyPath:@"networkReachabilityStatus" options:NSKeyValueObservingOptionNew context:__flag];
    [reachability setReachabilityStatusChangeBlock:^(MLNetworkReachabilityStatus status) {
       
        
       BOOL flag = [reachability isReachable];
        NSLog(@"===>%d",flag);
        
        NSString * info =  [reachability localizedNetworkReachabilityStatusString];
        
        printf("%s\n",[info UTF8String]);
        
    }];
    
   
   // [reachability observeValueForKeyPath:@"isReachableViaWiFi" ofObject:nil change:nil context:nil];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    NSLog(@"...................");
    
     char *flag = NULL;
    
     flag = (char *)(context);
  
     printf("%s\n", flag);
}

@end
