
//
//  SSSampleViewController.m
//  SeeScoreIOS
//
// No warranty is made as to the suitability of this for any purpose
//

#define UseNoteCursor // define this to make the cursor move to each note as it plays, else it moves to the current bar
//#define PrintPlayData // define this to print play data in the console when play is pressed
#define ColourPlayedNotes // define this to colour played notes green
#define ColourTappedItem // define this to colour any item tapped in the score for 0.5s
//#define PrintXMLForTappedBar // define this to print the XML for the bar in the console (contents licence needed)
#import <SystemConfiguration/SCNetworkReachability.h>
#import "SSSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "SSScrollView.h"
#import "InfoViewController.h"
#import "SettingsViewController.h"
#import "SSEditLayer.h"
#import "BTLEManager.h"
#include "sscore_key.h"
#include <dispatch/dispatch.h>

static const float kDefaultMagnification = 2.0F;    //was 1 ADDED BY BRIAN
static const float kEditMagnification = 1.3F;
static const float kMinTempoScaling = 0.3;
static const float kMaxTempoScaling = 3.0;
static const int kMinTempo = 10;
static const int kMaxTempo = 360;
static const int kDefaultTempo = 80;
static const float kStartPlayDelay = 1.0;//s ATTACK CHANGED FROM 80// decayt was 200//over;lap 20
static const float kRestartDelay = 0.2;//s

#define kMaxSampledInstruments 10 // cannot use const int in array de

static const sscore_sy_sampledinstrumentinfo kSampledInstrumentsInfo[] = {
	//	name,		baseFile,	extn,	lowestMidi, numFiles,	volume, attack_ms, decay_ms, overlap_ms, names,							pitch_offset, instrument family,					flags, extrasamples);
	//{"Piano",	"Piano.mf", "m4a",		23,		86,			1.0,	4,			10,			10,			"piano,pianoforte,klavier",				0,	sscore_sy_instrumentfamily_hammeredstring,	0,		0,		{0}},
	//{"Violin",	"violin",	"m4a",		55,		44,			1.0,	150,		600,		480,		"violin,violon,violine,violino,geige",	0,	sscore_sy_instrumentfamily_bowedstring,		0,		0,		{0}},
	//{"Viola",	"viola",	"m4a",		48,		44,			1.0,	100,		600,		480,		"viola,viole,bratsche", 0, sscore_sy_instrumentfamily_bowedstring, 0,0, {0}},
	//{"Cello",	"cello",	"m4a",		36,		48,			1.0,	150,		600,		480,		"cello,\'cello,violoncello,violoncelle", 0, sscore_sy_instrumentfamily_bowedstring, 0,0, {0}},
	{"Flute",	"flute.nonvib.mf", "wav",	50, 38,			1.0,	4,			10,		15,			"flute,flauto", 0, sscore_sy_instrumentfamily_woodwind, 0,0,  {0}},
	//{"Guitar", "guitar",	"m4a",		48,		24,			1.0,	4,			200,		10,			"guitar,guitare,gitarre,chitarra", 0, sscore_sy_instrumentfamily_pluckedstring, 0,0, {0}}
	//{"Trumpet", "Trumpet.novib.mf",	"m4a",		52,		35,			1.0,	4,			200,		10,			"trumpet", 0, sscore_sy_instrumentfamily_brass, 0,0, {0}}
};
static const int kNumSampledInstruments = sizeof(kSampledInstrumentsInfo)/sizeof(*kSampledInstrumentsInfo);
// 3 metronome ticks are currently supported (tickpitch = 0, 1 or 2):
static const sscore_sy_synthesizedinstrumentinfo kTick1Info = {"Tick1", 0, 1.0};

static float limit(float val, int min, int max)
{
	if (val < min)
		return min;
	else if (val > max)
		return max;
	else
		return val;
}

@interface SSSampleViewController ()<BTLEManagerDelegate, NSURLSessionDelegate, NSXMLParserDelegate, UITableViewDelegate, UITableViewDataSource>
{
	SSScore *score;
	UIPopoverController *popover;
	UITapGestureRecognizer *tapRecognizer;
	UILongPressGestureRecognizer *pressRecognizer;
	UIPanGestureRecognizer *panRecognizer;
	
	bool showingSinglePart; // is set when a single part is being displayed
	int showingSinglePartIndex;
	
	NSMutableArray *showingParts;
	SSLayoutOptions *layOptions; // set of options for layout
	
	NSString *currentFilePath;
	int loadFileIndex; // increment to load next file in directory
	
	SSPData *playData;
	SSSynth *synth;
	
	unsigned instrumentId[kMaxSampledInstruments];
	unsigned metronomeInstrumentId;
	
	bool rEnabled;
	bool lEnabled;
	
	int loopStartBarIndex; // -1 for non-looping
	int loopEndBarIndex;
	
	bool editMode;
    
    //ADDED
    UITableView *firstTableView;
    UITableView *secondTableView;
    IBOutlet UITableView *myOutlet;
    CGFloat myInhaleThresholdMaxValue;
    CGFloat myExhaleThresholdMaxValue;
    NSMutableArray *myDataSource;
    NSArray *myDataSourceNoDuplicates;
    
    //CGFloat _currentInhaleValue;
    //CGFloat _currentExhaleValue;
    
    BOOL *allowNextNote;
    
}

// text for tapping beat instructions
@property (strong, nonatomic) IBOutlet UILabel *beatTapLabel;

@property sscore_changehandler_id changeHandlerId;

-(void)moveNoteCursor:(NSArray*)notes;

@property(nonatomic,strong)UIImageView  *btOnOfImageView;
@property(nonatomic,strong)BTLEManager  *btleMager;


@end

bool triggeredPlayButton = true;
int myCurrentBar = 0;
NSMutableArray *URLArray;
long _exhalethresholdValue = 0.5;
long _inhalethresholdValue = 0.2;
BOOL _exhaleTriggerToggle = true;
BOOL playAll = false;
BOOL triggerNextBar = true;
BOOL triggerNextNote = true;
BOOL paused = false;
BOOL _disallowNextNote = false;

BOOL _disallowNextExhale = false;
BOOL _disallowNextInhale = false;

int currentBarIndex = 0;
int myCurrentNoteNumber = 0;
float _lowestInhaleValue = 1;
float _lowestExhaleValue = 1;

CGFloat _currentInhaleValue;
CGFloat _currentExhaleValue;

CGFloat _lastInhaleVale;
CGFloat _lastExhaleVale;


/********** Event Handlers ***********/

@interface BarChangeHandler : NSObject <SSEventHandler>
{
	SSSampleViewController *svc;
	int lastIndex;
}
@end

@implementation BarChangeHandler

-(instancetype)initWith:(SSSampleViewController *)vc
{
	self = [super init];
	if (self)
	{
		svc = vc;
		lastIndex=-100;
	}
	return self;
}

-(void)event:(int)index countIn:(bool)countIn
{
#ifdef ColourPlayedNotes

    index = myCurrentBar;

	bool startRepeat = index < lastIndex;
	
    if (startRepeat)
	{
		sscore_barrange br;
		br.startbarindex = index;
		br.numbars = svc.score.numBars - index;
		[svc.sysScrollView clearColouringForBarRange:&br];
        NSLog(@"colouring function");
	}
#endif
#ifdef UseNoteCursor
	//[svc.sysScrollView setCursorAtBar:index type:cursor_line scroll:scroll_bar];
#else
	//[svc.sysScrollView setCursorAtBar:index
							  type:(countIn) ? cursor_line : cursor_rect
							scroll:scroll_bar];
#endif
	svc.cursorBarIndex = index;
	lastIndex = index;
    
    if(index == 0){
        
        NSLog(@"bar index xhange %d", index);
       [svc.sysScrollView clearAllColouring];
    }
    
}
@end

@interface BeatHandler : NSObject <SSEventHandler>
{ SSSampleViewController *svc; }
@end

@implementation BeatHandler

-(instancetype)initWith:(SSSampleViewController *)vc
{
	self = [super init];
	if (self)
	{ svc = vc;	}
	return self;
}

-(void)event:(int)index countIn:(bool)countIn
{
	svc.countInLabel.hidden = !countIn;
	if (countIn)
		svc.countInLabel.text = [NSString stringWithFormat:@"%d", index + 1]; // show count-in
}
@end

@interface EndHandler : NSObject <SSEventHandler>
{ SSSampleViewController *svc; }
@end

@implementation EndHandler

