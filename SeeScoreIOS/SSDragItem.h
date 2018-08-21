//
//  SSDragItem.h
//  SeeScoreiOS Sample App
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//

#ifndef SSDragItem_h
#define SSDragItem_h

#import <SeeScoreLib/SeeScoreLib.h>
#import <UIKit/UIKit.h>

@interface SSDragItem : NSObject

@property sscore_edit_type itemType;
@property float scale;

-(instancetype)initWithType:(sscore_edit_type)type scale:(float)scale;

-(CGRect)bounds:(CGContextRef)ctx;

-(void)draw:(CGContextRef)ctx  pos:(CGPoint)pos colour:(UIColor*)colour;

@end

#endif /* SSDragItem_h */
