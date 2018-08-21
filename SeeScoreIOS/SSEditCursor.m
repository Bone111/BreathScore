//
//  SSEditCursor.m
//  ScoreEditor
//
//  Created by James Sutton on 29/11/2015.
//  Copyright © 2015 Dolphin Computing Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "SSEditCursor.h"
#import "SSDragItem.h"
#include <math.h>

typedef struct {float r,g,b,a;} Colour;

static const CGPoint kDefaultActiveCentreXYOffsetFromFinger = {-40, -40};
static const float kFingerCircleRadius = 25;
static const float kVertHorizLineLength = 10; // short lines around active circle
static const float kDiagLineLength = 4;
//static const float kHitMaxDistance = 30; // hit if within finger circle
//static const float kHitMaxSqDistance = kHitMaxDistance*kHitMaxDistance;

static const float kActiveCircleLockedRadius = 6;
static const float kActiveCircleUnlockedRadius = 14;

static const Colour kTargetColourLocked = {0, 1, 0, 1}; // green
static const Colour kTargetColourUnlocked = {1, 0.1, 0.1, 0.4}; // red
static const float kObjectAlphaLocked = 1;
static const float kObjectAlphaUnlocked = 0.4;
static const Colour kFingerCircleColour = {0.2, 0.2, 0.4, 1};
static const Colour kFingerConnectionColour = {0.2, 0.2, 0.4, 1};

static void setStrokeColour(CGContextRef ctx, const Colour *col)
{
	CGContextSetRGBStrokeColor(ctx, col->r, col->g, col->b, col->a);
}

static void setFillColour(CGContextRef ctx, const Colour *col)
{
	CGContextSetRGBFillColor(ctx, col->r, col->g, col->b, col->a);
}

@interface SSEditCursor ()

@property bool suppressActiveRightLine;
@property bool drawFingerCircle;
@property CGPoint fingerPos;
@property SSDragItem *draggingItem;
@property CGPoint trajectoryStart;
@property CGPoint trajectoryEnd;
@property float trajectoryDistance;

@end

@implementation SSEditCursor
/* NB we cannot use normal variables!
 {}
 */

// implementation detail of CALayer requires the properties to be dynamic
// These are auto copied by initWithLayer
@dynamic stretch;
@dynamic suppressActiveRightLine;
@dynamic drawFingerCircle;
@dynamic fingerPos;
@dynamic draggingItem;
@dynamic trajectoryStart;
@dynamic trajectoryEnd;
@dynamic trajectoryDistance;

-(instancetype)init
{
	if (self = [super init])
	{
		self.stretch = 0;
		self.suppressActiveRightLine = false;
		self.drawFingerCircle = true;
		self.anchorPoint = CGPointMake(0,0);
		self.contentsScale = [UIScreen mainScreen].scale; // this prevents it being pixelated on a retina screen
	}
	return self;
}

+ (BOOL)needsDisplayForKey:(NSString *)key
{
	if ([@"stretch" isEqualToString:key])
	{
		return YES;
	}
	else if ([@"trajectoryDistance" isEqualToString:key])
	{
		return YES;
	}
	return [super needsDisplayForKey:key];
}

- (id<CAAction>)actionForKey:(NSString *)key
{
	if ([key isEqualToString:@"stretch"])
	{
		CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:key];
		animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
		animation.fromValue = @([[self presentationLayer] stretch]);
		animation.duration = 0.5;
		return animation;
	}
	else if ([key isEqualToString:@"trajectoryDistance"])
	{
		CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:key];
		animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
		animation.fromValue = @([[self presentationLayer] trajectoryDistance]);
		animation.duration = 0.2;//self.trajectoryDistance == 0 ? 0 : 2;
		return animation;
	}
	return [super actionForKey:key];
}

-(CGPoint)activePosForFinger:(CGPoint)finger
{
	float currentStretch = [[self presentationLayer] stretch];
	CGPoint activeOffset = CGPointMake(kDefaultActiveCentreXYOffsetFromFinger.x * currentStretch, kDefaultActiveCentreXYOffsetFromFinger.y * currentStretch);
	return CGPointMake(finger.x + activeOffset.x,finger.y + activeOffset.y);
}