-(instancetype)initWith:(SSSampleViewController *)vc
{
	self = [super init];
	if (self)
	{ svc = vc;	}
	return self;
}

-(void)event:(int)index countIn:(bool)countIn
{
	[svc.sysScrollView hideCursor];
	svc.countInLabel.hidden = true;
	svc.cursorBarIndex = 0;
	[svc stopPlaying];
    
    UIImage *image = [UIImage imageNamed: @"playbuttonTINY.png"];
    [svc.playButton setImage:image];
    
    
#ifdef ColourPlayedNotes
	[svc.sysScrollView clearAllColouring];
#endif
}
@end

@interface NoteHandler : NSObject <SSNoteHandler>
{ SSSampleViewController *svc; }
@end

@implementation NoteHandler

-(instancetype)initWith:(SSSampleViewController *)vc
{
	self = [super init];
	if (self)
	{ svc = vc;}
	return self;
}

-(void)startNotes:(NSArray *)pnotes
{
    
	assert(pnotes.count > 0);
//	[svc moveNoteCursor:pnotes];
#ifdef ColourPlayedNotes
	// convert array of SSPDPartNote to array of SSPDNote
	NSMutableArray *notes = NSMutableArray.array;
    for (SSPDPartNote *n in pnotes){
	///	[notes addObject:n.note];
        [svc colourPDNotes:notes];
             [notes addObject:n.note];
    }
    [svc moveNoteCursor:pnotes];
    [svc colourPDNotes:notes];
    
#endif
}

-(void) endNote:(SSPDPartNote *)note
{

   
}
@end


@implementation SSSampleViewController

+(NSString*)defaultDirectoryPath
{
	NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return [searchPaths objectAtIndex: 0];
}

+(NSString*)copyBundleFileToDocuments:(NSURL *)srcURL
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *urls = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
	NSURL *dstURL = [[urls objectAtIndex:0] URLByAppendingPathComponent:[srcURL lastPathComponent]];
	NSError *error;
	[fileManager copyItemAtURL:srcURL
						 toURL:dstURL
						 error:&error];
	return [dstURL path];
}

-(bool)loadableFile:(NSString*)filename
{
	return ([[filename pathExtension] isEqualToString:@"xml"]
			||[[filename pathExtension] isEqualToString:@"mxl"]);
}

#pragma mark -Audio Session Route Change Notification

- (void)handleRouteChange:(NSNotification *)notification
{
	UInt8 reasonValue = [[notification.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey] intValue];
	//AVAudioSessionRouteDescription *routeDescription = [notification.userInfo valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
	
	switch (reasonValue) {
		case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
			if (synth && synth.isPlaying)
				[synth reset];
			break;
	}
}

-(bool)setupAudioSession
{
	NSError *error = nil;
	
	// Configure the audio session
	AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
	
	// our default category -- we change this for conversion and playback appropriately
	[sessionInstance setCategory:AVAudioSessionCategoryPlayback error:&error];
	if (error.code != 0)
		return false;// couldn't set audio category
	
	NSTimeInterval bufferDuration = .005;
	[sessionInstance setPreferredIOBufferDuration:bufferDuration error:&error];
	if (error.code != 0)
		return false;// couldn't set IOBufferDuration
	
	double hwSampleRate = 44100.0;
	[sessionInstance setPreferredSampleRate:hwSampleRate error:&error];
	if (error.code != 0)
		return false;// couldn't set preferred sample rate
	
	// add interruption handler
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleInterruption:)
												 name:AVAudioSessionInterruptionNotification
											   object:sessionInstance];
	
	// we don't do anything special in the route change notification
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleRouteChange:)
												 name:AVAudioSessionRouteChangeNotification
											   object:sessionInstance];
	
	// activate the audio session
	[sessionInstance setActive:YES error:&error];
	if (error.code != 0)
		return false;// couldn't set audio session active

	return YES;
}

-(void)clearAudioSession
{
	AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	NSError *error = nil;
	[sessionInstance setActive:NO error:&error];
}

-(bool)isNetworkAvailable
{
   // NSLog(@"Checking network");
    SCNetworkReachabilityFlags flags;
    SCNetworkReachabilityRef address;
    address = SCNetworkReachabilityCreateWithName(NULL, "www.apple.com" );
    //NSLog(@"Checking network  address %@", address);
    Boolean success = SCNetworkReachabilityGetFlags(address, &flags);
   // NSLog(@"Checking network success %hhu", success);
    CFRelease(address);
    
    bool canReach = success
    && !(flags & kSCNetworkReachabilityFlagsConnectionRequired)
    && (flags & kSCNetworkReachabilityFlagsReachable);

    return canReach;
}

- (void)viewDidLoad
{

    NSLog(@"Splashing");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3]];
    
    _currentExhaleValue = 0.5;
    _currentInhaleValue = 0.5;
    paused = false;
    
    _currentInhaleValue = [self loadFloatFromUserDefaultsForKey:@"_currentInhaleValue"];
     _currentExhaleValue = [self loadFloatFromUserDefaultsForKey:@"_currentExhaleValue"];
    
    myDataSource = [[NSMutableArray alloc] init];
    [super viewDidLoad];
	editMode = false;
	rEnabled = lEnabled = true;
	layOptions = [[SSLayoutOptions alloc] init];
	showingSinglePart = false;
	showingSinglePartIndex = 0;
	self.sysScrollView.scrollDelegate = self.barControl;
	tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap)];
	[self.sysScrollView addGestureRecognizer:tapRecognizer];
	pressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
	[self.sysScrollView addGestureRecognizer:pressRecognizer];
	panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
	// PAN RECOGNISER DISABLES SCROLL! Don't enable it until needed for edit
	panRecognizer.enabled = false;
	[self.sysScrollView addGestureRecognizer:panRecognizer];
	loadFileIndex = 0;
	self.cursorBarIndex = 0;
	//[self loadNextFile:nil];
	sscore_version version = [SSScore version];
	self.versionLabel.text = [NSString stringWithFormat:@"SeeScore V%d.%02d", version.major, version.minor];
	// test setting of background colour programmatically
	self.sysScrollView.backgroundColor = [UIColor colorWithRed:1.F green:1.F blue:0.95F alpha:1.F];
	loopStartBarIndex = loopEndBarIndex = -1;
	_tempoSlider.enabled = true;
	_leftLoopButton.enabled = false;
	_rightLoopButton.enabled = false;
	self.undoButton.enabled = false;
	self.redoButton.enabled = false;
	self.editButton.enabled = false;
    
    //ADDED
    _exhaleTriggerToggle = true;
     self.tempoLabel.hidden = true;
    
    [self.thresholdSliderButton setImage:[UIImage imageNamed:@"EXHALEButton.png"] forState:UIControlStateNormal];
    ///[[self.thresholdSliderButton imageView] setContentMode: UIViewContentModeScaleAspectFit];
    [self.thresholdSliderButton  setContentMode:UIViewContentModeCenter];
    
    [_leftLoopButton setEnabled:NO];
    [_leftLoopButton setTintColor: [UIColor clearColor]];
    
    [_rightLoopButton setEnabled:NO];
    [_rightLoopButton setTintColor: [UIColor clearColor]];
    
    [self.undoButton setEnabled:NO];
    [self.undoButton setTintColor: [UIColor clearColor]];
    
    [self.redoButton setEnabled:NO];
    [self.redoButton setTintColor: [UIColor clearColor]];
    
    [self.editButton setEnabled:NO];
    [self.editButton setTintColor: [UIColor clearColor]];
    
    [self.saveButton setEnabled:NO];
    [self.saveButton setTintColor: [UIColor clearColor]];
    
    [self.settingsButton setEnabled:NO];
    [self.settingsButton setTintColor: [UIColor clearColor]];
    
    [self.L_label setEnabled:NO];
    [self.L_label setTintColor: [UIColor clearColor]];
    
    [self.R_label setEnabled:NO];
    [self.R_label setTintColor: [UIColor clearColor]];
    
    [self.nextFileButton setEnabled:NO];
    [self.nextFileButton setTintColor: [UIColor clearColor]];
    
    self.nextFileButton.enabled = NO;
    self.R_label.enabled = NO;
    self.L_label.enabled = NO;
    
    triggeredPlayButton = false;
    myInhaleThresholdMaxValue = 0.5;
    myExhaleThresholdMaxValue = 0.5;
    
    self.btleMager=[BTLEManager new];
    self.btleMager.delegate=self;
    
    [self.btleMager startWithDeviceName:@"GroovTube 2.0" andPollInterval:0.035]; //was .035
    
    UIImage *image = [UIImage imageNamed: @"BlueToothDisconnected.png"];
    [self.myBluetoothStatusImage setImage:image];
    self.myBluetoothStatusImage.contentMode = UIViewContentModeCenter;
    
    self.thresholdSliderButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.thresholdSliderButton.frame = CGRectMake(40, 140, 240, 30);
    [self.thresholdSliderButton setTitle:@"vc2:v1" forState:UIControlStateNormal];
    [self.thresholdSliderButton addTarget:self action:@selector(goToOne) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.thresholdSliderButton];

    self.thresholdSliderUnit.minimumValue = 0;
    self.thresholdSliderUnit.maximumValue = 1;
    
    _disallowNextExhale = false;
    _disallowNextInhale = false;
    
    
     self.thresholdSliderUnit.value = _currentExhaleValue;
    
     self.breathGauge.progress = 0;
    
    [self.myOpenDropdownButton setTitle:@"Tap to select song..." forState:UIControlStateNormal];
   
     self.myOpenDropdownButton.font = [UIFont fontWithName:@"Helvetica" size:25.0f];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appplicationIsActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationEnteredForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    if([self isNetworkAvailable] == true)
    {
        NSLog(@"Network available. Checking online for Scores..");
        [self readXmlListfromURL: [self getXmlList]];
        // [self addToListFromDocuments: [self getXmlList] ];
    }else{
        NSLog(@"Network unavailable. ");
        
    }
    
     NSLog(@"Creating list. ");
    [self addToListFromDocuments: 0];
    
    firstTableView=[[UITableView alloc]init];
    firstTableView.frame = CGRectMake(20,74,320,250);
    firstTableView.dataSource=self;
    firstTableView.delegate=self;
    [firstTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [firstTableView reloadData];
    firstTableView.hidden=true;
    [self.view addSubview:firstTableView];
    
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    

}

