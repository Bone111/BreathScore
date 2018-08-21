ReadMe
------
SeeScoreLib SDK for iOS

This release provides:

* The SeeScore library for iOS providing support for rendering of MusicXML in a Core Graphics CGContext with a simple Objective-C interface (SSScore and SSSystem) in a modern iOS framework SeeScoreLib.framework

* The SSPData class interface for play data - information about playing the score

* The SSSynth class for the built-in synthesizer which uses the play data to play the score with sampled instruments, and includes metronome support, and support for events eg to drive a cursor

* SSScrollView (+SSSystemView) which is a drop-in scrollable view for displaying the music score in a MusicXML file for simple incorporation into any iOS app. For many applications this is all a developer will need.

* The SeeScoreIOS sample project which builds an app using SSScrollView. This provides a starting point for a developer wanting to use SSScrollView and the SeeScore library

* An evaluation licence key file evaluation_key.c which causes translucent red 'watermark' text to be displayed over the top of the score to prevent resale.
A licence key file can be purchased from Dolphin Computing to remove the watermark, and to enable other features. Details are in the documentation of the individual functions.
Some of these licenses are included in the evaluation version so the functions can be evaluated.
NB For evaluation of the synth it can be used without licence for 5 minutes after application start. Also there is a limit to the number of notes returned from the playdata when unlicensed


Documentation
-------------
Full documentation is in directory doc/


Using the SeeScoreLib.framework
-------------------------------
¥ Use the 'Copy Files' Build Phase to copy the SeeScoreLib.framework into the app with Destination "Frameworks".
¥ Apps should be developed using the SeeScoreLib/Universal/SeeScoreLib.framework which allows use of real iOS devices and the iOS simulator. For submission to the App Store the app should use SeeScoreLib/AppStore-Release/SeeScoreLib.framework which contains only device code. If you try to upload the universal framework you get several errors and it will fail.
¥ The sample project SeeScoreIOS.xcodeproj shows how you can setup a target and scheme for App Store release which uses the device-only release framework


Notes
-----
¥ All source code supplied may be used without any conditions attached, or any warranty implied.
¥ SeeScoreLib.framework must not be copied to a third party, but should always be sourced from Dolphin Computing. http://www.dolphin-com.co.uk
