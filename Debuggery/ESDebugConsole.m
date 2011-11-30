//
//  ESDebugConsole.m
//
//  Created by Doug Russell on 4/26/10.
//  Copyright Doug Russell 2010. All rights reserved.
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

#import "ESDebugConsole.h"
#import <asl.h>

#if !__has_feature(objc_arc)
#define NO_ARC(noarccode) noarccode
#else
#define NO_ARC(noarccode) 
#endif

@interface ESConsoleEntry : NSObject 
@property (nonatomic, retain) NSString *message;
@property (nonatomic, retain) NSString *shortMessage;
@property (nonatomic, retain) NSString *applicationIdentifier;
@property (nonatomic, retain) NSDate *date;
- (id)initWithDictionary:(NSDictionary *)dictionary;
@end

//http://www.cocoanetics.com/2011/03/accessing-the-ios-system-log/
//http://developer.apple.com/library/ios/#documentation/System/Conceptual/ManPages_iPhoneOS/man3/asl.3.html#//apple_ref/doc/man/3/asl
static NSArray * getConsole(BOOL constrainToCurrentApp)
{
	aslmsg q, m;
	int i;
	const char *key, *val;
	NSMutableArray *consoleLog;
	NSString *applicationIdentifier;
	NSString *applicationIdentifierKey;
	
	q = asl_new(ASL_TYPE_QUERY);
	
	consoleLog = [NSMutableArray new];
	
	applicationIdentifier = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleIdentifierKey];
	applicationIdentifierKey = [NSString stringWithCString:ASL_KEY_FACILITY encoding:NSUTF8StringEncoding];
	aslresponse r = asl_search(NULL, q);
	while (NULL != (m = aslresponse_next(r)))
	{
		NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
		
		for (i = 0; (NULL != (key = asl_key(m, i))); i++)
		{
			NSString *keyString = [NSString stringWithUTF8String:(char *)key];
			
			val = asl_get(m, key);
			
			NSString *string = [NSString stringWithUTF8String:val];
			
			if (string != nil)
				[tmpDict setObject:string forKey:keyString];
		}
		
		if (constrainToCurrentApp && ![[tmpDict objectForKey:applicationIdentifierKey] isEqualToString:applicationIdentifier])
			continue;
		
		ESConsoleEntry *entry = [[ESConsoleEntry alloc] initWithDictionary:tmpDict];
		if (entry != nil)
		{
			[consoleLog addObject:entry];
			NO_ARC([entry release];)
		}
	}
	aslresponse_free(r);
	
	[consoleLog sortUsingDescriptors:[NSArray arrayWithObjects:[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO], nil]];
	
	NSArray *retVal = [NSArray arrayWithArray:consoleLog];
	
	NO_ARC([consoleLog release];)
	
	return retVal;
}

@interface ESDebugTableViewController : UITableViewController
@property (nonatomic, retain) NSArray *logs;
@end

@interface ESDebugTableViewCell : UITableViewCell
@property (nonatomic, retain) UILabel *applicationIdentifierLabel;
@property (nonatomic, retain) UILabel *messageLabel;
@property (nonatomic, retain) UILabel *dateLabel;
@end

@interface ESDebugDetailViewController : UIViewController
@property (nonatomic, retain) UITextView *textView;
@end

@interface ESDebugConsole ()
@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UIPopoverController *popoverController;
@property (nonatomic, retain) UINavigationController *navigationController;
@property (nonatomic, retain) ESDebugTableViewController *debugTableViewController;
- (void)activate;
@end

@implementation ESDebugConsole
@synthesize window=_window;
@synthesize popoverController=_popoverController;
@synthesize navigationController=_navigationController;
@synthesize debugTableViewController=_debugTableViewController;

#pragma mark - 

+ (id)sharedDebugConsole
{
	static ESDebugConsole *sharedConsole;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedConsole = [ESDebugConsole new];
	});
	return sharedConsole;
}

- (id)init
{
	self = [super init];
	if (self)
	{
		[self activate];
	}
	return self;
}

- (void)activate
{
	UIWindow* window = [UIApplication sharedApplication].keyWindow;
	if (!window)
		window = [[UIApplication sharedApplication].windows objectAtIndex:0];
	if (window == nil)
	{
		[NSException raise:@"Nil Window Exception" format:@"Activated ESDebugConsole without a window to attach to"];
		return;
	}
	if (window.rootViewController == nil && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
	{
		[NSException raise:@"Nil Root View Controller Exception" format:@"Activated ESDebugConsole without a root view controller to attach to"];
		return;
	}
	self.window = window;
	UIRotationGestureRecognizer *rotationGesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(gestureRecognized:)];
	[window addGestureRecognizer:rotationGesture];
	NO_ARC([rotationGesture release];)
}

