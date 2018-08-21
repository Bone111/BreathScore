//
//  SSDeleteButtonView.m
//  SeeScoreIOS
//
//  Created by James Sutton on 06/03/2016.
//  Copyright © 2016 Dolphin Computing Ltd. All rights reserved.
//

#import "SSDeleteButtonView.h"

static const CGPoint kOffsetFromCursor = {10,-10};
static const float kDeleteCircleRadius = 15;
static const float kDeleteCrossFraction = 0.3;
// delete button animation parameters
static const float kSwellEnlarge = 1.5;
static const float kAnimationTime = 0.2;
static const float kDelayAnimationStart = 0.1;
static const float kDelayAnimationEnd = 0.2;
static const float kAnimationSpringVelocity = 0.1;
static const float kAnimationSpringDamping = 0.3;
static const CGSize kDefaultButtonSize = {kDeleteCircleRadius*2,kDeleteCircleRadius*2};
static const CGSize kDefaultEnlargedButtonSize = {kDeleteCircleRadius*2*kSwellEnlarge,kDeleteCircleRadius*2*kSwellEnlarge};

@implementation SSDeleteButtonView

+(CGPoint)offset
{
	return CGPointMake(kDeleteCircleRadius+kOffsetFromCursor.x, -kDeleteCircleRadius+kOffsetFromCursor.y);
}

+(CGRect)deleteFrameAt:(CGPoint)centre
{
	return CGRectMake(centre.x - kDefaultButtonSize.width/2, centre.y - kDefaultButtonSize.height/2,
					  kDefaultButtonSize.width,kDefaultButtonSize.height);
}

+(CGRect)enlargedDeleteFrameAt:(CGPoint)centre
{
	return CGRectMake(centre.x - kDefaultEnlargedButtonSize.width/2, centre.y - kDefaultEnlargedButtonSize.height/2,
					  kDefaultEnlargedButtonSize.width,kDefaultEnlargedButtonSize.height);
}

-(instancetype)initAt:(CGPoint)p
{
	if (self = [super initWithFrame:[SSDeleteButtonView deleteFrameAt:p]])
	{
		self.opaque = false;
	}
	return self;
}

-(CGSize) defaultSize
{
	return CGSizeMake(kDeleteCircleRadius*2,kDeleteCircleRadius*2);
}

+(void)drawCrosspath:(CGContextRef)ctx size:(float)size at:(CGPoint)p colour:(UIColor*)colour
{
	const float oblique = sqrtf(2*size*size);
	const float oblique45 = sqrtf(oblique*oblique/2);
	float x = p.x - size;
	float y = p.y;
	CGContextBeginPath(ctx);
	CGContextMoveToPoint(ctx, x,  y);//0
	x -= oblique45;
	y -= oblique45;
	CGContextAddLineToPoint(ctx, x,  y);//1
	x += oblique45;
	y -= oblique45;
	CGContextAddLineToPoint(ctx, x,  y);//2
	x = p.x;
	y = p.y - size;
	CGContextAddLineToPoint(ctx, x,  y);//3
	x += oblique45;
	y -= oblique45;
	CGContextAddLineToPoint(ctx, x,  y);//4
	x += oblique45;
	y += oblique45;
	CGContextAddLineToPoint(ctx, x,  y);//5
	x = p.x + size;
	y = p.y;
	CGContextAddLineToPoint(ctx, x,  y);//6
	x += oblique45;
	y += oblique45;
	CGContextAddLineToPoint(ctx, x,  y);//7
	x -= oblique45;
	y += oblique45;
	CGContextAddLineToPoint(ctx, x,  y);//8
	x = p.x;
	y = p.y + size;
	CGContextAddLineToPoint(ctx, x,  y);//9
	x -= oblique45;
	y += oblique45;
	CGContextAddLineToPoint(ctx, x,  y);//10
	x -= oblique45;
	y -= oblique45;
	CGContextAddLineToPoint(ctx, x,  y);//11
	x = p.x - size;
	y = p.y;
	CGContextAddLineToPoint(ctx, x,  y);//12
	CGContextClosePath(ctx);
	CGContextSetFillColorWithColor(ctx, colour.CGColor);
	CGContextFillPath(ctx);
}

// draw red button with cross
+(void)drawDeleteButton:(CGContextRef)ctx at:(CGPoint)deleteCentre radius:(float)radius
{
	CGRect deleteCircleRect = { deleteCentre.x - radius, deleteCentre.y - radius, radius*2,radius*2};
	CGContextSetRGBFillColor(ctx, 1, 0, 0, 0.8);
	CGContextFillEllipseInRect(ctx, deleteCircleRect);
	[self drawCrosspath:ctx size:radius*kDeleteCrossFraction at:deleteCentre colour:UIColor.whiteColor];
}

-(void)drawRect:(CGRect)rect
{
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect bounds = self.bounds;
	[SSDeleteButtonView drawDeleteButton:ctx at:CGPointMake(bounds.origin.x + bounds.size.width/2, bounds.origin.y + bounds.size.height/2) radius:bounds.size.width/2];
}

-(void)animate:(UIView*)parent atCentre:(CGPoint)centre
{
	self.frame = [SSDeleteButtonView deleteFrameAt:centre];
	[parent addSubview:self];
	[UIView animateWithDuration:kAnimationTime delay:kDelayAnimationStart usingSpringWithDamping:kAnimationSpringDamping initialSpringVelocity:kAnimationSpringVelocity options:UIViewAnimationOptionCurveEaseIn animations:^{
		
		self.frame = [SSDeleteButtonView enlargedDeleteFrameAt:centre];
		
	} completion:^(BOOL finished) {
		
		[UIView animateWithDuration:kAnimationTime delay:kDelayAnimationEnd options:UIViewAnimationOptionCurveEaseInOut animations:^{
			
			self.frame = [SSDeleteButtonView deleteFrameAt:centre];
			
		} completion:^(BOOL finished) {}];
	}];
}

@end
