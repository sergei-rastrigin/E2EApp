//
//  NXMLeg.m
//  NexmoClient
//
//  Created by Assaf Passal on 5/30/19.
//  Copyright © 2019 Vonage. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NXMLegPrivate.h"
#import "NXMUtils.h"

@implementation NXMLeg

- (nullable instancetype) initWithConversationId:(nullable NSString *)conversationId
                                     andMemberId:(nullable NSString *)memberId
                                        andLegId:(nullable NSString *)legId
                                     andlegTypeE:(NXMLegType)legType
                                   andLegStatusE:(NXMLegStatus)legStatus
                                         andDate:(nullable NSString *)date {
    if (self = [super init]){
        self.legId = legId;
        self.legType = legType;
        self.legStatus = legStatus;
        self.conversationId = conversationId;
        self.memberId = memberId;
        self.date = [date length] > 0 ? [NXMUtils dateFromISOString:date] : nil;
    }
    
    return self;
}

- (nullable instancetype) initWithConversationId:(nullable NSString *)conversationId
                                     andMemberId:(nullable NSString *)memberId
                                        andLegId:(nullable NSString *)legId
                                      andlegType:(nullable NSString *)legType
                                    andLegStatus:(nullable NSString *)legStatus
                                         andDate:(nullable NSString *)date {
    return [self initWithConversationId:conversationId
                            andMemberId:memberId
                               andLegId:legId
                            andlegTypeE:[NXMLeg getLegTypeFromString:legType]
                          andLegStatusE:[NXMLeg getLegStatusFromString:legStatus]
                                andDate:date];

}

- (nullable instancetype) initWithConversationId:(nullable NSString *) conversationId
                                     andMemberId:(nullable NSString *) memberId
                                      andLegData:(nullable NSDictionary *)legData
                                         andData:(nullable NSDictionary *)data {
    
    return [self initWithConversationId:conversationId
                            andMemberId:memberId
                               andLegId:legData[@"leg_id"]
                            andlegTypeE:[NXMLeg getLegTypeFromString:data[@"type"]]
                          andLegStatusE:[NXMLeg getLegStatusFromString:legData[@"status"]]
                                andDate:nil];
    
}

- (nullable instancetype)initWithData:(nullable NSDictionary *)data
                            andLegData:(nullable NSDictionary *)legData {
    
    return [self initWithConversationId:legData[@"convertsation_id"]
                            andMemberId:legData[@"member_id"]
                               andLegId:data[@"leg_id"]
                            andlegTypeE:[NXMLeg getLegTypeFromString:data[@"type"]]
                          andLegStatusE:[NXMLeg getLegStatusFromString:legData[@"status"]]
                                andDate:@"date"];
}


+ (NXMLegStatus)getLegStatusFromString:(nullable NSString*)statusString {
    return [statusString isEqualToString:@"riniging"] ? NXMLegStatusCalling :
            [statusString isEqualToString:@"answered"] ? NXMLegStatusAnswered :
            [statusString isEqualToString:@"started"] ? NXMLegStatusStarted :
            [statusString isEqualToString:@"completed"] ? NXMLegStatusCompleted :
            NXMLegStatusStarted;
}

+ (NXMLegType)getLegTypeFromString:(nullable NSString*)typeString {
    return [typeString isEqualToString:@"app"] ? NXMLegTypeApp :
           [typeString isEqualToString:@"phone"] ? NXMLegTypeApp :
           NXMLegTypeUnknown;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> legId=%@ legType=%ld legStatus=%ld convId=%@ memberId=%@ date=%@",
            NSStringFromClass([self class]),
            self,
            self.legId,
            (long)self.legType,
            (long)self.legStatus,
            self.conversationId,
            self.memberId,
            self.date];
}

@end
