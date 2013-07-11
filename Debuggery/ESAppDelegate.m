//
//  ESAppDelegate.m
//
//  Copyright Doug Russell 2011. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//	

#import "ESAppDelegate.h"
#import "ESDebugConsole.h"
#import "ESDebugConsole+iOS_GUI.h"
#import "ESDebugConsole+iOS_Mail.h"

@implementation ESAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
	self.window.rootViewController = [UIViewController new];
    [self.window makeKeyAndVisible];
	
	ESDebugConsole *console = [ESDebugConsole sharedDebugConsole];
	[console setConsoleSizeInPopover:CGSizeMake(320, 480)];
	[console setRecipients:[NSArray arrayWithObjects:@"youremail@yourwebsite.com", nil]];
	[console setSubject:@"Console Logs"];
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:console action:@selector(gestureRecognized:)];
	[console setGestureRecognizer:tap];
	[self.window.rootViewController.view addGestureRecognizer:tap];
	
	UILabel *label = [[UILabel alloc] initWithFrame:self.window.rootViewController.view.bounds];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	label.text = @"Tap anywhere to open log view";
	[self.window.rootViewController.view addSubview:label];
	
	NSLog(@"Launched");
	
    return YES;
}

@end
