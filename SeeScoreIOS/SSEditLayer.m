//
//  SSEditLayer.m
//  SeeScoreiOS Sample App
//
//  You are free to copy and modify this code as you wish
//  No warranty is made as to the suitability of this for any purpose
//

#import "SSEditLayer.h"
#import "SSViewInterface.h"
#import "SSTurnControl.h"
#import "SSDragItem.h"
#import "SSEditCursor.h"
#import "SSDeleteButtonView.h"

//#define ShowOverlay // define this to give translucency to the edit overlay, else it is transparent

#define kDefaultFontSize 9

static const float kTurnControlMinWidth = 110;
static const float kTurnControlHeight = 140;
static const float kTurnControlMinGap = 8;
static const float kTurnControlWidthGapRatio = 0.9;

static const float kTurnControlItemsScale = 1.1F;

static const float kMaxTargetDistance = 80; // jump to target within this distance
static const float kMaxTargetDistance_sq = kMaxTargetDistance*kMaxTargetDistance;

static const float kMaxHitButtonDistance = 30; // max tap dist away from delete button to register a hit/delete
static const float kMaxHitButtonDistance_sq = kMaxHitButtonDistance*kMaxHitButtonDistance;

@interface SSEditLayer ()
{
	id <SSViewInterface> ssView;
	
	enum sscore_system_stafflocation_e clickedStaffLocation;
	
	SSSystem *editingSystem;
	SSComponent *selectedComponent;
	SSDirectionTypeWords *editingDirectionWords;

	UITextField *temporaryTextField;
	NSArray<SSTurnControl *> *turnControls;
	SSDragItem *draggingItem;
	SSTurnControl *draggingFromControl;
	CGPoint dragFingerPos;
	SSEditCursor *editCursor;
	SSDeleteButtonView *deleteButton;
}
@end

@implementation SSEditLayer

static const int kNumTurnControls = 6;

static const enum sscore_edit_dynamic_type kDynamics[] =
{
	sscore_edit_dynamic_ff,
	sscore_edit_dynamic_f,
	sscore_edit_dynamic_mf,
	sscore_edit_dynamic_mp,
	sscore_edit_dynamic_p,
	sscore_edit_dynamic_pp
};
static const int kNumDynamics = sizeof(kDynamics)/sizeof(*kDynamics);

static const enum sscore_edit_articulation_type kArtics[] =
{
	sscore_edit_articulation_staccato,
	sscore_edit_articulation_tenuto,
	sscore_edit_articulation_accent,
	sscore_edit_articulation_strong_accent
};
static const int kNumArtics = sizeof(kArtics)/sizeof(*kArtics);

static const enum sscore_edit_ornament_type kOrns[] =
{
	sscore_edit_ornament_trill_mark,
	sscore_edit_ornament_turn,
	sscore_edit_ornament_mordent,
};
static const int kNumOrns = sizeof(kOrns)/sizeof(*kOrns);

static const enum sscore_edit_clef_type kClefs[] =
{
	sscore_edit_clef_C,
	sscore_edit_clef_F,
	sscore_edit_clef_G,
	sscore_edit_clef_perc
};
static const int kNumClefs = sizeof(kClefs)/sizeof(*kClefs);

static const enum sscore_edit_accidental_type kAccidentals[] =
{
	sscore_edit_accidental_doubleflat,
	sscore_edit_accidental_flat,
	sscore_edit_accidental_natural,
	sscore_edit_accidental_sharp,
	sscore_edit_accidental_doublesharp
};
static const int kNumAccidentals = sizeof(kAccidentals)/sizeof(*kAccidentals);
																					
static SSTurnControl *createTurnControl(CGPoint bottomLeft, float width, NSArray<SSDragItem*> *items, int centre_index, float scale)
{
	SSTurnControl *turnControl = [[SSTurnControl alloc] initWithFrame:CGRectMake(bottomLeft.x, bottomLeft.y - kTurnControlHeight,
																				 width, kTurnControlHeight)];
	[turnControl setItems:items
			central_index:centre_index
			magnification:scale
					knurl:knurl_below];
	return turnControl;
}

