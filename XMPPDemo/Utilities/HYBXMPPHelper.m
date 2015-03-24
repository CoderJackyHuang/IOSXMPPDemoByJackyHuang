//
//  HYBXMPPHelper.m
//  XMPPDemo
//
//  Created by huangyibiao on 15/3/23.
//  Copyright (c) 2015年 huangyibiao. All rights reserved.
//

#import "HYBXMPPHelper.h"
#import "XMPPMessageArchiving.h"
#import "XMPPMessageArchivingCoreDataStorage.h"
#import "XHMessage.h"

#define kFetchBuddyListQueryID @"1234567"

@interface HYBXMPPHelper () {
  NSString *_jid;
  NSString *_password;
  BOOL _isRegistering;
  BOOL _isLogining;
  NSString *_myNickname;
}

@property (nonatomic, strong) XMPPStream *xmppStream;
@property (nonatomic, strong) XMPPReconnect *xmppReconnect;

// 花名册相关
@property (nonatomic, strong) XMPPRoster *xmppRoster;
@property (nonatomic, strong) XMPPRosterCoreDataStorage *xmppRosterStorage;

// 名片相关
@property (nonatomic, strong) XMPPvCardCoreDataStorage *xmppvCardStorage;
@property (nonatomic, strong) XMPPvCardTempModule *xmppvCardTempModule;
@property (nonatomic, strong) XMPPvCardAvatarModule *xmppvCardAvatarModule;

// 性能相关
@property (nonatomic, strong) XMPPCapabilities *xmppCapabilities;
@property (nonatomic, strong) XMPPCapabilitiesCoreDataStorage *xmppCapailitiesStorage;

// 消息相关
@property (nonatomic, strong) XMPPMessageArchiving *xmppMessageArchiving;
@property (nonatomic, strong) XMPPMessageArchivingCoreDataStorage *xmppMessageStorage;

@property (nonatomic, copy) HYBCompletionBlock completionBlock;
@property (nonatomic, copy) HYBFetchResultBlock buddyListBlock;
@property (nonatomic, copy) HYBMessageListBlock messageListBlock;
@property (nonatomic, copy) HYBCompletionBlock sendMessageBlock;

@end

@implementation HYBXMPPHelper

+ (HYBXMPPHelper *)shared {
  static HYBXMPPHelper *sg_xmppSharedObject = nil;
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    if (!sg_xmppSharedObject) {
      sg_xmppSharedObject = [[self alloc] init];
      [sg_xmppSharedObject setupXmppStream];
    }
  });
  
  return sg_xmppSharedObject;
}

#pragma mark - Public
- (NSString *)myNickname {
 XMPPUserCoreDataStorageObject *object = [_xmppRosterStorage userForJID:_xmppStream.myJID
                                                             xmppStream:_xmppStream
                                                   managedObjectContext:[self rosterContext]];
  if (object.nickname) {
    return object.nickname;
  }
  
  if (object) {
    return object.jidStr;
  }
  
  return @"Jacky Huang";
}

- (void)registerWithJid:(NSString *)jidString
               password:(NSString *)password
             completion:(HYBCompletionBlock)completion {
  _isLogining = NO;
  
  if (_isRegistering) {
    return;
  }
  
  if (jidString == nil || password == nil) {
    if (completion) {
      completion(NO, @"用户名或者密码不能为空");
    }
    return;
  }
  
  _jid = jidString;
  _password = password;
  self.completionBlock = completion;

  _isRegistering = YES;
  if (![_xmppStream isConnected]) {
    if (![self connect]) {
      _isRegistering = NO;
      
      if (completion) {
        completion(NO, @"连接服务器失败");
      }
    }
    return;
  }
  
  [self registerWithJid:jidString];
}

- (void)registerWithJid:(NSString *)jidString {
  if (![jidString hasSuffix:kServer]) {
    jidString = [NSString stringWithFormat:@"%@@%@", jidString, kServer];
  }
  [_xmppStream setMyJID:[XMPPJID jidWithString:jidString]];
  
  // 设置服务器
  [_xmppStream setHostName:kServer];
  
  NSError *error = nil;
  _isRegistering = YES;
  if (![_xmppStream registerWithPassword:_password error:&error]) {
    NSLog(@"注册账号失败：%@", [error description]);
    _isRegistering = NO;
    if (self.completionBlock) {
      self.completionBlock(NO, [error description]);
    }
  }
}

