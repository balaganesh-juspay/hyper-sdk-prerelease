//
//  Hyper.h
//  HyperSDK
//
//  Copyright © Juspay Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// If this line gives error then it means that assets download didn't happen properly.
// That could be because of the following reasons:
// * Not all the steps are followed as given in the integration documentation.
// * Some error occured while doing pod install.
#import <HyperSDK/VerifyHyperAssets.h>
#import <HyperSDK/BridgeComponent.h>
#import <HyperSDK/BridgeModule.h>
#import <HyperSDK/HyperTenantParams.h>

@protocol HyperDelegate <NSObject>

@optional

- (UIView * _Nullable)merchantViewForViewType:(NSString * _Nonnull)viewType;

/**
 Delegate method will be triggered once JuspaySafeBrowser's webview is initialized.

 @param webView The web view object.
*/
- (void)onWebViewReady:(WKWebView * _Nonnull)webView;


/**
 Notifies the delegate that the user has initiated a back press action within the JuspaySafeBrowser view controller
 that is pushed on a custom navigation controller.
 
 Implement this method in your delegate to handle specific behavior when the user presses the back button.
*/
- (void)didBackPressOnJuspaySafe;

@end

@interface Hyper : NSObject

/**
 Hides bottom bar to provide more screen. Default is true.
 
 @since v0.1
 */
@property (nonatomic) BOOL shouldHideBottomBarWhenPushed;

/**
 Hides navigation bar to provide more screen. Default is true.
 
 @since v2.1.41
 */
@property (nonatomic) BOOL shouldHideNavigationBarWhenPushed;

#pragma mark - SDK Integration

/**
 Callback block for communicating between callee to service .
 
 @param data Data being passed for service.
 
 @since v0.4
 */
typedef void (^HyperEventsCallback)(NSDictionary* _Nonnull data);

/**
 Callback block to handle various callbacks/outputs from the SDK.
 
 @param data Response data from SDK once execution is complete.
 
 @since v0.4
 */
typedef void (^HyperSDKCallback)(NSDictionary<NSString*, id>* _Nullable data);

/**
 Custom loader to be shown in case of network calls.
 
 @since v0.1
 */
@property (nonatomic, strong, nullable) UIView *activityIndicator;

/**
 Base view controller.
 
 @since v0.4
 */
@property (nonatomic, weak, nullable) UIViewController *baseViewController;

/**
 Base view where SDK UI needs to be drawn.
 
 @since v2.1.40
 */
@property (nonatomic, weak, nullable) UIView *baseView;

/**
 HyperSDK callback.
 
 @since v0.4
 */
@property (nonatomic, copy, nullable) HyperSDKCallback hyperSDKCallback;


/**
 Return the current version of SDK.
 
 @return Version number in string representation.
 
 @since v0.1
 */
+(NSString*_Nonnull)HyperSDKVersion;


/**
@property hyperDelegate
*/

@property (nonatomic, weak) id <HyperDelegate> _Nullable hyperDelegate;

/**
 For initiating Hyper engine and for passing external modules to attach with.

 @param modules An array of BridgeModule class names.
 @return An initialized instance of the class.
 
 @since v2.1.38
 */

- (instancetype _Nonnull )initWithModules:(NSArray<NSString *>*_Nonnull) modules;

/**
 For initiating Hyper engine with TenantParams.

 @param tenantParams the params to be passed from wrapper for multi tenancy.
 @return An initialized instance of the class.
 */

- (instancetype _Nonnull)initWithTenantParams:(HyperTenantParams * _Nonnull)tenantParams;

/**
 For updating assets and establishing connections.
 
 @since v0.2
 */
+ (void)preFetch:(NSDictionary*_Nonnull)data;

/**
 Callback to be triggered by merchant.
 
 @return HyperEventsCallback to be triggered for passing data back.
 
 @since v0.4
 */
- (HyperEventsCallback _Nullable )merchantEvent;

/**
 * Handles the redirection back to the app from the PWA UI
 *
 * @param url the redirect URL
 * @param sourceApplication the sourceApplication where it comes from
 *
 * @return whether the response with the URl was handled successfully or not.
 *
 */
+ (BOOL)handleRedirectURL:(NSURL * _Nonnull)url sourceApplication:(NSString * _Nonnull)sourceApplication;

/**
Check if current instance is Initialised.

@since v2.0
*/
- (Boolean)isInitialised;
    
///---------------------
/// @name Hyper entry points
///---------------------

/**
 For initiating Hyper engine.
 
 @param viewController Reference ViewController marked as starting point of view.
 @param initiationPayload Payload required for starting up engine.
 @param callback Callback block to handle various callbacks or events triggered by SDK.
 
 @since v0.4
 */
- (void)initiate:(UIViewController * _Nonnull)viewController payload:(NSDictionary * _Nonnull)initiationPayload callback:(HyperSDKCallback _Nonnull)callback;

/**
 To perform an action.
 
 @param processPayload Payload required for the operation.
 
 @since v0.4
 */
- (void)process:(NSDictionary * _Nonnull)processPayload;

/**
 To perform an action.
 
 This method performs an action based on the provided payload, displaying UI as necessary on the specified base view controller.
 
 @param viewController Base view controller on which UI needs to be shown.
 @param processPayload Payload required for the operation.
 
 @since v2.1.38
 */
- (void)process:(UIViewController * _Nonnull)viewController processPayload:(NSDictionary * _Nonnull)processPayload;

/**
 To stop Hyper engine.
 
 @since v0.4
 */

- (void)terminate;

/**
 To close session and pop JuspaySafe ViewController when it is opened in App's navigation controller.
 */

- (void)closeJuspaySafe;

/**
 To stop a performed action.
 
 @param terminatePayload Payload required for  the operation.
 
 @since v0.4
 */

- (void)terminateProcess:(NSDictionary * _Nullable)terminatePayload;

/**
 Set it as true if HyperSDK's UI needs to be opened in a new view controller instead of adding it in baseViewController.
 The default is false.
 */
@property (nonatomic) BOOL shouldUseViewController;

/**
 To use App's navigation controller to open JuspaySafe ViewController. The default is false.
 */
@property (nonatomic) BOOL shouldUseAppNavigationController;

@end

/**
HyperServices sub-class to allow uniform class calls across OS.

@since v2.0
*/
@interface HyperServices : Hyper
@end