- (void) saveFloatToUserDefaults:(float)x forKey:(NSString *)key {
    NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setFloat:x forKey:key];
    [userDefaults synchronize];
}


-(float) loadFloatFromUserDefaultsForKey:(NSString *)key {
    NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults floatForKey:key];
}


- (void)applicationFinishedRestoringState:(UIApplication *)application{
    
    [super applicationFinishedRestoringState];
    
    NSLog(@"Restored State!");
}


- (void)appplicationIsActive:(NSNotification *)notification {
   // NSLog(@"Application Did Become Active");
}

- (void)applicationEnteredForeground:(NSNotification *)notification {
    NSLog(@"Application Entered Foreground");
   
    //myDataSource = NULL;
    [myDataSource removeAllObjects];
    
    if( [self isNetworkAvailable] == true )
    {
        NSLog(@"Network available. Checking online for Scores..");
        [self readXmlListfromURL: [self getXmlList]];
    }else{
        NSLog(@"Network unavailable. Compiling list from existing scores.");
    }
    
    [self addToListFromDocuments: 0 ];
    firstTableView.dataSource=self;
    [firstTableView reloadData];
    firstTableView.hidden=true;
}



- (void)view:(UIApplication *)application{
    
    [super applicationFinishedRestoringState];
    
    NSLog(@"Restored State!");
    
}


- (void)viewWillDisappear:(BOOL)animated
{
	[self.sysScrollView abortBackgroundProcessing:^{
		[self.sysScrollView clearAll];
		score = nil;
	}];
}

-(void)dealloc
{
	if (editMode && score)
		[score removeChangeHandler:self.changeHandlerId];
	[self clearAudioSession];
	score = nil;
}


- (IBAction)changeDirection:(id)sender {

    myInhaleThresholdMaxValue = .5;
    myExhaleThresholdMaxValue = .5;
    
    if (_exhaleTriggerToggle == false){

        self.thresholdSliderUnit.value = _currentExhaleValue;
        self.breathGauge.progress = 0;
        _exhaleTriggerToggle = true;
        [sender setImage:[UIImage imageNamed:@"EXHALEButton.png"] forState:UIControlStateNormal];
        [[sender imageView] setContentMode: UIViewContentModeScaleAspectFit];
        NSLog(@"Trigger set to exhale , %f", myExhaleThresholdMaxValue );
        
    }else if (_exhaleTriggerToggle == true){

        self.breathGauge.progress = 0;
        self.thresholdSliderUnit.value = _currentInhaleValue;
        _exhaleTriggerToggle = false;
        [sender setImage:[UIImage imageNamed:@"INHALEButton.png"] forState:UIControlStateNormal];
        [[sender imageView] setContentMode: UIViewContentModeScaleAspectFit];
        NSLog(@"Trigger set to inhale , %f", myInhaleThresholdMaxValue);
    }
}

-(SSScore*)score
{
	return score;
}

-(bool)isEditMode
{
	return editMode;
}

-(void)clearPlayLoop
{
	loopEndBarIndex = loopStartBarIndex = -1;
	[self.sysScrollView clearPlayLoopGraphics];
	if (playData)
		[playData clearLoop];
}

-(void)setupTempoUI
{
	if (score)
	{
		if (score.scoreHasDefinedTempo)
		{
			self.tempoSlider.minimumValue = kMinTempoScaling;
			self.tempoSlider.maximumValue = kMaxTempoScaling;
			self.tempoSlider.value = 1.0F;
			sscore_pd_tempo tempo = score.tempoAtStart;
			if (tempo.bpm > 0)
				self.tempoLabel.text = [NSString stringWithFormat:@"%1.0f", self.tempoSlider.value * tempo.bpm];
			else
				self.tempoLabel.text = [NSString stringWithFormat:@"%1.1f", self.tempoSlider.value];
		}
		else
		{
			self.tempoSlider.minimumValue = kMinTempo;
			self.tempoSlider.maximumValue = kMaxTempo;
			self.tempoSlider.value = kDefaultTempo;
			self.tempoLabel.text = [NSString stringWithFormat:@"%d", (int)self.tempoSlider.value];
		}
		self.tempoSlider.enabled = true;
	}
	else
		self.tempoSlider.enabled = false;
}

-(void)loadFile:(NSString*)filePath
{
    myCurrentBar = 0;
    myCurrentNoteNumber = 0;
    
	editMode = false;
	panRecognizer.enabled = false;
	[self clearPlayLoop];
	if (synth)
		[synth reset];
	synth = nil; // synth has to be recreated for a new file
	bool loadable = [self loadableFile:filePath];
	bool readable = [[NSFileManager defaultManager] isReadableFileAtPath:filePath];
	if (loadable && readable)
	{
		currentFilePath = filePath;
		self.beatTapLabel.hidden = true;
		self.sysScrollView.hidden = false;
		[self.sysScrollView abortBackgroundProcessing:^{ // empty dispatch queues
			[self.sysScrollView clearAll];
			score = nil;
			[self.ignoreXMLLayoutSwitch setOn:NO animated:NO];
			self.stepper.value = 0;
			self.transposeLabel.text = [NSString stringWithFormat:@"%+d", 0];
			showingSinglePart = false;
			showingSinglePartIndex = 0;
			[showingParts removeAllObjects];
			self.cursorBarIndex = 0;
			SSLoadOptions *loadOptions = [[SSLoadOptions alloc] initWithKey:sscore_libkey];
			loadOptions.checkxml = true;
			sscore_loaderror err;
			score = [SSScore scoreWithXMLFile:filePath options:loadOptions error:&err];
			
			if (score)
			{
				self.titleLabel.text = [filePath lastPathComponent];
				int numParts = score.numParts;
				showingParts = [NSMutableArray arrayWithCapacity:numParts];
				for (int i = 0; i < numParts; ++i)
				{
					[showingParts addObject:[NSNumber numberWithBool:YES]];// display all parts
				}
				[self.sysScrollView setupScore:score openParts:showingParts mag:kDefaultMagnification opt:layOptions];
				self.barControl.delegate = self.sysScrollView;
				[self enableButtons];
				[self setupTempoUI];
			}
			else
			{
				switch (err.err)
				{
					case sscore_OutOfMemoryError:	NSLog(@"out of memory");break;
						
					case sscore_XMLValidationError:
						NSLog(@"XML validation error line:%d col:%d %s", err.line, err.col, err.text?err.text:"");
						break;
						
					case sscore_NoBarsInFileError:	NSLog(@"No bars in file error");break;
					case sscore_NoPartsError:		NSLog(@"NoParts Error"); break;
					default:
					case sscore_UnknownError:		NSLog(@"Unknown error");break;
				}
			}
		}];
	}
	[self enableButtons];
	[self setupTempoUI];
}

