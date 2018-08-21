//
//  SSDragItem.m
//  SeeScoreiOS Sample App
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//

#import <Foundation/Foundation.h>
#import "SSDragItem.h"

@interface SSDragItem ()
{
	sscore_symbol symbol; // store the symbol as lookup is non-trivial
}
@end

@implementation SSDragItem

-(instancetype)initWithType:(sscore_edit_type)type scale:(float)scale
{
	if (self = [super init])
	{
		_itemType = type;
		_scale = scale;
		symbol = sscore_edit_symbolfor(&_itemType);
	}
	return self;
}

-(CGRect)bounds:(CGContextRef)ctx
{
	sscore_graphics *graphics = sscore_graphics_create(ctx);
	sscore_symbol sym = sscore_edit_symbolfor(&_itemType);
	sscore_rect bb = sscore_sym_bb(graphics, sym);
	sscore_graphics_dispose(graphics);
	return CGRectMake(bb.xorigin, bb.yorigin, bb.width, bb.height);
}

-(void)draw:(CGContextRef)ctx pos:(CGPoint)pos colour:(UIColor*)colour
{
	sscore_point p = {pos.x, pos.y};
	const CGFloat *comp = CGColorGetComponents(colour.CGColor);
	int numcomps = (int)CGColorGetNumberOfComponents(colour.CGColor);
	sscore_colour_alpha rgba;
	rgba.r = comp[0];
	rgba.g = (numcomps > 2) ? comp[1] : comp[0];
	rgba.b = (numcomps > 2) ? comp[2] : comp[0];
	rgba.a = (numcomps > 3) ? comp[3] : (numcomps == 2) ? comp[1] : 1;
	//sscore_symbol sym = sscore_edit_symbolfor(&_itemType); // don't call this too often as it is rather expensive (allocation of ItemType)
	sscore_graphics *graphics = sscore_graphics_create(ctx);
	sscore_rect bb = sscore_sym_bb(graphics, symbol);
	sscore_sym_draw(graphics, symbol, &p, 0, bb.height*_scale, &rgba);
	sscore_graphics_dispose(graphics);
}

@end
