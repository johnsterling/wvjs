//
//  JavaScriptBridge.h
//  JavaScript Bridge
//
//  Created by John Sterling on 9/29/14.
//  Copyright (c) 2014 Volar Video. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *const JavaScriptBridgeErrorDomain;

@interface JavaScriptBridge : NSObject <UIWebViewDelegate>

/**
 * Underlying UIWebView containing the JavaScript context.
 */
@property (strong, nonatomic, readonly) UIWebView *webView;

/**
 * Objects that have been registered.
 */
@property (strong, nonatomic, readonly) NSMutableArray *objects;


#pragma mark - Initialization

/**
 * Loads underlying UIWebView.
 */
- (void)loadWithReadyBlock:(void(^)())readyBlock;


#pragma mark - ObjC -> JS

/**
 * Loads a script file from a URL.
 */
- (void)loadScriptURL:(NSURL *)URL readyBlock:(void(^)())readyBlock;

/**
 * Runs a JavaScript script.
 */
- (NSString *)runScript:(NSString *)script error:(NSError **)error;

/**
 * Calls a JavaScript function.
 */
- (id)callFunction:(NSString *)function args:(NSArray *)args error:(NSError **)error;


#pragma mark - JS -> ObjC

/**
 * Registers an object, making it available to JavaScript.
 */
- (void)registerObject:(NSObject *)object forVar:(NSString *)var;

/**
 * Registers an object, making it available to JavaScript.
 */
- (void)registerObject:(NSObject *)object forVar:(NSString *)var withMethodMap:(NSDictionary *)methodMap;

@end
