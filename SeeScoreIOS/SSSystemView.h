//
//  SSSystemView.h
//  SeeScore for iOS
//
// No warranty is made as to the suitability of this for any purpose
//
// This is used by SSScrollView and manages and draws a single system of music using the SeeScoreLib framework
//

#import <UIKit/UIKit.h>
#include <SeeScoreLib/SeeScoreLib.h>

@class SSScore;
@class SSSystem;
@class SSColourRender;

/*!
 * @interface SSSystemView
 * @abstract used by SSScrollView, manages and draws a single system of music using the SeeScoreLib framework
 */
@interface SSSystemView : UIView

/*!
 * @property height
 * @abstract the height of the system within the UIView in CGContext units
 */
@property (nonatomic,readonly) float systemHeight;

/*!
 * @property upperMargin
 * @abstract the empty margin above the system to the top of the UIView in CGContext units
 */
@property (nonatomic,readonly) float upperMargin;

/*!
 * @property colourRender
 * @abstract any current colour rendering (used to define coloured items in the score)
 */
@property (nonatomic) SSColourRender *colourRender;

/*!
 * @property system
 * @abstract the SSSystem which this is displaying
 */
@property (nonatomic,readonly) SSSystem *system;

/*!
 * @property systemIndex
 * @abstract the index of the system that this is displaying - 0 is the top system
 */
@property (nonatomic, readonly) int systemIndex;

/*!
 @property drawScale
 @abstract the scale at which this system was drawn (1.0 approximates to a standard printed score with 6mm staff height)
 */
@property (nonatomic, readonly) float drawScale;

/*!
 * @method initWithBackgroundColour
 * @abstract initialise defining a background colour
 * @param bgcol the background colour
 * @return the SSSystemView
 */
- (instancetype)initWithBackgroundColour:(UIColor*)bgcol;

/*!
 * @method setSystem
 * @abstract setup with the system
 * @param system the system
 * @param score the score
 */
-(void)setSystem:(SSSystem*)system
		   score:(SSScore*)score;

/*!
 * @method clear
 * @abstract clear any owned pointers so the view can be recycled
 */
-(void)clear;

/*!
 * @method clearColourRender
 * @abstract clear all coloured rendering
 */
-(void)clearColourRender;

/*!
 * @method clearColourRenderForBarRange:
 * @abstract clear any coloured rendering in the bar range
 * @param barrange the range of bars defined by a start index and number of bars
 */
-(void)clearColourRenderForBarRange:(const sscore_barrange*)barrange;

/*!
 * @method showCursorAtBar
 * @abstract show the bar cursor at the given bar
 * @param barIndex the index of the bar
 * @param pre if true show a single vertical line cursor at the start of the bar, else a rectangle around the bar
 */
-(void)showCursorAtBar:(int)barIndex pre:(BOOL)pre;

/*!
 * @method showCursorAtXpos
 * @abstract show the vertical line cursor at the given xpos in the system
 * @param xpos the x position of the cursor within the system
 * @param barIndex the index of the bar which the cursor is to be displayed within
 */
-(void)showCursorAtXpos:(float)xpos barIndex:(int)barIndex;

/*!
 * @method hideCursor
 * @abstract hide the cursor
 */
-(void)hideCursor;

/*!
 * @method zoomUpdate
 * @abstract call for interactive zooming (magnifies backImage)
 * @param z the zoom magnification
 */
-(void)zoomUpdate:(float)z;

/*!
 * @method zoomComplete
 * @abstract finish interactive zooming - system is redrawn at new magnification
 */
-(void)zoomComplete;

/*!
 * @method selectItem
 * @abstract show an item as selected in the layout by colouring
 */
-(void)selectItem:(sscore_item_handle)item_h part:(int)partIndex bar:(int)barIndex
	   foreground:(CGColorRef)fg background:(CGColorRef)bg;

/*!
 * @method deselectItem
 * @abstract deselect a selected item
 */
-(void)deselectItem:(sscore_item_handle)item_h;

/*!
 * @method deselectAll
 * @abstract deselect all selected items
 */
-(void)deselectAll;

/*!
 * @method updateLayout:newState
 * @abstract update the layout after edit
 */
-(void)updateLayout:(CGContextRef)ctx newState:(const sscore_state_container *)newstate;

@end
