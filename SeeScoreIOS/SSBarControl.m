//
//  SSBarControl.m
//  SeeScoreMac & SeeScoreiOS Sample Apps
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//

#import "SSBarControl.h"
#import <CoreGraphics/CoreGraphics.h>

#define UseGradientBackground 0

@interface SSBarControl ()
{
	bool requestedUpdate;
	
#if TARGET_OS_IPHONE
	UIPanGestureRecognizer *panRecogniser;
	UITapGestureRecognizer *tapRecogniser;
#endif
}
@end

typedef struct {float r,g,b,a;} Colour;

static const Colour kControlOutlineColour = {0,0,0,0};//no outline
static const Colour kTickColour = {0,0,0,1};
static const Colour kDisplayedBarsColour = {0.47,0.67,1,1};
static const Colour kUnLoadedBarsColour = {0.98,0.98,0.98,1};
static const Colour kBackgroundGradientTopColour = {1,1,1,1};
static const Colour kBackgroundGradientBottomColour = {0.7,0.7,0.7,1};
static const Colour kCursorOutlineColour = {0,0,0,1};
static const Colour kCursorFillColour = {0,0,0,0};
static const Colour kCursorCircleOutlineColour = {0,0,0,1};
static const Colour kCursorCircleFillColour = {0.47,0.67,1,1};
static const Colour kTransparent = {0,0,0,0};

//static const float kUnLoadedPatternAlpha = 0.05;

static const float kOutlineWidth = 1;
static const float kOutlineCornerRadius = 10;
static const float kPiby2 = 3.14159265/2;
static NSString *kFontName = @"Georgia";
static const float kTotalFontSize = 18;
static const float kLeftMargin = 2;
static const float kRightMargin = 2;
static const float kTopMargin = 1;
static const float kBottomMargin = 1;
static const float kMinTickPitch = 5; // eliminate ticks closer than this
static const float kMaxTextWidth = 70;
static const float kTextLeftMargin = 10;
static const float kControlLeft = 30;
static const float k1TickSize = 2; // these are half heights
static const float k5TickSize = 4;
static const float k10TickSize = 6;
static const float k50TickSize = 8;
static const float k100TickSize = 10;
static const float kControlOffsetY = 4; // move the centre of the control down a little to allow space for the bar number above
static const float kDisplayedBarsStripeHeight = 12;

static const float kCursorOuterLineWidth = 0.8;
static const float kCursorCircleLineWidth = 8;
static const float kDotRadius = 4;
static const float kCursorCornerRadius = 3;
static const float kCursorFontSize = 13;
static const float kHalfCursorRectWidth = 11;
static const float kHalfCursorRectHeight = 9;

static const float kXHitSize = 30; // pan has asymmetric hit so we enlarge the hit width to make sure it catches within the outer rect

@implementation SSBarControl

-(float)scaleLeft
{
	return kControlLeft;
}

-(float)scaleWidth
{
	return self.bounds.size.width - kControlLeft - kMaxTextWidth - kTextLeftMargin;
}

static void drawCircle(CGContextRef ctx, float x, float y, float radius, float lineWidth,
					   const Colour *strokeColour, const Colour *fillColour)
{
	CGContextSetLineWidth(ctx, lineWidth);
	CGRect r = CGRectMake(x-radius, y-radius, radius*2, radius*2);
	CGContextSetRGBStrokeColor (ctx, strokeColour->r, strokeColour->g, strokeColour->b, strokeColour->a);
	CGContextStrokeEllipseInRect (ctx, r);
	if (fillColour->a > 0.01)
	{
		CGContextSetRGBFillColor (ctx, fillColour->r, fillColour->g, fillColour->b, fillColour->a);
		CGContextFillEllipseInRect (ctx, r);
	}
}

static void drawTick(CGContextRef ctx, float x, float y, float height, const Colour *colour)
{
	CGContextSetRGBStrokeColor (ctx, colour->r, colour->g, colour->b, colour->a);
	CGContextSetLineWidth(ctx, 1);
	CGPoint points[2];
	int i = 0;
	points[i++] = CGPointMake(x, y + height);
	points[i++] = CGPointMake(x, y - height);
	CGContextAddLines (ctx,points,i);
	CGContextDrawPath (ctx, kCGPathStroke);
}