-(NSURL *)findMatchingFilename:(NSString*)filename from:(NSArray<NSURL*> *)fileUrls
{
	for (NSURL *url in fileUrls)
	{
		if ([filename.stringByDeletingPathExtension compare:url.lastPathComponent.stringByDeletingPathExtension] == NSOrderedSame)
		{
			return url;
		}
	}
	return nil;
}

- (IBAction)loadNextFile:(id)sender
{
    //[self stopPlaying];
	//NSArray *sampleMXLFileUrls = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"mxl" subdirectory:@""];
	///NSArray *sampleXMLFileUrls = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"xml" subdirectory:@""];
	//NSMutableArray *sampleFileUrls = NSMutableArray.array;
	//[sampleFileUrls addObjectsFromArray:sampleXMLFileUrls];
	//[sampleFileUrls addObjectsFromArray:sampleMXLFileUrls];
	//NSURL *loadSampleUrl = sampleFileUrls[loadFileIndex];
	//NSString *localFilePath = [SSSampleViewController copyBundleFileToDocuments:loadSampleUrl]; // copy sample file to Documents directory
	//[self loadFile:localFilePath];
	//++loadFileIndex;
	//if (loadFileIndex >= sampleFileUrls.count)
	//	loadFileIndex = 0;
    
    NSArray *sampleFileUrls = [self findDocumentItemURLs];
    NSURL *loadSampleUrl = sampleFileUrls[loadFileIndex];
    NSString *localFilePath = [SSSampleViewController copyBundleFileToDocuments:loadSampleUrl];
    
    NSString *theFileName = [[localFilePath lastPathComponent] stringByDeletingPathExtension];
    [self.myOpenDropdownButton setTitle:theFileName forState:UIControlStateNormal];
    [self loadFile:localFilePath];
    ++loadFileIndex;
    if (loadFileIndex >= sampleFileUrls.count)
        loadFileIndex = 0;
}

-(void)tap
{
	self.countInLabel.hidden = true;
	CGPoint p = [tapRecognizer locationInView:self.sysScrollView];
	[self.sysScrollView tap:p];
	if (!editMode)
	{
		int barIndex = [self.sysScrollView barIndexForPos:p];
		if (barIndex >= 0)
		{
			self.cursorBarIndex = barIndex;
			[self.sysScrollView setCursorAtBar:barIndex
										  type:cursor_rect
										scroll:scroll_bar];
		}
		else
			[self.sysScrollView hideCursor];
		
		if (barIndex >= 0)
		{
			int partIndex = [self.sysScrollView partIndexForPos:p];
#ifdef PrintXMLForTappedBar
			enum sscore_error err;
			NSString *xml = [score xmlForPart:partIndex bar:barIndex err:&err];
			if (xml.length > 0)
				//NSLog(@"XML for bar %@", xml);
#endif
			if (synth && synth.isPlaying)
			{
				dispatch_time_t playRestartTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kStartPlayDelay * NSEC_PER_SEC));
				[synth setNextBarToPlay:barIndex at:playRestartTime];
			}
			else
			{
#ifdef ColourTappedItem
				SSSystemPoint sysPt = [self.sysScrollView systemAtPos:p];
				SSSystem *sys = [self.sysScrollView systemAtIndex:sysPt.systemIndex];
				if (sys)
				{
					NSArray *components = [sys hitTest:sysPt.posInSystem];
					if (components.count > 0)
					{
						unsigned elementTypes = 0;
						SSComponent *comp = [components objectAtIndex:0];
						switch (comp.type)
						{
							case sscore_comp_clef:		elementTypes |= sscore_dopt_colour_clef; break;
							case sscore_comp_timesig:	elementTypes |= sscore_dopt_colour_timesig; break;
							case sscore_comp_keysig:	elementTypes |= sscore_dopt_colour_keysig; break;
							case sscore_comp_notehead:	elementTypes |= sscore_dopt_colour_notehead; break;
							case sscore_comp_accidental: elementTypes |= sscore_dopt_colour_accidental; break;
							case sscore_comp_note_stem:	elementTypes |= sscore_dopt_colour_stem; break;
							case sscore_comp_note_dots:	elementTypes |= sscore_dopt_colour_dot; break;
							case sscore_comp_lyric:		elementTypes |= sscore_dopt_colour_lyric; break;
							case sscore_comp_beam:
							case sscore_comp_beamgroup:	elementTypes |= sscore_dopt_colour_beam; break;
							default:					elementTypes |= sscore_dopt_colour_all; break;
						}
						[self.sysScrollView colourComponents:components colour:UIColor.cyanColor elementTypes:elementTypes];
						//  remove colour after 0.5s
						double delayInSeconds = 0.5;
						dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
						dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
							[self.sysScrollView clearAllColouring];
						});
					}
				}
#endif
			}
		}
	}
	[self enableButtons];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	[self clearPlayLoop];
	[self stopPlaying];
	if (popover)
	{
		[popover dismissPopoverAnimated:NO];
		popover = nil;
	}
	if ([segue.identifier isEqualToString:@"info"])
	{
		InfoViewController *ivc = (InfoViewController*)segue.destinationViewController;
		[ivc showHeaderInfo:score];
	}
	else if ([segue.identifier isEqualToString:@"settings"])
	{
		SettingsViewController *svc = (SettingsViewController*)segue.destinationViewController;
		[svc setPartNames:!layOptions.hidePartNames barNumbers:!layOptions.hideBarNumbers dlg:self];
	}
	if ([segue isKindOfClass:UIStoryboardPopoverSegue.class])
	{
		popover = ((UIStoryboardPopoverSegue *)segue).popoverController;
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)stopPlaying
{
	if (synth && synth.isPlaying)
	{
		[synth reset];
		self.countInLabel.hidden = true;
		[self clearAudioSession];
	}
}

-(void)pan:(UIGestureRecognizer*)gr
{
	[self.sysScrollView pan:gr];
}

- (IBAction)longPress:(id)sender {
    
	if (editMode)
	{
	}
	else
	{
		[self clearPlayLoop];
		[self stopPlaying];
		if (score && pressRecognizer.state == UIGestureRecognizerStateEnded)
		{
			if (showingSinglePart) // flip to showing all parts
			{
				showingSinglePart = false;
				showingParts = [NSMutableArray array];
				for (int i = 0; i < score.numParts; ++i)
				{
					[showingParts addObject:[NSNumber numberWithBool:YES]];
				}
				[self.sysScrollView displayParts:showingParts];
			}
			else // flip to showing a single part
			{
				CGPoint p = [pressRecognizer locationInView:self.sysScrollView];
				int partIndex = [self.sysScrollView partIndexForPos:p];
				if (partIndex >= 0)
				{
					assert(partIndex < score.numParts);
					showingParts = [NSMutableArray array];
					for (int i = 0; i < score.numParts; ++i)
					{
						[showingParts addObject:[NSNumber numberWithBool:(i == partIndex)]];
					}
					[self.sysScrollView displayParts:showingParts];
					showingSinglePart = true;
					showingSinglePartIndex = partIndex;
				}
			}
		}
	}
	[self enableButtons];
}

- (IBAction)transpose:(id)sender
{
	[self clearPlayLoop];
	[self stopPlaying];
	UIStepper *stepper = (UIStepper*)sender;
	if (stepper.value < -8) // demonstrate change treble clefs to bass clef for transpose more than 8 semitones down
	{
		sscore_tr_clefchangedef clefchange;
		memset(&clefchange, 0, sizeof(clefchange));
		clefchange.num = 1;
		clefchange.staffchange[0].partindex = sscore_tr_kAllPartsPartIndex;
		clefchange.staffchange[0].staffindex = sscore_tr_kAllStaffsStaffIndex;
		clefchange.staffchange[0].conv.fromclef = sscore_tr_trebleclef;
		clefchange.staffchange[0].conv.toclef = sscore_tr_bassclef;
		sscore_tr_setclefchange(score.rawscore, &clefchange);
	}
	else
		sscore_tr_clearclefchange(score.rawscore);
	[score setTranspose:stepper.value];
	self.transposeLabel.text = [NSString stringWithFormat:@"%+d", score.transpose];
	[self.sysScrollView setLayoutOptions:layOptions];
}

