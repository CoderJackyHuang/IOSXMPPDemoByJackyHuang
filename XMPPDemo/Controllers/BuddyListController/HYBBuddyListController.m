//
//  HYBBuddyListController.m
//  XMPPDemo
//
//  Created by huangyibiao on 15/3/23.
//  Copyright (c) 2015年 huangyibiao. All rights reserved.
//

#import "HYBBuddyListController.h"
#import "HYBXMPPHelper.h"
#import "HYBAddBuddyController.h"
#import "HYBChatController.h"

@interface HYBBuddyListController () <UITableViewDelegate, UITableViewDataSource> {
  NSMutableArray *_datasource;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation HYBBuddyListController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  _datasource = [[NSMutableArray alloc] init];
  
  UIBarButtonItem *item = [[UIBarButtonItem alloc]
                           initWithTitle:@"添加"
                           style:UIBarButtonItemStylePlain
                           target:self
                           action:@selector(onAddBuddyClicked:)];
  self.navigationItem.rightBarButtonItem = item;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  if (_datasource.count == 0) {
    [self loadBuddyList];
  }
}

// 加载所有好友
- (void)loadBuddyList {
  static int count = 0;
  
  [[HYBXMPPHelper shared] fetchBuddyListWithCompletion:^(NSArray *buddyList, NSString *errogMsg) {
    if (buddyList && buddyList.count) {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_datasource removeAllObjects];
        [_datasource addObjectsFromArray:buddyList];
        
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.tableView reloadData];
          count = 0;
        });
      });
    } else {
      count++;
      if (_datasource.count == 0 && count <= 10) {
        [self performSelector:@selector(loadBuddyList) withObject:nil afterDelay:0.5];
      }
    }
  }];
}

// 添加好友
- (void)onAddBuddyClicked:(id)sender {
  HYBAddBuddyController *add = [[HYBAddBuddyController alloc] init];
  add.hidesBottomBarWhenPushed = YES;
  [self.navigationController pushViewController:add animated:YES];
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  HYBChatController *chat = [[HYBChatController alloc] init];
  chat.hidesBottomBarWhenPushed = YES;
  XMPPUserCoreDataStorageObject *model = [_datasource objectAtIndex:indexPath.row];
  chat.jidString = model.jidStr;
  [self.navigationController pushViewController:chat animated:YES];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return _datasource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cellIdentifier = @"CellIdentifier";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
  
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                  reuseIdentifier:cellIdentifier];
  }
  
  /*
   subscription:
   .如果是none表示对方还没有确认
   .to 我关注对方
   . from 对方关注我
   .both 互粉
   
   section:
   .0 在线
   .1 离开
   .2 离线
   
   */
  if (indexPath.row < _datasource.count) {
    XMPPUserCoreDataStorageObject *model = [_datasource objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@ | %@",
                           [[model.jidStr componentsSeparatedByString:@"@"] firstObject],
                           [self subscriptionText:model.subscription]];
    cell.detailTextLabel.text = model.section == 0 ? @"在线" : model.section == 1 ? @"离开" : @"离线";
  }
  return cell;
}

- (NSString *)subscriptionText:(NSString *)subscription {
  if ([subscription isEqualToString:@"to"]) {
    return @"我关注对方";
  } else if ([subscription isEqualToString:@"from"]) {
    return @"对方关注我";
  } else if ([subscription isEqualToString:@"both"]) {
    return @"互为好友";
  }
  
  return @"对方还没有确认";
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    XMPPUserCoreDataStorageObject *model = [_datasource objectAtIndex:indexPath.row];
    [[HYBXMPPHelper shared] removeBuddyWithJid:model.jidStr completion:^(BOOL isSuccessful, NSString *errorMsg) {
      if (isSuccessful) {
        [_datasource removeObject:model];
        [tableView reloadData];
      } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMsg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
      }
    }];
  }
}

@end