- (void)dealloc
{
	NO_ARC(
		   [_window release];
		   [_popoverController release];
		   [_navigationController release];
		   [_debugTableViewController release];
		   [super dealloc];
		   )
}

#pragma mark - 

- (void)gestureRecognized:(UIRotationGestureRecognizer *)gestureRecognizer
{
	if (gestureRecognizer.state != UIGestureRecognizerStateEnded)
		return;
	
	if (fabsf(gestureRecognizer.rotation) < M_PI)
		return;
	
	self.debugTableViewController.logs = getConsole(YES);
	[self.debugTableViewController.tableView reloadData];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
	{
		[self.popoverController presentPopoverFromRect:CGRectMake(0, 0, 10, 10) 
												inView:gestureRecognizer.view 
							  permittedArrowDirections:UIPopoverArrowDirectionAny 
											  animated:YES];
	}
	else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
	{
		[self.window.rootViewController presentModalViewController:self.navigationController animated:YES];
	}
}

#pragma mark - 

- (UIPopoverController *)popoverController
{
	if (_popoverController == nil)
	{
		_popoverController = [[UIPopoverController alloc] initWithContentViewController:self.navigationController];
	}
	return _popoverController;
}

- (UINavigationController *)navigationController
{
	if (_navigationController == nil)
	{
		_navigationController = [[UINavigationController alloc] initWithRootViewController:self.debugTableViewController];
	}
	return _navigationController;
}

- (ESDebugTableViewController *)debugTableViewController
{
	if (_debugTableViewController == nil)
	{
		_debugTableViewController = [ESDebugTableViewController new];
	}
	return _debugTableViewController;
}

@end

@implementation ESConsoleEntry
@synthesize message=_message;
@synthesize shortMessage=_shortMessage;
@synthesize applicationIdentifier=_applicationIdentifier;
@synthesize date=_date;

#pragma mark -

//#define ASL_KEY_TIME      "Time"
//#define ASL_KEY_HOST      "Host"
//#define ASL_KEY_SENDER    "Sender"
//#define ASL_KEY_FACILITY  "Facility"
//#define ASL_KEY_PID       "PID"
//#define ASL_KEY_UID       "UID"
//#define ASL_KEY_GID       "GID"
//#define ASL_KEY_LEVEL     "Level"
//#define ASL_KEY_MSG       "Message"

- (id)initWithDictionary:(NSDictionary *)dictionary
{
	self = [super init];
	if (self != nil)
	{
		if (dictionary == nil)
		{
			NO_ARC([self release];)
			self = nil;
			return nil;
		}
		
		self.message = [dictionary objectForKey:[NSString stringWithCString:ASL_KEY_MSG encoding:NSUTF8StringEncoding]];
		if (self.message.length > 400)
			self.shortMessage = [self.message substringToIndex:400];
		else
			self.shortMessage = self.message;
		self.applicationIdentifier = [dictionary objectForKey:[NSString stringWithCString:ASL_KEY_FACILITY encoding:NSUTF8StringEncoding]];
		self.date = [NSDate dateWithTimeIntervalSince1970:[[dictionary objectForKey:[NSString stringWithCString:ASL_KEY_TIME encoding:NSUTF8StringEncoding]] doubleValue]];
	}
	return self;
}

- (void)dealloc
{
	NO_ARC(
		   [_message release];
		   [_shortMessage release];
		   [_applicationIdentifier release];
		   [_date release];
		   [super dealloc];
		   )
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"Application Identifier: %@\n\nConsole Message: %@\n\nTime: %@", self.applicationIdentifier, self.message, self.date];
}

@end

@implementation ESDebugTableViewController
@synthesize logs=_logs;

#pragma mark - 

- (void)dealloc
{
	NO_ARC(
		   [_logs release];
		   [super dealloc];
		   )
}

#pragma mark - 

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.title = @"Console";
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
	{
		UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
		self.navigationItem.rightBarButtonItem = doneButton;
		NO_ARC([doneButton release];)
	}
	
	UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Current", @"All", nil]];
	segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
	segmentedControl.selectedSegmentIndex = 0;
	[segmentedControl addTarget:self action:@selector(segmentedControlChanged:) forControlEvents:UIControlEventValueChanged];
	self.tableView.tableHeaderView = segmentedControl;
	NO_ARC([segmentedControl release];)
}

