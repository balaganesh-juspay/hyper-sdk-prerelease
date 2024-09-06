//
//  BridgeComponent.h
//  HyperSDK
//
//  Copyright © Juspay Technologies. All rights reserved.
//

#ifndef BridgeCompontent_h
#define BridgeCompontent_h

#import <UIKit/UIKit.h>
#import "HPJPLoggerDelegate.h"

extern NSString * _Nonnull const kHyperNetworkChangeNotification;

@protocol BridgeComponent <HPJPLoggerDelegate>

@required

- (UIView * _Nullable)getContainerView;

- (UIViewController * _Nullable)getBaseViewController;

- (void)executeOnWebView:(NSString * _Nonnull)jsString;

- (NSDictionary * _Nonnull)getSdkConfig;

@end

#endif /* BridgeCompontent_h */
