//
//  SSSystemView.m
//  SeeScore for iOS
//
// No warranty is made as to the suitability of this for any purpose
//
// This is used by SSScrollView and manages and draws a single system of music using the SeeScoreLib framework
//

//#define DrawOutline // define this to draw a blue outline around the SSSystemView for debug

#import "SSSystemView.h"
#import <QuartzCore/QuartzCore.h>
#include <dispatch/dispatch.h>
#include "sscore_key.h"
#include <assert.h>

static const float CursorLineWidth = 2;

@interface CursorLayer : CALayer
-(CursorLayer*)init;
-(void)show:(CGRect)frame;
-(void)hide;
@end

@implementation CursorLayer

-(CursorLayer*)init
{
	self = [super init];
	self.borderWidth = CursorLineWidth;
	self.borderColor = [UIColor orangeColor].CGColor;
	self.opacity = 0.0;
	return self;
}

-(void)show:(CGRect)r
{
	self.frame = r;
	self.opacity = 1.0F;
}

-(void)hide
{
	self.opacity = 0;
}
@end


@interface SSSystemView ()
{
	SSScore *score;
	SSSystem *system;
	float zoom; // normally 1 except while pinch-zooming
	bool isZooming;
	CursorLayer *cursorLayer;
	UIColor *bgColour;
}
@end
	
@implementation SSSystemView

- (id)initWithBackgroundColour:(UIColor*)bgcol
{
	assert(bgcol);
    self = [super init];
    if (self) {
		score = nil;
		system = nil;
		bgColour = bgcol;
		zoom = 1.0;
		isZooming = false;
		cursorLayer = [[CursorLayer alloc] init];
		[self.layer addSublayer:cursorLayer];
	}
    return self;
}

-(int)systemIndex
{
	assert(system != nil);
	return system.index;
}

-(float) drawScale
{
	return system.magnification;
}

-(int)partIndexForYPos:(float)ypos
{
	assert(system != nil);
	return [system partIndexForYPos:ypos];
}

-(int)barIndexForXPos:(float)xpos
{
	assert(system != nil);
	return [system barIndexForXPos:xpos];
}

-(void)setSystem:(SSSystem*)sys
		   score:(SSScore*)sc
{
	assert(sys && sc);
	score = sc;
	system = sys;
	self.backgroundColor = bgColour;
	_colourRender = nil;
	zoom = 1.0F;
	isZooming = false;
	CGSize sz = system.bounds;
	self.frame  = CGRectMake(0,0,sz.width,sz.height);
	[self hideCursor];
	[self setNeedsDisplay];
}

-(void)clear
{
	score = nil;
	system = nil;
	self.colourRender = nil;
}

// we centralise the system inside the view in y - so we see upper and lower margins in edit mode
-(float)upperMargin
{
	return (self.bounds.size.height - self.systemHeight) / 2;
}

-(float)systemHeight
{
	return system ? system.bounds.height : 0;
}

-(CGRect)boundsForItems:(SSColourRender*)render
{
	CGRect uRect = CGRectMake(0, 0, 0, 0);
	for (SSColouredItem *item in render.colouredItems)
	{
		CGRect r = [system boundsForItem:item.item_h];
		if (r.size.width > 0)
		{
			uRect = (uRect.size.width > 0) ? CGRectUnion(uRect, r) : r;
		}
	}
	return uRect;
}

-(void)setColourRender:(SSColourRender*)render
{
	assert(render.colouredItems.count < 1000);
	CGRect uRect = CGRectMake(0, 0, 0, 0);
	// add old items to bounds..
	if (_colourRender) // get rect bounds of changing items to optimise the update
	{
		uRect = [self boundsForItems:_colourRender];
	}
	_colourRender = render;
	if (render) // add new bounds
	{
		CGRect r = [self boundsForItems:render];
		if (r.size.width)
			uRect = (uRect.size.width > 0) ? CGRectUnion(uRect, r) : r;
	}
	if (uRect.size.width > 0)
	{
		[self setNeedsDisplayInRect:uRect];
	}
	else
	{
		[self setNeedsDisplay];
	}
}

-(void)clearColourRender
{
	CGRect uRect = CGRectMake(0, 0, 0, 0);
	// add old items to bounds..
	if (_colourRender) // get rect bounds of changing items to optimise the update
	{
		uRect = [self boundsForItems:_colourRender];
	}
	_colourRender = nil;
	if (uRect.size.width > 0)
	{
		[self setNeedsDisplayInRect:uRect];
	}
	else
	{
		[self setNeedsDisplay];
	}
}

-(bool)bar:(int)barIndex inRange:(const sscore_barrange*)barrange
{
	return barIndex >= barrange->startbarindex && barIndex < barrange->startbarindex + barrange->numbars;
}