// return xpos of centre of notehead of note or 0
-(float)noteXPos:(SSPDNote*)note
{
	SSSystem *system = [self.sysScrollView systemContainingBarIndex:note.startBarIndex];
	if (system)
	{
		NSArray *comps = [system componentsForItem:note.item_h];
		// find centre of notehead or rest
		for (SSComponent *comp in comps)
		{
			if (comp.type == sscore_comp_notehead
				|| comp.type == sscore_comp_rest)
			{
				return comp.rect.origin.x + comp.rect.size.width / 2;
			}
		}
		return 0;
	}
	else
		return 0;
}

-(void)moveNoteCursor:(NSArray*)notes
{
    
  //  NSLog(@"move note cursor");
    
    if (synth.isPlaying == true){
        UIImage *image = [UIImage imageNamed: @"pausebuttonTINY.png"];
        [self.playButton setImage:image];
    }
    
	for (SSPDPartNote *note in notes) // normally this will not need to iterate over the whole chord, but will exit as soon as it has a valid xpos
	{
		if (note.note.midiPitch > 0 && note.note.start >= 0) // priority given to notes over rests, but ignore cross-bar tied notes
		{
			float xpos = [self noteXPos:note.note];
			if (xpos > 0) // noteXPos returns 0 if the note isn't found in the layout (it might be in a part which is not shown)
			{
				[self.sysScrollView setCursorAtXpos:xpos barIndex:note.note.startBarIndex scroll:scroll_bar];

				return; // abandon iteration
			}
		}
	}
	for (SSPDPartNote *note in notes) // if no note found then we move to a rest
	{
		if (note.note.midiPitch == 0) // rest
		{
			float xpos = [self noteXPos:note.note];
			if (xpos > 0) // noteXPos returns 0 if the note isn't found in the layout (it might be in a part which is not shown)
			{
				[self.sysScrollView setCursorAtXpos:xpos barIndex:note.note.startBarIndex scroll:scroll_bar];
                self->allowNextNote = false;
				return; // abandon iteration
			}
		}
	}
}

-(int)numBars
{
	return score.numBars;
}



-(void)colourPDNotes:(NSArray*)notes
{
	UIColor *kPlayedNoteColour = [UIColor colorWithRed:0 green:1 blue:0 alpha:1];// green
	[self.sysScrollView colourPDNotes:notes colour:kPlayedNoteColour];
}


-(void)displaynotes:(SSPData*)pd
{
#ifdef PrintPlayData
	for (SSPDBar *bar in playData.bars)
	{
		NSLog(@"bar %d: %dms", bar.index, bar.duration_ms);
		for (int partIndex = 0; partIndex < score.numParts; ++partIndex)
		{
			SSPDPart *part = [bar part:partIndex];
			for (SSPDNote *note in part.notes)
			{
				NSLog(@"part %d %s pitch:%d startbar:%d start:%dms duration:%dms at x=%1.0f",
					  partIndex, note.grace?"grace":"note",
					  note.midiPitch, note.startBarIndex,
					  note.start, note.duration,
					  [self noteXPos:note]);
			}
		}
	}
#endif
}

-(void)error:(NSString*)message
{
	self.warningLabel.text = message;
	self.warningLabel.hidden = (message.length == 0);
}

- (IBAction)play:(id)sender {
	[self error:@""]; // clear any error message
    
    playAll = false;
    
    if (sender != nil ){
        playAll = true;
        
        NSLog(@"Attempting to play all");
        self.cursorBarIndex = 0;
        myCurrentBar = 0;
        myCurrentNoteNumber = 0;
    }
        
    if (synth.isPlaying == true && playAll == true){
        
        [self stopPlaying];

        
        UIImage *image = [UIImage imageNamed: @"playbuttonTINY.png"];
                 [self.playButton setImage:image];
        
        [self.sysScrollView clearAllColouring];
       
        NSLog(@"Stopped Playing");
    
    }else{
    
       [self stopPlaying];
        
        self.countInLabel.hidden = true;
	
    if (score )
	{
#ifdef ColourPlayedNotes
		[self.sysScrollView clearAllColouring];
#endif

			if (!synth)
			{
				synth = [SSSynth createSynth:self score:score];
				if (synth)
				{
					for (int i = 0; i < kNumSampledInstruments; ++i)
					{
						assert(i < kMaxSampledInstruments);
						instrumentId[i] = [synth addSampledInstrument:&kSampledInstrumentsInfo[i]];
					}
					//metronomeInstrumentId = [synth addSynthesizedInstrument:&kTick1Info]; ///METRONOME TURNED OFF HERE
				}
			}
			if (synth) // start playing if not playing
			{
				if ([self setupAudioSession])
				{
                    /// NSLog(@"sscore %@", [score xmlForPart:0 bar:0 handle:106 err:nil]);
                    self.cursorBarIndex = myCurrentBar;
                    SSBarGroup *mine = [score barContentsForPart:0 bar:myCurrentBar err:nil];
                    NSArray *itemArray = [mine items];
                    NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
                    
                    for (SSDisplayedItem *item in itemArray){
                        if (!(item.type == 1 || item.type == 2)){
                           // NSLog(@"Removing %u ", item.type);
                        }else{
                            [mutableArray addObject: item];
                        }
                    }
        
                    
                    SSDisplayedItem *currentNote = mutableArray[myCurrentNoteNumber];
                
                        if (playAll == true){
                            NSLog(@"Playing all");
                        
                            playData = [SSPData createPlayDataFromScore:score tempo:self];
                        }else if ((playAll == false && currentNote.type == 1) || (playAll == false && currentNote.type == 2) || (playAll == false && currentNote.type == 3)){
                            
                            //NSLog(@"Playing single part");
                            playData = [SSPData createSingleChordPlayData:score part:0 bar:myCurrentBar note: currentNote.item_h];
                            
                            UIColor *kPlayedNoteColour = [UIColor colorWithRed:0 green:1 blue:0 alpha:1];// green
                            [self.sysScrollView colourPDNotesSecondFunction:currentNote.item_h colour:kPlayedNoteColour startBar: myCurrentBar];
                            
                            SSSystem *system = [self.sysScrollView systemContainingBarIndex:myCurrentBar];
                            if (system)
                            {
                                NSArray *comps = [system componentsForItem:currentNote.item_h];
                                for (SSComponent *comp in comps)
                                {
                                    if (comp.type == sscore_comp_notehead
                                        || comp.type == sscore_comp_rest)
                                    {
                                        // return comp.rect.origin.x + comp.rect.size.width / 2;
                                        [self.sysScrollView setCursorAtXpos: (comp.rect.origin.x + comp.rect.size.width / 2) barIndex:myCurrentBar      scroll:scroll_bar];
                                        break;
                                    }
                                }
                            }
                        }else if(score.numParts > 1){
                            NSLog(@"Score has too many parts");
                            
                            return;
                        }
                    
                            if (loopStartBarIndex >= 0 && loopEndBarIndex >= 0)
                            {
                                [playData setLoopStart:loopStartBarIndex loopBackBar:loopEndBarIndex numRepeats:10];
                                self.cursorBarIndex = loopStartBarIndex;
                            }
                            else
                                [playData clearLoop];
                            if (playData)
                            {
                                // display notes to play in console
                                [self displaynotes:playData];
                                // setup bar change notification to move cursor
                                int cursorAnimationTime_ms = [CATransaction animationDuration]*1000;
                                //[self.sysScrollView setCursorAtBar:self.cursorBarIndex type:cursor_line scroll:scroll_bar];
#ifdef UseNoteCursor
                                [synth setNoteHandler:[[NoteHandler alloc] initWith:self] delay:-cursorAnimationTime_ms];
#endif
                                [synth setBarChangeHandler:[[BarChangeHandler alloc] initWith:self] delay:-cursorAnimationTime_ms];
                                [synth setEndHandler:[[EndHandler alloc] initWith:self] delay:0];
                                //[synth setBeatHandler:[[BeatHandler alloc] initWith:self] delay:0];
                                    enum sscore_error err = [synth setup:playData];
                                
                               
                                
                                if (err == sscore_NoError)
                                {
                                    double delayInSeconds = 0.02; //was 2.0
                                    dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
							
                                    //ADDED - REMOVE COUNTIN
                                    // if (self.cursorBarIndex == 0){
                                    //     static const bool countIn = true;
                                    //     err = [synth startAt:startTime bar:self.cursorBarIndex countIn:countIn]; // start synth
                                    // }else{
                                        static const bool countIn = false;
                                        //NSLog(@"currentBar+1 %d", (myCurrentBar+1));
                                    
                                    if (score.numParts == 1){
                                    
                                        err = [synth startAt:startTime bar:(myCurrentBar) countIn:countIn]; // start synth
                                        
                                    }else{
                                    
                                        NSLog(@"Too many parts in xml file.");
                                    }
                                    
                                }
                                if (err == sscore_UnlicensedFunctionError)
                                {
                                    [self error:@"synth license expired!"];
                                }
                                else if (err != sscore_NoError)
                                {
                                    [self error:@"synth failed to start!"];
                                }
                        
                                myCurrentNoteNumber = myCurrentNoteNumber+1;
                                
                        if (myCurrentNoteNumber == ([mutableArray count])){
                            myCurrentBar++;
                            myCurrentNoteNumber = 0;
                            NSLog(@"Bar changed to %d ", myCurrentBar);
                        }
                        
                        if (myCurrentBar == score.numBars){
                            myCurrentBar = 0;
                            NSLog(@"Bar resetted to 0");
                        }
                        
					}
					else
						[self error:@"playdata is nil!"];
				}
			}
			else
				NSLog(@"No licence for synth");
		}
    }
	//}
}


