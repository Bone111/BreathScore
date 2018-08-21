//
//  SSDeleteButtonView.h
//  SeeScoreIOS
//
//  Created by James Sutton on 06/03/2016.
//  Copyright © 2016 Dolphin Computing Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SSDeleteButtonView : UIView

+(CGPoint)offset; // offset the button from the top right of the item it's attached to

+(CGRect)deleteFrameAt:(CGPoint)centre;

-(instancetype)initAt:(CGPoint)p;

-(void)animate:(UIView*)parent atCentre:(CGPoint)centre;

@end
