//
//  SSBarControl.h
//  SeeScoreMac & SeeScoreiOS Sample Apps
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//

#import "SSBarControlProtocol.h"
#import "SSUpdateScrollProtocol.h"

#include "TargetConditionals.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#define PlatView UIView
#else
#define PlatView NSView
#endif

@interface SSBarControl : PlatView <SSUpdateScrollProtocol> {

	BOOL touchHit;
	CGPoint startPan;
}

@property (nonatomic, unsafe_unretained) IBOutlet id <SSBarControlProtocol> delegate;
@property (readonly) float scaleLeft;
@property (readonly) float scaleWidth;

#undef PlatView

@end