static SSTurnControl *createDynamicsTurnControl(CGPoint bottomLeft, float width)
{
	NSMutableArray<SSDragItem*> *items = NSMutableArray.array;
	static const float scale = kTurnControlItemsScale;
	for (int i = 0; i < kNumDynamics; ++i)
		[items addObject:[[SSDragItem alloc] initWithType:sscore_edit_typefordynamicsnotation(kDynamics[i]) scale:scale]];
	return createTurnControl(bottomLeft, width, items, 3, scale);
}

static SSTurnControl *createArticTurnControl(CGPoint bottomLeft, float width)
{
	NSMutableArray<SSDragItem*> *items = NSMutableArray.array;
	static const float scale = kTurnControlItemsScale * 1.5;
	for (int i = 0; i < kNumArtics; ++i)
		[items addObject:[[SSDragItem alloc] initWithType:sscore_edit_typeforarticulation(kArtics[i]) scale:scale]];
	return createTurnControl(bottomLeft, width, items, (int)(items.count/2), scale);
}

static SSTurnControl *createTechTurnControl(CGPoint bottomLeft, float width)
{
	NSMutableArray<SSDragItem*> *items = NSMutableArray.array;
	static const float scale = kTurnControlItemsScale * 1.1;
	[items addObject:[[SSDragItem alloc] initWithType: sscore_edit_typefortechnical(sscore_edit_technical_harmonic,"") scale: scale]];
	[items addObject:[[SSDragItem alloc] initWithType: sscore_edit_typefortechnical(sscore_edit_technical_open_string,"") scale: scale]];
	[items addObject:[[SSDragItem alloc] initWithType:sscore_edit_typefortechnical(sscore_edit_technical_down_bow,"") scale:scale]];
	[items addObject:[[SSDragItem alloc] initWithType: sscore_edit_typefortechnical(sscore_edit_technical_up_bow,"") scale: scale]];
	[items addObject:[[SSDragItem alloc] initWithType: sscore_edit_typefortechnical(sscore_edit_technical_fingering,"1") scale: scale]];
	[items addObject:[[SSDragItem alloc] initWithType: sscore_edit_typefortechnical(sscore_edit_technical_fingering,"2") scale: scale]];
	[items addObject:[[SSDragItem alloc] initWithType: sscore_edit_typefortechnical(sscore_edit_technical_fingering,"3") scale: scale]];
	[items addObject:[[SSDragItem alloc] initWithType: sscore_edit_typefortechnical(sscore_edit_technical_fingering,"4") scale: scale]];
	[items addObject:[[SSDragItem alloc] initWithType: sscore_edit_typefortechnical(sscore_edit_technical_fingering,"5") scale: scale]];
	return createTurnControl(bottomLeft, width, items, 3, scale);
}

static SSTurnControl *createOrnamentsTurnControl(CGPoint bottomLeft, float width)
{
	NSMutableArray<SSDragItem*> *items = NSMutableArray.array;
	static const float scale = kTurnControlItemsScale * 1.5;
	for (int i = 0; i < kNumOrns; ++i)
		[items addObject:[[SSDragItem alloc] initWithType:sscore_edit_typeforornament(kOrns[i]) scale:scale]];
	return createTurnControl(bottomLeft, width, items, (int)(items.count/2), scale);
}

static SSTurnControl *createClefsTurnControl(CGPoint bottomLeft, float width)
{
	NSMutableArray<SSDragItem*> *items = NSMutableArray.array;
	static const float scale = kTurnControlItemsScale * 0.75;
	for (int i = 0; i < kNumClefs; ++i)
		[items addObject:[[SSDragItem alloc] initWithType:sscore_edit_typeforclef(kClefs[i], 0, sscore_edit_clef_shift_none) scale:scale]];
	return createTurnControl(bottomLeft, width, items, 1, scale);
}

