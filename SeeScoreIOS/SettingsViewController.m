//
//  SettingsViewController.m
//  SeeScoreIOS
//
//  Created by James Sutton on 23/03/2013.
//  Copyright (c) 2013 Dolphin Computing Ltd. All rights reserved.
//

#import "SettingsViewController.h"

@interface SettingsViewController ()
{
	bool showPartNames;
	bool showBarNumbers;
    UIImageView *splashView;
}

@end

@implementation SettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.partNamesSwitch.on = showPartNames;
	self.barNumbersSwitch.on = showBarNumbers;
}

-(void)setPartNames:(BOOL)pn barNumbers:(BOOL)bn dlg:(id<ChangeSettingsProtocol>)dlg
{
	showPartNames = pn;
	showBarNumbers = bn;
	self.dlg = dlg;
}

- (IBAction)changePartNames:(id)sender {
	[self.dlg showPartNames:((UISwitch*)sender).on];
}

- (IBAction)changeBarNumbers:(id)sender {
	[self.dlg showBarNumbers:((UISwitch*)sender).on];
}



@end