- (void)loginWithJid:(NSString *)jidString
            password:(NSString *)password
          completion:(HYBCompletionBlock)completion {
  _isRegistering = NO;
  
  if (_xmppStream.isAuthenticated) {// 已经登录了，就无须再登录
    if (completion) {
      completion(YES, nil);
    }
    return;
  }
  
  if (_isLogining) {
    return;
  }
  
  if (jidString == nil || password == nil) {
    if (completion) {
      completion(NO, @"用户名或者密码不能为空");
    }
    return;
  }
  
  _jid = jidString;
  _password = password;
    self.completionBlock = completion;
  _isLogining = YES;
  
  if (![_xmppStream isConnected]) {
    if (![self connect]) {
      _isLogining = NO;
      
      if (completion) {
        completion(NO, @"连接服务器失败");
      }
    }
    return;
  }
  
  [self loginWithJid:jidString];
}

- (void)loginWithJid:(NSString *)jidString {
  if (![jidString hasSuffix:kServer]) {
    jidString = [NSString stringWithFormat:@"%@@%@", jidString, kServer];
  }
  [_xmppStream setMyJID:[XMPPJID jidWithString:jidString]];
  
  // 设置服务器
  [_xmppStream setHostName:kServer];
  
  NSError *error = nil;
  _isLogining = YES;
  if (![_xmppStream authenticateWithPassword:_password error:&error]) {
    NSLog(@"登录失败：%@", [error description]);
    _isLogining = NO;
    if (self.completionBlock) {
      self.completionBlock(NO, [error description]);
    }
  }
}

- (void)addBuddyWithJid:(NSString *)jidString completion:(HYBCompletionBlock)completion {
  if (![jidString hasSuffix:kServer]) {
    jidString = [NSString stringWithFormat:@"%@@%@", jidString, kServer];
  }
  
  // 先判断是否已经是我的好友，如果是，就不再添加
  if ([_xmppRosterStorage userForJID:[XMPPJID jidWithString:jidString]
                          xmppStream:_xmppStream
                managedObjectContext:[self rosterContext]]) {
    if (completion) {
      completion(NO, [NSString stringWithFormat:@"%@已经是您的好友！", jidString]);
    }
    return;
  }
  
  self.completionBlock = completion;
  
  // 设置服务器
  [_xmppStream setHostName:kServer];
  
// 发送添加好友请求
  /*
   presence.type有以下几种状态：
   
   available: 表示处于在线状态(通知好友在线)
   unavailable: 表示处于离线状态（通知好友下线）
   subscribe: 表示发出添加好友的申请（添加好友请求）
   unsubscribe: 表示发出删除好友的申请（删除好友请求）
   unsubscribed: 表示拒绝添加对方为好友（拒绝添加对方为好友）
   error: 表示presence信息报中包含了一个错误消息。（出错）
   */
  [_xmppRoster subscribePresenceToUser:[XMPPJID jidWithString:jidString]];
}

- (void)removeBuddyWithJid:(NSString *)jidString completion:(HYBCompletionBlock)completion {
  if (![jidString hasSuffix:kServer]) {
    jidString = [NSString stringWithFormat:@"%@@%@", jidString, kServer];
  }
  
  self.completionBlock = completion;
  
  // 设置服务器
  [_xmppStream setHostName:kServer];

  // 发送移除好友请求
  [_xmppRoster removeUser:[XMPPJID jidWithString:jidString]];
  // 如果用下面的方法来移除，则需要在移除后，手动调用从数据库中移除，否则会有问题
 // [_xmppRoster unsubscribePresenceFromUser:[XMPPJID jidWithString:jidString]];
}

/*
 一个 IQ 请求：
 <iq type="get"
 　　from="xiaoming@example.com"
 　　to="example.com"
 　　id="1234567">
 　　<query xmlns="jabber:iq:roster"/>
 <iq />
 
 type 属性，说明了该 iq 的类型为 get，与 HTTP 类似，向服务器端请求信息
 from 属性，消息来源，这里是你的 JID
 to 属性，消息目标，这里是服务器域名
 id 属性，标记该请求 ID，当服务器处理完毕请求 get 类型的 iq 后，响应的 result 类型 iq 的 ID 与 请求 iq 的 ID 相同
 <query xmlns="jabber:iq:roster"/> 子标签，说明了客户端需要查询 roster
 */
