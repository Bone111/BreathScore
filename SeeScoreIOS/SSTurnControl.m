//
//  SSTurnControl.m
//  SeeScoreiOS Sample App
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//
// Wheel Angle is the angle around the wheel - 0 at the default centre item increases to right
// Turn Angle is the angle the wheel is turned from the default position increases to right
// Front Angle is the angle of drawn elements in the viewed front part of the wheel [-PI/2..+PI/2] increases to right

#import "SSTurnControl.h"
#import "SSDragItem.h"

#import <SeeScoreLib/SeeScoreLib.h>

static const float pi = 3.14159;
static const float kMargin = 20;
static const float kKnurlHeight_cg = 50;
static const float kKnurlWidth_cg = 1;
static const float kKnurlPitch_cg = 2;
static const float kTopCurveHeight = 3;
static const float kLeftXCurveFrac = 1./8.;
static const float kRightXCurveFrac = 7./8.;
static const float kOuterCornerCurveParam = 20;
static const float kInnerCornerCurveParam = 15;
static const float kItemsFromKnurlYSpacing = 10;
static const float kItemSpacing = 18;
static const float kHalfItemSpacing = kItemSpacing/2;

@interface SSTurnControl ()
{
	NSArray<SSDragItem*> *items; // of SSDragItem*
	int central_index;
	float turn_angle;
	bool isDragging;
	enum TCKnurlPos knurlPos;

	// panning
	bool isRotating;
	float startTCAngle;
}
@end

@implementation SSTurnControl

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		_magnification = 1.0;
		central_index = 0;
	}
	return self;
}

-(instancetype)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		_magnification = 1.0;
		central_index = 0;
	}
	return self;
}

-(void)setItems:(NSArray<SSDragItem*>*)items_array
  central_index:(int)cidx
  magnification:(float)mag
		  knurl:(enum TCKnurlPos)pos;
{
	assert(mag > 0);
	_magnification = mag;
	items = items_array;
	central_index = cidx;
	knurlPos = pos;
	[self invalidateIntrinsicContentSize];
	self.opaque = false;
	[self setNeedsDisplay];
}

-(float)turnAngle
{
	return turn_angle;
}

-(void)clear
{
	items = nil;
	central_index = 0;
	[self invalidateIntrinsicContentSize];
	[self setNeedsDisplay];
}

-(float)maxItemDrop:(sscore_graphics*)graphics
{
	float max = 0;
	for (int i = 0; i < self.numItems; ++i)
	{
		sscore_symbol sym = [self symbolForIndex:i];
		sscore_rect bb = sscore_sym_bb(graphics, sym);
		float drop = (bb.height - bb.yorigin) * _magnification;
		if (drop > max)
			max = drop;
	}
	return max * _magnification;
}

-(float)maxItemRise:(sscore_graphics*)graphics
{
	float max = 0;
	for (int i = 0; i < self.numItems; ++i)
	{
		sscore_symbol sym = [self symbolForIndex:i];
		sscore_rect bb = sscore_sym_bb(graphics, sym);
		float rise = bb.yorigin * _magnification;
		if (rise > max)
			max = rise;
	}
	return max * _magnification;
}

-(float)itemWidth:(sscore_graphics*)graphics index:(int)itemIndex
{
	sscore_symbol sym = [self symbolForIndex:itemIndex];
	sscore_rect bb = sscore_sym_bb(graphics, sym);
	return bb.width * _magnification;
}

-(int)numItems
{
	return items ? (int)items.count : 0;
}

-(float)wheelRadius
{
	return self.bounds.size.width/2;
}

