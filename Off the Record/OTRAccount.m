//
//  OTRAccount.m
//  Off the Record
//
//  Created by David Chiles on 3/28/14.
//  Copyright (c) 2014 Chris Ballinger. All rights reserved.
//

#import "OTRAccount.h"
#import "SSKeychain.h"
#import "OTRLog.h"

#import "OTRXMPPAccount.h"
#import "OTRXMPPTorAccount.h"
#import "OTRGoogleOAuthXMPPAccount.h"
#import "OTRFacebookOAuthXMPPAccount.h"

const struct OTRAccountAttributes OTRAccountAttributes = {
	.autologin = @"autologin",
	.displayName = @"displayName",
    .accountType = @"accountType",
	.rememberPassword = @"rememberPassword",
	.username = @"username"
};

NSString *const OTRAimImageName               = @"aim.png";
NSString *const OTRGoogleTalkImageName        = @"gtalk.png";
NSString *const OTRXMPPImageName              = @"xmpp.png";
NSString *const OTRXMPPTorImageName           = @"xmpp-tor-logo.png";

@interface OTRAccount ()

@property (nonatomic) OTRAccountType accountType;

@end

@implementation OTRAccount

- (id)init
{
    if(self = [super init])
    {
        self.accountType = OTRAccountTypeNone;
    }
    return self;
}

- (id)initWithAccountType:(OTRAccountType)accountType
{
    if (self = [self init]) {
        
        self.accountType = accountType;
    }
    return self;
}

- (OTRProtocolType)protocolType
{
    return OTRProtocolTypeNone;
}

- (UIImage *)accountImage
{
    return nil;
}

- (NSString *)accountDisplayName
{
    return @"";
}

- (NSString *)protocolTypeString
{
    return @"";
}

- (Class)protocolClass {
    return nil;
}

- (void)setPassword:(NSString *) password {
    
    if (!password.length || !self.rememberPassword) {
        NSError *error = nil;
        [SSKeychain deletePasswordForService:kOTRServiceName account:self.uniqueId error:&error];
        if (error) {
            DDLogError(@"Error deleting password from keychain: %@%@", [error localizedDescription], [error userInfo]);
        }
        return;
    }
    NSError *error = nil;
    [SSKeychain setPassword:password forService:kOTRServiceName account:self.uniqueId error:&error];
    if (error) {
        DDLogError(@"Error saving password to keychain: %@%@", [error localizedDescription], [error userInfo]);
    }
}

- (NSString *)password {
    if (!self.rememberPassword) {
        return nil;
    }
    NSError *error = nil;
    NSString *password = [SSKeychain passwordForService:kOTRServiceName account:self.uniqueId error:&error];
    if (error) {
        DDLogError(@"Error retreiving password from keychain: %@%@", [error localizedDescription], [error userInfo]);
        error = nil;
    }
    return password;
}


#pragma mark NSCoding
- (instancetype)initWithCoder:(NSCoder *)decoder // NSCoding deserialization
{
    if (self = [super initWithCoder:decoder]) {
        self.autologin = [decoder decodeBoolForKey:OTRAccountAttributes.autologin];
        self.rememberPassword = [decoder decodeBoolForKey:OTRAccountAttributes.rememberPassword];
        self.displayName = [decoder decodeObjectForKey:OTRAccountAttributes.displayName];
        self.accountType = [decoder decodeIntForKey:OTRAccountAttributes.accountType];
        self.username = [decoder decodeObjectForKey:OTRAccountAttributes.username];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder // NSCoding serialization
{
    [super encodeWithCoder:encoder];
    
    [encoder encodeBool:self.autologin forKey:OTRAccountAttributes.autologin];
    [encoder encodeBool:self.rememberPassword forKey:OTRAccountAttributes.rememberPassword];
    [encoder encodeInt:self.accountType forKey:OTRAccountAttributes.accountType];
    [encoder encodeObject:self.displayName forKey:OTRAccountAttributes.displayName];
    [encoder encodeObject:self.username forKey:OTRAccountAttributes.username];
    
}

#pragma - mark Class Methods

+(OTRAccount *)accountForAccountType:(OTRAccountType)accountType
{
    OTRAccount *account = nil;
    if (accountType == OTRAccountTypeJabber) {
        account = [[OTRXMPPAccount alloc] initWithAccountType:accountType];
    }
    else if (accountType == OTRAccountTypeXMPPTor) {
        account = [[OTRXMPPTorAccount alloc] initWithAccountType:accountType];
    }
    else if (accountType == OTRAccountTypeGoogleTalk) {
        account = [[OTRGoogleOAuthXMPPAccount alloc] initWithAccountType:accountType];
    }
    else if (accountType == OTRAccountTypeFacebook) {
        account = [[OTRFacebookOAuthXMPPAccount alloc] initWithAccountType:accountType];
    }
    
    return account;
}

+ (OTRAccount *)fetchAccountWithUsername:(NSString *)username protocolType:(OTRProtocolType)protocolType transaction:(YapDatabaseReadTransaction*)transaction
{
    __block OTRAccount *finalAccount = nil;
    [transaction enumerateKeysAndObjectsInCollection:[OTRAccount collection] usingBlock:^(NSString *key, OTRAccount *account, BOOL *stop) {
        if ([account isKindOfClass:[OTRAccount class]]) {
            if ([account.username isEqualToString:username] && account.protocolType == protocolType) {
                finalAccount = account;
                *stop = YES;
            }
        }
    }];
    return finalAccount;
    
}
+ (NSArray *)allAccountsWithTransaction:(YapDatabaseReadTransaction*)transaction
{
    NSMutableArray *accounts = [NSMutableArray array];
    NSArray *allAccountKeys = [transaction allKeysInCollection:[OTRAccount collection]];
    [allAccountKeys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [accounts addObject:[transaction objectForKey:obj inCollection:[OTRAccount collection]]];
    }];
    
    return [accounts copy];
    
}

@end