-(float)xposForBarNumber:(int)barNumber totalBars:(int)numBars
{
	float frac = (numBars >= 2) ? ((float)(barNumber-1) / (numBars-1)) : 0; // avoid /0
	return self.scaleLeft + frac * self.scaleWidth;
}

-(int)barNumberForXpos:(float)xpos totalBars:(int)numBars
{
	float scaLeft = self.scaleLeft;
	float scaWidth = self.scaleWidth;
	if (xpos - scaLeft > 0 && xpos - scaLeft < scaWidth && numBars >= 2)
	{
		return 1 + (0.5 + (xpos - scaLeft) * numBars / scaWidth);
	}
	else
		return 1;
}

-(void)drawMultiTick:(CGContextRef)ctx start:(int)startTick step:(int)tickStep loaded:(int)numBarsLoaded totalBars:(int)totalBars y:(float)tick_ypos sz:(float)tickSize col:(const Colour *)tickColour
{
	CGContextSetRGBStrokeColor (ctx, tickColour->r, tickColour->g, tickColour->b, tickColour->a);
	CGContextSetLineWidth(ctx, 1);
	CGContextBeginPath(ctx);
	for (int i = startTick; i <= numBarsLoaded; i+=tickStep)
	{
		float xpos = [self xposForBarNumber:i totalBars:totalBars];
		CGContextMoveToPoint(ctx, xpos, tick_ypos - tickSize);
		CGContextAddLineToPoint(ctx, xpos, tick_ypos + tickSize);
	}
	CGContextDrawPath (ctx, kCGPathStroke);
}

static void drawFilledRect(CGContextRef ctx, CGRect rect, const Colour *fgColour)
{
	CGContextSetRGBFillColor (ctx, fgColour->r, fgColour->g, fgColour->b, fgColour->a);
	CGContextFillRect (ctx, rect);					   
}

static void drawGradient(CGContextRef ctx, CGPoint p1, const CGPoint p2,
					 const Colour *startColour, const Colour *endColour)
{
#if UseGradientBackground // setting this substantially reduces scroll performance on iPhone
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	CGFloat colourBuf[8]; //rgba
	colourBuf[0] = startColour->r;
	colourBuf[1] = startColour->g;
	colourBuf[2] = startColour->b;
	colourBuf[3] = startColour->a;
	colourBuf[4] = endColour->r;
	colourBuf[5] = endColour->g;
	colourBuf[6] = endColour->b;
	colourBuf[7] = endColour->a;
	CGGradientRef gradient = CGGradientCreateWithColorComponents(rgb, colourBuf, NULL, 2);
	CGColorSpaceRelease(rgb);
	CGGradientDrawingOptions options = 0;
	//options |= kCGGradientDrawsBeforeStartLocation;
	//options |= kCGGradientDrawsAfterEndLocation;
	CGContextDrawLinearGradient(ctx, gradient,p1, p2, options);
	CGGradientRelease(gradient);
#endif
}

