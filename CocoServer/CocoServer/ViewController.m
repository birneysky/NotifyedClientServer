//
//  ViewController.m
//  CocoServer
//
//  Created by zhangguang on 15/5/20.
//  Copyright (c) 2015年 com.v2tech. All rights reserved.
//

#import "ViewController.h"
#import "HTTPServer.h"

@interface ViewController () <NSNetServiceDelegate,HTTPConnectionDelegate,NSTableViewDataSource,NSTableViewDelegate,NSStreamDelegate>
@property (weak) IBOutlet NSTextField *statusField;
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTextField *inputTextfield;

@property (nonatomic,strong) NSMutableArray* registerdUsers;
@property (nonatomic,strong) NSNetService* service;
@property (nonatomic,strong) HTTPServer* server;
@property (nonatomic,strong) NSOutputStream* writeStream;
@property (nonatomic,strong) NSInputStream* readStream;
@end

@implementation ViewController

#pragma mark - properties
-(NSNetService*)service
{
    if (!_service) {
        _service = [[NSNetService alloc] initWithDomain:@"" type:@"_http._tcp." name:@"CocoaHttpServer" port:[self.server port]];
    }
    return _service;
}

-(HTTPServer*)server
{
    if (!_server) {
        _server = [[HTTPServer alloc] init];
    }
    return _server;
}

-(NSMutableArray*)registerdUsers
{
    if (!_registerdUsers) {
        _registerdUsers = [[NSMutableArray alloc] init];
    }
    return _registerdUsers;
}

#pragma mark - init view
- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
//    _service = [[NSNetService alloc] initWithDomain:@"" type:@"_http._tcp." name:@"CocoaHttpServer" port:10000];
//    _service.delegate = self;
//    [_service publish];
    
    self.server.delegate = self;
    NSError* err;
    [self.server start:&err];
    
    if (err) {
        NSLog(@"Server failed to Start : %@",err);
        return;
    }
    
    self.service.delegate = self;
    [self.service publish];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self connectToAppleNotificationServer];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark - target action
- (IBAction)sendBtnClicked:(id)sender {
    NSUInteger row = [self.tableView selectedRow];
    if (-1 == row) {
        return;
    }
    
    NSData* token = [self.registerdUsers[row] objectForKey:@"token"];
    
    NSData* data = [self notificationDataForMessage:self.inputTextfield.stringValue token:token];
    
    [self.writeStream write:data.bytes maxLength:data.length];
}

#pragma mark - service delegate
-(void)netServiceDidPublish:(NSNetService *)sender
{
    [self.statusField setStringValue:@"Server is advertising"];
}


-(void)netServiceDidStop:(NSNetService *)sender
{
    [self.statusField setStringValue:@"Server is not advertising"];
}

-(void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
    [self.statusField setStringValue:@"Server is not advertising"];
}


#pragma mark - htppserver delegate
-(void)HTTPConnection:(HTTPConnection *)conn didReceiveRequest:(HTTPServerRequest *)mess
{
    BOOL requestWasOkay = NO;
    
    //HTTPServerRequest 对象包含CFHTTPMessage对象
    //CFHttpMessage 对象保存来自客户端的web请求
    CFHTTPMessageRef request = [mess request];
    
    //得到相应web请求的http方法
    NSString* method =  (__bridge NSString *)(CFHTTPMessageCopyRequestMethod(request));
    //NSDictionary* method = (__bridge NSDictionary *)(CFHTTPMessageCopyAllHeaderFields(request));
    
    //只处理HTTP方法是POST的WEB请求
    if ([method isEqualToString:@"POST"]) {
        NSURL* requestUrl = (__bridge NSURL *)(CFHTTPMessageCopyRequestURL(request));
        NSString* ab = requestUrl.absoluteString;
        NSString* path = requestUrl.path;
        NSString* rel = requestUrl.relativeString;
        NSString* res = requestUrl.resourceSpecifier;
        if ([requestUrl.resourceSpecifier isEqualToString:@"/register"]) {
            requestWasOkay = [self handleRegister:request];
        }
    }
    
    CFHTTPMessageRef response = NULL;
    if (requestWasOkay) {
        //如果web请求中的数据符合要求
        //就返回HTTP状态200
        //这也是NSURLConnection 对象会收到的状态
        response = CFHTTPMessageCreateResponse(NULL, 200, NULL, kCFHTTPVersion1_1);
    }
    else
    {
        //如果web请求的数据不符合要求
        //就返回400
        response = CFHTTPMessageCreateResponse(NULL, 400, NULL, kCFHTTPVersion1_1);
    }
    
    //必须为HTTP 响应设置 content-leght
    CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Length", (CFStringRef)@"0");
    
    //设置HTTPServer Request对象的response属性后
    //该对象会自动得将CFHTTPMessage对象（response）发送给发出响应web请求的客户端
    
    [mess setResponse:response];
    
    CFRelease(response);
    
}

- (void)HTTPConnection:(HTTPConnection *)conn didSendResponse:(HTTPServerRequest *)mess
{
    
}

#pragma mark - handle register
-(BOOL)handleRegister:(CFHTTPMessageRef)request
{
    NSData* body = (__bridge NSData *)(CFHTTPMessageCopyBody(request));
    
    NSDictionary* bodyDict = [NSPropertyListSerialization propertyListFromData:body mutabilityOption:NSPropertyListXMLFormat_v1_0 format:nil errorDescription:nil];
    
    NSString* name = [bodyDict objectForKey:@"name"];
    NSData* token = [bodyDict objectForKey:@"token"];
    if (name && token) {
        
        BOOL unique = YES;
        for (NSDictionary* d in self.registerdUsers) {
            if ([[d objectForKey:@"token"] isEqual:token]) {
                unique = NO;
            }
        }
        if (unique) {
            [self.registerdUsers addObject:bodyDict];
            [self.tableView reloadData];
        }

        return YES;
    }
    
    return NO;
}


