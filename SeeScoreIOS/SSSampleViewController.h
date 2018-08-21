// 
//  SSSampleViewController.h
//  SeeScoreIOS
//
// No warranty is made as to the suitability of this for any purpose
//

#import <UIKit/UIKit.h>
#import "SSBarControl.h"
#import "SettingsViewController.h"
#import <SeeScoreLib/SeeScoreLib.h>
#import <AVFoundation/AVFoundation.h>

@class SSScrollView;

//Added
@protocol SETTINGS_DELEGATE

-(void)sendValue:(int)note onoff:(int)onoff;
-(void)setFilter:(int)index;
-(void)setRate:(float)value;
-(void)setThreshold:(float)value;
-(void)setBTTreshold:(float)value;
-(void)setBTBoost:(float)value;
@end

@interface SSSampleViewController : UIViewController <ChangeSettingsProtocol, SSSyControls, SSUTempo, ScoreChangeHandler, AVAudioPlayerDelegate>{



    int midiinhale;
    int midiexhale;
    int currentdirection;
    
    BOOL midiIsOn;


}

@property (readonly) SSScore *score;
@property (strong, nonatomic) IBOutlet SSBarControl *barControl;
@property (strong, nonatomic) IBOutlet SSScrollView *sysScrollView;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *transposeLabel;
@property (strong, nonatomic) IBOutlet UIStepper *stepper;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *playButton;
@property (strong, nonatomic) IBOutlet UILabel *countInLabel;
@property (strong, nonatomic) IBOutlet UILabel *warningLabel;
@property (strong, nonatomic) IBOutlet UISlider *tempoSlider;
@property (strong, nonatomic) IBOutlet UILabel *tempoLabel;
@property (strong, nonatomic) IBOutlet UISwitch *metronomeSwitch;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *nextFileButton;
@property int cursorBarIndex;
@property (strong, nonatomic) IBOutlet UISwitch *ignoreXMLLayoutSwitch;
@property (strong, nonatomic) IBOutlet UILabel *versionLabel;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *L_label;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *R_label;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *leftLoopButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *rightLoopButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *editButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *undoButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *redoButton;
@property (readonly) bool isEditMode;

@property (weak, nonatomic) IBOutlet UIImageView *imageButton;


-(bool)isNetworkAvailable;

- (IBAction)longPress:(id)sender;
- (IBAction)loadNextFile:(id)sender;
- (IBAction)transpose:(id)sender;
- (IBAction)play:(id)sender;
- (IBAction)tempoChanged:(id)sender;
- (IBAction)metronomeSwitched:(id)sender;
- (IBAction)switchIgnoreLayout:(id)sender;
- (IBAction)tapR:(UIBarButtonItem *)sender;
- (IBAction)tapL:(UIBarButtonItem *)sender;
- (IBAction)save:(UIBarButtonItem *)sender;

-(void)stopPlaying;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *dropdownOpen;


- (IBAction)dropDown:(id)sender;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *settingsButton;

@property (weak, nonatomic) IBOutlet UIButton *myOpenDropdown;
@property (weak, nonatomic) IBOutlet UIToolbar *myToolbar;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (weak, nonatomic) IBOutlet UIButton *myOpenDropdownButton;
- (IBAction)openDDButton:(id)sender;
-(void)colourPDNotes:(NSArray*)notes; // array of SSPDNote*
@property (weak, nonatomic) IBOutlet UIBarButtonItem *toggleDropDown;
@property (weak, nonatomic) IBOutlet UIProgressView *breathGauge;
@property (weak, nonatomic) IBOutlet UITableView *myTable;
@property (weak, nonatomic) IBOutlet UIImageView *myBluetoothStatusBar;
@property (weak, nonatomic) IBOutlet UISlider *thresholdSliderUnit;
@property (weak, nonatomic) IBOutlet UIButton *thresholdSliderButton;
- (IBAction)toggleDropDownWindow:(id)sender;
- (IBAction)cueDropDown:(id)sender;

-(NSArray*) findDocumentItemURLs;

@property (weak, nonatomic) IBOutlet UIImageView *myBluetoothStatusImage;

- (IBAction)thresholdToggle:(id)sender;

- (IBAction)myThresholdSlider:(id)sender;

- (void) saveFloatToUserDefaults:(float)x forKey:(NSString *)key;

-(float) loadFloatFromUserDefaultsForKey:(NSString *)key;

-(NSArray *)getXmlList;

-(void)readXmlListfromURL:(NSArray*)list;

-(void)readXMLfromBundle;

-(void)addXMLtoDocumentsFromURL: (NSString*)item;

-(void)loadFileAfterSelect: (NSString* )filename;

- (void) addToListFromDocuments: (NSArray*)list;


//ADDED

-(void)background;
-(void)foreground;

@end