static void drawRoundedRect(CGContextRef ctx, CGRect rect, float lineWidth, float cornerRadius,
							const Colour *fillColour, const Colour *outlineColour,
							bool useGradientBackground)
{
	CGContextSaveGState(ctx);
	CGContextSetLineWidth(ctx, lineWidth);
	CGContextBeginPath(ctx);
	float width = rect.size.width;
	float height = rect.size.height;
	//tl
	CGContextMoveToPoint (ctx, rect.origin.x + cornerRadius, rect.origin.y);
	//top >
	CGContextAddLineToPoint(ctx, rect.origin.x + width - cornerRadius, rect.origin.y);
	//tr
	CGContextAddArc (ctx,
					 rect.origin.x + width - cornerRadius,
					 rect.origin.y + cornerRadius,
					 cornerRadius,
					 -kPiby2, 0, 0);// clockwise is 0 NOT 1 as in the documentation
	//right 
	CGContextAddLineToPoint(ctx, rect.origin.x + width, rect.origin.y + height - cornerRadius);
	//br
	CGContextAddArc (ctx,
					 rect.origin.x + width - cornerRadius,
					 rect.origin.y + height - cornerRadius,
					 cornerRadius,
					 0, kPiby2, 0);
	//bottom <
	CGContextAddLineToPoint(ctx, rect.origin.x + cornerRadius, rect.origin.y + height);
	//bl
	CGContextAddArc (ctx,
					 rect.origin.x + cornerRadius,
					 rect.origin.y + height - cornerRadius,
					 cornerRadius,
					 kPiby2, 2*kPiby2, 0);
	//left ^
	CGContextAddLineToPoint(ctx, rect.origin.x, rect.origin.y + cornerRadius);
	//tl
	CGContextAddArc (ctx,
					 rect.origin.x + cornerRadius,
					 rect.origin.y + cornerRadius,
					 cornerRadius,
					 2*kPiby2, -kPiby2, 0);
	CGContextClosePath(ctx);
	if (useGradientBackground)
	{
		CGContextClip(ctx); // clip the gradient to the outline
		drawGradient(ctx, 
			 CGPointMake(rect.origin.x, rect.origin.y),
			 CGPointMake(rect.origin.x, rect.origin.y + rect.size.height),
			 &kBackgroundGradientTopColour, &kBackgroundGradientBottomColour);
	}
	if (fillColour->a > 0.01)
	{
		CGContextSetRGBFillColor (ctx, fillColour->r, fillColour->g, fillColour->b, fillColour->a);
		CGContextFillPath (ctx);
	}
	if (outlineColour->a > 0.01)
	{
		CGContextSetRGBStrokeColor (ctx, outlineColour->r, outlineColour->g, outlineColour->b, outlineColour->a);
		CGContextStrokePath (ctx);
	}
	CGContextRestoreGState(ctx);
}

static void drawControlBackground(CGContextRef ctx, CGRect bounds)
{
	drawRoundedRect(ctx, CGRectMake(bounds.origin.x + kLeftMargin, bounds.origin.y + kTopMargin,
									bounds.size.width - kLeftMargin - kRightMargin,
									bounds.size.height - kBottomMargin - kTopMargin),
					kOutlineWidth, kOutlineCornerRadius, &kTransparent, &kControlOutlineColour,
					UseGradientBackground);
}

// create a rounded rect centred at (x,y)
static void drawCursor(CGContextRef ctx, float x, float y, int barNum)
{
	drawRoundedRect(ctx, CGRectMake(x-kHalfCursorRectWidth, y - kHalfCursorRectHeight,
									2*kHalfCursorRectWidth, 2*kHalfCursorRectHeight),
					kCursorOuterLineWidth, kCursorCornerRadius, &kCursorFillColour, &kCursorOutlineColour,
					false);
	// cursor central dot
	drawCircle(ctx, x, y, kDotRadius, kCursorCircleLineWidth, &kCursorCircleOutlineColour, &kCursorCircleFillColour);
	drawTick(ctx, x, y, k100TickSize, &kTickColour);
	CGContextSetRGBFillColor (ctx, 0, 0, 0, 1); // text uses fill colour
#if TARGET_OS_IPHONE
	// bar number above cursor
	UIFont *font = [UIFont fontWithName:kFontName size:kCursorFontSize];
	NSString *str = [NSString stringWithFormat:@"%d", barNum];
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	[dict setObject:font forKey:NSFontAttributeName];
	CGSize bounds = [str sizeWithAttributes:dict];
	CGContextSetRGBFillColor (ctx, 0, 0, 0, 1); // text uses fill colour
	// origin is top left of string
	[str drawAtPoint:CGPointMake(x - bounds.width/2,
								 y - bounds.height - kHalfCursorRectHeight) withAttributes:dict];
#else
#endif
}

