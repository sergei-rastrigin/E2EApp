//
//  NXMRouter.m
//  NexmoConversationObjC
//
//  Created by Chen Lev on 3/7/18.
//  Copyright © 2018 Vonage. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "NXMRouter.h"
#import "NXMErrors.h"
#import "NXMErrorParser.h"
#import "NXMAddUserRequest.h"
#import "NXMSendTextEventRequest.h"
#import "NXMDeleteEventRequest.h"
#import "NXMLogger.h"

#import "NXMNetworkCallbacks.h"
#import "NXMMemberEvent.h"
#import "NXMMediaEvent.h"
#import "NXMTextEvent.h"
#import "NXMSipEvent.h"
#import "NXMTextStatusEvent.h"
#import "NXMTextTypingEvent.h"
#import "NXMTextEventStatus.h"
#import "NXMImageEvent.h"
#import "NXMUtils.h"

static NSString * const EVENTS_URL_FORMAT = @"%@/conversations/%@/events";

@interface NXMRouter()

@property NSString *baseUrl;
@property (nonatomic) NSString *token;
@property (nonatomic) NSString *sessionId;


@end
@implementation NXMRouter

- (nullable instancetype)initWithHost:(nonnull NSString *)host {
    if (self = [super init]) {
        self.baseUrl = host;
    }
    
    return self;
}

- (void)setToken:(NSString *)token {
    _token = token;
}

- (void)setSessionId:(nonnull NSString *)sessionId {
    _sessionId = sessionId;
}


- (void)enablePushNotifications:(nonnull NXMEnablePushRequest *)request
                      onSuccess:(SuccessCallback _Nullable)onSuccess
                        onError:(ErrorCallback _Nullable)onError {
    
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"device_token"] = [self hexadecimalString:request.deviceToken];
    dict[@"device_type"] = @"ios";
    
    #ifdef DEBUG
        dict[@"device_push_environment"] = @"sandbox";
    #endif

    
    NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/devices/%@", self.baseUrl, deviceId]];
    
    [self requestToServer:dict url:url httpMethod:@"PUT" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error){
            onError(error);
            return;
        }
        
        onSuccess();
    }];
}


- (BOOL)getConversationWithId:(NSString*)convId  completionBlock:(void (^_Nullable)(NSError * _Nullable error, NXMConversationDetails * _Nullable conversation))completionBlock {

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@", self.baseUrl, convId]];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [self addHeader:request];
    
    [self executeRequest:request responseBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error) {
            completionBlock(error, nil);
            return;
        }
        
        NXMConversationDetails *details = [[NXMConversationDetails alloc] initWithId:convId];
        details.name = data[@"name"];
        details.created = data[@"timestamp"][@"created"];
        details.sequence_number = [data[@"sequence_number"] intValue];
        details.properties = data[@"properties"];
        
        NSMutableArray *members = [[NSMutableArray alloc] init];
        
        for (NSDictionary* memberJson in data[@"members"]) {
            NXMMember *member = [[NXMMember alloc] initWithMemberId:memberJson[@"member_id"] conversationId:convId user:memberJson[@"user_id"] name:memberJson[@"name"] state:memberJson[@"state"]];

            member.inviteDate = memberJson[@"timestamp"][@"invited"]; // TODO: NSDate
            member.joinDate = memberJson[@"timestamp"][@"joined"]; // TODO: NSDate
            member.leftDate = memberJson[@"timestamp"][@"left"]; // TODO: NSDate
            
            [members addObject:member];
        }

        completionBlock(nil, details);
    }];
    
    return YES;
}


- (void)createConversation:(nonnull NXMCreateConversationRequest*)createConversationRequest
                 onSuccess:(SuccessCallbackWithId _Nullable)onSuccess
                   onError:(ErrorCallback _Nullable)onError {
    NSError *jsonErr;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:@{@"display_name": createConversationRequest.displayName} options:0 error: &jsonErr];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@conversations", self.baseUrl]];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [self addHeader:request];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:jsonData];
    
    [self executeRequest:request responseBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error) {
            NSError *resError = [[NSError alloc] initWithDomain:NXMStitchErrorDomain code:[NXMErrorParser parseError:data] userInfo:nil];
            onError(resError);
            return;
        }
        
        NSString *convId = (NSString *)data[@"id"];
        if (!convId) {
            // TODO: error conv failed
            onError([[NSError alloc] initWithDomain:@"f" code:0 userInfo:nil]);
            return;
        }
        
      //  NSString *conv = convId;
        onSuccess(convId);
        
    }];
}