static SSTurnControl *createAccidentalsTurnControl(CGPoint bottomLeft, float width)
{
	NSMutableArray<SSDragItem*> *items = NSMutableArray.array;
	static const float scale = kTurnControlItemsScale * 1.1;
	for (int i = 0; i < kNumAccidentals; ++i)
		[items addObject:[[SSDragItem alloc] initWithType:sscore_edit_typeforaccidental(kAccidentals[i]) scale:scale]];
	return createTurnControl(bottomLeft, width, items, (int)(items.count/2), scale);
}

-(NSArray *)placeTurnControls:(CGRect)frame systemBottom:(float)systemBottom
{
	// fit Turn Controls into available width
	float turnControlPitch = frame.size.width / kNumTurnControls;
	float turnControlWidth = fmax(turnControlPitch * kTurnControlWidthGapRatio, kTurnControlMinWidth); // default control uses 80% of available width
	float turnControlGap = turnControlPitch - turnControlWidth;
	if (turnControlGap < kTurnControlMinGap)
	{
		turnControlGap = kTurnControlMinGap;
		turnControlWidth = turnControlPitch - turnControlGap;
	}
	// place turn controls along the bottom
	NSMutableArray *controls = NSMutableArray.array;
	// bottom of turn controls is below system if possible but not below screen bottom
	CGPoint bl = CGPointMake(frame.origin.x + turnControlGap/2, fmin(systemBottom + kTurnControlHeight + turnControlGap, frame.origin.y+frame.size.height));
	SSTurnControl *tc = createClefsTurnControl(bl, turnControlWidth);
	[controls addObject:tc];
	[self addSubview:tc];
	bl.x += turnControlWidth + turnControlGap;
	tc = createDynamicsTurnControl(bl, turnControlWidth);
	[controls addObject:tc];
	[self addSubview:tc];
	bl.x += turnControlWidth + turnControlGap;
	tc = createArticTurnControl(bl, turnControlWidth);
	[controls addObject:tc];
	[self addSubview:tc];
	bl.x += turnControlWidth + turnControlGap;
	tc = createOrnamentsTurnControl(bl, turnControlWidth);
	[controls addObject:tc];
	[self addSubview:tc];
	bl.x += turnControlWidth + turnControlGap;
	tc = createTechTurnControl(bl, turnControlWidth);
	[controls addObject:tc];
	[self addSubview:tc];
	bl.x += turnControlWidth + turnControlGap;
	tc = createAccidentalsTurnControl(bl, turnControlWidth);
	[controls addObject:tc];
	[self addSubview:tc];
	return controls;
}

-(instancetype)initWithFrame:(CGRect)frame systemBottom:(float)systemBottom interface:(id<SSViewInterface>)ssViewInterf
{
	if (self = [super initWithFrame:frame])
	{
		ssView = ssViewInterf;
		self.opaque = false;
		self.clipsToBounds = true;
		[self registerForKeyboardNotifications];
		turnControls = [self placeTurnControls:frame systemBottom:systemBottom];
		editCursor = [[SSEditCursor alloc] init];
		[self.layer addSublayer:editCursor];
		editCursor.bounds = self.bounds;
	}
	return self;
}

-(UIView*)view
{
	return self;
}

-(void)clear
{
	[self deselectAll];
}

-(void)deselectAll
{
	if (deleteButton)
	{
		[deleteButton removeFromSuperview];
		deleteButton = nil;
	}
	[ssView deselectAll];
	selectedComponent = nil;
	[self setNeedsDisplay];
}


-(void)registerForKeyboardNotifications
{
	[NSNotificationCenter.defaultCenter addObserverForName:UIKeyboardDidShowNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notify) {
		
		// Called when the UIKeyboardDidShowNotification is sent.
		if (temporaryTextField != nil)
		{
			// If active text field is hidden by keyboard, scroll it so it's visible
			NSDictionary *info = notify.userInfo;
			NSValue *val = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
			[ssView warnShowingKeyboardRect:val.CGRectValue];
		}
	}];
	[NSNotificationCenter.defaultCenter addObserverForName:UIKeyboardWillHideNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notify) {
		// Called when the UIKeyboardWillHideNotification is sent
		[ssView warnHidingKeyboard];
	}];
}


