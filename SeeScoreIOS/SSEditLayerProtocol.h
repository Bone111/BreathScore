//
//  SSEditLayerProtocol.h
//  SeeScoreIOS
//
//  Created by James Sutton on 16/02/2016.
//  Copyright © 2016 Dolphin Computing Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol SSEditLayerProtocol <NSObject>

/*!
 * @method view
 * @abstract return the UIView associated with the editlayer
 */
-(UIView *)view;

/*!
 * @method clear:
 * @abstract
 */
-(void)clear;

/*!
 * @method selectComponent:
 * @abstract
 * @param
 */
-(void) selectComponent:(SSComponent*)comp;

/*!
 * @method addOverlaidDirectionWordsTextFieldAt:system:
 * @abstract
 * @param
 */
-(void)addOverlaidDirectionWordsTextFieldAt:(CGPoint)pos system:(SSSystem*)system;

/*!
 * @method abortTextInput
 * @abstract
 */
-(void)abortTextInput;

/*!
 * @method tap:
 * @abstract
 * @param
 */
-(void)tap:(CGPoint)p;

/*!
 * @method pan:
 * @abstract
 * @param
 */
-(void)pan:(UIGestureRecognizer*)gr;

@end