- (void)enableMedia:(NSString *)conversationId memberId:(NSString *)memberId sdp:(NSString *)sdp mediaType:(NSString *)mediaType // TODO: enum
          onSuccess:(SuccessCallbackWithId _Nullable)onSuccess
            onError:(ErrorCallback _Nullable)onError {
    NSDictionary *dict = @{ @"from": memberId,
                            @"body": @{
                                @"offer": @{
                                    @"sdp": sdp,
                                    @"label": @""
                                }
                            },
                            @"originating_session": self.sessionId };
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@/rtc", self.baseUrl, conversationId]];

    [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error){
            onError(error);
            return;
        }
        
        onSuccess(data[@"rtc_id"]);
    }];
}

// TODO: member id not found error
- (void)disableMedia:(NSString *)conversationId
               rtcId:(NSString *)rtcId
            memberId:(NSString *)memberId
           onSuccess:(SuccessCallback _Nullable)onSuccess
             onError:(ErrorCallback _Nullable)onError {
    
    NSDictionary *dict = @{ @"from": memberId, @"originating_session": self.sessionId};
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@/rtc/%@", self.baseUrl, conversationId, rtcId]];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0]; // TODO: timeout
    [self addHeader:request];

    [self requestToServer:dict url:url httpMethod:@"DELETE" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error){
            onError(error);
            return;
        }
        
        onSuccess();
    }];
}

- (void)muteAudioInConversation:(nonnull NSString *) conversationId
                     fromMember:(nonnull NSString *)fromMemberId
                       toMember:(nonnull NSString *)toMemberId
                      withRtcId:(nullable NSString *)rtcId
                      onSuccess:(SuccessCallback _Nullable)onSuccess
                        onError:(ErrorCallback _Nullable)onError {
    
    NSDictionary *dict = @{ @"type": @"audio:mute:on",
                            @"from": fromMemberId,
                            @"to": toMemberId,
                            @"body": @{
                                    @"rtc_id": rtcId ? rtcId : [NSNull null]
                                    }
                            };
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:EVENTS_URL_FORMAT, self.baseUrl, conversationId]];
    
    [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error){
            onError(error);
            return;
        }
        
        onSuccess();
    }];
}

- (void)unmuteAudioInConversation:(nonnull NSString *) conversationId
                       fromMember:(nonnull NSString *)fromMemberId
                         toMember:(nonnull NSString *)toMemberId
                        withRtcId:(nullable NSString *)rtcId
                        onSuccess:(SuccessCallback _Nullable)onSuccess
                          onError:(ErrorCallback _Nullable)onError {
    
    NSDictionary *dict = @{ @"type": @"audio:mute:off",
                            @"from": fromMemberId,
                            @"to": toMemberId,
                            @"body": @{
                                    @"rtc_id": rtcId ? rtcId : [NSNull null]
                                    }
                            };
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:EVENTS_URL_FORMAT, self.baseUrl, conversationId]];
    
    [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error){
            onError(error);
            return;
        }
        
        onSuccess();
    }];    
}

- (void)suspendMedia:(NSString *)conversationId mediaType:(NSString *)mediaType // TODO: enum
      completionHandler:(void (^_Nullable)(NSError * _Nullable error))completionHandler {
    
}

- (void)resumeMedia:(NSString *)conversationId mediaType:(NSString *)mediaType // TODO: enum
       completionHandler:(void (^_Nullable)(NSError * _Nullable error))completionHandler {
    
}


- (void)addUserToConversation:(nonnull NXMAddUserRequest*)addUserRequest
                    onSuccess:(SuccessCallbackWithId _Nullable)onSuccess
                      onError:(ErrorCallback _Nullable)onError {

    NSDictionary *dict = @{
                           @"user_id": addUserRequest.userID,
                           @"action": @"join",
                           @"channel": @{
                                   @"type": @"app"
                                   }
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@/members", self.baseUrl, addUserRequest.conversationID]];
    
    [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error) {
            onError(error);
            return;
        }
        
        onSuccess(nil); // TODO: eventId;
    }];
}

- (void)inviteUserToConversation:(nonnull NXMInviteUserRequest *)inviteUserRequest
                       onSuccess:(SuccessCallbackWithId _Nullable)onSuccess
                         onError:(ErrorCallback _Nullable)onError {
    NSDictionary *dict = @{
                           @"user_id": inviteUserRequest.userID,
                           @"action": @"invite",
                           @"channel": @{
                                   @"type": @"app"
                                   }
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@/members", self.baseUrl, inviteUserRequest.conversationID]];
    
    [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error) {
            onError(error);
            return;
        }
        
        onSuccess(nil); // TODO: eventId;
    }];
}