-(void)selectComponent:(SSComponent*)comp
{
	selectedComponent = comp;
	CGPoint systemTopLeft = [ssView systemRect:editingSystem.index].origin;
	CGRect selRect = [self rectForComponent:selectedComponent systemTopLeft:systemTopLeft margin:2];
	CGPoint deleteButtonPos = {selRect.origin.x+selRect.size.width + [SSDeleteButtonView offset].x, selRect.origin.y+[SSDeleteButtonView offset].y};
	if (deleteButton == nil)
		deleteButton = [[SSDeleteButtonView alloc] initAt:deleteButtonPos];
	[deleteButton animate:self atCentre:deleteButtonPos];
	[self setNeedsDisplay];
}

-(SSDirectionTypeWords*)directionWordsAt:(SSSystem *)system pos:(CGPoint)posInSystem
{
	// get the closest words to this point
	SSComponent *directionComponent = [system nearestDirectionComponentAt:posInSystem type:sscore_dir_words maxDistance:40];
	if (directionComponent != nil)
	{
		SSDirectionType *directionType = [system directionTypeForComponent:directionComponent];
		assert(directionType);
		if (directionType.type == sscore_dir_words)
		{
			return (SSDirectionTypeWords*)directionType;
		}
	}
	return nil;
}

-(CGRect)rectForComponent:(SSComponent*)component systemTopLeft:(CGPoint)systemTopLeft margin:(float)margin
{
	CGRect rect = component.rect;
	return CGRectMake(rect.origin.x + systemTopLeft.x - margin, rect.origin.y + systemTopLeft.y - margin, rect.size.width + 2*margin, rect.size.height + 2*margin);
}

-(void)addOverlaidDirectionWordsTextFieldAt:(CGPoint)posInSystem system:(SSSystem*)system
{
	assert(ssView.score);
	assert(ssView);
	if (temporaryTextField != nil)
	{
		[temporaryTextField resignFirstResponder];
		[temporaryTextField removeFromSuperview];
		temporaryTextField = nil;
	}
	CGPoint systemTopLeft = [ssView systemRect:system.index].origin;
	// find any words direction at this point. If there is we edit it
	editingDirectionWords = [self directionWordsAt:editingSystem pos:posInSystem];
	
	CGRect rect;
	NSArray<SSComponent*> *comps = editingDirectionWords.components;
	if (comps.count > 0)
	{
		// cover component completely with Text Field
		rect = comps.firstObject.rect;
		rect = [self rectForComponent:comps.firstObject systemTopLeft:systemTopLeft margin:1]; // allow margin to ensure complete coverage
		rect.size.width += 20;
	}
	else
	{
		static const float kTextFieldWidth = 200; // arbitrary
		static const float kTextFieldHeight = 30;
		rect = CGRectMake(posInSystem.x + systemTopLeft.x, posInSystem.y + systemTopLeft.y - kTextFieldHeight, kTextFieldWidth, kTextFieldHeight);
	}
	UITextField *textField = [[UITextField alloc] initWithFrame:rect];
	textField.text = editingDirectionWords != nil ? editingDirectionWords.words : @"Words";
	float points = editingDirectionWords.pointSize;
	float fontSize = [editingSystem pointsToFontSize:(points > 0) ? points : kDefaultFontSize];

	if (editingDirectionWords.bold && editingDirectionWords.italic)
	{
		textField.font = [UIFont fontWithName:@"Georgia-BoldItalic" size:fontSize];
	}
	else if (editingDirectionWords.bold)
	{
		textField.font = [UIFont fontWithName:@"Georgia-Bold" size:fontSize];
	}
	else if (editingDirectionWords.italic)
	{
		textField.font = [UIFont fontWithName:@"Georgia-Italic" size:fontSize];
	}
	else
	{
		textField.font = [UIFont fontWithName:@"Georgia" size:fontSize];
	}
	[textField becomeFirstResponder];
	textField.delegate = self;
	[self addSubview:textField]; // THIS CALL CAN TAKE MANY SECONDS, but only when debugging on real hardware and only the first time. Probably loading the keyboard
	textField.backgroundColor = [UIColor colorWithRed:.8 green:.8 blue:0.9 alpha:0.9];
	temporaryTextField = textField;
	[ssView ensureVisible:rect]; // scroll to make this visible
}


