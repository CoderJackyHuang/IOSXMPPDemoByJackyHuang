//
//  HYBRegisterController.m
//  XMPPDemo
//
//  Created by huangyibiao on 15/3/23.
//  Copyright (c) 2015年 huangyibiao. All rights reserved.
//

#import "HYBRegisterController.h"
#import "HYBXMPPHelper.h"

@interface HYBRegisterController ()

@property (weak, nonatomic) IBOutlet UITextField *jidTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;

- (IBAction)onRegisterButtonClicked:(UIButton *)sender;

@end

@implementation HYBRegisterController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (IBAction)onRegisterButtonClicked:(UIButton *)sender {
  if (self.jidTextField.text.length > 0 && self.passwordTextField.text.length > 0) {
    [[HYBXMPPHelper shared] registerWithJid:self.jidTextField.text password:self.passwordTextField.text completion:^(BOOL isSuccessful, NSString *errorMsg) {
      if (isSuccessful) {
        [[NSUserDefaults standardUserDefaults] setObject:self.jidTextField.text forKey:kUserJIDKey];
        [[NSUserDefaults standardUserDefaults] setObject:self.passwordTextField.text forKey:kUserPasswordKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [self.navigationController popViewControllerAnimated:YES];
      } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMsg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
        NSLog(@"注册失败：%@", errorMsg);
      }
    }];
  }
}
@end
