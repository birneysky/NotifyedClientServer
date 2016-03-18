//
//  ViewController.m
//  Notified
//
//  Created by zhangguang on 15/5/20.
//  Copyright (c) 2015年 com.v2tech. All rights reserved.
//

#import "ViewController.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import "NotificationNameMacros.h"

@interface ViewController ()<NSNetServiceBrowserDelegate,NSNetServiceDelegate,NSURLConnectionDelegate,NSURLConnectionDataDelegate>

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (nonatomic,strong) NSNetService* desktopServer;
@property (nonatomic,strong) NSNetServiceBrowser* browser;
@property (nonatomic,strong) NSData* deviceToken;
@end

@implementation ViewController

#pragma mark - properties
-(NSNetServiceBrowser*)browser
{
    if (!_browser) {
        _browser = [[NSNetServiceBrowser alloc] init];
    }
    return _browser;
}

#pragma mark - init view
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.browser.delegate = self;
    [self.browser searchForServicesOfType:@"_http._tcp." inDomain:@""];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceTokenNotification:) name:DEVICE_TOKEN_NOTIFICATION object:nil];
}



#pragma mark - server info
-(NSString*)serverHostName
{
    NSArray* address = [self.desktopServer addresses];
    NSData* firstAddress = [address objectAtIndex:0];
    
    const struct sockaddr_in* addy = firstAddress.bytes;
    
    char* ipAddress = inet_ntoa(addy->sin_addr);
    UInt16 port = ntohs(addy->sin_port);
    return [NSString stringWithFormat:@"%s:%u",ipAddress,port];
}


#pragma mark - browser delegate
-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
          didFindService:(NSNetService *)aNetService
              moreComing:(BOOL)moreComing
{
    if (!self.desktopServer && [aNetService.name isEqualToString:@"CocoaHttpServer"]) {
        self.desktopServer = aNetService;
        [self.desktopServer resolveWithTimeout:30];
        self.desktopServer.delegate = self;
        self.statusLabel.text = @"ResolVing CocoaHttpServer ...";
    }
    else
    {
        NSLog(@"ignoring %@",aNetService);
    }
    
}

-(void)postInfomationToServer
{
    self.statusLabel.text = @"Sending data to server...";
    
    //创建包含设备名称的字典对象
    NSDictionary* d = [NSDictionary dictionaryWithObjectsAndKeys:[UIDevice currentDevice].name,@"name",self.deviceToken,@"token", nil];
    
    //将字典对象序列化为xml格式的数据
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:d format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    //url 字符串由服务器端地址，端口号和应用名称组成
    //地址，端口号由解析成功的NSNetService 对象提供
    NSString* urlString = [NSString stringWithFormat:@"http://%@/register",[self serverHostName]];
    
    //web请求使用之前构建的url，使用post方法发送转字典对象的数据
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:data];
    
    NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
    [connection start];
    
}

#pragma mark - desktop server delegate

-(void)netServiceDidResolveAddress:(NSNetService *)sender
{
    NSString* text = [NSString stringWithFormat:@"Resolved service ... %@",sender.domain];
    self.statusLabel.text = text;
    self.desktopServer = sender;
}

-(void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
    self.statusLabel.text = @"Could not resolve service.";
    NSLog(@"%@",errorDict);
    
    self.desktopServer = nil;
}


#pragma mark - urlconnection delegate
-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.statusLabel.text = @"Data Send to server.";
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.statusLabel.text = @"Connection to server failed";
    NSLog(@"%@",error);
}


#pragma mark - notification selector
- (void)deviceTokenNotification:(NSNotification*)notification
{
    self.deviceToken = notification.object;
    
    [self postInfomationToServer];
}

@end