- (void)fetchBuddyListWithCompletion:(HYBFetchResultBlock)completion {
  self.buddyListBlock = completion;
  
  // 通过coredata获取好友列表
  NSManagedObjectContext *context = [self rosterContext];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
                                            inManagedObjectContext:context];
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  [request setEntity:entity];
  
 __block NSError *error = nil;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSArray *results =[context executeFetchRequest:request error:&error];
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion) {
        completion(results, [error description]);
      }
    });
  });
  // 下面的方法是从服务器中查询获取好友列表
//  // 创建iq节点
//  NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
//  [iq addAttributeWithName:@"type" stringValue:@"get"];
//  [iq addAttributeWithName:@"from" stringValue:[NSString stringWithFormat:@"%@@%@", _jid, kServer]];
//  [iq addAttributeWithName:@"to" stringValue:kServer];
//  [iq addAttributeWithName:@"id" stringValue:kFetchBuddyListQueryID];
//  // 添加查询类型
//  NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
//  [iq addChild:query];
//  
//  // 发送查询
//  [_xmppStream sendElement:iq];
}

- (void)fetchMessageListWithCompletion:(HYBMessageListBlock)completion {
  self.messageListBlock = completion;
  
  NSManagedObjectContext *context = [self messageContext];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPMessageArchiving_Message_CoreDataObject"
                                            inManagedObjectContext:context];
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  [request setEntity:entity];
  
  if (self.currentChatingBuddyJidString != nil) {
    // 过滤内容，只找我与正要聊天的好友的聊天记录
    NSString *jidString = [NSString stringWithFormat:@"%@@%@", _jid, kServer];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(bareJidStr like %@) && (streamBareJidStr like %@)", self.currentChatingBuddyJidString , jidString];
    request.predicate = predicate;
  }
  __block NSError *error = nil;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSArray *results =[context executeFetchRequest:request error:&error];
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:results.count];
    for (XMPPMessageArchiving_Message_CoreDataObject *object in results) {
      XHMessage *model = [[XHMessage alloc] initWithText:object.body
                                                  sender:object.bareJidStr
                                               timestamp:object.timestamp];
      [array addObject:model];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion) {
        completion(array, [error description]);
      }
    });
  });
}

/*
  发送消息的格式
 <message type="chat" to="hehe@example.com">
 　　<body>Hello World!<body />
 <message />
 */
- (void)sendText:(NSString *)text toJid:(NSString *)jidString completion:(HYBCompletionBlock)completion {
   self.sendMessageBlock = completion;
   
  NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
  [body setStringValue:text];
  
  NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
  [message addAttributeWithName:@"type" stringValue:@"chat"];
  
   if (![jidString hasSuffix:kServer]) {
     jidString = [NSString stringWithFormat:@"%@@%@", jidString, kServer];
   }
   
  [message addAttributeWithName:@"to" stringValue:jidString];
  [message addChild:body];
  [self.xmppStream sendElement:message];
}

- (void)destroyResources {
  [_xmppStream removeDelegate:self];
  [_xmppRoster removeDelegate:self];
  [_xmppReconnect deactivate];
  [_xmppRoster deactivate];
  [_xmppvCardTempModule deactivate];
  [_xmppvCardAvatarModule deactivate];
  [_xmppCapabilities deactivate];
  [_xmppMessageArchiving deactivate];
  
  [_xmppStream disconnect];
  
  _xmppStream = nil;
  _xmppRoster = nil;
  _xmppReconnect = nil;
  _xmppRosterStorage = nil;
  _xmppvCardAvatarModule = nil;
  _xmppvCardStorage = nil;
  _xmppvCardTempModule = nil;
  _xmppCapabilities = nil;
  _xmppCapailitiesStorage = nil;
  _xmppMessageStorage = nil;
  _xmppMessageArchiving = nil;
}