#if TARGET_OS_IPHONE
-(void)pan
{
	int totalBars = (self.delegate != nil) ? [self.delegate totalBars] : 1;
	int cursorBarNumber = (self.delegate != nil) ? [self.delegate startBarDisplayed] + 1 : 0;
	if ([panRecogniser state] == UIGestureRecognizerStateBegan)
	{
		startPan = [panRecogniser locationInView:self];
		//float cursor_frac = (float)cursorIndex / totalBars;
		float cursor_centre = [self xposForBarNumber:cursorBarNumber totalBars:totalBars];
		//float cursor_centre = kMargin + cursor_frac * (self.bounds.size.width - 2*kMargin);
		float cursor_left = cursor_centre - kXHitSize;
		float cursor_right = cursor_centre + kXHitSize;
		touchHit = (startPan.x >= cursor_left && startPan.x <= cursor_right);
		//NSLog(@"startPan.x%f, f:%f, c:%f, l:%f, r:%f, touchHit %d", p.x, cursor_frac, cursor_centre, cursor_left, cursor_right, touchHit);
	}
	else if ([panRecogniser state] == UIGestureRecognizerStateEnded)
	{
		CGPoint p = [panRecogniser translationInView:self];
		int bn = [self barNumberForXpos:p.x + startPan.x totalBars:totalBars];
		if (bn >= 1 && bn <= totalBars)
		{
			if (self.delegate != nil)
				[self.delegate cursorChanged:bn-1];
			[self setNeedsDisplay];
		}
	}
	else if (touchHit)
	{
		CGPoint p = [panRecogniser translationInView:self];
		int bn = [self barNumberForXpos:p.x + startPan.x totalBars:totalBars];
		if (bn >= 1 && bn <= totalBars)
		{
			if (self.delegate != nil)
				[self.delegate cursorChanged:bn-1];
			[self setNeedsDisplay];
		}
	}
}
#endif

#if !TARGET_OS_IPHONE
-(void)setNeedsDisplay
{
	[self setNeedsDisplay:YES];
}
#endif

#if TARGET_OS_IPHONE
-(void)tap
#else
-(void)mouseDown:(NSEvent *)event
#endif
{
#if TARGET_OS_IPHONE
	CGPoint p = [tapRecogniser locationInView:self];
#else
	NSPoint p = [self convertPoint:[event locationInWindow]
									  fromView:nil];
#endif
	if (self.bounds.size.width > 0)
	{
		int totalBars = (self.delegate != nil) ? [self.delegate totalBars] : 1;
		int bn = [self barNumberForXpos:p.x totalBars:totalBars];
		if (bn >= 1 && bn < totalBars)
		{
			if (self.delegate != nil)
				[self.delegate cursorChanged:bn-1];
			[self setNeedsDisplay];
		}
	}
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	touchHit = NO;
#if TARGET_OS_IPHONE
	panRecogniser = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan)];
	[self addGestureRecognizer:panRecogniser];
	tapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap)];
	[self addGestureRecognizer:tapRecogniser];
#endif
}