-(void)abortTextInput
{
	if (temporaryTextField != nil)
	{
		[temporaryTextField resignFirstResponder];
		[temporaryTextField removeFromSuperview];
		temporaryTextField = nil;
	}
}

-(SSComponent*)nearestNoteComponentAt:(CGPoint)pos
{
	SSSystemPoint sysPt = [ssView systemAtPos:pos];
	SSSystem *system = [ssView systemAtIndex:sysPt.systemIndex];
	return [system nearestNoteComponentAt:sysPt.posInSystem maxDistance:500];
}

-(bool)insertDirectionWords:(NSString*)words atNote:(SSComponent *)noteComponent
					  where:(enum sscore_system_stafflocation_e)vloc
				   fontInfo:(const sscore_edit_fontinfo*)finfo
{
	assert(ssView.score);
	sscore_component note = noteComponent.rawcomponent;
	sscore_edit_insertinfo insertInfo = sscore_edit_gettextinsertinfo(ssView.score.rawscore, &note, vloc, words.UTF8String, sscore_edit_tt_undefined, finfo);
	SSSystem *system = [ssView systemContainingBarIndex:noteComponent.barIndex];
	sscore_component comp = noteComponent.rawcomponent;
	sscore_edit_targetlocation target = sscore_edit_targetlocationfornotecomponent(system.rawsystem, &comp);
	return sscore_edit_insertitem(ssView.score.rawscore, &insertInfo, &target);
}

- (void)drawRect:(CGRect)rect
{
	//[super drawRect:rect]; // not needed
	CGContextRef ctx = UIGraphicsGetCurrentContext();
#ifdef ShowOverlay
	CGContextSetFillColorWithColor (ctx, [UIColor colorWithWhite:0.4F alpha:0.4F].CGColor);
	CGContextFillRect (ctx, rect);
	CGContextSetStrokeColorWithColor (ctx, UIColor.greenColor.CGColor);
	CGContextStrokeRect(ctx, rect);
#endif
	CGPoint systemTopLeft = [ssView systemRect:editingSystem.index].origin;
	if (selectedComponent)
	{
		CGRect selRect = [self rectForComponent:selectedComponent systemTopLeft:systemTopLeft margin:2];
		CGContextSetStrokeColorWithColor (ctx, UIColor.orangeColor.CGColor);
		CGContextStrokeRect(ctx, selRect);
		CGPoint deleteButtonOffset = [SSDeleteButtonView offset];
		CGPoint deleteButtonPos = {selRect.origin.x+selRect.size.width + deleteButtonOffset.x, selRect.origin.y+deleteButtonOffset.y};
		CGPoint p[2];
		p[0] = CGPointMake(selRect.origin.x+selRect.size.width, selRect.origin.y);
		p[1] = deleteButtonPos;
		CGContextStrokeLineSegments(ctx, p, 2);
	}
	if (draggingItem)
	{
		CGPoint activePos = [editCursor activePosForFinger:dragFingerPos];
		sscore_edit_type editType = draggingItem.itemType;
		[editingSystem drawDragItem:ctx itemType:&editType pos:activePos];
	}
}

static CGPoint centre(CGRect r)
{
	return CGPointMake(r.origin.x + r.size.width/2, r.origin.y + r.size.height/2);
}

-(bool)deletableComponent:(SSComponent *)comp
{
	switch (comp.type)
	{
		case sscore_comp_note_stem: // dont select stem etc because we don't allow delete
		case sscore_comp_note_dots:
		case sscore_comp_lyric:
		case sscore_comp_ledgers:
		case sscore_comp_beamgroup:
		case sscore_comp_beam:
		case sscore_comp_timesig:
		case sscore_comp_keysig:
		case sscore_comp_clef:		return false;
			
		default: return true;
	}
}

