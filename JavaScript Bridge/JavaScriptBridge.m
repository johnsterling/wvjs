//
//  JavaScriptBridge.m
//  JavaScript Bridge
//
//  Created by John Sterling on 9/29/14.
//  Copyright (c) 2014 Volar Video. All rights reserved.
//

#import "JavaScriptBridge.h"

NSString *const JavaScriptBridgeErrorDomain = @"JavaScriptBridgeErrorDomain";
enum {
	JavaScriptBridgeJavaScriptError = 1,
	JavaScriptBridgeJSONError = 2,
};

static NSString *const kBridgePagePath = @"JavaScriptBridge";
static NSString *const kBridgeSelfVar = @"JavaScriptBridge.jsb";
static NSString *const kBridgeLoadFunc = @"JavaScriptBridge.load";
static NSString *const kBridgeRegisterFunc = @"JavaScriptBridge.register";
static NSString *const kBridgeCallScheme = @"jsbridge";
static NSString *const kBridgeCallbacksVar = @"JavaScriptBridge.callbacks";
static NSString *const kBridgeErrorPrefix = @"JavaScriptBridgeError";

@interface JavaScriptBridge () {
	void (^_readyBlock)();
	NSMutableArray *_scriptBlocks;
}

@end

@implementation JavaScriptBridge

#pragma mark - Initialization

- (instancetype)init
{
	if ((self = [super init])) {
		_webView = [[UIWebView alloc] init];
		_webView.delegate = self;
		_objects = [[NSMutableArray alloc] init];
		_scriptBlocks = [[NSMutableArray alloc] init];
	}
	return self;
}

/**
 * Loads underlying UIWebView.
 */
- (void)loadWithReadyBlock:(void(^)())readyBlock
{
	_readyBlock = readyBlock;
	NSURL *url = [[NSBundle mainBundle] URLForResource:kBridgePagePath withExtension:@"html"];
	NSURLRequest *request = [NSURLRequest requestWithURL:url];
	[_webView loadRequest:request];
}

#pragma mark - ObjC -> JS

/**
 * Loads a script file from a URL.
 */
- (void)loadScriptURL:(NSURL *)URL readyBlock:(void(^)())readyBlock
{
	if (readyBlock == nil) {
		[_scriptBlocks addObject:[NSNull null]];
	} else {
		[_scriptBlocks addObject:readyBlock];
	}
	NSString *evalString = [NSString stringWithFormat:@"%@('%@',%lu);",
							kBridgeLoadFunc, [URL absoluteString], [_scriptBlocks count]-1];
	[_webView stringByEvaluatingJavaScriptFromString:evalString];
}

/**
 * Runs a JavaScript script.
 */
- (NSString *)runScript:(NSString *)script error:(NSError *__autoreleasing *)error
{
	NSString *evalString = [NSString stringWithFormat:@"try{%@}catch(e){'%@'+e;}", script, kBridgeErrorPrefix];
	NSString *returnString = [_webView stringByEvaluatingJavaScriptFromString:evalString];
	if ([returnString hasPrefix:kBridgeErrorPrefix]) {
		if (error != nil) {
			NSString *jsErr = [returnString substringFromIndex:kBridgeErrorPrefix.length];
			NSDictionary *errInfo = @{
				NSLocalizedDescriptionKey: jsErr,
				NSLocalizedFailureReasonErrorKey: jsErr,
			};
			if (error != nil) {
				*error = [NSError errorWithDomain:JavaScriptBridgeErrorDomain code:JavaScriptBridgeJavaScriptError userInfo:errInfo];
			}
		}
		return nil;
	}
	return returnString;
}

/**
 * Calls a JavaScript function.
 */
- (id)callFunction:(NSString *)function args:(NSArray *)args error:(NSError *__autoreleasing *)error
{
	NSString *argString;
	if (args != nil) {
		NSMutableArray *encodedArgs = [NSMutableArray arrayWithCapacity:args.count];
		for (id arg in args) {
			NSError *jsonErr = nil;
			NSData *data = [NSJSONSerialization dataWithJSONObject:arg
														   options:(NSJSONWritingOptions)NSJSONReadingAllowFragments
															 error:&jsonErr];
			if (data == nil && jsonErr != nil) {
				NSDictionary *errInfo = @{
					NSLocalizedDescriptionKey: @"JSON parse failed.",
					NSLocalizedFailureReasonErrorKey: @"JSON parse failed.",
					NSUnderlyingErrorKey: jsonErr,
				};
				if (error != nil) {
					*error = [NSError errorWithDomain:JavaScriptBridgeErrorDomain code:JavaScriptBridgeJSONError userInfo:errInfo];
				}
				return nil;
			}
			NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			[encodedArgs addObject:string];
		}
		argString = [encodedArgs componentsJoinedByString:@","];
	} else {
		argString = @"";
	}
	NSString *evalString = [NSString stringWithFormat:@"JSON.stringify(%@(%@));", function, argString];
	NSString *returnString = [self runScript:evalString error:error];
	id returnObj = nil;
	if (returnString != nil && returnString.length > 0) {
		NSError *jsonErr = nil;
		returnObj = [NSJSONSerialization JSONObjectWithData:[returnString dataUsingEncoding:NSUTF8StringEncoding]
													options:NSJSONReadingAllowFragments
													  error:&jsonErr];
		if (returnObj == nil && jsonErr != nil) {
			NSDictionary *errInfo = @{
				NSLocalizedDescriptionKey: @"JSON parse failed.",
				NSLocalizedFailureReasonErrorKey: @"JSON parse failed.",
				NSUnderlyingErrorKey: jsonErr,
			};
			if (error != nil) {
				*error = [NSError errorWithDomain:JavaScriptBridgeErrorDomain code:JavaScriptBridgeJSONError userInfo:errInfo];
			}
		}
	}
	return returnObj;
}

