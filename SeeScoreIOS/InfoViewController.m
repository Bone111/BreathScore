//
//  InfoViewController.m
//  SeeScoreIOSSample
//
//  Created by James Sutton on 23/01/2013.
//
// No warranty is made as to the suitability of this for any purpose
//

#import "InfoViewController.h"
#import <SeeScoreLib/SeeScoreLib.h>

@interface InfoViewController ()
{
	NSString *text;
}
@end

@implementation InfoViewController

- (void)showHeaderInfo:(SSScore*)score
{
	if (score)
	{
		SSHeader *header = score.header;
		sscore_version ver = [SSScore version];
		NSMutableString *str = [NSMutableString stringWithFormat:@"SeeScoreLib version: %d.%02d\n", ver.major, ver.minor];
		[str appendString:@"score-header:\n"];
		if (header.work_number && header.work_number.length > 0)
			[str appendFormat:@" work_number: %@\n", header.work_number];
		if (header.work_title && header.work_title.length > 0)
			[str appendFormat:@" work_title: %@\n", header.work_title];
		if (header.movement_number && header.movement_number.length > 0)
			[str appendFormat:@" movement_number: %@\n", header.movement_number];
		if (header.movement_title && header.movement_title.length > 0)
			[str appendFormat:@" movement_title: %@\n", header.movement_title];
		if (header.composer && header.composer.length > 0)
			[str appendFormat:@" composer: %@\n", header.composer];
		if (header.lyricist && header.lyricist.length > 0)
			[str appendFormat:@" lyricist: %@\n", header.lyricist];
		if (header.arranger && header.arranger.length > 0)
			[str appendFormat:@" arranger: %@\n", header.arranger];
		[str appendString:@" credit_words:\n"];
		for (NSString *cred in header.credit_words)
			[str appendFormat:@"   %@\n", cred];
		[str appendString:@" Part Names:\n"];
		for (SSPartName *pn in header.parts)
		{
			[str appendFormat:@"    %@", pn.full_name];
			 if (pn.abbreviated_name.length > 0)
				[str appendFormat:@" <%@>\n", pn.abbreviated_name];
			 else
				[str appendString:@"\n"];
		}
		text = str;
	}
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	textView.text = text;
}

@end
