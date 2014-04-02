//
//  OTRNewBuddyViewController.m
//  Off the Record
//
//  Created by David on 3/4/13.
//  Copyright (c) 2013 Chris Ballinger. All rights reserved.
//

#import "OTRNewBuddyViewController.h"
#import "OTRInLineTextEditTableViewCell.h"
#import "OTRProtocolManager.h"
#import <QuartzCore/QuartzCore.h>
#import "Strings.h"
#import "OTRXMPPManager.h"
#import "OTRDatabaseManager.h"

#import "OTRAccount.h"
#import "OTRBuddy.h"

@interface OTRNewBuddyViewController ()

@property (nonatomic) BOOL isXMPPaccount;

@end

@implementation OTRNewBuddyViewController

-(id)initWithAccountId:(NSString *)accountId {
    
    if (self = [super init]) {
        
        [[OTRDatabaseManager sharedInstance].mainThreadReadOnlyDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            self.account = [OTRAccount fetchObjectWithUniqueID:accountId transaction:transaction];
        }];

    }
    return self;
    
}

-(void)setAccount:(OTRAccount *)account
{
    self.isXMPPaccount = [[account protocolClass] isSubclassOfClass:[OTRXMPPManager class]];
    _account = account;
    
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return self.account.username;
    }
    return @"";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = ADD_BUDDY_STRING;
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(doneButtonPressed:)];
    
    
    self.accountNameTextField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.accountNameTextField.placeholder = REQUIRED_STRING;
    
    if (self.isXMPPaccount) {
        self.displayNameTextField = [[UITextField alloc] initWithFrame:CGRectZero];
        self.displayNameTextField.placeholder = OPTIONAL_STRING;
        self.accountNameTextField.delegate= self.displayNameTextField.delegate = self;
        
        self.displayNameTextField.autocapitalizationType = self.accountNameTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.displayNameTextField.autocorrectionType = self.accountNameTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    }
    
    
    
    UITableView * tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.scrollEnabled = NO;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    [self.view addSubview:tableView];
    
    [self.accountNameTextField becomeFirstResponder];
	// Do any additional setup after loading the view.
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.isXMPPaccount) {
        return 2;
    }
    return 1;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * cellType = @"Cell";
    UITextField * textField = nil;
    NSString * cellText = nil;
    
    if (indexPath.row == 0) {
        textField = self.accountNameTextField;
        cellText = EMAIL_STRING;
    }
    else if(indexPath.row == 1) {
        textField = self.displayNameTextField;
        cellText = NAME_STRING;
    }
    
    OTRInLineTextEditTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:cellType];
    if (!cell) {
        cell = [[OTRInLineTextEditTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellType];
    }
    cell.textLabel.text = cellText;
    [cell layoutIfNeeded];
    cell.textField = textField;
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

-(BOOL)checkFields
{
    if ([[self.accountNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]) {
        return YES;
    }
    else
    {
        return NO;
    }
}

-(void)updateReturnButtons:(UITextField *)textField;
{
    if ([self checkFields] && [[self.accountNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] &&[[self.displayNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]) {
        textField.returnKeyType = UIReturnKeyDone;
    }
    else if ([textField isEqual:self.accountNameTextField]) {
        textField.returnKeyType = UIReturnKeyNext;
    }
    else if ([textField isEqual:self.displayNameTextField] && ![self checkFields])
    {
        textField.returnKeyType = UIReturnKeyNext;
    }
    else
    {
        textField.returnKeyType = UIReturnKeyDone;
    }
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self updateReturnButtons:textField];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField.returnKeyType == UIReturnKeyDone ) {
        [self doneButtonPressed:textField];
    }
    else{
        [textField resignFirstResponder];
        if ([textField isEqual:self.accountNameTextField]) {
            [self.displayNameTextField becomeFirstResponder];
        }
        else{
            [self.accountNameTextField becomeFirstResponder];
        }
    }
    
    return NO;
}

-(void)cancelButtonPressed:(id)sender
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}
-(void)doneButtonPressed:(id)sender
{
    if ([self checkFields]) {
        NSString * newBuddyAccountName = [[self.accountNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
        NSString * newBuddyDisplayName = [self.displayNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        __block OTRBuddy *buddy = nil;
        [[OTRDatabaseManager sharedInstance].readWriteDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            buddy = [OTRBuddy fetchBuddyWithUsername:newBuddyAccountName withAccountUniqueId:self.account.uniqueId transaction:transaction];
            if (!buddy) {
                buddy = [[OTRBuddy alloc] init];
                buddy.username = newBuddyAccountName;
                buddy.accountUniqueId = self.account.uniqueId;
            }
            
            buddy.displayName = newBuddyDisplayName;
            [transaction setObject:buddy forKey:buddy.uniqueId inCollection:[OTRBuddy collection]];
        }];
        
        id<OTRProtocol> protocol = [[OTRProtocolManager sharedInstance] protocolForAccount:self.account];
        [protocol addBuddy:buddy];
        
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        
        [UIView animateWithDuration:.3 animations:^{
            self.accountNameTextField.backgroundColor = [UIColor colorWithRed: 0.734 green: 0.124 blue: 0.124 alpha: .8];
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:.3 animations:^{
                self.accountNameTextField.backgroundColor = [UIColor clearColor];
            } completion:NULL];
        }];
        
    }
    
}

@end
