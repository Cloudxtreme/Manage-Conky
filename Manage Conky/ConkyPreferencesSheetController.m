//
//  ConkyPreferencesSheetController.m
//  Manage Conky
//
//  Created by Nickolas Pylarinos on 09/09/2017.
//  Copyright © 2017 Nickolas Pylarinos. All rights reserved.
//

#import "ConkyPreferencesSheetController.h"

#import <ServiceManagement/ServiceManagement.h>
#import "PFMoveApplication.h"
#import <unistd.h>

/* defines */
#define kConkyAgentPlistName @"org.npyl.conky.plist"

#define CONKY_BUNDLE_IDENTIFIER "org.npyl.conky"
#define CONKYX_PATH             "/Applications/ConkyX.app"

#define kConkyLaunchAgentLabel  @"org.npyl.conky"
#define kConkyExecutablePath    @"/Applications/ConkyX.app/Contents/Resources/conky"

#define CONKYX          @"/Applications/ConkyX.app"
#define MANAGE_CONKY    @"/Applications/Manage Conky.app"
#define CONKY_SYMLINK   @"/usr/local/bin/conky"

@interface OnlyIntegerValueFormatter : NSNumberFormatter
@end

@implementation OnlyIntegerValueFormatter

- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**)newString errorDescription:(NSString**)error
{
    if([partialString length] == 0)
    {
        return NO;
    }
    
    /* accept until 3 digits */
    if ([partialString length] > 3)
    {
        return NO;
    }
    
    NSScanner* scanner = [NSScanner scannerWithString:partialString];
    
    if(!([scanner scanInt:0] && [scanner isAtEnd])) {
        NSBeep();
        return NO;
    }
    
    return YES;
}

@end

@implementation ConkyPreferencesSheetController
/* helper functions */
- (void)showAlertWithMessageText:(NSString*)msg informativeText:(NSString*)info andAlertStyle:(NSAlertStyle)style
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msg];
    [alert setInformativeText:info];
    [alert setAlertStyle:style];
    [alert beginSheetModalForWindow:[super sheet] completionHandler:^(NSModalResponse returnCode) {}];
}

- (void)show_error_alert:(NSString*)withErrorMsg
{
    [self showAlertWithMessageText:@"Error" informativeText:withErrorMsg andAlertStyle:NSAlertStyleCritical];
}
/* end of helper functions */



