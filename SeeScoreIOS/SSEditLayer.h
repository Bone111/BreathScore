//
//  SSEditLayer.h
//  SeeScoreiOS Sample App
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SeeScoreLib/SeeScoreLib.h>
#import "SSScrollView.h"

@class SSViewInterface;
@class SSScore;

/*!
 * @interface SSEditLayer
 * @abstract
 */
@interface SSEditLayer : UIView <UITextFieldDelegate, SSEditLayerProtocol>

/*!
 * @method initWithFrame:interface:
 * @abstract
 * @param
 * @param
 * @param
 * @param
 * @return
 */
-(instancetype)initWithFrame:(CGRect)frame systemBottom:(float)systemBottom interface:(id<SSViewInterface>)ssViewInterf;

-(UIView*)view;

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
 * @method addOverlaidDirectionWordsTextFieldAt:
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