- (void)invitePstnToConversation:(nonnull NXMInvitePstnRequest *)invitePstnRequest
                       onSuccess:(SuccessCallbackWithId _Nullable)onSuccess
                         onError:(ErrorCallback _Nullable)onError{
    NSDictionary *dict = @{
                           @"user_id": invitePstnRequest.userID,
                           @"action": @"invite",
                           @"channel": @{
                                   @"type": @"phone",
                                   @"to":@{
                                       @"type": @"phone",
                                       @"number": invitePstnRequest.phoneNumber
                                   }
                                }
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@/members", self.baseUrl, invitePstnRequest.conversationID]];
    
    [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error) {
            onError(error);
            return;
        }
        
        onSuccess(nil); // TODO: eventId;
    }];
}


- (void)invitePstnKnockingToConversation:(nonnull NXMInvitePstnKnockingRequest *)invitePstnRequest
                               onSuccess:(SuccessCallbackWithId _Nullable)onSuccess
                                 onError:(ErrorCallback _Nullable)onError{
    NSDictionary *dict = @{
                      @"channel": @{
                              @"type": @"app",
                              @"from":@{
                                      @"type":@"app",
                                      @"user":invitePstnRequest.userName
                                      },
                              @"to":@{
                                      @"type": @"phone",
                                      @"number": invitePstnRequest.phoneNumber
                                      }
                              }
                      };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/knocking", self.baseUrl]];
    
    [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error) {
            onError(error);
            return;
        }
        
        onSuccess(data[@"id"]); // TODO: eventId;
    }];
}

- (void)joinMemberToConversation:(nonnull NXMJoinMemberRequest *)joinMembetRequest
                       onSuccess:(SuccessCallbackWithId)onSuccess
                         onError:(ErrorCallback _Nullable)onError {
    NSDictionary *dict = @{
                           @"member_id": joinMembetRequest.memberID,
                           @"action": @"join",
                           @"channel": @{
                                   @"type": @"app"
                                   }
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@/members", self.baseUrl, joinMembetRequest.conversationID]];
    
    [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error) {
            onError(error);
            return;
        }
        
        onSuccess(nil); // TODO: eventId;
    }];
}

- (void)removeMemberFromConversation:(nonnull NXMRemoveMemberRequest *)removeMemberRequest
                           onSuccess:(SuccessCallbackWithId _Nullable)onSuccess
                             onError:(ErrorCallback _Nullable)onError{
    NSDictionary *dict = @{
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@/members/%@", self.baseUrl, removeMemberRequest.conversationID, removeMemberRequest.memberID]];
    
    [self requestToServer:dict url:url httpMethod:@"DELETE" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error) {
            onError(error);
            return;
        }
        
        onSuccess(nil); // TODO: eventId;
    }];
}

- (void)sendTextToConversation:(nonnull NXMSendTextEventRequest*)sendTextEventRequest
                     onSuccess:(SuccessCallbackWithId _Nullable)onSuccess
                       onError:(ErrorCallback _Nullable)onError {
    NSDictionary *dict = @{
                           @"from": sendTextEventRequest.memberID,
                           @"type": @"text",
                           @"body": @{
                                   @"text": sendTextEventRequest.textToSend
                                   }
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:EVENTS_URL_FORMAT, self.baseUrl, sendTextEventRequest.conversationID]];
    
    [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        NSString *textId = [data[@"id"]stringValue];
        if (error) {
            onError(error);
            return;
        }
        
        onSuccess(textId); // TODO: eventId;
    }];
}

- (void)sendImage:(nonnull NXMSendImageRequest *)sendImageRequest
        onSuccess:(SuccessCallbackWithId _Nullable)onSuccess
          onError:(ErrorCallback _Nullable)onError {
    
    NSDictionary *headers = @{ @"content-type": @"multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW",
                               @"authorization": [NSString stringWithFormat:@"bearer %@", self.token]
                               };

    NSString *boundary = @"----WebKitFormBoundary7MA4YWxkTrZu0gW";
    
    NSDictionary *params = @{@"quality_ratio"     : @"100",
                            @"thumbnail_size_ratio"    : @"30",
                            @"medium_size_ratio" : @"50"};
    
    NSMutableData *httpBody = [NSMutableData data];
    
    
    [params enumerateKeysAndObjectsUsingBlock:^(NSString *parameterKey, NSString *parameterValue, BOOL *stop) {
        [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", parameterKey] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"%@\r\n", parameterValue] dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    
    [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", sendImageRequest.imageName] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:[[NSString stringWithFormat:@"Content-Type: image/png\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:sendImageRequest.image];
    [httpBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    [httpBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.nexmo.com/v1/image/"]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    [request setHTTPBody:httpBody];

    [self executeRequest:request responseBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error){
            onError(error);
            return;
        }
        
        
        NSDictionary *dict = @{
                               @"from": sendImageRequest.memberId,
                               @"type": @"image",
                               @"body": data
                               };
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:EVENTS_URL_FORMAT, self.baseUrl, sendImageRequest.conversationId]];
        
        [self requestToServer:dict url:url httpMethod:@"POST" completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
            NSString *textId = [data[@"id"]stringValue];
            if (error) {
                onError(error);
                return;
            }
            
            onSuccess(textId); // TODO: eventId;
        }];
    }];

}