#pragma mark - tableview delegate
-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSDictionary* entry = self.registerdUsers[row];
    return [NSString stringWithFormat:@"%@ (%@)",[entry objectForKey:@"name"],[entry objectForKey:@"token"]];
}

-(NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSDictionary* entry = self.registerdUsers[row];
    NSString* txt = [NSString stringWithFormat:@"%@",[entry objectForKey:@"name"]];
    NSTextField* textfield  = [[NSTextField alloc] init];
    [textfield setStringValue:txt];
    return textfield;
}

//-(NSCell*)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
//{
//    NSDictionary* entry = self.registerdUsers[row];
//    NSString* txt = [NSString stringWithFormat:@"%@",[entry objectForKey:@"name"]];
//    NSCell* cell = [[NSCell alloc] initTextCell:txt];
//    return cell;
//}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.registerdUsers.count;
}


#pragma mark - private

- (void)connectToAppleNotificationServer
{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"gateway.sandbox.push.apple.com", 2195, &readStream, &writeStream);
    self.readStream = (__bridge NSInputStream *)(readStream);
    self.writeStream = (__bridge NSOutputStream *)(writeStream);
    
    [self.readStream open];
    [self.writeStream open];
    
    if ([self.readStream streamStatus] != NSStreamStatusError
        && [self.writeStream streamStatus] != NSStreamStatusError)  {
        [self configureStream];
    }
    else
    {
        NSLog(@" Failed to connect to apple push server");
    }
}

- (NSArray*)certificateArray
{
    NSString* certPath = [[NSBundle mainBundle] pathForResource:@"aps_development_push_notification" ofType:@"cer"];
    
    NSData* certData = [NSData dataWithContentsOfFile:certPath];
    
    
    SecCertificateRef cert = SecCertificateCreateWithData(NULL,(__bridge CFDataRef)certData);
                                                                 
    SecIdentityRef identity;
    OSStatus err = SecIdentityCreateWithCertificate(NULL, cert, &identity);
    if (err) {
        NSLog(@"Failed to create certificate identity: %d",err);
        return nil;
    }
    
    return [NSArray arrayWithObjects:(__bridge id)identity,cert, nil];
}

- (void)configureStream
{
    NSArray* certArray = [self certificateArray];
    if (!certArray) {
        return;
    }
    
    NSDictionary* sslSettings = [NSDictionary dictionaryWithObjectsAndKeys:[self certificateArray],kCFStreamSSLCertificates,kCFStreamSocketSecurityLevelNegotiatedSSL,kCFStreamSSLLevel, nil];
    
    [self.writeStream setProperty:sslSettings forKey:(id)kCFStreamPropertySSLSettings];
    [self.readStream setProperty:sslSettings forKey:(id)kCFStreamPropertySSLSettings];
    
    self.readStream.delegate = self;
    self.writeStream.delegate = self;
    
    [self.writeStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.readStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

#pragma mark - stream delegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable:
            {
                //如果数据是服务器返回的，就说明又错误发生
                NSUInteger lengthRead = 0;
                do{
                    //错误数据包的大小是6个字节
                    uint8_t* buffer = malloc(6);
                    lengthRead = [self.readStream read:buffer maxLength:6];
                    //第一个字节是command（值固定是8）
                    uint8_t command = buffer[0];
                    //第二个字节是状态码
                    uint8_t status = buffer[1];
                    //获取通知标示符
                    uint32_t* ident = (uint32_t*)(buffer + 2);
                    NSLog(@"ERROR WITH NOTIFICATION:%d %d %d",(int)command,(int)status,*ident);
                    free(buffer);
                }while (lengthRead > 0);
                NSLog(@" %@ has byptes",aStream);
            }
            break;
        case NSStreamEventOpenCompleted:
            NSLog(@" %@ is open",aStream);
            break;
        case NSStreamEventHasSpaceAvailable:
            NSLog(@" %@ can accopt bytes",aStream);
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"%@ err: %@",aStream,[aStream streamError]);
            break;
        case NSStreamEventEndEncountered:
            NSLog(@"%@ ended - probably closed by server",aStream);
            break;
        default:
            break;
    }
}

- (NSData*)notificationDataForMessage:(NSString*)messageText token:(NSData*)token
{
    uint8_t command = 1;
    
    //针对响应通知的标示
    static uint32_t identifier = 5000;
    //通知有效期一天
    uint32_t expiry = htonl(time(NULL) + 86400);
    
    //token的数据长度
    uint16_t tokenLength = htons([token length]);
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:@{@"aps":@{@"alert":messageText,@"sound":@"Sound12.aif"}} options:0 error:nil];
    
    NSString* payload = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    uint16_t payloadLength = htons(strlen(payload.UTF8String));
    
    NSMutableData* data = [NSMutableData data];
    
    [data appendBytes:&command length:sizeof(command)];
    
    [data appendBytes:&identifier length:sizeof(identifier)];
    
    [data appendBytes:&expiry length:sizeof(expiry)];
    
    [data appendBytes:&tokenLength length:sizeof(tokenLength)];
    
    [data appendBytes:token.bytes length:token.length];
    
    [data appendBytes:&payloadLength length:sizeof(payloadLength)];
    
    [data appendBytes:payload.UTF8String length:strlen(payload.UTF8String)];
    
    NSLog(@"%@",payload);
    
    identifier ++;
    
    return data;
}

@end