-(void)drawActiveTarget:(CGContextRef)ctx at:(CGPoint)activeCentre
{
	const float activeCircleRadius = self.lockedIn ? 6 : 10;
	setStrokeColour(ctx, self.lockedIn ? &kTargetColourLocked : &kTargetColourUnlocked);
	const float kDiagLineXYOffset45 = sqrtf(kDiagLineLength*kDiagLineLength/2); // x,y offsets at 45deg
	const float kDiagActiveCircleRadiusXYOffset45 = sqrtf(activeCircleRadius*activeCircleRadius/2);
	static const int kNumPoints = 16;
	CGPoint points[kNumPoints];
	int numPoints = 0;
	// diag lines
	// tl
	points[numPoints++] = CGPointMake(activeCentre.x - kDiagActiveCircleRadiusXYOffset45,  activeCentre.y - kDiagActiveCircleRadiusXYOffset45);
	points[numPoints++] = CGPointMake(activeCentre.x - kDiagActiveCircleRadiusXYOffset45 - kDiagLineXYOffset45,  activeCentre.y - kDiagActiveCircleRadiusXYOffset45 - kDiagLineXYOffset45);
	// tr
	points[numPoints++] = CGPointMake(activeCentre.x + kDiagActiveCircleRadiusXYOffset45,  activeCentre.y - kDiagActiveCircleRadiusXYOffset45);
	points[numPoints++] = CGPointMake(activeCentre.x + kDiagActiveCircleRadiusXYOffset45 + kDiagLineXYOffset45,  activeCentre.y - kDiagActiveCircleRadiusXYOffset45 - kDiagLineXYOffset45);
	// bl
	points[numPoints++] = CGPointMake(activeCentre.x - kDiagActiveCircleRadiusXYOffset45,  activeCentre.y + kDiagActiveCircleRadiusXYOffset45);
	points[numPoints++] = CGPointMake(activeCentre.x - kDiagActiveCircleRadiusXYOffset45 - kDiagLineXYOffset45,  activeCentre.y + kDiagActiveCircleRadiusXYOffset45 + kDiagLineXYOffset45);
	// br
	points[numPoints++] = CGPointMake(activeCentre.x + kDiagActiveCircleRadiusXYOffset45,  activeCentre.y + kDiagActiveCircleRadiusXYOffset45);
	points[numPoints++] = CGPointMake(activeCentre.x + kDiagActiveCircleRadiusXYOffset45 + kDiagLineXYOffset45,  activeCentre.y + kDiagActiveCircleRadiusXYOffset45 + kDiagLineXYOffset45);
	// vert lines
	points[numPoints++] = CGPointMake(activeCentre.x,  activeCentre.y - activeCircleRadius - kVertHorizLineLength);
	points[numPoints++] = CGPointMake(activeCentre.x,  activeCentre.y - activeCircleRadius);
	points[numPoints++] = CGPointMake(activeCentre.x,  activeCentre.y + activeCircleRadius + kVertHorizLineLength);
	points[numPoints++] = CGPointMake(activeCentre.x,  activeCentre.y + activeCircleRadius);
	// horiz lines
	points[numPoints++] = CGPointMake(activeCentre.x - activeCircleRadius - kVertHorizLineLength, activeCentre.y);
	points[numPoints++] = CGPointMake(activeCentre.x - activeCircleRadius, activeCentre.y);
	// short line to right of active centre is optional (so last)
	if (!self.suppressActiveRightLine)
	{
		points[numPoints++] = CGPointMake(activeCentre.x + activeCircleRadius + kVertHorizLineLength, activeCentre.y);
		points[numPoints++] = CGPointMake(activeCentre.x + activeCircleRadius, activeCentre.y);
	}
	assert(numPoints <= kNumPoints);
	CGContextStrokeLineSegments(ctx, points, numPoints);
}

static CGPoint centreOf(CGRect r)
{
	return CGPointMake(r.origin.x+r.size.width/2, r.origin.y+r.size.height/2);
}