- (void)deleteEventFromConversation:(nonnull NXMDeleteEventRequest*)deleteEventRequest
                         onSuccess:(SuccessCallback _Nullable)onSuccess
                           onError:(ErrorCallback _Nullable)onError {
    NSDictionary *dict = @{
                           @"from": deleteEventRequest.memberID,
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@/events/%ld", self.baseUrl, deleteEventRequest.conversationID,(long)deleteEventRequest.eventID]];
    
    NSString* requestType = @"DELETE";
    [self requestToServer:dict url:url httpMethod:requestType completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error) {
            onError(error);
            return;
        }
        
        onSuccess(); // TODO: eventId;
    }];
}

- (BOOL)getConversationsPaging:( NSString* _Nullable )name dateStart:( NSString* _Nullable )dateStart  dateEnd:( NSString* _Nullable )dateEnd pageSize:(long)pageSize recordIndex:(long)recordIndex order:( NSString* _Nullable )order completionBlock:(void (^_Nullable)(NSError * _Nullable error, NSArray<NXMConversationDetails*> * _Nullable data))completionBlock{
    NSDictionary *dict = @{
                           };
    //TODO:for now we get the first 100 conversations
    //we need to have support in the server to get all the conversations
    NSString* vars = @"";
    if (pageSize > 0){
        vars = [NSString stringWithFormat:@"pageSize:%ld",MIN(100,pageSize)];
    }
    if (recordIndex > 0){
        vars = [NSString stringWithFormat:@"%@&&recordIndex:%ld",vars,recordIndex];
    }
    if (name != nil){
        vars = [NSString stringWithFormat:@"%@&&name:%@",vars,name];
    }
    if (dateStart != nil){
        vars = [NSString stringWithFormat:@"%@&&dateStart:%@",vars,dateStart];
    }
    if (dateEnd != nil){
        vars = [NSString stringWithFormat:@"%@&&dateEnd:%@",vars,dateEnd];
    }
    if (order != nil){
        vars = [NSString stringWithFormat:@"%@&&order:%@",vars,order];
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations?%@", self.baseUrl, vars]];
    
    NSString* requestType = @"GET";
    [self requestToServer:dict url:url httpMethod:requestType completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data){
        if (data != nil){
            NSMutableArray *conversations = [[NSMutableArray alloc] init];
            for (NSDictionary* conversationJson in data[@"_embedded"][@"conversations"]){
                NXMConversationDetails *details = [NXMConversationDetails alloc];
                details.name = conversationJson[@"name"];
                details.uuid = conversationJson[@"uuid"];
                [conversations addObject:details];
            }
            completionBlock(nil, conversations);
        }
        else{
            completionBlock(error,nil);
        }
    }];
    return YES;
}