-(void)clearColourRenderForBarRange:(const sscore_barrange*)barrange
{
	if (self.colourRender != nil)
	{
		NSMutableArray *newItems = NSMutableArray.array;
		for (SSColouredItem *item in self.colourRender.colouredItems)
		{
			NSArray *comps = [system componentsForItem:item.item_h];
			for (SSComponent *comp in comps)
			{
				if (![self bar:comp.barIndex inRange:barrange])
				{
					[newItems addObject:item]; // add items which arent in specified barrange
				}
				// only look at the first component
				break;
			}
		}
		if (newItems.count > 0)
		{
			SSColourRender *newRender = [[SSColourRender alloc] initWithItems:newItems];
			[self setColourRender:newRender];
		}
		else
			[self setColourRender:nil];
	}
}

-(SSSystem*)system
{
	return system;
}

-(SSCursorRect)cursorRectForBar:(int)barIndex
{
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(10,10), YES/*opaque*/, 0.0/* scale*/);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	SSCursorRect cursorRect = [system cursorRectForBar:barIndex context:ctx];
	UIGraphicsEndImageContext();
	return cursorRect;
}

-(void)showCursorAtBar:(int)barIndex pre:(BOOL)pre
{
	if (score && system) // it may have been recycled on another thread (shouldn't happen?)
	{
		SSCursorRect cursorRect = [self cursorRectForBar:barIndex];
		if (cursorRect.bar_in_system)
		{
			[cursorLayer show:CGRectMake(cursorRect.rect.origin.x,
										 cursorRect.rect.origin.y,
										 pre ? cursorLayer.borderWidth : cursorRect.rect.size.width,
										 cursorRect.rect.size.height)];
		}
		else
			[cursorLayer hide];
	}
}

-(void)showCursorAtXpos:(float)xpos barIndex:(int)barIndex
{
	if (score && system) // it may have been recycled on another thread (shouldn't happen?)
	{
		SSCursorRect cursorRect = [self cursorRectForBar:barIndex];
		if (cursorRect.bar_in_system)
		{
			[cursorLayer show:CGRectMake(xpos  - cursorLayer.borderWidth/2,
										 cursorRect.rect.origin.y,
										 cursorLayer.borderWidth,
										 cursorRect.rect.size.height)];
		}
		else
			[cursorLayer hide];
	}
}

-(void)hideCursor
{
	[cursorLayer hide];
}

-(void)zoomUpdate:(float)z
{
	zoom = z;
	isZooming = true;
	self.colourRender = nil; // clear colouring on zoom
	[self setNeedsDisplay];
}

-(void)zoomComplete
{
	zoom = 1.0;
	isZooming = false;
	self.colourRender = nil; // clear colouring on zoom
	[self setNeedsDisplay];
}

-(void)drawInContext:(CGContextRef)ctx
{
	assert(ctx && system);
	CGPoint tl = CGPointMake(0, self.upperMargin);
	// draw system
	if (_colourRender)
		[system drawWithContext:ctx at:tl magnification:zoom colourRender:_colourRender];
	else
		[system drawWithContext:ctx at:tl magnification:zoom];
}

- (void)drawRect:(CGRect)rect
{
	//[super drawRect:rect];
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	// we need to clear the background even when we draw the background image which should fill the frame
	// otherwise we get an intermittent faint horizontal line artifact between systems esp with retina display
	assert(bgColour);
	CGContextSetFillColorWithColor (ctx, bgColour.CGColor);
	CGContextFillRect (ctx, rect);
	if (system)
	{
		[self drawInContext:ctx];
	}
#ifdef DrawOutline
	CGContextSetStrokeColorWithColor (ctx, UIColor.blueColor.CGColor);
	CGContextStrokeRect(ctx, rect);
#endif
}

-(void)selectItem:(sscore_item_handle)item_h part:(int)partIndex bar:(int)barIndex
	   foreground:(CGColorRef)fg background:(CGColorRef)bg
{
	[system selectItem:item_h part:partIndex bar:barIndex foreground:fg background:bg];
	[self setNeedsDisplay];
}

-(void)deselectItem:(sscore_item_handle)item_h
{
	[system deselectItem:item_h];
	[self setNeedsDisplay];
}

-(void)deselectAll
{
	[system deselectAll];
	[self setNeedsDisplay];
}

-(void)updateLayout:(CGContextRef)ctx newState:(const sscore_state_container *)newstate
{
	[system updateLayout:ctx newState:newstate];
	CGRect frame = self.frame;
	frame.size = system.bounds;							// update system height
	[self setNeedsDisplay];
}

@end