#pragma mark - JS -> ObjC

/**
 * Registers an object, making it available to JavaScript.
 */
- (void)registerObject:(NSObject *)object forVar:(NSString *)var
{
	// TODO: introspect available selectors to create method map
	[self registerObject:object forVar:var withMethodMap:@{}];
}

/**
 * Registers an object, making it available to JavaScript.
 */
- (void)registerObject:(NSObject *)object forVar:(NSString *)var withMethodMap:(NSDictionary *)methodMap
{
	[_objects addObject:object];
	NSMutableArray *encodedMap = [NSMutableArray arrayWithCapacity:[methodMap count]];
	for (NSString *method in methodMap) {
		NSString *string = [NSString stringWithFormat:@"'%@':'%@'", method, methodMap[method]];
		[encodedMap addObject:string];
	}
	NSString *mapString = [NSString stringWithFormat:@"{%@}", [encodedMap componentsJoinedByString:@","]];
	NSString *evalString = [NSString stringWithFormat:@"%@=%@(%lu,%@);",
							var, kBridgeRegisterFunc, (unsigned long)[self.objects count]-1, mapString];
	[_webView stringByEvaluatingJavaScriptFromString:evalString];
}

#pragma mark - Bridge internals

- (void)scriptDidLoad:(NSNumber *)index
{
	id readyBlock = _scriptBlocks[[index intValue]];
	if (readyBlock != [NSNull null]) {
		_scriptBlocks[index.intValue] = [NSNull null];
		((void (^)())readyBlock)();
	}
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	if (_readyBlock != nil) {
		[self registerObject:self forVar:kBridgeSelfVar withMethodMap:@{@"scriptDidLoad":@"scriptDidLoad:"}];
		_readyBlock(self);
	}
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	NSLog(@"JavaScriptBridge: UIWebView load error: %@", error);
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = request.URL;
	if ([url.scheme isEqualToString:kBridgeCallScheme]) {
		NSObject *object = _objects[url.host.intValue];
		NSArray *pathComponents = url.pathComponents;
		NSString *callback = nil;
		if (url.query != nil && url.query.length > 0) {
			callback = [NSString stringWithFormat:@"%@[%ld]", kBridgeCallbacksVar, (long)url.query.intValue];
		}
		SEL selector = NSSelectorFromString(pathComponents[1]);
		NSMethodSignature *signature = [object methodSignatureForSelector:selector];
		if (signature == nil) {
			NSLog(@"JavaScriptBridge: Selector '%@' not recognized for class '%@'", pathComponents[1], NSStringFromClass([object class]));
			if (callback != nil) {
				[self callFunction:callback
							  args:@[[NSNull null],
									 [NSString stringWithFormat:@"Selector '%@' not recognized for class '%@'",
									  pathComponents[1], NSStringFromClass([object class])]]
							 error:nil];
			}
			return NO;
		}
		BOOL voidReturn;
		switch (signature.methodReturnType[0]) {
			case '@':
				voidReturn = NO;
				break;
			case 'v':
				voidReturn = YES;
				break;
			default:
				NSLog(@"Return type of method for selector '%@' on class '%@' is not JSON-compatible", pathComponents[1], NSStringFromClass([object class]));
				if (callback != nil) {
					[self callFunction:callback
								  args:@[[NSNull null],
										 [NSString stringWithFormat:
										  @"Return type of method for selector '%@' on class '%@' is not JSON-compatible",
										  pathComponents[1], NSStringFromClass([object class])]]
								 error:nil];
				}
				return NO;
		}
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		[invocation setTarget:object];
		[invocation setSelector:selector];
		for (int arg_i = 2; arg_i < pathComponents.count; ++arg_i) {
			NSError *jsonErr = nil;
			id arg = [NSJSONSerialization JSONObjectWithData:[pathComponents[arg_i] dataUsingEncoding:NSUTF8StringEncoding]
													 options:NSJSONReadingAllowFragments
													   error:&jsonErr];
			if (arg == nil && jsonErr != nil) {
				NSDictionary *errInfo = @{
					NSLocalizedDescriptionKey: @"JSON parse failed.",
					NSLocalizedFailureReasonErrorKey: @"JSON parse failed.",
					NSUnderlyingErrorKey: jsonErr,
				};
				NSError *error = [NSError errorWithDomain:JavaScriptBridgeErrorDomain code:JavaScriptBridgeJSONError userInfo:errInfo];
				NSLog(@"JavaScriptBridge: JSON parse failed: %@", error);
			}
			[invocation setArgument:&arg atIndex:arg_i];
		}
		[invocation invoke];
		if (callback) {
			NSArray *args;
			if (!voidReturn) {
				id returnVal;
				[invocation getReturnValue:&returnVal];
				args = @[returnVal];
			} else {
				args = @[];
			}
			[self callFunction:callback args:args error:nil];
		}
		return NO;
	}
	return YES;
}

@end
