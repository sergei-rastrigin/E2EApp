//
//  NXMTestAppUserInfo.m
//  NexmoTestApp
//
//  Created by Doron Biaz on 12/11/18.
//  Copyright © 2018 Vonage. All rights reserved.
//

#import "NTAUserInfo.h"

@implementation NTAUserInfo
-(instancetype)initWithName:(NSString *)name password:(NSString *)password displayName:(NSString *)displayName csUserName:(NSString *)csUserName csUserId:(NSString *)csUserId csUserToken:(NSString *)csUserToken {
    if(self = [super init]) {
        self.name = name;
        self.password = password;
        self.displayName = displayName;
        self.csUserName = csUserName;
        self.csUserId = csUserId;
        self.csUserToken = csUserToken;
        self.initials = [self initialsWithDisplayName:self.displayName];
    }
    return self;
}

- (NSString *)initialsWithDisplayName:(NSString *)displayName {
    NSArray<NSString *> *commaSeperatedWords = [displayName componentsSeparatedByString:@" "];
    NSString *initials = @"";
    for (NSString *word in commaSeperatedWords) {
        if(word.length) {
            initials = [initials stringByAppendingString:[[word uppercaseString] substringToIndex:1]];
        }
    }
    return initials;
}
@end