- (void)getConversations:(nonnull NXMGetConversationsRequest*)getConvetsationsRequest
               onSuccess:(SuccessCallbackWithConversations _Nullable)onSuccess
                 onError:(ErrorCallback _Nullable)onError {
    NSDictionary *dict = @{ };
    //TODO:for now we get the first 100 conversations
    //we need to have support in the server to get all the conversations
    NSString* vars = @"";
    if (getConvetsationsRequest.pageSize > 0){
        vars = [NSString stringWithFormat:@"pageSize:%ld",MIN(100,getConvetsationsRequest.pageSize)];
    }
    
    if (getConvetsationsRequest.recordIndex > 0){
        vars = [NSString stringWithFormat:@"%@&&recordIndex:%ld",vars,getConvetsationsRequest.recordIndex];
    }
    
    if ([getConvetsationsRequest.name length] > 0){
        vars = [NSString stringWithFormat:@"%@&&name:%@",vars,getConvetsationsRequest.name];
    }
    
    if ([getConvetsationsRequest.dateStart  length] > 0){
        vars = [NSString stringWithFormat:@"%@&&dateStart:%@",vars,getConvetsationsRequest.dateStart];
    }
    
    if ([getConvetsationsRequest.dateEnd  length] > 0){
        vars = [NSString stringWithFormat:@"%@&&dateEnd:%@",vars,getConvetsationsRequest.dateEnd];
    }
    
    if ([getConvetsationsRequest.order  length] > 0){
        vars = [NSString stringWithFormat:@"%@&&order:%@",vars,getConvetsationsRequest.order];
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations?%@", self.baseUrl, vars]];
    
    NSString* requestType = @"GET";
    [self requestToServer:dict url:url httpMethod:requestType completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data){
        if (error) {
            onError(error);
            return;
        }
        
        if (!data){
            onError([[NSError alloc] initWithDomain:NXMStitchErrorDomain code:NXMStitchErrorCodeUnknown userInfo:nil]);
            return;
        }
        
        NSMutableArray *conversations = [[NSMutableArray alloc] init];
        for (NSDictionary* conversationJson in data[@"_embedded"][@"conversations"]){
            NXMConversationDetails *details = [NXMConversationDetails alloc];
            details.name = conversationJson[@"name"];
            details.uuid = conversationJson[@"uuid"];
            [conversations addObject:details];
        }
        
        NXMPageInfo *pageInfo = [[NXMPageInfo alloc] initWithCount:data[@"count"]
                                                          pageSize:data[@"page_size"]
                                                       recordIndex:data[@"record_index"]];
    
        onSuccess(conversations, pageInfo);
    }];
}
- (void)getEvents:(NXMGetEventsRequest *)getEventsRequest onSuccess:(SuccessCallbackWithEvents)onSuccess onError:(ErrorCallback)onError{
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:EVENTS_URL_FORMAT, self.baseUrl, getEventsRequest.conversationId]];
    NSString* requestType = @"GET";
    
    NSDictionary *body = @{};
    if (getEventsRequest.startId && getEventsRequest.endId) {
        body = @{ @"start_id": getEventsRequest.startId,
                 @"end_id": getEventsRequest.endId
                  };
    };
    
    [self requestToServer:body url:url httpMethod:requestType completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data) {
        if (error){
            onError(error);
            return;
        }
        
        if (!data){
            onError([[NSError alloc] initWithDomain:NXMStitchErrorDomain code:NXMStitchErrorCodeUnknown userInfo:nil]);
            return;
        }
        
        NSMutableArray *events = [[NSMutableArray alloc] init];
        for (NSDictionary* eventJson in data) {
            NSString* type = eventJson[@"type"];
            if ([type isEqual:@"member:joined"]) {
                [events addObject:[self parseMemberEvent:@"joined" dict:eventJson conversationId:getEventsRequest.conversationId]];
                continue;
            }
            
            if ([type isEqual:@"member:invited"]){
                [events addObject:[self parseMemberEvent:@"invited" dict:eventJson conversationId:getEventsRequest.conversationId]];
                continue;
            }
            
            if ([type isEqual:@"member:left"]){
                [events addObject:[self parseMemberEvent:@"left" dict:eventJson conversationId:getEventsRequest.conversationId]];
                continue;
            }
            
            if ([type isEqual:@"member:media"]){
                [events addObject:[self parseMediaEvent:eventJson conversationId:getEventsRequest.conversationId]];
                continue;
            }
            
            if ([type isEqual:@"text:seen"]){
                [events addObject:[self parseTextStatusEvent:eventJson conversationId:getEventsRequest.conversationId state:NXMTextEventStatusESeen]];
                continue;
            }
            
            if ([type isEqual:@"text:delivered"]){
                [events addObject:[self parseTextStatusEvent:eventJson conversationId:getEventsRequest.conversationId
                                                       state:NXMTextEventStatusEDelivered]];
                continue;
            }
            
            if ([type isEqual:@"text"]){
                [events addObject:[self parseTextEvent:eventJson conversationId:getEventsRequest.conversationId]];
                continue;
            }
            
            if ([type isEqual:@"image"]){
                [events addObject:[self parseImageEvent:eventJson conversationId:getEventsRequest.conversationId]];

                // TODO: [events addObject:event];
                continue;
            }
            
            if ([type isEqual:@"image:seen"]){
                // TODO: [events addObject:event];
                continue;
            }
            
            if ([type isEqual:@"image:delivered"]) {
                //// TODO: [events addObject:event];
                continue;
            }
            
            if ([type isEqual:@"event:deleted"]) {
                [events addObject:[self parseTextStatusEvent:eventJson conversationId:getEventsRequest.conversationId state:NXMTextEventStatusEDeleted]];
                continue;
            }
            
            if ([type isEqual:@"sip:ringing"]) {
                [events addObject:[self parseSipEvent:eventJson conversationId:getEventsRequest.conversationId state:NXMSipEventRinging]];
                continue;
            }
            
            if ([type isEqual:@"sip:answered"]){
                [events addObject:[self parseSipEvent:eventJson conversationId:getEventsRequest.conversationId state:NXMSipEventAnswered]];
                continue;
            }
            
            if ([type isEqual:@"sip:hangup"]) {
                [events addObject:[self parseSipEvent:eventJson conversationId:getEventsRequest.conversationId state:NXMSipEventHangup]];
                continue;
            }
            
            if ([type isEqual:@"sip:status"]) {
                [events addObject:[self parseSipEvent:eventJson conversationId:getEventsRequest.conversationId state:NXMSipEventStatus]];
                continue;
            }

        }
        
        onSuccess(events);
    }];
}