-(void)tap:(CGPoint)pos
{
	for (SSTurnControl *tc in turnControls) // ignore tap in turn controls
	{
		if (CGRectContainsPoint(tc.frame, pos))
		{
			return;
		}
	}
	SSSystemPoint sysPt = [ssView systemAtPos:pos];
	editingSystem = [ssView systemAtIndex:sysPt.systemIndex];
	if (deleteButton)
	{
		if (distance_sq(centre(deleteButton.frame), pos) < kMaxHitButtonDistance_sq)
		{
			/*bool deleted =*/ [editingSystem deleteItem:selectedComponent];
			//if (deleted)
		}
		// could use 2 beeps for succeed and fail - animate button if failed?
		[deleteButton removeFromSuperview];
		deleteButton = nil;
		[self deselectAll];
		[self abortTextInput];
		[self setNeedsDisplay];
	}
	else // tap to select item?
	{
		static const float kMaxHitDistance = 40;
		NSArray<SSComponent*> *components = [ssView componentsAt:pos maxDistance:kMaxHitDistance];
		for (int i = 0; i < components.count; ++i) // closest first
		{
			SSComponent *comp = [components objectAtIndex:i];
			if ([self deletableComponent:comp])			{
				[self selectComponent:comp];
				if (comp.type == sscore_comp_direction_text)
					[self addOverlaidDirectionWordsTextFieldAt:sysPt.posInSystem system:editingSystem]; // this will edit the text in the component
				else
					[self abortTextInput];
				return;
			}
		}
		// can add direction words with tap if nothing was hit
		{
			enum sscore_system_stafflocation_e yloc = [editingSystem staffLocationForYPos:sysPt.posInSystem.y];
			if (yloc == sscore_system_staffloc_above)
			{
				// if the tap is above the staff and is not near anything then assume we are expecting to add text - we place a text field
				sscore_edit_type wordsType = sscore_edit_typefordirectionwords(sscore_edit_tt_undefined);
				SSTargetLocation *target = [editingSystem nearestInsertTargetFor:&wordsType at:sysPt.posInSystem max:kMaxTargetDistance];
				CGPoint textInsertPos =  target.insertPos;
				[self addOverlaidDirectionWordsTextFieldAt:textInsertPos system:editingSystem];
			}
		}
	}
}

// we can avoid the expensive sqrt
static float distance_sq(CGPoint p1, CGPoint p2)
{
	float x = p1.x - p2.x;
	float y = p1.y - p2.y;
	return x*x + y*y;
}

-(void)updateDrag:(SSDragItem*)ditem pos:(CGPoint)pos
{
	SSSystemPoint sysPt = [ssView systemAtPos:pos];
	CGRect systemRect = [ssView systemRect:sysPt.systemIndex];
	if (pos.y > 0 && pos.y < systemRect.origin.y + systemRect.size.height)
	{
		SSSystem *system = [ssView systemAtIndex:sysPt.systemIndex];
		sscore_edit_type itemType = ditem.itemType;
		
		SSTargetLocation *target = [system nearestInsertTargetFor:&itemType at:sysPt.posInSystem max:kMaxTargetDistance];
		if (target)
		{
			CGPoint systemInsertPos = target.insertPos;
			if (systemInsertPos.x > 0 && distance_sq(systemInsertPos, sysPt.posInSystem) <= kMaxTargetDistance_sq)
			{
				CGPoint nearestInsertPos = CGPointMake(systemInsertPos.x + systemRect.origin.x, systemInsertPos.y + systemRect.origin.y);
				[editCursor showNearestTarget:nearestInsertPos];
				return;
			}
		}
	}
	[editCursor noTarget];
}

