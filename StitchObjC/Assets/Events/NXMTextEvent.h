//
//  NXMTextEvent.h
//  NexmoConversationObjC
//
//  Created by Chen Lev on 3/12/18.
//  Copyright © 2018 Vonage. All rights reserved.
//

#import "NXMEvent.h"

@interface NXMTextEvent : NXMEvent
@property (nonatomic, strong) NSString *text;
// TODO: type
@property (nonatomic, strong, nonnull) NSDictionary<NSNumber *,NSDictionary<NSString *, NSDate *> *> *state;
@end
