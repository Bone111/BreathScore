//
//  SSPlayLoopGraphics.h
//  SeeScoreiOS Sample App
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//

#ifndef SSPlayLoopGraphics_h
#define SSPlayLoopGraphics_h

#import <UIKit/UIKit.h>
#import <SeeScoreLib/SeeScoreLib.h>

/*!
 @interface SSPlayLoopGraphics
 @abstract use 2 CALayers (fore and background) to display pseudo repeat dotted double bars in chosen colour to indicate start and end of repeat loop
 @discussion We draw a standard repeat barline (thick, thin barlines with 2 dots) in each staff in blue over the score aligned with the barline.
 Also draw a translucent rectangular margin background to each barline to prevent the black score obscuring the blue.
 The CALayers should be added to the SSScrollView when required
 */
@interface SSPlayLoopGraphics : NSObject

/*!
 @property background
 @abstract translucent background to each double-bar
 @discussion the caller should use addSublayer to display this
 */
@property (readonly) CALayer *background;

/*!
 @property foreground
 @abstract coloured double-bars on each part at the given barline
 @discussion the caller should use addSublayer to display this
 */
@property (readonly) CALayer *foreground;

/*!
 @method initWithNumParts:leftSystem:leftSystemTopLeft:leftBarIndex:rightSystem:rightSystemTopLeft:rightBarIndex:colour:
 @abstract setup foreground and background CALayer properties to be displayed as an overlay over SSScrollView
 */
-(instancetype)initWithNumParts:(int)numParts
					 leftSystem:(SSSystem*)leftSystem leftSystemTopLeft:(CGPoint)leftSystemTopLeft leftBarIndex:(int)leftBarIndex
					rightSystem:(SSSystem*)rightSystem rightSystemTopLeft:(CGPoint)rightSystemTopLeft rightBarIndex:(int)rightBarIndex
						 colour:(UIColor*)colour;


@end

#endif /* PlayLoopGraphics_h */
