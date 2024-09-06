//
//  HyperTenantParams.h
//  HyperSDK
//
//  Copyright © 2024 Juspay Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HyperTenantParams : NSObject

@property (nonatomic, strong) NSString * _Nullable clientId;
@property (nonatomic, strong) NSString * tenantId;
@property (nonatomic, strong) NSString * releaseConfigURL;

@end

NS_ASSUME_NONNULL_END
