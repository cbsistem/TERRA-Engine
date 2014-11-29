//
//  Created by Sergio Flores on 3/3/11.


#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

#include "PascalImports.h"

#import "TERRA_AppDelegate.h"
#import "TERRA_Utils.h"
#import "TERRA_EAGLView.h"
#import "TERRA_InputController.h"
#import "TERRA_InAppPurchaseManager.h"
#import "TERRA_iCloudSync.h"
#import "TERRA_WebcamController.h"

#import "Flurry.h"

#import "SSKeychain.h"
#import <Security/Security.h>

#import "FBSettings.h"
#import "FBSession.h"
#import "FBRequestConnection.h"
#import "FBAppEvents.h"

#import "iCadeReaderView.h"
#import "iCadeState.h"


@implementation TERRA_AppDelegate

@synthesize window;
@synthesize glView;
@synthesize viewController;
@synthesize adBannerView;
@synthesize adMobView;
@synthesize iAPManager;

TERRA_AppDelegate *_delegate;

void ExcludeFileFromCloud(char *fileName)
{
	NSURL * fileURL;
	NSString* fileID = [NSString stringWithFormat:@"%s", fileName];
	fileURL = [ NSURL fileURLWithPath: fileID];
	[fileURL setResourceValue: [ NSNumber numberWithBool: YES ] forKey: NSURLIsExcludedFromBackupKey error: nil ];
}

int getCPUCores()
{
	return [[NSProcessInfo processInfo] processorCount];
}

bool isDeviceJailbroken()
{
	return [_delegate isJailbroken];
}

-(BOOL)isJailbroken
{
    NSURL* url = [NSURL URLWithString:@"cydia://package/com.example.package"];
    return [[UIApplication sharedApplication] canOpenURL:url];
}

void postToFacebook(char* msg, char *link, char* desc, char* image)
{
	if (!isSocialFrameworkAvailable())
	{
		ApplicationOnFacebookError();
		return;
	}
	
	NSString* mymsg = [NSString stringWithFormat:@"%s", msg];
	NSString* mylink = [NSString stringWithFormat:@"%s", link];
	NSString* mydesc = [NSString stringWithFormat:@"%s", desc];
	NSString* myimage = [NSString stringWithFormat:@"%s", image];

/*    NSArray *activityItems = @[mymsg, myimage, mylink];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]initWithActivityItems:activityItems applicationActivities:nil];
    [self presentViewController:activityVC animated:TRUE completion:nil];*/
    [_delegate postWithText:mymsg ImageName:myimage URL:mylink];
}

void iCloudSynchronize()
{
    NSLog(@"SYNCING iCLOUD!!!!!!!!");
	[iCloudSync start];				
}

bool m_postingInProgress = false;

+ (TERRA_AppDelegate*)getInstance
{
    return _delegate;
}

-(void) postWithText: (NSString*) message
           ImageName: (NSString*) image
                 URL: (NSString*) url
{
    
    NSMutableDictionary* params = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                   url, @"link",
                                   message, @"message",
                                   image, @"picture",
                                   nil];
    
    NSArray *permissions = FBSession.activeSession.permissions;
    if ([permissions indexOfObject:@"publish_actions"] == NSNotFound)
    {
        // No permissions found in session, ask for it
        FBSession *activeSession = FBSession.activeSession;
        [activeSession requestNewPublishPermissions: [NSArray arrayWithObject:@"publish_actions"]
                                              defaultAudience: FBSessionDefaultAudienceFriends
                                            completionHandler: ^(FBSession *session, NSError *error)
         {
             if (!error)
             {
                 // If permissions granted and not already posting then publish the story
                 if (!m_postingInProgress)
                 {
                     [self postToWall: params];
                 }
             }
         }];
    }
    else
    {
        // If permissions present and not already posting then publish the story
        if (!m_postingInProgress)
        {
            [self postToWall: params];
        }
    }
}

-(void) postToWall: (NSMutableDictionary*) params
{
    m_postingInProgress = YES; //for not allowing multiple hits
    
    [FBRequestConnection startWithGraphPath:@"me/feed"
                                 parameters:params
                                 HTTPMethod:@"POST"
                          completionHandler:^(FBRequestConnection *connection,
                                              id result,
                                              NSError *error)
     {
         if (error)
         {
             //showing an alert for failure
             /*UIAlertView *alertView = [[UIAlertView alloc]
                                       initWithTitle:@"Post Failed"
                                       message:error.localizedDescription
                                       delegate:nil
                                       cancelButtonTitle:@"OK"
                                       otherButtonTitles:nil];
             [alertView show];*/
			 ApplicationOnFacebookError();
         }
         else
             ApplicationOnFacebookPost();
             
         m_postingInProgress = NO;
     }];
}

UITextView *myTextView = NULL;