- (void)drawRect:(CGRect)rect
{
	int cursorBarNumber = (self.delegate != nil) ? [self.delegate startBarDisplayed] + 1 : 0;
#if TARGET_OS_IPHONE
	CGContextRef ctx = UIGraphicsGetCurrentContext();
#else
	NSGraphicsContext* aContext = [NSGraphicsContext currentContext];
	CGContextRef ctx = (CGContextRef)aContext.graphicsPort;
#endif
	CGContextSaveGState(ctx);
	drawControlBackground(ctx, self.bounds);
	int totalBars = (self.delegate != nil) ? [self.delegate totalBars] : 0;
	if (totalBars > 0)
	{
		float dot_ypos = rect.size.height/2 + kControlOffsetY;
#if TARGET_OS_IPHONE
		// draw total number of bars on right
		UIFont *font = [UIFont fontWithName:kFontName size:kTotalFontSize];
		NSString *str;
		if (rect.size.width < 500) // show "bars" on ipad, but not enough space on iphone
			str = [NSString stringWithFormat:@"%d", totalBars];
		else
			str = [NSString stringWithFormat:@"%d %@", totalBars, NSLocalizedString(@"bars","number of bars")];
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		[dict setObject:font forKey:NSFontAttributeName];
		CGSize textBounds = [str sizeWithAttributes:dict];
		float textLeft = kControlLeft + self.scaleWidth + kTextLeftMargin;
		// draw "10 bars" at right of control. Origin is top left of string
		[str drawAtPoint:CGPointMake(textLeft, dot_ypos - textBounds.height/2) withAttributes:dict];
#endif
		float tick_ypos = dot_ypos;
		// numBarsLoaded is the number of bars which have been laid out. This increases to totalBars within a few seconds
		// the loaded section is displayed with a ruler, the unloaded section is displayed with a stipple pattern
		int numBarsLoaded = totalBars;
		if (self.delegate)
		{
			int startBarNumberDisplayed = [self.delegate startBarDisplayed]+1;
			int numBarsDisplayed = [self.delegate numBarsDisplayed];
			numBarsLoaded = [self.delegate numBarsLoaded];
			if (numBarsDisplayed >= 0 && numBarsLoaded > 0)
			{
				float display_start_xpos = [self xposForBarNumber:startBarNumberDisplayed totalBars:totalBars];
				float display_end_xpos = [self xposForBarNumber:startBarNumberDisplayed + numBarsDisplayed - 1 totalBars:totalBars];
				// loaded bars lt grey background rect
				float unloaded_start_xpos = (numBarsLoaded > 0) ? [self xposForBarNumber:numBarsLoaded totalBars:totalBars] : kControlLeft;
																   float unloaded_end_xpos = [self xposForBarNumber:totalBars totalBars:totalBars];
				CGRect unloadedBarsRect = CGRectMake(unloaded_start_xpos, dot_ypos - kDisplayedBarsStripeHeight/2,
													 unloaded_end_xpos - unloaded_start_xpos, kDisplayedBarsStripeHeight);
				drawFilledRect(ctx, unloadedBarsRect, &kUnLoadedBarsColour);
				//[UIUtil paintPattern:UIUtil_pattern2 ctx:ctx rect:plat::cgRect(unloadedBarsRect) alpha:kUnLoadedPatternAlpha];
				// displayed bars grey background rect
				CGRect displayedBarsRect;
				displayedBarsRect.origin = CGPointMake(display_start_xpos, dot_ypos - kDisplayedBarsStripeHeight/2);
				displayedBarsRect.size = CGSizeMake(display_end_xpos - display_start_xpos, kDisplayedBarsStripeHeight);
				drawFilledRect(ctx, displayedBarsRect, &kDisplayedBarsColour);
			}
		}
		float tickPitch = (totalBars >= 2) ? self.scaleWidth / (totalBars - 1) : self.scaleWidth;
		// NB We want the first tick at bar 1, and then major ticks at bar 10,20 etc
		// This is NOT like a ruler which has the first major tick at 0!
		// major tick at bar 1
		drawTick(ctx, [self xposForBarNumber:1 totalBars:totalBars], tick_ypos, k100TickSize, &kTickColour);
		// ticks at 100,200..
		[self drawMultiTick:ctx start:100 step:100 loaded:numBarsLoaded totalBars:totalBars y:tick_ypos sz:k100TickSize col:&kTickColour];
		// ticks at bar 50,150,250..
		if (tickPitch*50 > kMinTickPitch)
		{
			[self drawMultiTick:ctx start:50 step:100 loaded:numBarsLoaded totalBars:totalBars y:tick_ypos sz:k50TickSize col:&kTickColour];
		}
		// ticks at 10,20..
		if (tickPitch*10 > kMinTickPitch)
		{
			[self drawMultiTick:ctx start:10 step:10 loaded:numBarsLoaded totalBars:totalBars y:tick_ypos sz:k10TickSize col:&kTickColour];
		}
		// ticks at bar 5,15,25..
		if (tickPitch*5 > kMinTickPitch)
		{
			[self drawMultiTick:ctx start:5 step:10 loaded:numBarsLoaded totalBars:totalBars y:tick_ypos sz:k5TickSize col:&kTickColour];
		}
		// small ticks at the start of each bar (excluding 5,10,15..)
		if (tickPitch > kMinTickPitch)
		{
			[self drawMultiTick:ctx start:1 step:1 loaded:numBarsLoaded totalBars:totalBars y:tick_ypos sz:k1TickSize col:&kTickColour];
		}
		// cursor
		float cursor_xpos = [self xposForBarNumber:cursorBarNumber totalBars:totalBars];
		drawCursor(ctx, cursor_xpos, dot_ypos, cursorBarNumber);
		CGContextRestoreGState(ctx);
	}// else if 0 bars draw nothing
}

//protocol SSUpdateScrollProtocol

-(void) update
{
	if (self.delegate)
	{
		if (!requestedUpdate) // this flag causes multiple update calls to be coalesced
		{
			requestedUpdate = true;
			float delayInSeconds = 0.1F;
			dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
			dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
				[self setNeedsDisplay];
				requestedUpdate = false;
			});
		}
	}
}

@end