-(float)wheelAngle:(sscore_graphics*)graphics forItemIndex:(int)itemIndex
{
	float angle = 0;
	if (itemIndex == central_index)
	{
		return angle;
	}
	else
	{
		const float wheelRadius = self.wheelRadius;
		float halfItemWidth = [self itemWidth:graphics index:central_index]/2;
		float halfItemPitch = halfItemWidth + kHalfItemSpacing;
		int itemCentreOffset = itemIndex - central_index;
		int index = itemCentreOffset < 0 ? -1 : +1; // -1 => itemIndex is left of centre; +1 => itemIndex is right of centre
		int endIndex = itemCentreOffset < 0 ? -1 : self.numItems; // 1 past last item
		angle += halfItemPitch/wheelRadius * index;
		for (int i = central_index + index; i != endIndex; i += index)
		{
			halfItemWidth = [self itemWidth:graphics index:i]/2;
			halfItemPitch = halfItemWidth + kHalfItemSpacing;
			angle += halfItemPitch/wheelRadius * index;
			if ( i == itemIndex)
				return angle;
			angle += halfItemPitch/wheelRadius * index;
		}
		assert(false);
	}
	return 0;
}

-(int)itemIndexForWheelAngle:(float)angle graphics:(sscore_graphics*)graphics
{
	for (int itemIndex = 0; itemIndex < self.numItems; ++itemIndex)
	{
		float itemAngle = [self wheelAngle:graphics forItemIndex:itemIndex]; // not the most efficient algorithm but the code is simple and reliable!
		float halfItemWidth = [self itemWidth:graphics index:itemIndex]/2;
		float maxItemAngle = itemAngle + (halfItemWidth + kHalfItemSpacing) / self.wheelRadius;
		if (angle < maxItemAngle)
			return itemIndex;
	}
	assert(false);
	return 0;
}

-( sscore_symbol)symbolForIndex:(int)index
{
	if (index >= 0 && index < items.count)
	{
		SSDragItem *ditem = (SSDragItem*)[items objectAtIndex:index];
		sscore_edit_type itemType = ditem.itemType;
		return sscore_edit_symbolfor(&itemType);
	}
	else
		return sscore_sym_invalid;
}

-(float)clampAngle:(float)angle min:(float)min max:(float)max
{
	if (angle < min)
		return min;
	else if (angle > max)
		return max;
	else
		return angle;
}

-(float)maxItemWidth:(sscore_graphics*)graphics
{
	float maxWidth = 0;
	for (int i = 0; i < [self numItems]; ++i)
	{
		sscore_symbol sym = [self symbolForIndex:i];
		sscore_rect bb = sscore_sym_bb(graphics, sym);
		maxWidth = fmax(maxWidth, bb.width*_magnification);
	}
	return maxWidth * _magnification;
}

-(float)maxHeightForItems:(sscore_graphics*)graphics
{
	float maxRise = [self maxItemRise:graphics];
	float maxDrop = [self maxItemDrop:graphics];
	return maxRise + maxDrop;
}

-(float)minScaleAngle:(sscore_graphics*)graphics
{
	return [self wheelAngle:graphics forItemIndex:0];
}

-(float)maxScaleAngle:(sscore_graphics*)graphics
{
	return [self wheelAngle:graphics forItemIndex:self.numItems-1];
}

-(float)minTurnAngle:(sscore_graphics*)graphics
{
	float rval = [self wheelAngle:graphics forItemIndex:self.numItems-1];
	return -rval;
}

-(float)maxTurnAngle:(sscore_graphics*)graphics
{
	float rval = [self wheelAngle:graphics forItemIndex:0];
	return -rval;
}

-(float)frontAngleForWheelAngle:(float)wangle
{
	float fangle = wangle + self.turnAngle;
	return fangle;
}

-(float)wheelAngleForFrontAngle:(float)fangle
{
	float wangle = fangle - self.turnAngle;
	return wangle;
}

-(float)centre_x
{
	CGRect frame = self.frame;
	return frame.size.width/2;
}

-(float)frontAngleForXPos:(float)xpos
{
	return asin((xpos - [self centre_x]) / self.wheelRadius);
}

-(float)displacementForFrontAngle:(float)angle
{
	return self.wheelRadius * sin(angle);
}

-(float)scaleForFrontAngle:(float) angle
{
	return 1;//kCentreZDistance + kRadius * cos(angle);
}

-(float)xposForFrontAngle:(float)angle  ctx:(CGContextRef)ctx
{
	return [self centre_x] + [self displacementForFrontAngle:angle];
}

-(float)xscaleForFrontAngle:(float)angle
{
	return cos(angle);
}

