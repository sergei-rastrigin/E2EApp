//
//  ConversationListTableCellView.h
//  StitchTestApp
//
//  Created by Chen Lev on 5/24/18.
//  Copyright © 2018 Vonage. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NXMConversationDetails.h"

@class NXMConversationDetails;

@interface ConversationListTableCellView : UITableViewCell

-(void)updateWithConversation:(NXMConversationDetails*)conversation;
- (NXMConversationDetails *)getConversation;

@end