- (IBAction)tempoChanged:(id)sender {
	UISlider *slider = (UISlider*)sender;
	if (score)
	{
		if (score.scoreHasDefinedTempo)
		{
			sscore_pd_tempo tempo = score.tempoAtStart;
			if (tempo.bpm > 0)
				self.tempoLabel.text = [NSString stringWithFormat:@"%1.0f", slider.value * tempo.bpm];
			else
				self.tempoLabel.text = [NSString stringWithFormat:@"%1.1f", slider.value];
		}
		else
			self.tempoLabel.text = [NSString stringWithFormat:@"%d", (int)slider.value];

		if (synth && synth.isPlaying)
		{
			dispatch_time_t playRestartTime = dispatch_time(DISPATCH_TIME_NOW, kRestartDelay*NSEC_PER_SEC);
            
			[synth updateTempoAt:playRestartTime];
		}
	}
}

- (IBAction)metronomeSwitched:(id)sender {
	if (synth && synth.isPlaying)
	{
		[synth changedControls];
	}
}

- (IBAction)switchInstrument:(id)sender {
	if (synth && synth.isPlaying)
	{
		[synth reset];
	}
}

- (IBAction)switchIgnoreLayout:(id)sender {
	[self clearPlayLoop];
	layOptions.ignoreXMLPositions = ((UISwitch*)sender).on;
	[self.sysScrollView setLayoutOptions:layOptions];
}

- (IBAction)tapR:(UIBarButtonItem *)sender {
	rEnabled = !rEnabled;
	self.R_label.tintColor = rEnabled ? UIColor.redColor : UIColor.whiteColor;
}

- (IBAction)tapL:(UIBarButtonItem *)sender {
	lEnabled = !lEnabled;
	self.L_label.tintColor = lEnabled ? UIColor.greenColor : UIColor.whiteColor;
}

- (IBAction)tapLRepeat:(UIBarButtonItem *)sender {
	if (self.sysScrollView.displayingCursor)
	{
		if (synth.isPlaying)
			[synth reset];
		if (loopStartBarIndex != self.sysScrollView.cursorBarIndex) {
			loopStartBarIndex = self.sysScrollView.cursorBarIndex;
			if (loopEndBarIndex < 0)
				loopEndBarIndex = score.numBars-1; // tap left with right undefined sets right to last bar
			[self.sysScrollView displayPlayLoopGraphicsLeft:loopStartBarIndex right:loopEndBarIndex];
			if (playData)
				[playData setLoopStart:loopStartBarIndex loopBackBar:loopEndBarIndex numRepeats:10];
		}
		else { // clear loop with 2nd tap on left bar
			[self clearPlayLoop];
		}
	}
}

- (IBAction)tapRRepeat:(UIBarButtonItem *)sender {
	if (self.sysScrollView.displayingCursor)
	{
		if (synth.isPlaying)
			[synth reset];
		if (loopEndBarIndex != self.sysScrollView.cursorBarIndex) {
			loopEndBarIndex = self.sysScrollView.cursorBarIndex;
			if (loopStartBarIndex < 0)
				loopStartBarIndex = 0; // tap right with left undefined sets left to first bar - reasonable default
			[self.sysScrollView displayPlayLoopGraphicsLeft:loopStartBarIndex right:loopEndBarIndex];
			if (playData)
				[playData setLoopStart:loopStartBarIndex loopBackBar:loopEndBarIndex numRepeats:10];
		}
		else { // clear loop with 2nd tap on right bar
			[self clearPlayLoop];
		}
	}
}

-(void)enableButtons
{
	_editButton.enabled = score && showingSinglePart;
	_nextFileButton.enabled = !editMode;
	_L_label.enabled = score && !editMode;
	_R_label.enabled = score && !editMode;
	_playButton.enabled = score && !editMode;
	_stepper.enabled = score && !editMode;
	_metronomeSwitch.enabled = score && !editMode;
	_ignoreXMLLayoutSwitch.enabled = score && !editMode;
	_leftLoopButton.enabled = score && !editMode;
	_rightLoopButton.enabled = score && !editMode;
	_undoButton.enabled = score && editMode && score.hasUndo;
	_redoButton.enabled = score && editMode && score.hasRedo;
	_leftLoopButton.enabled = !editMode && _sysScrollView.displayingCursor;
	_rightLoopButton.enabled = !editMode && _sysScrollView.displayingCursor;
}

-(void)installChangeHandler
{
	self.changeHandlerId = [score addChangeHandler:self];
}

-(void)uninstallChangeHandler
{
	[score removeChangeHandler:self.changeHandlerId];
}

// toggle edit mode IFF in single part display mode
- (IBAction)edit:(id)sender {
	if (showingSinglePart)
	{
		editMode = !editMode;
		panRecognizer.enabled = editMode; // enable pan only in edit mode (otherwise we cannot scroll)

		if (score)
		{
			if (editMode)
			{
				__block SSScrollView *block_sysScrollView = self.sysScrollView;
				__weak SSSampleViewController *weakSelf = self;
				[self.sysScrollView setEditMode:showingSinglePartIndex
								  startBarIndex:self.cursorBarIndex
											mag:editMode?kEditMagnification:kDefaultMagnification
								createEditLayer:^id<SSEditLayerProtocol>(CGRect frame, float systemBottom) {
									return [[SSEditLayer alloc] initWithFrame:frame systemBottom:systemBottom interface:block_sysScrollView];
								}
									 completion:^{
										 if (weakSelf)
											 [weakSelf installChangeHandler];
									 }];
			}
			else
			{
				[self uninstallChangeHandler];
				[self.sysScrollView clearEditMode];
			}
		}
		[self enableButtons];
	}
	else
	{
		editMode = false;
		[self enableButtons];
	}
}

- (IBAction)undo:(id)sender {
	if (score)
		[score undo];
}

- (IBAction)redo:(id)sender {
	if (score)
		[score redo];
}

- (IBAction)save:(UIBarButtonItem *)sender {
	NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDir = [searchPaths objectAtIndex: 0];
	enum sscore_error err = [score saveToFile:[NSString stringWithFormat:@"%@/%@", documentsDir, @"saved.xml"]];
	NSLog(@"err:%d", err);
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self.sysScrollView didRotate];
    
    NSLog(@"rotated %ld", (long)fromInterfaceOrientation);
    
    
    CGFloat tableHeight = [myDataSourceNoDuplicates count]*50;
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    //CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    CGFloat screenHeightThreeeQuarters = (screenRect.size.height/4)*2.6;
    
    if (tableHeight <= screenHeightThreeeQuarters){
        firstTableView.frame = CGRectMake(20,74,320, tableHeight);
    }else{
        firstTableView.frame = CGRectMake(20,74,320, screenHeightThreeeQuarters);
    }

	if (editMode) // restore edit mode
	{
		__block SSScrollView *block_sysScrollView = self.sysScrollView;
		[self.sysScrollView setEditMode:showingSinglePartIndex
						  startBarIndex:self.cursorBarIndex
									mag:kEditMagnification
						createEditLayer:^id<SSEditLayerProtocol>(CGRect frame, float systemBottom) {
							return [[SSEditLayer alloc] initWithFrame:frame systemBottom:systemBottom interface:block_sysScrollView];
                            
                                                       //NSLog(@"frame %@", frame);
						}
							 completion:^{}];
	}
}