-(bool)endDrag:(SSDragItem*)ditem pos:(CGPoint)pos
{
	SSSystemPoint sysPt = [ssView systemAtPos:pos];
	CGRect systemRect = [ssView systemRect:sysPt.systemIndex];
	if (pos.y > systemRect.origin.y && pos.y < systemRect.origin.y + systemRect.size.height)
	{
		SSSystem *system = [ssView systemAtIndex:sysPt.systemIndex];
		sscore_edit_type itemType = ditem.itemType;
		
		SSTargetLocation *target = [system nearestInsertTargetFor:&itemType at:sysPt.posInSystem max:kMaxTargetDistance];
		if (target)
		{
			CGPoint systemInsertPos = target.insertPos;
			if (systemInsertPos.x > 0 && distance_sq(systemInsertPos, sysPt.posInSystem) <= kMaxTargetDistance_sq)
			{
				sscore_edit_insertinfo insertInfo = sscore_edit_getinsertinfo(ssView.score.rawscore, &itemType, nil);
				return [system tryInsertItem:&insertInfo at:target];
			}
		}
	}
	return false; // ignore drop outside target range
}

// called while dragging
- (void)pan:(UIGestureRecognizer *)panReco
{
	switch (panReco.state)
	{
		case UIGestureRecognizerStatePossible:
			break;

		case UIGestureRecognizerStateBegan:
		{
			draggingFromControl = nil;
			for (SSTurnControl *tc in turnControls)
			{
				if ([tc hit:panReco])
				{
					draggingFromControl = tc;
					break;
				}
			}
			if (draggingFromControl)
			{
				draggingItem = [draggingFromControl pan:panReco];
				if (draggingItem)
				{
					
					[editCursor startDrag:dragFingerPos draggingItem:draggingItem];
					dragFingerPos = [panReco locationInView:self];
					return;
				}
			}
		}
		case UIGestureRecognizerStateChanged:
		{
			if (draggingFromControl)
			{
				[draggingFromControl pan:panReco];
			}
			if (draggingItem)
			{
				dragFingerPos = [panReco locationInView:self];
				[editCursor updateDrag:dragFingerPos];
				CGPoint activePoint = [editCursor activePosForFinger:dragFingerPos];
				[self updateDrag:draggingItem pos:activePoint];
			}
		}break;
			
		case UIGestureRecognizerStateEnded:
		{
			if (draggingItem)
			{
				// get cursor active point from finger point
				dragFingerPos = [panReco locationInView:self];
				CGPoint activePoint = [editCursor activePosForFinger:dragFingerPos];
				[self endDrag:draggingItem pos:activePoint];
				[editCursor endDrag:dragFingerPos];
			}
		} // .. fall thru ..
		case UIGestureRecognizerStateCancelled:
		case UIGestureRecognizerStateFailed:
		{
			if (draggingFromControl)
			{
				[draggingFromControl pan:panReco];
			}
			if (draggingItem)
				[self setNeedsDisplay];
			draggingItem = nil;
			draggingFromControl = nil;
		}break;
	}
}

//@protocol UITextFieldDelegate <NSObject>

/*- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField        // return NO to disallow editing.
- (void)textFieldDidBeginEditing:(UITextField *)textField           // became first responder
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField          // return YES to allow editing to stop and to resign first responder status. NO to disallow the editing session to end
- (void)textFieldDidEndEditing:(UITextField *)textField             // may be called if forced even if shouldEndEditing returns NO (e.g. view removed from window) or endEditing:YES called
*/

- (BOOL)textFieldShouldReturn:(UITextField *)textField      // called when 'return' key pressed. return NO to ignore.
{
	[self deselectAll];
	bool rval = false;
	if (editingDirectionWords != nil) // modify existing text
	{
		if (textField.text.length == 0)
		{
			// remove existing text
			[editingSystem deleteDirectionType:editingDirectionWords];
		}
		else // modify existing text
		{
			editingDirectionWords.words = textField.text; // writing to SSDirectionTypeWords.words changes the score
		}
	}
	else if (textField.text.length > 0) // insert new text
	{
		SSComponent *note = [self nearestNoteComponentAt:textField.frame.origin];
		rval = [self insertDirectionWords:textField.text atNote:note where:clickedStaffLocation fontInfo:nil];
	}
	[textField resignFirstResponder];
	[textField removeFromSuperview];
	temporaryTextField = nil;
	return rval;
}

@end