#pragma mark - 

- (void)done:(id)sender
{
	if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
		[self dismissViewControllerAnimated:YES completion:nil];
	else
		[self dismissModalViewControllerAnimated:YES];
}

- (void)segmentedControlChanged:(UISegmentedControl *)sender
{
	switch ([sender selectedSegmentIndex]) {
		case 0:
			self.logs = getConsole(YES);
			break;
		case 1:
			self.logs = getConsole(NO);
			break;
		default:
			break;
	}
	[self.tableView reloadData];
}

#pragma mark - 

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (self.logs)
		return self.logs.count;
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *reuseIdentifier = @"Cell";
	ESDebugTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
	if (cell == nil)
	{
		cell = [[ESDebugTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
		NO_ARC([cell autorelease];)
	}
	
	ESConsoleEntry *entry = [self.logs objectAtIndex:indexPath.row];
	cell.applicationIdentifierLabel.text = entry.applicationIdentifier;
	cell.messageLabel.text = entry.shortMessage;
	cell.dateLabel.text = [entry.date description];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	ESDebugDetailViewController *detailViewController = [ESDebugDetailViewController new];
	detailViewController.textView.text = [NSString stringWithFormat:@"%@", [self.logs objectAtIndex:indexPath.row]];
	[self.navigationController pushViewController:detailViewController animated:YES];
	NO_ARC([detailViewController release];)
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// This assumes that the table view cells content view is as wide as the actual table,
	// which isn't necessarily true, but works fine here
	CGSize size = [[[self.logs objectAtIndex:indexPath.row] shortMessage] sizeWithFont:[UIFont systemFontOfSize:17] constrainedToSize:CGSizeMake(self.tableView.frame.size.width - 20, 10000) lineBreakMode:UILineBreakModeWordWrap];
	// add in the padding for the applicationIdentifier and date
	size.height += 60;
	return size.height;
}

#pragma mark - 

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return YES;
}

@end

@implementation ESDebugTableViewCell
@synthesize applicationIdentifierLabel=_applicationIdentifierLabel;
@synthesize messageLabel=_messageLabel;
@synthesize dateLabel=_dateLabel;

#pragma mark - 

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (self != nil)
	{
		_applicationIdentifierLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_applicationIdentifierLabel.font = [UIFont boldSystemFontOfSize:18];
		[self.contentView addSubview:_applicationIdentifierLabel];
		_messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_messageLabel.numberOfLines = 0;
		_messageLabel.font = [UIFont systemFontOfSize:17];
		_messageLabel.textColor = [UIColor darkGrayColor];
		[self.contentView addSubview:_messageLabel];
		_dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[self.contentView addSubview:_dateLabel];
	}
	return self;
}

- (void)dealloc
{
	NO_ARC(
		   [_applicationIdentifierLabel release];
		   [_messageLabel release];
		   [_dateLabel release];
		   [super dealloc];
		   )
}

#pragma mark - 

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	self.applicationIdentifierLabel.frame = CGRectMake(10, 10, self.contentView.frame.size.width - 20, 18);
	CGSize size = CGSizeMake(self.contentView.frame.size.width - 20, 18);
	if (self.messageLabel.text.length)
		size = [self.messageLabel.text sizeWithFont:[self.messageLabel font] constrainedToSize:CGSizeMake(size.width, 10000) lineBreakMode:UILineBreakModeWordWrap];
	self.messageLabel.frame = CGRectMake(10, 30, size.width, size.height);
	self.dateLabel.frame = CGRectMake(10, CGRectGetMaxY(self.messageLabel.frame), self.contentView.frame.size.width - 20, 18);
}

@end

@implementation ESDebugDetailViewController
@synthesize textView=_textView;

#pragma mark - 

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.title = @"Details";
	
	self.textView.frame = self.view.bounds;
	
	[self.view addSubview:self.textView];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
	
	self.textView = nil;
}

#pragma mark -

- (UITextView *)textView
{
	if (_textView == nil)
	{
		_textView = [[UITextView alloc] initWithFrame:CGRectZero];
		_textView.editable = NO;
		_textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	}
	return _textView;
}

#pragma mark - 

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return YES;
}

@end