- (void)getConversationEvents:(NSString *)conversationId
                    onSuccess:(SuccessCallbackWithConversationDetails _Nullable)onSuccess
                      onError:(ErrorCallback _Nullable)onError { // TODO: add start and end index
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:EVENTS_URL_FORMAT, self.baseUrl, conversationId]];
    NSString* requestType = @"GET";
    
    [self requestToServer:@{} url:url httpMethod:requestType completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data){
        if (error) {
            onError(error);
            return;
        }
        
        
    }];
}

- (void)getUserConversations:(NSString *)userId
                     onSuccess:(SuccessCallbackWithConversations _Nullable)onSuccess
                       onError:(ErrorCallback _Nullable)onError {
    NSDictionary *dict = @{
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/%@/conversations", self.baseUrl, userId]];
    [NXMLogger infoWithFormat:@"%@",url];
    
    NSString* requestType = @"GET";
    [self requestToServer:dict url:url httpMethod:requestType completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data){
        
        if (error) {
            onError(error);
            return;
        }
        
        if (!data){
            onError([[NSError alloc] initWithDomain:NXMStitchErrorDomain code:NXMStitchErrorCodeUnknown userInfo:nil]);
            return;
        }
        NSMutableArray *items = [NSMutableArray new];

        for (NSDictionary* detailsJson in data) {
            NXMConversationDetails *detail = [[NXMConversationDetails alloc] init];
            detail.displayName = detailsJson[@"display_name"];
            detail.members = @[];
            detail.name = detailsJson[@"name"];
            detail.sequence_number = [detailsJson[@"sequence_number"] integerValue];
            detail.uuid = detailsJson[@"id"];
            
            [items addObject:detail];
        }

        onSuccess(items, nil);
    }];
}


- (void)getConversationDetails:(nonnull NSString*)conversationId
                     onSuccess:(SuccessCallbackWithConversationDetails _Nullable)onSuccess
                       onError:(ErrorCallback _Nullable)onError {
    NSDictionary *dict = @{
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/conversations/%@", self.baseUrl, conversationId]];
    
    NSString* requestType = @"GET";
    [self requestToServer:dict url:url httpMethod:requestType completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data){
        
        if (error) {
            onError(error);
            return;
        }
        
        if (!data){
            onError([[NSError alloc] initWithDomain:NXMStitchErrorDomain code:NXMStitchErrorCodeUnknown userInfo:nil]);
            return;
        }
        
        [NXMLogger infoWithFormat:@"getConversationPressed result %@",data];

        NXMConversationDetails *details = [[NXMConversationDetails alloc] initWithId:conversationId];
        details.name = data[@"name"];
        details.created = data[@"timestamp"][@"created"];
        details.sequence_number = [data[@"sequence_number"] intValue];
        details.properties = data[@"properties"];
        details.uuid = data[@"uuid"];
        details.displayName = data[@"display_name"];
        
        NSMutableArray *members = [[NSMutableArray alloc] init];
        
        for (NSDictionary* memberJson in data[@"members"]) {
            NXMMember *member = [[NXMMember alloc] initWithMemberId:memberJson[@"member_id"] conversationId:conversationId user:memberJson[@"user_id"] name:memberJson[@"name"] state:memberJson[@"state"]];
            
            member.inviteDate = memberJson[@"timestamp"][@"invited"]; // TODO: NSDate
            member.joinDate = memberJson[@"timestamp"][@"joined"]; // TODO: NSDate
            member.leftDate = memberJson[@"timestamp"][@"left"]; // TODO: NSDate
            
            [members addObject:member];
        }
        
        details.members = members;
        onSuccess(details);
    }];
}


- (void)getUser:(nonnull NSString*)userId
        completionBlock:(void (^_Nullable)(NSError * _Nullable error, NXMUser * _Nullable data))completionBlock{
    NSDictionary *dict = @{
                           };
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/users/%@", self.baseUrl, userId]];
    
    NSString* requestType = @"GET";
    [self requestToServer:dict url:url httpMethod:requestType completionBlock:^(NSError * _Nullable error, NSDictionary * _Nullable data){
        if (data != nil){
            [NXMLogger infoWithFormat:@"getUser result %@",data];

            NXMUser *user = [NXMUser alloc];
            user.name = data[@"name"];
            user.uuid = data[@"id"];
           
            completionBlock(nil, user);
        }
        else{
            completionBlock(error,nil);
        }
    }];
}
#pragma mark - private

