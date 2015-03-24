//
//  HYBXMPPHelper.h
//  XMPPDemo
//
//  Created by huangyibiao on 15/3/23.
//  Copyright (c) 2015年 huangyibiao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPFramework.h"

@class XHMessage;

#define kServer @"127.0.0.1"

typedef void (^HYBCompletionBlock)(BOOL isSuccessful, NSString *errorMsg);
typedef void (^HYBFetchResultBlock)(NSArray *buddyList, NSString *errogMsg);
typedef HYBFetchResultBlock HYBMessageListBlock;
// to表示接收者的JID
typedef void (^HYBGetNewMessageBlock)(XHMessage *newMessage, NSString *to);

@interface HYBXMPPHelper : NSObject <XMPPStreamDelegate, XMPPRosterDelegate>

/**
 * 如果我的昵称为空，则返回JID字符串
 */
@property (nonatomic, copy, readonly) NSString *myNickname;
/**
 * 接收到新消息时的回调
 */
@property (nonatomic, copy) HYBGetNewMessageBlock getNewMessageBlock;
@property (nonatomic, copy) NSString *currentChatingBuddyJidString;

/**
 * Singleton shared method
 */
+ (HYBXMPPHelper *)shared;

- (BOOL)connect;
- (BOOL)disconnect;
// 上线
- (void)goOnline;
// 下线
- (void)goOffline;

- (void)destroyResources;

/**
 * 注册账号
 *
 * @param jidString 账号，如test,不要写完整的test@example.com
 * @param password 密码
 * @param completion 完成时的回调
 */
- (void)registerWithJid:(NSString *)jidString
               password:(NSString *)password
             completion:(HYBCompletionBlock)completion;

/**
 * 登录
 *
 * @param jidString 账号，如test,不要写完整的test@example.com
 * @param password 密码
 * @param completion 完成时的回调
 */
- (void)loginWithJid:(NSString *)jidString
               password:(NSString *)password
             completion:(HYBCompletionBlock)completion;

/**
 * 添加好友
 *
 * @param jidString  账号，如test,不要写完整的test@example.com
 * @param completion 完成时的回调
 */
- (void)addBuddyWithJid:(NSString *)jidString completion:(HYBCompletionBlock)completion;

/**
 * 删除好友
 *
 * @param jidString  账号，如test,不要写完整的test@example.com
 * @param completion 完成时的回调
 */
- (void)removeBuddyWithJid:(NSString *)jidString completion:(HYBCompletionBlock)completion;

/**
 * 获取好友列表
 */
- (void)fetchBuddyListWithCompletion:(HYBFetchResultBlock)completion;

/**
 * 获取消息列表
 */
- (void)fetchMessageListWithCompletion:(HYBMessageListBlock)completion;

/**
 * 发送文本消息
 */
- (void)sendText:(NSString *)text toJid:(NSString *)jidString completion:(HYBCompletionBlock)completion;

@end
