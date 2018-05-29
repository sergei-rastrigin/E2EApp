//
//  NXMGetEventsRequest.h
//  NexmoConversationObjC
//
//  Created by user on 29/05/2018.
//  Copyright © 2018 Vonage. All rights reserved.
//

#ifndef NXMGetEventsRequest_h
#define NXMGetEventsRequest_h

#import "NXMBaseRequest.h"

@interface NXMGetEventsRequest : NXMBaseRequest

@property (nonatomic, strong, nullable) NSString *conversationId;

@end


#endif /* NXMGetEventsRequest_h */
