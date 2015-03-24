//
//  HYBLoginController.m
//  XMPPDemo
//
//  Created by huangyibiao on 15/3/23.
//  Copyright (c) 2015年 huangyibiao. All rights reserved.
//

#import "HYBLoginController.h"
#import "HYBRegisterController.h"
#import "HYBXMPPHelper.h"
#import "HYBBuddyListController.h"

@interface HYBLoginController ()

@property (weak, nonatomic) IBOutlet UITextField *jidTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;

- (IBAction)onLoginButtonClicked:(UIButton *)sender;
- (IBAction)onRegisterButtonClicked:(UIButton *)sender;

@end

@implementation HYBLoginController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  self.jidTextField.text = [userDefaults objectForKey:kUserJIDKey];
  self.passwordTextField.text = [userDefaults objectForKey:kUserPasswordKey];
}

- (IBAction)onLoginButtonClicked:(UIButton *)sender {
  if (self.jidTextField.text.length > 0 && self.passwordTextField.text.length > 0) {
    [[HYBXMPPHelper shared] loginWithJid:self.jidTextField.text password:self.passwordTextField.text completion:^(BOOL isSuccessful, NSString *errorMsg) {
      if (isSuccessful) {
        [[NSUserDefaults standardUserDefaults] setObject:self.jidTextField.text forKey:kUserJIDKey];
        [[NSUserDefaults standardUserDefaults] setObject:self.passwordTextField.text forKey:kUserPasswordKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        HYBBuddyListController *b = [[HYBBuddyListController alloc] init];
        b.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:b animated:YES];
      } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMsg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
      }
    }];
  }
}

- (IBAction)onRegisterButtonClicked:(UIButton *)sender {
  HYBRegisterController *registerController = [[HYBRegisterController alloc] init];
  registerController.hidesBottomBarWhenPushed = YES;
  [self.navigationController pushViewController:registerController animated:YES];
}

@end
