//
//  EditCursor.h
//  ScoreEditor
//
//  Created by James Sutton on 29/11/2015.
//  Copyright © 2015 Dolphin Computing Ltd. All rights reserved.
//

#ifndef SSEditCursor_h
#define SSEditCursor_h

#import <UIKit/UIKit.h>

@class SSDragItem;

@interface SSEditCursor : CALayer

@property (nonatomic, assign) float stretch;

@property (readonly) bool lockedIn;

-(instancetype)init;

-(CGPoint)activePosForFinger:(CGPoint)finger;

-(void)startDrag:(CGPoint)finger draggingItem:(SSDragItem*)ditem;

-(void)updateDrag:(CGPoint)finger;

-(void)endDrag:(CGPoint)finger;

-(void)showNearestTarget:(CGPoint)nearestTarget;

-(void)noTarget;

@end

#endif /* SSEditCursor_h */
