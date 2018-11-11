//
//  NXMJoinMemberRequest.m
//  NexmoConversationObjC
//
//  Created by user on 16/04/2018.
//  Copyright © 2018 Vonage. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NXMJoinMemberRequest.h"

@implementation NXMJoinMemberRequest

- (instancetype)initWithConversationId:(NSString *)conversationID andMemberId:(NSString *)memberID {
    if (self = [super init]) {
        self.conversationID = conversationID;
        self.memberID = memberID;
    }
    
    return self;
}

@end