void focusKeyboard(char *s)
{
	if (myTextView == NULL)
	{
        CGRect r;
        r.origin.x = 0;
        r.origin.y = 0;
        r.size.width = 100;
        r.size.height = 100;
		myTextView  = [[[UITextView alloc] initWithFrame:r] autorelease];
        [_delegate.viewController.view addSubview:myTextView];
		myTextView.delegate = _delegate;
		[myTextView setHidden:true];
	}
	
//	NSString *text = [NSString stringWithFormat:@"%s", s];
//	[myTextView setText:text];
	
	[myTextView becomeFirstResponder];	
}


char deviceID[200];
char *getUniqueDeviceID()
{
	UIDevice *myDevice=[UIDevice currentDevice];
	NSString *UUID = NULL;
    
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
        UUID = [[myDevice identifierForVendor] UUIDString];
    } else {
        // This will run before iOS6
        
        //Use the bundle name as the App identifier. No need to get the localized version.
        NSString *Appname = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
        
        //Check if we have UUID already
        NSString *retrieveuuid = [SSKeychain passwordForService:Appname account:@"user"];
        
        if (retrieveuuid == NULL)
        {
            
            //Create new key for this app/device
            
            CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
            
            retrieveuuid = (__bridge_transfer NSString*)CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
            
            CFRelease(newUniqueId);
            
            //Save key to Keychain
            [SSKeychain setPassword:retrieveuuid forService:Appname account:@"user"];
        }
        
        UUID = retrieveuuid;
        
    }
	strcpy(deviceID, [UUID UTF8String]);
	return deviceID;
}


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    // Any new character added is passed in as the "text" parameter
    if ([text isEqualToString:@"\n"]) {
       // Be sure to test for equality using the "isEqualToString" message
        [textView resignFirstResponder];
 
        // Return FALSE so that the final '\n' character doesn't get added
        return FALSE;
    }
 
    if ([text isEqualToString:@""]) {
        ApplicationSendInput(8);
        return TRUE;
    }
    


    NSString *str = text;
    
    if (str!=NULL)
    {
        char buf[1024];
        strcpy(buf, [str UTF8String]);
        int len = strlen(buf);
        if (strstr(buf, "\b")!=NULL)
        {
            ApplicationSendInput(8);
            return TRUE;
        }
        else
        if (len>0)
        {
            ApplicationSendInput(buf[len-1]);
        }
    }
    
    // For any other character return TRUE so that the text gets added to the view
    return TRUE;
}



- (void)showIADView
{
    if (!iADSupported)
    {
        [self showAdMobView];
        return;
    }
    
    NSLog(@"Using iAD");

    if (_adMobViewController == NULL)
    {
        _iAdViewController = [[iAdViewController alloc] initWithContentViewController:self.viewController];
        self.window.rootViewController = _iAdViewController;
    }
}

- (void)showAdMobView
{
    NSLog(@"Using adMob");

    if (_adMobViewController == NULL)
    {
        _adMobViewController = [[AdMobViewController alloc] initWithContentViewController:self.viewController];
        self.window.rootViewController = _adMobViewController;
    }
    else
    {
        [_adMobViewController show];
    }
    
    [_adMobViewController startRequest];
}

- (void)hideAdMobView
{
    if (_adMobViewController != NULL)
    {
        NSLog(@"Hiding adMob");
        
        [_adMobViewController hide];
    }
}

- (void)createAdBannerView 
{	
	Class adClass = (NSClassFromString(@"ADBannerView"));
	if (adClass==nil) 
	{
		iADSupported = NO; 
		NSLog(@"iAd unavailable");
	} 
	else 
	{
		NSString   *countryCode = [[NSLocale currentLocale] objectForKey: NSLocaleCountryCode];
		NSArray *countryList = [[NSArray alloc] initWithObjects:@"US", @"FR",@"GB",@"IT",@"JP",@"ES",@"DE", nil]; 
		iADSupported = [countryList containsObject: countryCode];
	}


    ApplicationSetViewport(0, 0, [[UIScreen mainScreen]bounds].size.width - 25, [[UIScreen mainScreen]bounds].size.height);

	if (iADSupported)
    {
		[self showIADView];
    }
    else
    {
        [self showAdMobView];
    }
}

void showAds()
{
    [_delegate createAdBannerView];
}

- (UIViewController *)viewControllerForPresentingModalView 
{
	return self.viewController;
}

void initAppViews()
{
	[_delegate initViews];
}

void enableAVCapture()
{
    NSLog(@"Enabling SJITT!!!");
	[_delegate initVideo];
}

- (void)initVideo
{
    NSLog(@"EINIT VIDEO!!");
	WebcamController* av = [[WebcamController alloc] init];
    //[window addSubview:av.view];
}

bool isSimulator()
{
    return  ( 0 == strcmp((const char*)"Apple Software Renderer", (const char*) glGetString(GL_RENDERER)) )?TRUE:FALSE;
}

