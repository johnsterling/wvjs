//
//  ViewController.m
//  JavaScript Bridge
//
//  Created by John Sterling on 9/29/14.
//  Copyright (c) 2014 Volar Video. All rights reserved.
//

#import "ViewController.h"
#import "JavaScriptBridge.h"
#import "Square.h"

@interface ViewController ()

@property (strong, nonatomic) IBOutlet Square *square;
@property (strong, nonatomic) JavaScriptBridge *bridge;

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.bridge = [[JavaScriptBridge alloc] init];
	[self.bridge loadWithReadyBlock:^{
		NSURL *url = [[NSBundle mainBundle] URLForResource:@"Controller" withExtension:@"js"];
		[self.bridge loadScriptURL:url readyBlock:^{

		}];
		[self.bridge registerObject:self.square
							 forVar:@"controller.square"
					  withMethodMap:@{@"setColor":@"setColorRed:green:blue:"}];
	}];
}

- (void)log:(NSString *)msg
{
	NSLog(@"%@", msg);
}

- (IBAction)test:(id)sender
{
	NSError *error = nil;
	[self.bridge callFunction:@"controller.toggle" args:nil error:&error];
	if (error) {
		NSLog(@"%@", error);
	}
}

@end
