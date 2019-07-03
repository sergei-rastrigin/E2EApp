//
//  NXMLeg.h
//  NexmoClient
//
//  Copyright © 2019 Vonage. All rights reserved.
//

#import "NXMEnums.h"

/*!
 @interface NXMLeg
 
 @brief The NXMLeg object represent the member media state
 */
@interface NXMLeg : NSObject

/// Indicates the unique identifier of the leg.
@property (nonatomic, copy, nonnull) NSString *legId;

/// Indicates the leg type.
@property (nonatomic, assign) NXMLegType legType;

/// Indicates the leg status.
@property (nonatomic, assign) NXMLegStatus legStatus;

/// Indicates the leg conversation id.
@property (nonatomic, copy, nullable) NSString *conversationId;

/// Indicates the leg member id.
@property (nonatomic, copy, nullable) NSString *memberId;

/// Indicates the started time of the current status of the leg.
@property (nonatomic, copy, nullable) NSDate *date;

@end