static void hGradientPaintRect(CGContextRef ctx, CGRect rect, float startx, float endx, float ypos, UIColor *bgCol)
{
	CGContextSaveGState(ctx);
	CGContextClipToRect (ctx, CGRectMake(0,0,rect.size.width,rect.size.height));
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	static const int kNumColours = 10;
	CGFloat *colourBuf = (CGFloat*)malloc(kNumColours * 4 * sizeof(CGFloat)); //rgba
	for (int i = 0; i < kNumColours; ++i)
	{
		CGFloat red, green, blue, alpha;
		[bgCol getRed:&red green:&green blue:&blue alpha:&alpha];
		float var = (float)i / (kNumColours-1);
		float grad = 1-cos(var * pi/2);
		colourBuf[4*i] = red;
		colourBuf[4*i+1] = green;
		colourBuf[4*i+2] = blue;
		colourBuf[4*i+3] = grad;
	}
	CGGradientRef gradient = CGGradientCreateWithColorComponents(rgb, colourBuf, NULL, kNumColours);
	CGColorSpaceRelease(rgb);
	CGGradientDrawingOptions options = 0;
	//options |= kCGGradientDrawsBeforeStartLocation;
	//options |= kCGGradientDrawsAfterEndLocation;
	CGContextDrawLinearGradient(ctx, gradient,CGPointMake(startx, ypos), CGPointMake(endx, ypos), options);
	CGGradientRelease(gradient);
	free(colourBuf);
	CGContextRestoreGState(ctx);
}

-(void)drawGradients:(CGContextRef)ctx
{
	CGRect frame = self.frame;
	float width = frame.size.width;
	float left_x = 0;
	float centre_x = width/2;
	float right_x = width;
	hGradientPaintRect(ctx, frame, centre_x, left_x, 0, UIColor.grayColor);
	hGradientPaintRect(ctx, frame, centre_x, right_x, 0, UIColor.grayColor);
}

-(float)knurlTop
{
	return (knurlPos == knurl_above) ? 0 : (knurlPos == knurl_below) ? self.frame.size.height - kKnurlHeight_cg : 0;
}

-(float)knurlBottom
{
	return (knurlPos == knurl_above) ? kKnurlHeight_cg : (knurlPos == knurl_below) ? self.frame.size.height : 0;
}

-(float)itemsTop
{
	return (knurlPos == knurl_above) ? self.knurlBottom : kMargin;
}

-(float)itemsBottom
{
	return (knurlPos == knurl_below) ? self.knurlTop : self.frame.size.height - kMargin;
}


-(void)drawKnurl:(CGContextRef)ctx
{
	if (knurlPos != knurl_none)
	{
		sscore_graphics *graphics = sscore_graphics_create(ctx);
		const float knurl_angle = kKnurlPitch_cg / self.wheelRadius;
		const float start_angle = [self minScaleAngle:graphics] - pi/2;
		const float end_angle = [self maxScaleAngle:graphics] + pi/2;
		bool dark = true;
		for (float angle = start_angle; angle < end_angle; angle += knurl_angle)
		{
			float front_angle = [self frontAngleForWheelAngle:angle];
			if (front_angle > -pi/2 && front_angle < pi/2) // ..but only draw the ones at the front
			{
				float disp = [self displacementForFrontAngle:front_angle];
				float scale = [self scaleForFrontAngle:front_angle];
				CGRect r2 = {[self centre_x]+disp, self.knurlTop, kKnurlWidth_cg*scale, self.knurlBottom };
				CGContextSetFillColorWithColor(ctx, dark ? UIColor.darkGrayColor.CGColor : UIColor.lightGrayColor.CGColor);
				CGContextFillRect(ctx, r2);
			}
			dark = !dark;
		}
		sscore_graphics_dispose(graphics);
	}
}

