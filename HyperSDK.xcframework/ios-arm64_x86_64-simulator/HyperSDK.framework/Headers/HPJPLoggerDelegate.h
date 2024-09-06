//
//  LoggerProtocol.h
//  HyperSDK
//
//  Created by Sahaya Gebin on 23/05/24.
//  Copyright © 2024 Juspay Technologies. All rights reserved.
//

#ifndef LoggerDelegate_h
#define LoggerDelegate_h

@protocol HPJPLoggerDelegate

@required
- (void)trackEventWithLevel:(NSString *)level label:(NSString *)label value:(id)value category:(NSString *)category subcategory:(NSString *)subcategory;

@end
#endif /* LoggerDelegate_h */