- (void)requestToServer:(nonnull NSDictionary*)dict url:(nonnull NSURL*)url httpMethod:(nonnull NSString*)httpMethod completionBlock:(void (^_Nullable)(NSError * _Nullable error, NSDictionary * _Nullable data))completionBlock{
    NSError *jsonErr;
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error: &jsonErr];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    
    [self addHeader:request];
    
    [request setHTTPMethod:httpMethod];
    [request setHTTPBody:jsonData];
    
    [self executeRequest:request responseBlock:completionBlock];
}

- (void)addHeader:(NSMutableURLRequest *)request {
    [request setValue:[NSString stringWithFormat:@"bearer %@", self.token] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
}

- (void)executeRequest:(NSURLRequest *)request  responseBlock:(void (^_Nullable)(NSError * _Nullable error, NSDictionary *      _Nullable data))responseBlock {
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            // TODO: network error
            responseBlock(error, nil);
            [NXMLogger infoWithFormat:@"Got response %@ with error %@.\n", response, error];

            return;
        }
        
        // TODO: 413 Payload too large
        if (((NSHTTPURLResponse *)response).statusCode != 200){
            // TODO: map code from error msg
            NSDictionary* dataDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSError *resError = [[NSError alloc] initWithDomain:NXMStitchErrorDomain code:[NXMErrorParser parseErrorWithData:data] userInfo:dataDict];
            responseBlock(resError, nil);
            return;
        }
        
        
        NSError *jsonError;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!jsonDict || jsonError) {
            // TODO: map code from error msg
            NSError *resError = [[NSError alloc] initWithDomain:NXMStitchErrorDomain code:[NXMErrorParser parseErrorWithData:data] userInfo:nil];
            responseBlock(resError, nil);
            return;
        }
        
        responseBlock(nil, jsonDict);
        
    }] resume];
}

- (NSString*)getType:(nonnull NSDictionary*)dict{
    return dict[@"type"];
}
- (NSString*)getSequenceId:(nonnull NSDictionary*)dict{
    return dict[@"id"];
}
- (NSString*)getFromMemberId:(nonnull NSDictionary*)dict{
    return dict[@"from"];
}
- (NSDate*)getCreationDate:(nonnull NSDictionary*)dict{
    return dict[@"timestamp"];
}

- (NXMMemberEvent* )parseMemberEvent:(nonnull NSString*)state dict:(nonnull NSDictionary*)dict conversationId:(nonnull NSString*)conversationId{
    NXMMemberEvent* event = [NXMMemberEvent alloc];
    event.sequenceId = [[self getSequenceId:dict] integerValue];
    event.conversationId = conversationId;
    event.fromMemberId = [self getFromMemberId:dict];
    event.creationDate = [self getCreationDate:dict];
    event.type = NXMEventTypeMember;
    event.state = state;
    event.memberId = dict[@"body"][@"user"][@"member_id"];
    event.name = dict[@"body"][@"user"][@"name"];
    event.user = [NXMUser alloc];
    event.user.name = dict[@"body"][@"user"][@"name"];
    event.user.uuid = dict[@"body"][@"user"][@"user_id"];
    return event;
}

- (NXMMediaEvent* )parseMediaEvent:(nonnull NSDictionary*)dict conversationId:(nonnull NSString*)conversationId{
    NXMMediaEvent* event = [NXMMediaEvent alloc];
    event.sequenceId = [[self getSequenceId:dict] integerValue];
    event.conversationId = conversationId;
    event.fromMemberId = [self getFromMemberId:dict];
    event.creationDate = [self getCreationDate:dict];
    event.type = NXMEventTypeMedia;
    event.mediaSettings = [NXMMediaSettings new];
    if (dict[@"body"][@"audio"]){
        event.mediaSettings.isEnabled = [dict[@"body"][@"audio_settings"][@"enabled"] boolValue];
        event.mediaSettings.isSuspended = [dict[@"body"][@"audio_settings"][@"muted"] boolValue];
    }
    else if (dict[@"body"][@"video"]){
        event.mediaSettings.isEnabled = [dict[@"body"][@"video_settings"][@"enabled"] boolValue];
        event.mediaSettings.isSuspended = [dict[@"body"][@"video_settings"][@"muted"] boolValue];
    }
    return event;
}