- (IBAction)activatePreferencesSheet:(id)sender
{
    [super activateSheet:@"ConkyPreferences"];
    
    /* Is ConkyX already installed? */
    conkyXInstalled = (access(CONKYX_PATH, F_OK) == 0);
    
    // Install / Uninstall Button
    [_un_in_stallConkyButton setTitle:conkyXInstalled ? @"Uninstall Conky" : @"Install Conky"];
    [_un_in_stallConkyButton setEnabled:YES];
    
    // Startup Delay
    startupDelay = 20;  /* default value */
    
    if (conkyXInstalled)
    {
        /* Is conky agent present? */
        NSString* conkyAgentPlistPath = [NSString stringWithFormat:@"%@/Library/LaunchAgents/%@", NSHomeDirectory(), kConkyAgentPlistName];
        
        conkyAgentPresent = (access([conkyAgentPlistPath UTF8String], R_OK) == 0);
        
        if (conkyAgentPresent)
            [_runConkyAtStartupCheckbox setState:1];
        else
            NSLog(@"Agent plist doesnt exist or not accessible!");
        
        /* Conky configuration file location? */
        NSString * conkyConfigsPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"configsLocation"];
        
        if (!conkyConfigsPath)
        {
            NSString *kConkyConfigsDefaultPath = [NSString stringWithFormat:@"%@/.conky", NSHomeDirectory()];
            
            [[NSUserDefaults standardUserDefaults] setObject:kConkyConfigsDefaultPath forKey:@"configsLocation"];
            conkyConfigsPath = kConkyConfigsDefaultPath;
        }
        
        [_conkyConfigLocationTextfield setStringValue:conkyConfigsPath];
        [_conkyConfigLocationTextfield setDelegate:self];       /* Catch Enter-Key notification */
    }
    else
    {
        [_conkyConfigLocationTextfield setEnabled:NO];
        [_runConkyAtStartupCheckbox setEnabled:NO];
        [_conkyConfigFilesLocationLabel setTextColor:[NSColor grayColor]];
        [_startupDelayStepper setEnabled:NO];
        [_startupDelayField setEnabled:NO];
        [_startupDelayLabel setTextColor:[NSColor grayColor]];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    /*
     * See if it was due to key ENTER
     */
    
    if ( [[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] == NSReturnTextMovement )
    {
        [[NSUserDefaults standardUserDefaults] setObject:[_conkyConfigLocationTextfield stringValue] forKey:@"configsLocation"];
    }
}

- (IBAction)runConkyAtStartupCheckboxAction:(id)sender
{
    NSString *conkyAgentPlistPath = [NSString stringWithFormat:@"/Users/%@/Library/LaunchAgents/%@", NSUserName(), kConkyAgentPlistName];
    
    if ([sender state] == NSOffState)
    {
        NSLog(@"Request to remove the Agent!");
        
        /* SMJobRemove() deprecated but suggested by Apple, see https://lists.macosforge.org/pipermail/launchd-dev/2016-October/001229.html */
        SMJobRemove(kSMDomainUserLaunchd, CFSTR(CONKY_BUNDLE_IDENTIFIER), nil, YES, nil);
        
        unlink([conkyAgentPlistPath UTF8String]);
    }
    else
    {
        NSLog(@"Request to add the Agent!");
        
        id objects[] = { kConkyLaunchAgentLabel, @[ kConkyExecutablePath ], [NSNumber numberWithBool:YES], [NSNumber numberWithBool:YES] };
        id keys[] = { @"Label", @"ProgramArguments", @"RunAtLoad", @"KeepAlive" };
        NSUInteger count = sizeof(objects) / sizeof(id);
        
        NSDictionary *conkyAgentPlist = [NSDictionary dictionaryWithObjects:objects forKeys:keys count:count];
        
        NSAlert *keepAlivePrompt = [[NSAlert alloc] init];
        [keepAlivePrompt setMessageText:@"Select your preference"];
        [keepAlivePrompt setInformativeText:@"Always restart conky when for some reason it quits?"];
        [keepAlivePrompt setAlertStyle:NSAlertStyleInformational];
        [keepAlivePrompt addButtonWithTitle:@"Yes"];
        [keepAlivePrompt addButtonWithTitle:@"No"];
        
        NSModalResponse response = [keepAlivePrompt runModal];
        switch (response)
        {
            case NSAlertSecondButtonReturn:
                objects[3] = [NSNumber numberWithBool:NO];
                break;
        }
        
        [conkyAgentPlist writeToFile:conkyAgentPlistPath atomically:YES];
    }
}

// XXX must fix the text field
- (IBAction)modifyStartupDelay:(id)sender
{
    _startupDelayField.integerValue = [sender integerValue];
    startupDelay = [sender intValue];
}

- (IBAction)un_in_stallConky:(id)sender
{
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (conkyXInstalled)
    {
        /*
         * Uninstall conky
         */
        
        [fm removeItemAtPath:CONKYX error:&error];
        if (error)
        {
            [self show_error_alert:@"Error removing ConkyX"];
            NSLog(@"Error removing ConkyX: \n\n%@", error);
            return;
        }
        
        [fm removeItemAtPath:MANAGE_CONKY error:&error];
        if (error)
        {
            [self show_error_alert:@"Error removing Manage Conky.app"];
            NSLog(@"Error removing Manage Conky: \n\n%@", error);
            return;
        }
        
        [fm removeItemAtPath:CONKY_SYMLINK error:&error];
        if (error)
        {
            NSLog(@"Error removing symlink: \n\n%@", error);
        }
        
        /* create Successfully Installed message */
        NSAlert *successfullyUninstalled = [[NSAlert alloc] init];
        [successfullyUninstalled setMessageText:@"Successfully uninstalled!"];
        [successfullyUninstalled setInformativeText:@"conky (ConkyX and ManageConky) was successfully uninstalled from your computer. Manage Conky will now quit"];
        [successfullyUninstalled runModal];
        
        /* exit */
        exit(0);
    }
    else
    {
        /*
         * Install Conky
         */
        
        /*
         * Copy ConkyX.app to /Applications
         * using code from LetsMove to handle many cases
         * such as dmg, authentication etc.
         */
        CXForciblyMoveToApplicationsFolderConkyX();
        
        /* disable the Install/Uninstall button */
        [_un_in_stallConkyButton setEnabled:NO];
        
        /* create ConkyInstaller sheet */
        ctl = [[ConkyInstallerSheetController alloc] init];
        [[NSBundle mainBundle] loadNibNamed:@"ConkyInstaller" owner:ctl topLevelObjects:nil];
        [ctl beginInstalling];
    }
}

- (IBAction)okButtonPressed:(id)sender
{
    // Save whatever info we got from the sheet
    // Write Startup Delay
    // ...
    // ...
    NSLog(@"startupDelay: %li", (long)startupDelay);
    
    [super closeSheet:[super sheet]];
}

@end