-(CGPathRef) getFrameClipPath:(CGRect)frame
						width:(float)width
				  innerCorner:(float)innerCorner
				  outerCorner:(float)outerCorner
				  curveBottom:(bool)curveBottom
						  ctx:(CGContextRef)ctx
{
	const float l = frame.origin.x;
	const float r = frame.origin.x + frame.size.width;
	const float t = frame.origin.y;
	const float b = frame.origin.y + frame.size.height;
	const float h = frame.size.height;
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathMoveToPoint(path, nil, l,	t + h/2);
	CGPathAddLineToPoint(path, nil, l,	t + outerCorner);
	CGPathAddCurveToPoint(path, nil, l,	t, l, t, l + outerCorner, t);
	
	CGPathAddLineToPoint(path, nil, r - outerCorner, t);
	CGPathAddCurveToPoint(path, nil, r,	t,
				  r,	t,
				  r,	t + outerCorner);
	
	CGPathAddLineToPoint(path, nil, r,	b - outerCorner);
	CGPathAddCurveToPoint(path, nil, r,	b,
				  r,	b,
				  r - outerCorner, b);
	
	CGPathAddLineToPoint(path, nil, l + outerCorner, b);
	CGPathAddCurveToPoint(path, nil, l,	b,
				  l,	b,
				  l,	b - outerCorner);
	
	CGPathAddLineToPoint(path, nil, l,	t + h/2);// coincident with starting point
	CGPathAddLineToPoint(path, nil, l + width, t + h/2);

	CGPathAddLineToPoint(path, nil, l + width, b - width - innerCorner);
	CGPathAddCurveToPoint(path, nil, l + width, b - width,
				  l + width, b - width,
				  l + width + innerCorner, b - width);

	if (curveBottom)
		CGPathAddCurveToPoint(path, nil, l + kLeftXCurveFrac*frame.size.width, b - width + kTopCurveHeight,
				  l + kRightXCurveFrac*frame.size.width, b - width + kTopCurveHeight,
				  r - width - innerCorner, b - width);
	else
		CGPathAddLineToPoint(path, nil, r - width - innerCorner, b - width);
	CGPathAddCurveToPoint(path, nil, r - width, b - width,
				  r - width, b - width,
				  r - width, b - width - innerCorner);
	
	CGPathAddLineToPoint(path, nil, r - width, t + width + innerCorner);
	CGPathAddCurveToPoint(path, nil, r - width, t + width,
				  r - width, t + width,
				  r - width - innerCorner, t + width);
	
	CGPathAddLineToPoint(path, nil, l + width + innerCorner, t + width);
	CGPathAddCurveToPoint(path, nil, l + width, t + width,
				  l + width, t + width,
				  l + width, t + width + innerCorner);

	CGPathAddLineToPoint(path, nil, l + width, t + h/2);
	CGPathAddLineToPoint(path, nil, l, t + h/2);
	
	CGPathCloseSubpath(path);
	return path;
}

-(void)drawFrameGradient:(CGContextRef)ctx
				   frame:(CGRect)frame
				   width:(float)width
			 innerCorner:(float)innerCorner
			 outerCorner:(float)outerCorner
				  colour:(UIColor*)colour
			 curveBottom:(BOOL)curveBottom
{
	CGContextSaveGState(ctx);
	CGPathRef clipPath = [self getFrameClipPath:frame width:width innerCorner:innerCorner outerCorner:outerCorner curveBottom:curveBottom ctx:ctx];
	CGContextAddPath(ctx, clipPath);
	CGContextClip(ctx);
	CGPathRelease(clipPath);
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	static const int kNumColours = 2;
	CGFloat *colourBuf = (CGFloat*)malloc(kNumColours * 4 * sizeof(CGFloat)); //rgba
	CGFloat red, green, blue, alpha;
	[colour getRed:&red green:&green blue:&blue alpha:&alpha];
	for (int i = 0; i < kNumColours; ++i)
	{
		colourBuf[4*i] = red;
		colourBuf[4*i+1] = green;
		colourBuf[4*i+2] = blue;
		colourBuf[4*i+3] = 1;
		red = green = blue = 0;
	}
	CGGradientRef gradient = CGGradientCreateWithColorComponents(rgb, colourBuf, NULL, kNumColours);
	CGColorSpaceRelease(rgb);
	CGGradientDrawingOptions options = 0;
	//options |= kCGGradientDrawsBeforeStartLocation;
	//options |= kCGGradientDrawsAfterEndLocation;
	// vertical colour gradient
	CGContextDrawLinearGradient(ctx, gradient, CGPointMake(frame.origin.x + frame.size.width/2, frame.origin.y), CGPointMake(frame.origin.x + frame.size.width/2, frame.origin.y + frame.size.height), options);
	CGGradientRelease(gradient);
	free(colourBuf);

	CGContextRestoreGState(ctx);
}