- (NXMSipEvent* )parseSipEvent:(nonnull NSDictionary*)dict conversationId:(nonnull NSString*)conversationId state:(NXMSipEventType )state{
    NXMSipEvent * event = [NXMSipEvent alloc];
    event.sequenceId = [[self getSequenceId:dict] integerValue];
    event.conversationId = conversationId;
    event.fromMemberId = [self getFromMemberId:dict];
    event.creationDate = [self getCreationDate:dict];
    event.type = NXMEventTypeSip;
    event.sipType = state;
    event.phoneNumber = dict[@"body"][@"channel"][@"to"][@"number"];
    event.applicationId = dict[@"application_id"];
    
    return event;
}
- (NXMTextStatusEvent* )parseTextStatusEvent:(nonnull NSDictionary*)dict conversationId:(nonnull NSString*)conversationId state:(NXMTextEventStatusE )state{
    NXMTextStatusEvent * event = [NXMTextStatusEvent alloc];
    event.sequenceId = [[self getSequenceId:dict] integerValue];
    event.conversationId = conversationId;
    event.fromMemberId = [self getFromMemberId:dict];
    event.creationDate = [self getCreationDate:dict];
    event.type = NXMEventTypeTextStatus;
    event.status = state;
    event.eventId = [dict[@"body"][@"event_id"] integerValue];
    
    return event;
}

- (NXMTextEvent *)parseTextEvent:(nonnull NSDictionary*)dict conversationId:(nonnull NSString*)conversationId {
    NXMTextEvent* event = [NXMTextEvent alloc];
    event.sequenceId = [[self getSequenceId:dict] integerValue];
    event.conversationId = conversationId;
    event.fromMemberId = [self getFromMemberId:dict];
    event.creationDate = [self getCreationDate:dict];
    event.type = NXMEventTypeText;
    event.text = dict[@"body"][@"text"];
    event.state = [self parseStateFromDictionary:dict[@"state"]];
    return event;
}

- (NXMImageEvent *)parseImageEvent:(nonnull NSDictionary*)json conversationId:(nonnull NSString*)conversationId {
    
    NXMImageEvent *imageEvent = [[NXMImageEvent alloc] initWithConversationId:conversationId
                                                                   sequenceId:[json[@"id"] integerValue]
                                                                 fromMemberId:json[@"from"]
                                                                 creationDate:json[@"timestamp"]
                                                                         type:NXMEventTypeImage];
    NSDictionary *body = json[@"body"][@"representations"];
    imageEvent.imageId = body[@"id"];
    NSDictionary *originalJSON = body[@"original"];
    imageEvent.originalImage = [[NXMImageInfo alloc] initWithUuid:originalJSON[@"id"]
                                                             size:[originalJSON[@"size"] integerValue]
                                                              url:originalJSON[@"url"]
                                                             type:NXMImageTypeOriginal];
    
    NSDictionary *mediumJSON = body[@"medium"];
    imageEvent.mediumImage = [[NXMImageInfo alloc] initWithUuid:mediumJSON[@"id"]
                                                           size:[mediumJSON[@"size"] integerValue]
                                                            url:mediumJSON[@"url"]
                                                           type:NXMImageTypeMedium];
    
    
    NSDictionary *thumbnailJSON = body[@"thumbnail"];
    imageEvent.thumbnailImage = [[NXMImageInfo alloc] initWithUuid:thumbnailJSON[@"id"]
                                                              size:[thumbnailJSON[@"size"] integerValue]
                                                               url:thumbnailJSON[@"url"]
                                                              type:NXMImageTypeThumbnail];
    imageEvent.type = NXMEventTypeImage;
    
    imageEvent.state = [self parseStateFromDictionary:json[@"state"]];
    return imageEvent;
}

-(NSDictionary<NSNumber *,NSDictionary<NSString *, NSDate *> *> *)parseStateFromDictionary:(NSDictionary *)dictionary {
    if(![dictionary isKindOfClass:[NSDictionary class]]) {
        return @{@(NXMEventStateSeenBy):@{},
                 @(NXMEventStateDelievredTo):@{}
                 };
    }
    return  @{ @(NXMEventStateSeenBy):[self parseFromSpecificStateDictionary:dictionary[@"seen_by"]],
               @(NXMEventStateDelievredTo):[self parseFromSpecificStateDictionary:dictionary[@"delivered_to"]]
             };
}

-(NSDictionary<NSString *, NSDate *> *)parseFromSpecificStateDictionary:(NSDictionary *)specificStateDictionary {
    NSMutableDictionary<NSString *, NSDate *> *outputDictionary = [[NSMutableDictionary alloc] init];
    for (NSString *key in specificStateDictionary) {
        outputDictionary[key] = [NXMUtils dateFromISOString:specificStateDictionary[key]];
    }
    return outputDictionary;
}

- (NSString *)hexadecimalString:(NSData *)data {
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */
    
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    
    if (!dataBuffer)
        return [NSString string];
    
    NSUInteger          dataLength  = [data length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    
    return [NSString stringWithString:hexString];
}


@end
