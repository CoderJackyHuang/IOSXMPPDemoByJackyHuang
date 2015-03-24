//
//  HYBChatController.m
//  XMPPDemo
//
//  Created by huangyibiao on 15/3/24.
//  Copyright (c) 2015年 huangyibiao. All rights reserved.
//

#import "HYBChatController.h"
#import "HYBXMPPHelper.h"
#import "XMPPMessageArchiving_Message_CoreDataObject.h"

@interface HYBChatController ()

@end

@implementation HYBChatController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.messageTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.messageSender = [HYBXMPPHelper shared].myNickname;
  [self setBackgroundColor:[UIColor lightGrayColor]];
  
  typeof(self) weakSelf = self;
  [HYBXMPPHelper shared].getNewMessageBlock = ^(XHMessage *newMessage, NSString *receiver) {
    if ([receiver isEqualToString:weakSelf.jidString]) {
      [weakSelf addMessage:newMessage];
      [weakSelf.messageTableView reloadData];
    }
  };
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [HYBXMPPHelper shared].currentChatingBuddyJidString = self.jidString;

  if (self.messages.count == 0) {
    [self loadMessageList];
  }
}

- (void)loadMessageList {
  [[HYBXMPPHelper shared] fetchMessageListWithCompletion:^(NSArray *buddyList, NSString *errogMsg) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [self.messages removeAllObjects];
      [self.messages addObjectsFromArray:buddyList];
      
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.messageTableView reloadData];
      });
    });
  }];
}

#pragma mark - XHMessageTableViewControllerDataSource
- (id<XHMessageModel>)messageForRowAtIndexPath:(NSIndexPath *)indexPath {
  return [self.messages objectAtIndex:indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath targetMessage:(id<XHMessageModel>)message {
  static NSString *CellIdentifier = @"Cell";
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    cell.textLabel.font = [UIFont systemFontOfSize:15];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  }
  
  XHMessage *model = [self.messages objectAtIndex:indexPath.row];
  NSMutableString *showString = [[NSMutableString alloc] init];
  if (model.sender) {
    [showString appendFormat:@"发送者:%@\n",model.sender];
  }
  [showString appendString:model.text];
  
  if (model.timestamp) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
    [formatter setDateStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
    [showString appendFormat:@"\ntimestamp:%@\n",[formatter stringFromDate:model.timestamp]];
  }
  cell.textLabel.numberOfLines = 50;
  cell.textLabel.text = showString;
  
  return cell;
}


- (void)didSendText:(NSString *)text fromSender:(NSString *)sender onDate:(NSDate *)date {
  XHMessage *textMessage = [[XHMessage alloc] initWithText:text sender:sender timestamp:date];
  [self addMessage:textMessage];
  [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypeText];
  
  [[HYBXMPPHelper shared] sendText:text toJid:self.jidString completion:^(BOOL isSuccessful, NSString *errorMsg) {
    if (isSuccessful) {
      // 发送成功
    } else {
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMsg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
      [alert show];
    }
  }];
}

//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath targetMessage:(id<XHMessageModel>)message {
//  return 100;
//}

- (void)configureCell:(XHMessageTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row % 4) {
    cell.messageBubbleView.displayTextView.textColor = [UIColor colorWithRed:0.106 green:0.586 blue:1.000 alpha:1.000];
  } else {
    cell.messageBubbleView.displayTextView.textColor = [UIColor blackColor];
  }
}

- (BOOL)shouldDisplayTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
  return indexPath.row % 2;
}

- (BOOL)shouldPreventScrollToBottomWhileUserScrolling {
  return YES;
}


@end
