//
//  InfoViewController.h
//  SeeScoreIOSSample
//
//  Created by James Sutton on 23/01/2013.
//
// No warranty is made as to the suitability of this for any purpose
//

#import <UIKit/UIKit.h>

@class SSScore;

@interface InfoViewController : UIViewController
{
	IBOutlet UITextView *textView;
}

- (void)showHeaderInfo:(SSScore*)score;

@end