-(void)drawFrame:(CGContextRef)ctx frame:(CGRect)frame
{
	[self drawFrameGradient:ctx frame:inset(frame, 1.5) width:3 innerCorner:kOuterCornerCurveParam outerCorner:kOuterCornerCurveParam colour:UIColor.grayColor curveBottom:NO];
	[self drawFrameGradient:ctx frame:inset(frame, 4) width:4 innerCorner:kInnerCornerCurveParam outerCorner:kOuterCornerCurveParam-2 colour:UIColor.lightGrayColor curveBottom:NO];
}

-(float)symbolYPos:(sscore_graphics *)graphics
{
	float maxDrop = [self maxItemDrop:graphics];
	return (knurlPos == knurl_below) ? self.knurlTop - kItemsFromKnurlYSpacing - maxDrop : self.frame.size.height - kMargin - maxDrop;
}

-(void)drawItems:(CGContextRef) ctx
{
	assert(_magnification > 0);
	sscore_graphics *graphics = sscore_graphics_create(ctx);
	float ypos = [self symbolYPos:graphics];
	CGContextSetFillColorWithColor(ctx, UIColor.blackColor.CGColor);
	for (int i = 0; i < self.numItems; ++i)
	{
		float wheel_angle = [self wheelAngle:graphics forItemIndex:i];
		float front_angle = [self frontAngleForWheelAngle:wheel_angle];
		if (front_angle > -pi/2 && front_angle < pi/2) // only draw the ones at the front
		{
			float scale = [self scaleForFrontAngle:front_angle];
			if (scale > 0)
			{
				CGPoint p = {[self xposForFrontAngle:front_angle ctx:ctx], ypos};
				sscore_symbol sym = [self symbolForIndex:i];
				sscore_rect bb = sscore_sym_bb(graphics, sym);
				float xscale = [self xscaleForFrontAngle:front_angle]; // extra scaling in x to 'turn' the symbol around vert axis to narrow at edge
				sscore_point sp = {p.x+(bb.xorigin-bb.width/2)*_magnification, p.y};
				sscore_colour_alpha col = {0,0,0,1};
				sscore_sym_draw(graphics, sym, &sp, bb.width*xscale*scale*_magnification, bb.height*scale*_magnification, &col);
			}
		}
	}
	sscore_graphics_dispose(graphics);
}

// get path with dip at top
-(CGPathRef) getClipPath:(CGRect)frame ctx:(CGContextRef) ctx
{
	float x0 = frame.origin.x;
	float x1 = frame.origin.x+kLeftXCurveFrac*frame.size.width;
	float x2 = frame.origin.x+kRightXCurveFrac*frame.size.width;
	float x3 = frame.origin.x+frame.size.width;
	float y0 = frame.origin.y;
	float y1 = frame.origin.y+kTopCurveHeight;
	float y2 = frame.origin.y+frame.size.height;
	float y3 = frame.origin.y+frame.size.height+kTopCurveHeight;
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathMoveToPoint(path, nil, x0, y0);
	CGPathAddCurveToPoint(path, nil, x1, y1,
				  x2, y1,
				  x3, y0);
	CGPathAddLineToPoint(path, nil, x3, y2);
	CGPathAddCurveToPoint(path, nil, x2, y3,
				  x1, y3,
				  x0, y2);
	CGPathCloseSubpath(path);
	return path;
}

-(void)setClip:(CGContextRef) ctx frame:(CGRect)frame
{
	CGPathRef path = [self getClipPath:frame ctx:ctx];
	CGContextAddPath(ctx, path);
	CGContextClip(ctx);
	CGPathRelease(path);
}