-(void)showPartNames:(bool)pn
{
	[self clearPlayLoop];
	layOptions.hidePartNames = !pn;
	[self.sysScrollView setLayoutOptions:layOptions];
}

-(void)showBarNumbers:(bool)bn
{
	[self clearPlayLoop];
	layOptions.hideBarNumbers = !bn;
	[self.sysScrollView setLayoutOptions:layOptions];
}


//@protocol SSSyControls
/*
 SynthControlsImpl is the interface between the synth and the UI elements which control
 instruments for parts and metronome
 */
-(bool)partEnabled:(int)partIndex
{
	return showingSinglePart ? partIndex==showingSinglePartIndex : true;
}

-(unsigned)partInstrument:(int)partIndex
{
	return instrumentId[0]; // we can return any other instrument here
}

-(float)partVolume:(int)partIndex
{
	return 1.0;
}

-(bool)metronomeEnabled
{
	return self.metronomeSwitch.on;
}

-(unsigned)metronomeInstrument
{
	return metronomeInstrumentId;
}

-(float)metronomeVolume
{
	return 1.0;
}

//optional
-(bool)partStaffEnabled:(int)partIndex staff:(int)staffIndex
{
	return (staffIndex == 0) ? rEnabled : lEnabled;
}

-(int)loopStartIndex
{
	return loopStartBarIndex;
}

-(int)loopEndIndex
{
	return loopEndBarIndex;
}

-(int)loopRepeats
{
	return loopStartBarIndex >= 0 && loopEndBarIndex >= 0 ? 10 : 0; // return 0 when not looping
}

//@end

//@protocol SSUTempo <NSObject>

-(int)bpm
{
	return limit(self.tempoSlider.value, kMinTempo, kMaxTempo);
}

-(float)tempoScaling
{
	return limit(self.tempoSlider.value, kMinTempoScaling, kMaxTempoScaling);
}

//@end

//@protocol ScoreChangeHandler

-(void)change:(sscore_state_container *)prev newstate:(sscore_state_container *)newstate reason:(int)reason
{
	if (score)
	{
		_undoButton.enabled = score.hasUndo;
		_redoButton.enabled = score.hasRedo;
	}
	
}

///////// CUSTOM FUNCTIONS //////

