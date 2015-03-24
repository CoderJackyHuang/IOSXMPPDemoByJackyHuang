//
//  HYBAddBuddyController.m
//  XMPPDemo
//
//  Created by huangyibiao on 15/3/23.
//  Copyright (c) 2015年 huangyibiao. All rights reserved.
//

#import "HYBAddBuddyController.h"
#import "HYBXMPPHelper.h"

@interface HYBAddBuddyController ()

@property (weak, nonatomic) IBOutlet UITextField *jidTextField;

- (IBAction)onAddBuddyButtonClicked:(id)sender;

@end

@implementation HYBAddBuddyController

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (IBAction)onAddBuddyButtonClicked:(id)sender {
  if (self.jidTextField.text.length > 0) {
    [[HYBXMPPHelper shared] addBuddyWithJid:self.jidTextField.text completion:^(BOOL isSuccessful, NSString *errorMsg) {
      NSLog(@"%@", errorMsg);
      
      if (isSuccessful) {
        [self.navigationController popViewControllerAnimated:YES];
      } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMsg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
      }
    }];
  }
}

@end