-(CGPathRef) getFramePath:(CGRect)frame corner:(float)corner ctx:(CGContextRef) ctx
{
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathMoveToPoint(path, nil, frame.origin.x, frame.origin.y + frame.size.height/2);
	CGPathAddLineToPoint(path, nil, frame.origin.x, frame.origin.y + corner);
	CGPathAddCurveToPoint(path, nil, frame.origin.x, frame.origin.y,
				  frame.origin.x, frame.origin.y,
				  frame.origin.x + corner, frame.origin.y);
	CGPathAddLineToPoint(path, nil, frame.origin.x + frame.size.width - corner, frame.origin.y);
	CGPathAddCurveToPoint(path, nil, frame.origin.x + frame.size.width, frame.origin.y,
				  frame.origin.x + frame.size.width, frame.origin.y,
				  frame.origin.x + frame.size.width, frame.origin.y + corner);
	CGPathAddLineToPoint(path, nil, frame.origin.x + frame.size.width, frame.origin.y + frame.size.height - corner);
	CGPathAddCurveToPoint(path, nil, frame.origin.x + frame.size.width, frame.origin.y + frame.size.height,
				  frame.origin.x + frame.size.width, frame.origin.y + frame.size.height,
				  frame.origin.x + frame.size.width - corner, frame.origin.y + frame.size.height + kTopCurveHeight);
	CGPathAddLineToPoint(path, nil, frame.origin.x + corner, frame.origin.y + frame.size.height + kTopCurveHeight);
	/*path->curveTo(geom::Pos(frame.origin.x+kRightXCurveFrac*frame.size.width, frame.origin.y + frame.size.height + kTopCurveHeight),
	 geom::Pos(frame.origin.x+kLeftXCurveFrac*frame.size.width, frame.origin.y + frame.size.height + kTopCurveHeight),
	 geom::Pos(frame.origin.x + corner, frame.origin.y + frame.size.height));*/
	CGPathAddCurveToPoint(path, nil, frame.origin.x, frame.origin.y + frame.size.height + kTopCurveHeight,
				  frame.origin.x, frame.origin.y + frame.size.height + kTopCurveHeight,
				  frame.origin.x, frame.origin.y + frame.size.height + kTopCurveHeight - corner);
	CGPathCloseSubpath(path);
	return path;
}

-(void)clipToFrame:(CGContextRef)ctx frame:(CGRect)frame
{
	CGPathRef path = [self getFramePath:frame corner:kInnerCornerCurveParam ctx:ctx];
	CGContextAddPath(ctx, path);
	CGContextClip(ctx);
	CGPathRelease(path);
}

static CGRect inset(CGRect r, float margin)
{
	return CGRectInset(r, margin, margin);
}

- (CGSize)intrinsicContentSize
{
	if (self.hidden || items == nil || items.count == 0)
		return CGSizeMake(self.frame.size.width, 0);
	else
	{
		UIGraphicsBeginImageContextWithOptions(CGSizeMake(10,10), YES/*opaque*/, 0.0/* scale*/);
		CGContextRef ctx = UIGraphicsGetCurrentContext();
		sscore_graphics *graphics = sscore_graphics_create(ctx);
		float heightForSymbols = [self maxHeightForItems:graphics];
		sscore_graphics_dispose(graphics);
		UIGraphicsEndImageContext();
		return CGSizeMake(self.frame.size.width, 2*kMargin + kKnurlHeight_cg + heightForSymbols);
	}
}

- (void)drawRect:(CGRect)rect
{
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect frame = self.frame;
	CGRect outerBox = {0,0,frame.size.width,frame.size.height};
	CGRect innerBox1 = inset(outerBox, 4);
	CGRect innerBox2 = inset(outerBox, 8);
	CGContextSaveGState(ctx);
	[self clipToFrame:ctx frame:innerBox1];
	CGContextSetFillColorWithColor(ctx, [UIColor.whiteColor colorWithAlphaComponent:0.5].CGColor);
	CGContextFillRect(ctx, outerBox);
	CGContextClipToRect(ctx, innerBox2); // reduce clip
	[self drawGradients:ctx];
	[self drawKnurl:ctx];
	[self drawItems:ctx];
	CGContextRestoreGState(ctx);
	[self drawFrame:ctx frame:outerBox];
}