-(void)drawConnectionToFinger:(CGContextRef)ctx finger:(CGPoint)fingerPoint active:(CGPoint)activePoint
{
	const float activeCircleRadius = self.lockedIn ?  kActiveCircleLockedRadius : kActiveCircleUnlockedRadius;
	setStrokeColour(ctx, &kFingerConnectionColour);
	CGPoint activeCentre = activePoint;
	// connecting line
	float angle = atan2f(fingerPoint.y - activeCentre.y, fingerPoint.x - activeCentre.x);
	float sinangle = sinf(angle);
	float cosangle = cosf(angle);
	const float kFingerCircleXOffset = kFingerCircleRadius * cosangle;
	const float kFingerCircleYOffset = kFingerCircleRadius * sinangle;
	const float kActiveCircleXOffset = activeCircleRadius * cosangle;
	const float kActiveCircleYOffset = activeCircleRadius * sinangle;
	static const int kNumPoints = 2;
	CGPoint points[kNumPoints];
	points[0] = CGPointMake(activeCentre.x + kActiveCircleXOffset,  activeCentre.y + kActiveCircleYOffset);
	points[1] = CGPointMake(fingerPoint.x - kFingerCircleXOffset,  fingerPoint.y - kFingerCircleYOffset);
	CGContextStrokeLineSegments(ctx, points, kNumPoints);
}

-(void)drawFingerCircle:(CGContextRef)ctx finger:(CGPoint)fingerPoint
{
	setStrokeColour(ctx, &kFingerCircleColour);
	CGRect fingerRect = { fingerPoint.x - kFingerCircleRadius, fingerPoint.y - kFingerCircleRadius, kFingerCircleRadius*2, kFingerCircleRadius*2};
	CGContextStrokeEllipseInRect(ctx, fingerRect);
}

-(void)startDrag:(CGPoint)finger draggingItem:(SSDragItem*)ditem
{
	self.drawFingerCircle = true;
	self.fingerPos = finger;
	self.draggingItem = ditem;
	self.trajectoryDistance = 0;
	self.stretch = 1; // will animate
	_lockedIn = false;
	[self setNeedsDisplay];
}

-(void)updateDrag:(CGPoint)finger
{
	self.fingerPos = finger;
	[self setNeedsDisplay];
}

-(void)endDrag:(CGPoint)finger
{
	self.drawFingerCircle = false;
	self.fingerPos = finger;
	self.draggingItem = nil; // make cursor disappear
	self.stretch = 0;
	self.trajectoryDistance = 0;
}

-(void)showNearestTarget:(CGPoint)nearestTarget
{
	self.trajectoryStart = [self activePosForFinger:self.fingerPos];
	if (self.trajectoryEnd.x != nearestTarget.x || self.trajectoryEnd.y != nearestTarget.y)
		self.trajectoryDistance = 1;
	self.trajectoryEnd = nearestTarget;
	_lockedIn = true;
	[self setNeedsDisplay];
}

-(void)noTarget
{
	self.trajectoryDistance = 0;
	self.trajectoryEnd = CGPointZero;
	_lockedIn = false;
}

CGPoint between(CGPoint p1, CGPoint p2, float distance)
{
	assert(distance >= 0 && distance <= 1);
	return CGPointMake(p1.x * (1-distance) + p2.x * distance, p1.y * (1-distance) + p2.y * distance);
}

-(void)drawInContext:(CGContextRef)ctx
{
	if (self.fingerPos.x > 0)
	{
		CGContextSetLineWidth(ctx, 2);
		assert(self.fingerPos.y > 0);
		CGPoint activePos = [self activePosForFinger:self.fingerPos];
		if (self.trajectoryDistance > 0 && self.trajectoryEnd.x > 0)
		{
			activePos = between(activePos, self.trajectoryEnd, self.trajectoryDistance);
		}
		if (self.drawFingerCircle)
		{
			[self drawFingerCircle:ctx finger:self.fingerPos];
		}
		if (self.draggingItem)
		{
			//CGRect bb = [draggingItem bounds:ctx];
			[self drawActiveTarget:ctx at:activePos];
			[self drawConnectionToFinger:ctx finger:self.fingerPos active:activePos];
			[self.draggingItem draw:ctx pos:activePos colour:[UIColor.blackColor colorWithAlphaComponent:self.lockedIn?kObjectAlphaLocked:kObjectAlphaUnlocked]];
		}
	}
}

//@end

@end
