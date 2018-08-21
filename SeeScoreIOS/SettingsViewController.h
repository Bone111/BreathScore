//
//  SettingsViewController.h
//  SeeScoreIOS
//
//  Created by James Sutton on 23/03/2013.
//  Copyright (c) 2013 Dolphin Computing Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ChangeSettingsProtocol <NSObject>

-(void)showPartNames:(bool)pn;
-(void)showBarNumbers:(bool)bn;

@end

@interface SettingsViewController : UIViewController

@property (strong, nonatomic) IBOutlet UISwitch *partNamesSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *barNumbersSwitch;
@property (strong, nonatomic) IBOutlet id<ChangeSettingsProtocol> dlg;

-(void)setPartNames:(BOOL)pn barNumbers:(BOOL)bn dlg:(id<ChangeSettingsProtocol>)dlg;

- (IBAction)changePartNames:(id)sender;
- (IBAction)changeBarNumbers:(id)sender;

@end