-(bool)turn:(float)dist current_angle:(float)current_angle
{
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(10,10), YES/*opaque*/, 0.0/* scale*/);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	float pre = turn_angle;
	sscore_graphics *graphics = sscore_graphics_create(ctx);
	float new_angle = current_angle + (dist / self.wheelRadius);
	turn_angle = [self clampAngle:new_angle min:[self minTurnAngle:graphics] max:[self maxTurnAngle:graphics]];
	sscore_graphics_dispose(graphics);
	UIGraphicsEndImageContext();
	[self setNeedsDisplay];
	return turn_angle != pre;
}

-(bool)pointInKnurl:(CGPoint)pt
{
	CGRect frame = self.frame;
	return pt.x > kMargin && pt.x < frame.size.width - kMargin
			&& pt.y > self.knurlTop && pt.y < self.knurlBottom;
}

-(bool)pointInItems:(CGPoint)pt
{
	CGRect frame = self.frame;
	return pt.x > kMargin && pt.x < frame.size.width - kMargin
		&& pt.y > self.itemsTop && pt.y < self.itemsBottom;
}

-(SSDragItem*)nearestItem:(CGPoint)pt
{
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(10,10), YES/*opaque*/, 0.0/* scale*/);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	sscore_graphics *graphics = sscore_graphics_create(ctx);
	float wangle = [self wheelAngleForFrontAngle:[self frontAngleForXPos:pt.x]];
	int itemIndex = [self itemIndexForWheelAngle:wangle graphics:graphics];
	sscore_graphics_dispose(graphics);
	UIGraphicsEndImageContext();
	return itemIndex >= 0 && itemIndex < self.numItems ? [items objectAtIndex:itemIndex] : nil;
}

-(bool)hit:(UIGestureRecognizer *)panReco
{
	CGPoint panPos = [panReco locationInView:self];
	switch (panReco.state)
	{
		case UIGestureRecognizerStateBegan: return [self pointInKnurl:panPos] || [self pointInItems:panPos];
		default: return false;
	}
}

- (SSDragItem*)pan:(UIGestureRecognizer *)panReco
{
	CGPoint panPos = [panReco locationInView:self];
	switch (panReco.state)
	{
		case UIGestureRecognizerStatePossible:break;   // the recognizer has not yet recognized its gesture, but may be evaluating touch events. this is the default state
			
		case UIGestureRecognizerStateBegan:      // the recognizer has received touches recognized as the gesture. the action method will be called at the next turn of the run loop
		{
			if ([self pointInKnurl:panPos])
			{
				isRotating = true;
				isDragging = false;
				startTCAngle = self.turnAngle;
			}
			else if ([self pointInItems:panPos])
			{
				isRotating = false;
				isDragging = true;
				return [self nearestItem:panPos];
			}
		}break;
			
		case UIGestureRecognizerStateChanged:    // the recognizer has received touches recognized as a change to the gesture. the action method will be called at the next turn of the run loop
		{
			if (isRotating)
			{
				CGPoint translate = [(UIPanGestureRecognizer*)panReco translationInView:self];
				[self turn:translate.x current_angle:startTCAngle];
			}
		}break;
			
		case UIGestureRecognizerStateEnded:      // the recognizer has received touches recognized as the end of the gesture. the action method will be called at the next turn of the run loop and the recognizer will be reset to UIGestureRecognizerStatePossible
		case UIGestureRecognizerStateCancelled:  // the recognizer has received touches resulting in the cancellation of the gesture. the action method will be called at the next turn of the run loop. the recognizer will be reset to UIGestureRecognizerStatePossible
		case UIGestureRecognizerStateFailed:     // the recognizer has received a touch sequence that can not be recognized as the gesture. the action method will not be called and the recognizer will be reset to UIGestureRecognizerStatePossible
		{
			isRotating = false;
			isDragging = false;
		}break;
	}
	return nil;
}

@end
