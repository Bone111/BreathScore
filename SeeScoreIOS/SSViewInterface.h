//
//  SSViewInterface.h
//  SeeScoreiOS Sample App
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//

#import <Foundation/Foundation.h>

/*!
 * @struct SSSystemPoint
 * @abstract return value from systemAtYPos
 */
typedef struct SSSystemPoint
{
	// The index of this system
	int systemIndex;
	
	// the position in the coordinates of the system
	CGPoint posInSystem;
	
	// the 0-based part index
	int partIndex;
	
	// the 0-based bar index
	int barIndex;
	
	// the 0-based staff index (where there are 2 staves in a part)
	int staffIndex;
	
	// position relative to staff
	enum sscore_system_stafflocation_e staffLocation;
	
} SSSystemPoint;

@protocol SSViewInterface

/*!
 * @method score
 */
-(SSScore*)score;

/*!
 * @method systemAtPos
 * @abstract return the system index and location within it for a point in the SSScrollView
 * @discussion use systemAtIndex: to get the SSSystem from the systemIndex
 * @param p the point within the SSScrollView
 * @return the SystemPoint defining the system index, and part and bar indices at p
 */
-(SSSystemPoint)systemAtPos:(CGPoint)p;

/*!
 * @method systemAtIndex
 * @return the system at the given index (0-based, top to bottom)
 */
-(SSSystem*)systemAtIndex:(int)index;

/*!
 * @method systemContainingBarIndex
 * @return the system containing the given 0-based bar index
 */
-(SSSystem*)systemContainingBarIndex:(int)barIndex;

/*!
 * @method numSystems
 * @abstract return the number of systems currently displayed
 */
-(int)numSystems;

/*!
 * @method systemRect
 * @abstract the bounds of a given system
 * @return CGRect outline of system by index [0..numSystems-1]
 */
-(CGRect)systemRect:(int)systemIndex;

/*!
 * @method componentsAt
 * @abstract return the components at p, or near p in increasing distance order
 * @param p the point
 * @param maxDistance the maximum distance
 * @return the components
 */
-(NSArray<SSComponent*> *)componentsAt:(CGPoint)p maxDistance:(float)maxDistance;

/*!
 * @method warnShowingKeyboardRect
 * @abstract notification of keyboard appearing and covering the specified area of screen
 */
-(void)warnShowingKeyboardRect:(CGRect)kbRect;

/*!
 * @method warnHidingKeyboard
 * @abstract notification of keyboard disappearing
 */
-(void)warnHidingKeyboard;

/*!
 * @method ensureVisible
 * @abstract scroll to make the rect visible
 */
-(void)ensureVisible:(CGRect)rect;

/*!
 * @method deselectAll
 * @abstract deselect any selected item(s)
 */
-(void)deselectAll;

@end