- (void)initViews
{
    [window addSubview:viewController.view];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application 
{
	 _delegate = self;
    self.window.frame = CGRectMake(0, 0, [[UIScreen mainScreen]bounds].size.width, [[UIScreen mainScreen]bounds].size.height);

    /*
    char* _tfid = ApplicationGetTestFlightID();
    if (strlen(_tfid)>0)
    {
		NSString* myid = [NSString stringWithFormat:@"%s", _tfid];
		[TestFlight takeOff:myid];
    }
    */
	
	if (self.viewController == nil) {
		//NSLog(@"Creating Input Controller");
		self.viewController = [InputController alloc];
	}
    glView.animationInterval = 1.0 / 60.0;
    // Call initialisation routine of your Pascal code
	[glView startAnimation];
    openglView = glView;

	iCadeReaderView *control = [[iCadeReaderView alloc] initWithFrame:CGRectZero];
    [glView addSubview:control];
    control.active = YES;
    control.delegate = self;
    //[control release]; 
	
    
	[[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeRight];
	[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
		
    iAPManager = [InAppPurchaseManager alloc];
    [iAPManager loadStore];
	
	midiPlayer = [MidiPlayer alloc];
	[midiPlayer create];

	NSLog(@"FinishedLaunching");
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url 
{
/*	NSLog(@"handleOpenURL Method was called and sent the following:");
	NSString *urlString = [NSString stringWithContentsOfURL:(NSURL *)url];     
	NSLog(@"URL String: %@", urlString);
    Facebook * facebook = [[FBRequestWrapper defaultManager] GetFacebook];
	return [facebook handleOpenURL:url];*/
    return false;
}

/*
iCade
A C E G
B D F H

8Bitty
B			D
		E G
A C 	F H
*/

- (void)buttonDown:(iCadeState)button
{
    switch (button)
	{
    case iCadeJoystickUp:		ApplicationOnKeyDown(keyGamepadUp); break;
    case iCadeJoystickRight:	ApplicationOnKeyDown(keyGamepadRight); break;
    case iCadeJoystickDown:		ApplicationOnKeyDown(keyGamepadDown); break;
    case iCadeJoystickLeft:		ApplicationOnKeyDown(keyGamepadLeft); break;
    case iCadeButtonA:	ApplicationOnKeyDown(keyGamepadMenu); break;
    case iCadeButtonB:	ApplicationOnKeyDown(keyGamepadL); break;
//    case iCadeButtonC:	ApplicationOnKeyDown(keyGamepad); break;
    case iCadeButtonD:	ApplicationOnKeyDown(keyGamepadR); break;
    case iCadeButtonE:	ApplicationOnKeyDown(keyGamepadA); break;
    case iCadeButtonF:	ApplicationOnKeyDown(keyGamepadB); break;
    case iCadeButtonG:	ApplicationOnKeyDown(keyGamepadX); break;
    case iCadeButtonH:	ApplicationOnKeyDown(keyGamepadY); break;
	}
}

- (void)buttonUp:(iCadeState)button 
{
    switch (button)
	{
    case iCadeJoystickUp:		ApplicationOnKeyUp(keyGamepadUp); break;
    case iCadeJoystickRight:	ApplicationOnKeyUp(keyGamepadRight); break;
    case iCadeJoystickDown:		ApplicationOnKeyUp(keyGamepadUp); break;
    case iCadeJoystickLeft:		ApplicationOnKeyUp(keyGamepadLeft); break;
    case iCadeButtonA:	ApplicationOnKeyUp(keyGamepadMenu); break;
    case iCadeButtonB:	ApplicationOnKeyUp(keyGamepadL); break;
  //  case iCadeButtonC:	ApplicationOnKeyUp(keyGamepad); break;
    case iCadeButtonD:	ApplicationOnKeyUp(keyGamepadR); break;
    case iCadeButtonE:	ApplicationOnKeyUp(keyGamepadA); break;
    case iCadeButtonF:	ApplicationOnKeyUp(keyGamepadB); break;
    case iCadeButtonG:	ApplicationOnKeyUp(keyGamepadX); break;
    case iCadeButtonH:	ApplicationOnKeyUp(keyGamepadY); break;
	}
}

- (void)applicationDidEnterBackground:(UIApplication *)application 
{
    ApplicationEnterState(1);
	[glView stopAnimation];
	
    // End the session when the user leaves the app
  //  [[KPManager sharedManager] endSession];

}

- (void)applicationWillResignActive:(UIApplication *)application 
{
	glView.animationInterval = 1.0 / 5.0;
}

- (void)applicationWillEnterForeground:(UIApplication *)application 
{
    ApplicationEnterState(0);
	[glView startAnimation];
    // Start a session when the user enters the app
    //[[KPManager sharedManager] startSession];
}

- (void)applicationDidBecomeActive:(UIApplication *)application 
{
	glView.animationInterval = 1.0 / 60.0;
    ApplicationEnterState(0);
	[glView startAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application 
{
    // End the session when the app terminates
    //[[KPManager sharedManager] endSession];
}
- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
	ApplicationMemoryWarning();
}

 - (BOOL)prefersStatusBarHidden 
{
	return YES;
}

- (void)dealloc {
	[viewController release];
	[window release];
	[glView release];
	[super dealloc];
}

@end