- (BOOL)connect {
  if (![_xmppStream isDisconnected]) {
    return NO;
  }
  
  if (_jid == nil || _password == nil) {
    return NO;
  }
  
  [_xmppStream setMyJID:[XMPPJID jidWithString:_jid]];
  [_xmppStream setHostName:kServer];
  
  // 连接
  NSError *error = nil;
  if (![_xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error]) {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting"
                                                        message:@"See console for error details."
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles:nil];
    [alertView show];
    
    NSLog(@"Error connecting: %@", [error description]);
    
    return NO;
  }
  
  return YES;
}

- (BOOL)disconnect {
  if ([_xmppStream isDisconnected]) {
    NSLog(@"current xmpp stream is disconnected.");
    return NO;
  }
  
  [self goOffline];
  [_xmppStream disconnect];
  
  return YES;
}

- (void)goOnline {
  // 获取现场节点，默认type = "available"
  XMPPPresence *presence = [XMPPPresence presence];
  NSString *domain = [_xmppStream.myJID domain];
  
  // Google set their presence priority to 24, so we do the same to be compatible.
  if ([domain isEqualToString:@"gmail.com"]
      || [domain isEqualToString:@"gtalk.com"]
      || [domain isEqualToString:@"talk.google.com"]) {
    NSXMLElement *priority = [NSXMLElement elementWithName:@"priority"
                                               stringValue:@"24"];
    [presence addChild:priority];
  }
  
  // 发送下线信息
  [_xmppStream sendElement:presence];
}

- (void)goOffline {
  XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
  [_xmppStream sendElement:presence];
}

#pragma mark - Private
- (NSManagedObjectContext *)rosterContext {
  return [_xmppRosterStorage mainThreadManagedObjectContext];
}

- (NSManagedObjectContext *)capabilitesContext {
  return [_xmppCapailitiesStorage mainThreadManagedObjectContext];
}

- (NSManagedObjectContext *)messageContext {
  return [_xmppMessageStorage mainThreadManagedObjectContext];
}

- (void)setupXmppStream {
  NSAssert(_xmppStream == nil, @"-setupXmppStream method called multiple times");
  
  _jid = [[NSUserDefaults standardUserDefaults] objectForKey:kUserJIDKey];
  _password = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPasswordKey];
  
  
  _xmppStream = [[XMPPStream alloc] init];
  
#if !TARGET_IPHONE_SIMULATOR
  // 设置此行为YES,表示允许socket在后台运行
  // 在模拟器上是不支持在后台运行的
  _xmppStream.enableBackgroundingOnSocket = YES;
