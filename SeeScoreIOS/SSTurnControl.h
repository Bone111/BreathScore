//
//  SSTurnControl.h
//  SeeScoreiOS Sample App
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SSDragItem;

@interface SSTurnControl : UIView

enum TCKnurlPos { knurl_none,knurl_above,knurl_below};

@property (nonatomic,readonly) float turnAngle;
@property (nonatomic) float magnification;

-(void)setItems:(NSArray<SSDragItem*>*)items
  central_index:(int)cidx
  magnification:(float)mag
		  knurl:(enum TCKnurlPos)knurlPos;

-(void)clear;

-(int)numItems;

-(bool)turn:(float)dist current_angle:(float)current_angle;

-(bool)pointInKnurl:(CGPoint)pt;

-(bool)pointInItems:(CGPoint)pt;

-(SSDragItem*)nearestItem:(CGPoint)pt;

// return true if pan start in control
-(bool)hit:(UIGestureRecognizer *)panReco;

-(SSDragItem*)pan:(UIGestureRecognizer*)gr;

@end