- (void)loadFileAfterSelect:(NSString*)filename{
    
    [self stopPlaying];

    UIImage *image = [UIImage imageNamed: @"playbuttonTINY.png"];
    [self.playButton setImage:image];
    
    NSArray *sampleFileUrls = [self findDocumentItemURLs];
    NSURL *loadSampleUrl = NULL;
    
    for (NSInteger c = 0; c < [sampleFileUrls count]; c++){
       
        NSString *urlasstring = [sampleFileUrls[c] path];
        NSRange range = [urlasstring rangeOfString:@"Documents/"];
        NSString *substring = [[urlasstring substringFromIndex:NSMaxRange(range)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        NSCharacterSet *set = [NSCharacterSet URLHostAllowedCharacterSet];
        NSString *newstring = [substring stringByAddingPercentEncodingWithAllowedCharacters:set];
        newstring = [[newstring stringByReplacingOccurrencesOfString:@"%20"
                                                withString:@" "] mutableCopy];
        
        filename = [filename stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        filename = [filename stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        
        if ([substring isEqual:filename ]){

                loadSampleUrl = sampleFileUrls[c];
                NSString *localFilePath = [SSSampleViewController copyBundleFileToDocuments:loadSampleUrl]; // copy
                NSString *theFileName = [[localFilePath lastPathComponent]// 67
                                         stringByDeletingPathExtension];
                [self.myOpenDropdownButton setTitle:theFileName forState:UIControlStateNormal];
                
                [self loadFile:localFilePath];
                
            break;
        }
    }
}

- (NSArray*) findDocumentItemURLs {
    
    NSMutableArray *sampleFileUrls = [[NSMutableArray alloc] init];
    NSArray *paths1 = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    NSString *documentsDirectory = [paths1 objectAtIndex:0];
    NSArray *directoryContents = [fileMgr contentsOfDirectoryAtPath:documentsDirectory error:nil];
    NSString *item;
    
    for (item in directoryContents){
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentsURL = [paths lastObject];
        NSURL *bUrl = [documentsURL URLByAppendingPathComponent:item];
        NSString *path = [bUrl absoluteString];
        path = [[path stringByReplacingOccurrencesOfString:@"%0D"
                                                withString:@""] mutableCopy];
        NSURL *url = [NSURL URLWithString:path];
        [sampleFileUrls addObject:url];
    }
    
    NSArray *finalArray = [NSArray arrayWithArray:sampleFileUrls];
    return finalArray;
}

-(void)addXMLtoDocumentsFromURL: (NSString*)item{
    
    NSCharacterSet *set = [NSCharacterSet URLHostAllowedCharacterSet];
    NSString *newstring = [item stringByAddingPercentEncodingWithAllowedCharacters:set];
    
    NSString *queryString = [NSString stringWithFormat:@"http://breathscore.groovtube.nl/app/v1/%@", newstring];
    
    queryString = [[queryString stringByReplacingOccurrencesOfString:@"%0D"
                                                          withString:@""] mutableCopy];
    NSURL *selectedFileURL = [NSURL URLWithString:queryString];
    NSURLSessionDataTask *downloadTask = [[NSURLSession sharedSession]
                                          dataTaskWithURL:selectedFileURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                              
                                              if (data) {
                                                  
                    
                                                  NSArray   *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                                                  NSString  *documentsDirectory = [paths objectAtIndex:0];
                                                  
                                                  NSString *myNewFileName = [[newstring stringByReplacingOccurrencesOfString:@"%0D"
                                                                                                                  withString:@""] mutableCopy];
                                                  
                                                  NSString *mutableCopy = [[myNewFileName stringByReplacingOccurrencesOfString:@"%20"
                                                                                                                    withString:@" "] mutableCopy];
                                                  
                                                  NSString  *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory,mutableCopy];
                                                  
                                                  [data writeToFile:filePath atomically:YES];
                                                  
                                              }else{
                                                  NSLog(@"Error downloading %@, %@",item, error);
                                              }
                                          }];
    [downloadTask resume];

}

-(void)readXMLfromBundle{
    
    NSArray *bundleContents = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"xml" subdirectory:@""];
    
    NSArray *paths1 = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    NSString *documentsDirectory = [paths1 objectAtIndex:0];
    NSArray *directoryContents = [fileMgr contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    for (int i = 0; i < [bundleContents count]; i++){
        NSURL *thisPath = bundleContents[i];
        if (![directoryContents containsObject:bundleContents[i]] && [[thisPath pathExtension]isEqualToString:@"xml"]){
            [SSSampleViewController copyBundleFileToDocuments:thisPath];
            //NSLog(@"Bundle Item %@ added to documents folder", bundleContents[i]);
        }
    }
}


- (void) addToListFromDocuments: (NSArray*)list{
    
    NSArray *paths1 = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    NSString *documentsDirectory = [paths1 objectAtIndex:0];
    NSArray *directoryContents = [fileMgr contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    for (NSString* currentString in directoryContents){
        if (![myDataSource containsObject: currentString]){
            [myDataSource addObject: currentString];
        }
    }
}


-(void)readXmlListfromURL:(NSArray *)list{
    
    NSArray *paths1 = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    NSString *documentsDirectory = [paths1 objectAtIndex:0];
    NSArray *directoryContents = [fileMgr contentsOfDirectoryAtPath:documentsDirectory error:nil];
 
    for (int i = 0; i < [list count]; i++){
        
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentsURL = [paths lastObject];
        
        NSURL *bUrl = [documentsURL URLByAppendingPathComponent:list[i]];
        
        NSString *path = [bUrl absoluteString];
        path = [[path stringByReplacingOccurrencesOfString:@"%0D"
                                                withString:@""] mutableCopy];

        if (![directoryContents containsObject:list[i]]){
            [myDataSource addObject: list[i]];
            [self addXMLtoDocumentsFromURL: list[i]];
         //   NSLog(@"Adding to documents folder + list from URL %@",list[i]);
        }
    }
}

-(NSArray *)getXmlList {

    NSURL *url = [NSURL URLWithString:@"http://breathscore.groovtube.nl/app/v1/list.json"];
    NSString *text = [[NSString alloc] initWithContentsOfURL: url
                                                    encoding: NSUTF8StringEncoding
                                                       error: nil];
    
    NSData* jsonData = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray *items = [[NSMutableArray alloc] init];
    NSError *jsonError;
    NSDictionary *allKeys = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONWritingPrettyPrinted error:&jsonError];
    
    NSDictionary *xmlList= [allKeys objectForKey:@"file_list"];
    for (NSDictionary *key in xmlList) {
        NSString *name = [key objectForKey:@"name"];
        NSString *nameWithExtension = [name stringByAppendingString:@".xml"];        
       // NSLog(@"nameWe %@", nameWithExtension);
        [items addObject: nameWithExtension];
    }
    
    return items;
};

///////// TABLE VIEW STUFF ////////

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    NSMutableArray *temp = [[NSMutableArray alloc] init];
    for (NSString* elem in myDataSource){
       // NSString * newString = [elem stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSString *newerString = [[elem componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
        NSString *trimmedString = [newerString stringByTrimmingCharactersInSet:
                                   [NSCharacterSet whitespaceCharacterSet]];
        
        if (![trimmedString isEqualToString: @""]){
            [temp addObject: trimmedString];
        }
    }
    
    CGFloat tableHeight = [temp count]*50;
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    //CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    CGFloat screenHeightThreeeQuarters = (screenRect.size.height/4)*2.6;
    
    if (tableHeight <= screenHeightThreeeQuarters){
        firstTableView.frame = CGRectMake(20,74,320, tableHeight);
    }else{
        firstTableView.frame = CGRectMake(20,74,320, screenHeightThreeeQuarters);
    }

    myDataSourceNoDuplicates = [[NSSet setWithArray: temp] allObjects];

    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:
                             CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:
                UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSString *stringForCell;
    if (indexPath.section == 0) {
        stringForCell= [myDataSourceNoDuplicates objectAtIndex:indexPath.row];
    }
    else if (indexPath.section == 1){
        stringForCell= [myDataSourceNoDuplicates objectAtIndex:indexPath.row];
    }
 
    [cell.textLabel setText:stringForCell];
    [[cell textLabel] setFont:[UIFont fontWithName:@"Helvetica" size: 16.5]];
    
    return cell;
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    NSMutableArray *temp = [[NSMutableArray alloc] init];
    for (NSString* elem in myDataSource){
        //NSString * newString = [elem stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSString *newerString = [[elem componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
        NSString *trimmedString = [newerString stringByTrimmingCharactersInSet:
                                   [NSCharacterSet whitespaceCharacterSet]];
        if (![trimmedString isEqualToString: @""]){
            [temp addObject: trimmedString];
        }
    }
    
    myDataSourceNoDuplicates = [[NSSet setWithArray: temp] allObjects];
    int noOfElements = [myDataSourceNoDuplicates count];
    
    if (tableView == firstTableView) {
        return noOfElements;
    }else if (tableView == secondTableView) {
        return noOfElements;
    }else{
        
        return noOfElements;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0; //was 50
}

- (IBAction)openDDButton:(id)sender {
    
    if (firstTableView.hidden == true){
        firstTableView.hidden = false;}
    else if (firstTableView.hidden == false){
        firstTableView.hidden = true;
    }
    
    if (secondTableView.hidden == true){
        secondTableView.hidden = false;}
    else if (secondTableView.hidden == false){
        secondTableView.hidden = true;
    }
}

- (IBAction)dropDown:(id)sender{
    
    if (firstTableView.hidden == true){
        firstTableView.hidden = false;}
    else if (firstTableView.hidden == false){
        firstTableView.hidden = true;
    }
    
    if (secondTableView.hidden == true){
        secondTableView.hidden = false;}
    else if (secondTableView.hidden == false){
        secondTableView.hidden = true;
    }
    
}


- (IBAction)myThresholdSlider:(id)sender{
    
    NSLog(@"Value changed to %f", self.thresholdSliderUnit.value);
    
    if (sender == self.thresholdSliderUnit && _exhaleTriggerToggle == true) {
        _currentExhaleValue = self.thresholdSliderUnit.value;
        [self saveFloatToUserDefaults:_currentExhaleValue forKey:@"_currentExhaleValue"];
    }else if (sender == self.thresholdSliderUnit && _exhaleTriggerToggle == false){
        _currentInhaleValue = self.thresholdSliderUnit.value;
        [self saveFloatToUserDefaults:_currentInhaleValue forKey:@"_currentInhaleValue"];
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Selected row %@", indexPath);
    int row = (indexPath.row);
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *str = cell.textLabel.text;
    
    [self loadFileAfterSelect: str];
    firstTableView.hidden = true;
    secondTableView.hidden = true;
}


///ADDED BLUETOOTH STUFF////

-(void)btleManagerBreathBegan:(BTLEManager*)manager
{

}


-(void)btleManagerBreathStopped:(BTLEManager *)manager
{
   // NSLog(@"Breath Stopped");
    _disallowNextInhale = false;
    _disallowNextExhale = false;
    self.breathGauge.progress = 0;
}


-(void)btleManager:(BTLEManager*)manager inhaleWithValue:(float)percentOfmax{
    
   // NSLog(@"inhale perce %f", percentOfmax);
    
    if (percentOfmax < _lowestInhaleValue){
        _lowestInhaleValue = percentOfmax;
    }

    if (percentOfmax > (_lowestInhaleValue + 0.03)){
        self.breathGauge.progress = 0;
    }
    
    if (percentOfmax <= _currentInhaleValue){
        _disallowNextInhale = false;}
    
    float percentageValue = percentOfmax /_currentInhaleValue;
    self.breathGauge.progress = percentOfmax;
    
    if (_exhaleTriggerToggle == false){
         self.breathGauge.progress = percentageValue;
        
        float currentBreatheLevel = percentOfmax;
        
        if (currentBreatheLevel < self.thresholdSliderUnit.minimumValue){
            currentBreatheLevel = 0;
        }
    }
    
    if (percentOfmax >= _currentInhaleValue == 1 && _exhaleTriggerToggle == false && _disallowNextInhale == false){
        NSLog(@"VALID INHALE");        
         _disallowNextInhale = true;
        [self play:nil];
    }
}

-(void)btleManager:(BTLEManager*)manager exhaleWithValue:(float)percentOfmax
{

    if (percentOfmax < _lowestExhaleValue){
        _lowestExhaleValue = percentOfmax;
    }
    
    if (percentOfmax < (_lowestExhaleValue + 0.01)){
        self.breathGauge.progress = 0;
    }
    
    float percentageValue = percentOfmax /_currentExhaleValue;
    self.breathGauge.progress = percentageValue;
    
    if (percentOfmax <= _currentExhaleValue){
        _disallowNextExhale = false;
    }
    
    if (_exhaleTriggerToggle == true){
        self.breathGauge.progress = percentageValue;
        float currentBreatheLevel = percentOfmax;
        
        if (currentBreatheLevel < self.thresholdSliderUnit.minimumValue){
            currentBreatheLevel = 0;
        }
    }
    
    if (percentOfmax >= _currentExhaleValue == 1 && _exhaleTriggerToggle == true && _disallowNextExhale == false){
        NSLog(@"VALID EXHALE");
        _disallowNextExhale = true;
        [self play:nil];
    }
}

-(void)btleManagerConnected:(BTLEManager*)manager{
    
    UIImage *image = [UIImage imageNamed: @"BlueToothConnected.png"];
    NSLog(@"Bluetooth connected %@", image);
    [self.myBluetoothStatusImage setImage:image];
    self.myBluetoothStatusImage.contentMode = UIViewContentModeCenter;
}

-(void)btleManagerDisconnected:(BTLEManager*)manager{
    
    UIImage *image = [UIImage imageNamed: @"BlueToothDisconnected.png"];
    NSLog(@"Bluetooth disconnected %@", image);
    [self.myBluetoothStatusImage setImage:image];
    self.myBluetoothStatusImage.contentMode = UIViewContentModeCenter;
}

-(void)background
{
    self.btleMager.delegate=nil;
    self.btleMager=nil;
}

-(void)foreground
{
}


#pragma mark MIDI Output
- (IBAction) sendMidiData
{
    [self performSelectorInBackground:@selector(sendMidiDataInBackground) withObject:nil];
}
@end