#endif
  
  // XMPPReconnect模块会监控意外断开连接并自动重连
  _xmppReconnect = [[XMPPReconnect alloc] init];
  
  // 配置花名册并配置本地花名册储存
  _xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] init];
  _xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:_xmppRosterStorage];
  _xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
  _xmppRoster.autoFetchRoster = YES;
  
  // 配置vCard存储支持，vCard模块结合vCardTempModule可下载用户Avatar
  _xmppvCardStorage = [[XMPPvCardCoreDataStorage alloc] init];
  _xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:_xmppvCardStorage];
  _xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:_xmppvCardTempModule];
  
  // XMPP特性模块配置，用于处理复杂的哈希协议等
  _xmppCapailitiesStorage = [[XMPPCapabilitiesCoreDataStorage alloc] init];
  _xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:_xmppCapailitiesStorage];
  _xmppCapabilities.autoFetchHashedCapabilities = YES;
  _xmppCapabilities.autoFetchNonHashedCapabilities = NO;
  
  // 激活XMPP stream
  [_xmppReconnect activate:_xmppStream];
  [_xmppRoster activate:_xmppStream];
  [_xmppvCardTempModule activate:_xmppStream];
  [_xmppvCardAvatarModule activate:_xmppStream];
  [_xmppCapabilities activate:_xmppStream];
  
  // 消息相关
  _xmppMessageStorage = [[XMPPMessageArchivingCoreDataStorage alloc] init];
  _xmppMessageArchiving = [[XMPPMessageArchiving alloc] initWithMessageArchivingStorage:_xmppMessageStorage];
  [_xmppMessageArchiving setClientSideMessageArchivingOnly:YES];
  [_xmppMessageArchiving activate:_xmppStream];
  
  // 添加代理
  [_xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
  [_xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
  [_xmppMessageArchiving addDelegate:self delegateQueue:dispatch_get_main_queue()];
}

// XMPP协议错误码
//
- (NSString *)errorMessageWithErrorCode:(int)errorCode {
  switch (errorCode) {
    case 302:
      return @"重定向";
    case 400:
      return @"无效的请求";
    case 401:
      return @"未经过授权认证";
    case 402: // 目前保留，未使用
      return @"";
    case 403:
      return @"服务器拒绝执行，可能是注册密码存储失败";
    case 404:
      return @"找不到匹配的资源";
    case 405:
      return @"可能是权限不够，不允许操作";
    case 406:
      return @"服务器不授受";
    case 407:// 目前未使用
      return @"";
    case 408: // 当前只用于Jabber会话管理器使用的零度认证模式中。
      return @"注册超时";
    case 409:
      return @"用户名已经存在"; // 冲突
    case 500:
      return @"服务器内部错误";
    case 501:
      return @"服务器不支持此功能，不可执行";
    case 502:
      return @"远程服务器错误";
    case 503:
      return @"无法提供此服务";
    case 504:
      return @"远程服务器超时";
    case 510:
      return @"连接失败";
    default:
      break;
  }
  
  return @"发生未知错误";
}

#pragma mark - XMPPStreamDelegate
- (void)xmppStreamWillConnect:(XMPPStream *)sender {
  NSLog(@"xmpp stream 即将连接");
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender {
  NSLog(@"xmpp stream 已经连接上");
  
  NSString *password = [[NSUserDefaults standardUserDefaults] objectForKey:kUserPasswordKey];
  NSError *error = nil;
  if (!_isRegistering && ![_xmppStream authenticateWithPassword:password error:&error]) {
    NSLog(@"密码校验失败，登录不成功");
  }
}

- (void)xmppStreamConnectDidTimeout:(XMPPStream *)sender {
  NSLog(@"xmpp stream 连接超时");
}

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket {
  NSLog(@"socketDidConnect 成功连接上");
}

// @begin
// 登录相关
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
  if (_isRegistering) {
    [self registerWithJid:_jid];
    return;
  }
  
  // 登录成功
  if (self.completionBlock && _isLogining) {
    self.completionBlock(YES, nil);
  }
  
  NSLog(@"密码校验成功，用户将要上线");
  _isLogining = NO;
  [self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(DDXMLElement *)error {
  if (_isRegistering) {
    [self registerWithJid:_jid];
    return;
  }
  
  if (_isLogining) {
    [self loginWithJid:_jid];
    return;
  }
  
  _isLogining = NO;
  NSLog(@"didNotAuthenticate :密码校验失败，登录不成功,原因是：%@", [error XMLString]);
}
// @end

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error {
  NSLog(@"接收信息时，出现异常：%@", [error description]);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error {
  NSLog(@"xmpp stream 退出连接失败：%@", [error description]);
}

- (XMPPIQ *)xmppStream:(XMPPStream *)sender willReceiveIQ:(XMPPIQ *)iq {
  NSLog(@"willReceiveIQ: %@", iq.type);
  
  return iq;
}

/*
 一个 IQ 响应：
 <iq type="result"
 　　id="1234567"
 　　to="xiaoming@example.com">
 　　<query xmlns="jabber:iq:roster">
 　　　　<item jid="xiaoyan@example.com" name="小燕" />
 　　　　<item jid="xiaoqiang@example.com" name="小强"/>
 　　<query />
 <iq />
 type 属性，说明了该 iq 的类型为 result，查询的结果
 <query xmlns="jabber:iq:roster"/> 标签的子标签 <item />，为查询的子项，即为 roster
 item 标签的属性，包含好友的 JID，和其它可选的属性，例如昵称等。
 */
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
  NSLog(@"xmpp stream 接收到查询消息：%@", [iq XMLString]);
  
  // 获取好友列表结果
  if ([iq.type isEqualToString:@"result"]) {
    NSXMLElement *query = [iq elementForName:@"query"];
    // 如果是注册，from和to都不为空，如果是删除，且待删除的用户在服务器中并没有，那么就没有from和to
    if ([iq attributeStringValueForName:@"from"] && [iq attributeStringValueForName:@"to"]) {
      return YES;
    }
    
    if (query == nil) { // 用户不存在，直接从数据库删除即可
      if (self.completionBlock && !_isLogining && !_isRegistering) {
        self.completionBlock(YES, nil);
      }
      return YES;
    }
    // 这种方式是通过手动发送IQ来查询好友列表的，不过这样操作不如使用XMPP自带的coredata操作方便
//    NSString *thdID = [NSString stringWithFormat:@"%@", [iq attributeStringValueForName:@"id"] ];
//    if ([thdID isEqualToString:kFetchBuddyListQueryID]) {
//      NSXMLElement *query = [iq elementForName:@"query"];
//      
//      NSMutableArray *result = [[NSMutableArray alloc] init];
//      for (NSXMLElement *item in query.children) {
//        NSString *jid = [item attributeStringValueForName:@"jid"];
//        NSString *name = [item attributeStringValueForName:@"name"];
//        
//        HYBBuddyModel *model = [[HYBBuddyModel alloc] init];
//        model.jid = jid;
//        model.name = name;
//        
//        [result addObject:model];
//      }
//      
//      if (self.buddyListBlock) {
//        self.buddyListBlock(result, nil);
//      }
//      
//      return YES;
//    }
  }
  // 删除好友需要先查询，所以会进入到此代理回调函数中，如果type=@"set",
  // 说明是更新操作，即删除好友或者添加好友查询
  else if ([iq.type isEqualToString:@"set"] && !_isRegistering && !_isLogining) {
    NSXMLElement *query = [iq elementForName:@"query"];
    for (NSXMLElement *item in query.children) {
      NSString *ask = [item attributeStringValueForName:@"ask"];
      NSString *subscription = [item attributeStringValueForName:@"subscription"];
      if ([ask isEqualToString:@"unsubscribe"] && ![subscription isEqualToString:@"none"]) { // 删除好友成功
        if (self.completionBlock) {
          self.completionBlock(YES, nil);
        }
        return YES;
      }
      // 请求添加好友，但是查询没有结果，表示用户不存在
      // none表示未确认
      else if ([ask isEqualToString:@"subscribe"] && [subscription isEqualToString:@"none"]) {
        if (self.completionBlock) {
          self.completionBlock(YES, @"发送添加好友请求成功");
        }
        return YES;
      } else if (![subscription isEqualToString:@"none"]) { // 添加好友请求，查询成功
        return YES;
      }
    }
  }
  
  return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
  NSLog(@"xmpp stream 接收到好友消息：%@", [message XMLString]);
  
  if (self.getNewMessageBlock) {
    XHMessage *newMessage = [[XHMessage alloc] initWithText:message.body
                                                     sender:message.fromStr
                                                  timestamp:[NSDate date]];
    self.getNewMessageBlock(newMessage, message.from.bare);
  }
}

// @begin
// 注册相关
- (void)xmppStreamDidRegister:(XMPPStream *)sender {
  NSLog(@"注册成功");
  
  if (self.completionBlock && _isRegistering) {
    self.completionBlock(YES, nil);
  }
  
  _isRegistering = NO;
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(DDXMLElement *)error {
  /*
   <iq xmlns="jabber:client" type="error" to="127.0.0.1/347f0596">
   <query xmlns="jabber:iq:register">
   <username>test</username>
   <password>test</password>
   </query>
   <error code="409" type="cancel">
   <conflict xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"></conflict>
   </error>
   </iq>
   */
  NSLog(@"注册失败： %@", error);
  DDXMLElement *query = [error elementForName:@"query"];
  DDXMLElement *username = [query elementForName:@"username"];
  DDXMLElement *password = [query elementForName:@"password"];
  
  DDXMLElement *errorNode = [error elementForName:@"error"];
  int code = [errorNode attributeIntValueForName:@"code"];
  NSLog(@"%@ %@", [username stringValue], [password stringValue]);
  if (self.completionBlock && _isRegistering && !_isLogining) {
    self.completionBlock(NO, [self errorMessageWithErrorCode:code]);
  }
  
  _isRegistering = NO;
}
// @end

/*
 presence.type有以下几种状态：
 
 available: 表示处于在线状态(通知好友在线)
 unavailable: 表示处于离线状态（通知好友下线）
 subscribe: 表示发出添加好友的申请（添加好友请求）
 unsubscribe: 表示发出删除好友的申请（删除好友请求）
 unsubscribed: 表示拒绝添加对方为好友（拒绝添加对方为好友）
 error: 表示presence信息报中包含了一个错误消息。（出错）
 */
- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence {
  NSLog(@"接收到好友申请消息：%@", [presence fromStr]);
  // 好友在线状态
  NSString *type = [presence type];
  // 发送请求者
  NSString *fromUser = [[presence from] user];
  NSLog(@"接收到好友请求状态：%@   发送者：%@", type, fromUser);
  
  // 好友上线下线处理，具体应该要在此做一些处理，如更新好友在线状态
  // TO DO
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message {
  if (self.sendMessageBlock) {
    self.sendMessageBlock(YES, nil);
  }
}

- (void)xmppStream:(XMPPStream *)sender didFailToSendMessage:(XMPPMessage *)message error:(NSError *)error {
  if (self.sendMessageBlock) {
    self.sendMessageBlock(NO, [error description]);
  }
}

#pragma mark - XMPPRosterDelegate
// 加好友回调函数
/*
 presence.type有以下几种状态：
 
 available: 表示处于在线状态(通知好友在线)
 unavailable: 表示处于离线状态（通知好友下线）
 subscribe: 表示发出添加好友的申请（添加好友请求）
 unsubscribe: 表示发出删除好友的申请（删除好友请求）
 unsubscribed: 表示拒绝添加对方为好友（拒绝添加对方为好友）
 error: 表示presence信息报中包含了一个错误消息。（出错）
 */
- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence {
  NSLog(@"接收到好友申请消息：%@", [presence fromStr]);
  // 好友在线状态
  NSString *type = [presence type];
  // 发送请求者
  NSString *fromUser = [[presence from] user];
  // 接收者id
  NSString *user = _xmppStream.myJID.user;
  
  NSLog(@"接收到好友请求状态：%@   发送者：%@  接收者：%@", type, fromUser, user);
  
  // 防止自己添加自己为好友
  if (![fromUser isEqualToString:user]) {
    if ([type isEqualToString:@"subscribe"]) { // 添加好友
      // 接受添加好友请求,发送type=@"subscribed"表示已经同意添加好友请求并添加到好友花名册中
      [_xmppRoster acceptPresenceSubscriptionRequestFrom:[XMPPJID jidWithString:fromUser]
                                          andAddToRoster:YES];
      NSLog(@"已经添加对方为好友，这里就没有弹出让用户选择是否同意，自动同意了");
    } else if ([type isEqualToString:@"unsubscribe"]) { // 请求删除好友
      
    }
  }
}

// 添加好友同意后，会进入到此代理
- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterPush:(XMPPIQ *)iq {
  NSLog(@"添加成功!!!didReceiveRosterPush -> :%@",iq.description);
  
  DDXMLElement *query = [iq elementsForName:@"query"][0];
  DDXMLElement *item = [query elementsForName:@"item"][0];
  
  NSString *subscription = [[item attributeForName:@"subscription"] stringValue];
  // 对方请求添加我为好友且我已同意
  if ([subscription isEqualToString:@"from"]) {// 对方关注我
    NSLog(@"我已同意对方添加我为好友的请求");
  }
  // 我成功添加对方为好友
  else if ([subscription isEqualToString:@"to"]) {// 我关注对方
    NSLog(@"我成功添加对方为好友，即对方已经同意我添加好友的请求");
  } else if ([subscription isEqualToString:@"remove"]) {
    // 删除好友
    if (self.completionBlock) {
      self.completionBlock(YES, nil);
    }
  }
}

/**
 * Sent when the roster receives a roster item.
 *
 * Example:
 *
 * <item jid='romeo@example.net' name='Romeo' subscription='both'>
 *   <group>Friends</group>
 * </item>
 **/
// 已经互为好友以后，会回调此
- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(NSXMLElement *)item {
  NSString *subscription = [item attributeStringValueForName:@"subscription"];
  if ([subscription isEqualToString:@"both"]) {
    NSLog(@"双方已经互为好友");
    if (self.buddyListBlock) {
      // 更新好友列表
      [self fetchBuddyListWithCompletion:self.buddyListBlock];
    }
  }
}

@end
