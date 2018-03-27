//
//  ConkyInstallerSheetController.m
//  Manage Conky
//
//  Created by Nikolas Pylarinos on 02/03/2018.
//  Copyright © 2018 Nickolas Pylarinos. All rights reserved.
//

#import "ConkyInstallerSheetController.h"

#import "PFMoveApplication.h"
#import "NSAlert+runModalSheet.h"
#import <Foundation/NSFileManager.h>
#import <CoreFoundation/CoreFoundation.h>
#import <ServiceManagement/ServiceManagement.h>

#define MANAGE_CONKY_PATH "/Applications/Manage Conky.app"
#define HOMEBREW_PATH "/usr/local/bin/brew"
#define XQUARTZ_PATH  "/usr/X11"

@implementation ConkyInstallerSheetController

BOOL blessHelperWithLabel(NSString *label, CFErrorRef *error)
{
    BOOL result = NO;
    
    AuthorizationItem authItem        = { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
    AuthorizationRights authRights    = { 1, &authItem };
    AuthorizationFlags flags          = kAuthorizationFlagDefaults |
                                        kAuthorizationFlagInteractionAllowed    |
                                        kAuthorizationFlagPreAuthorize    |
                                        kAuthorizationFlagExtendRights;
    
    AuthorizationRef authRef = NULL;
    
    /* Obtain the right to install privileged helper tools (kSMRightBlessPrivilegedHelper). */
    OSStatus status = AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, flags, &authRef);
    if (status != errAuthorizationSuccess) {
        NSLog( @"Failed to create AuthorizationRef. Error code: %d", (int)status );
        
    } else {
        /* This does all the work of verifying the helper tool against the application
         * and vice-versa. Once verification has passed, the embedded launchd.plist
         * is extracted and placed in /Library/LaunchDaemons and then loaded. The
         * executable is placed in /Library/PrivilegedHelperTools.
         */
        result = SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)label, authRef, error);
    }
    
    return result;
}

- (void)writeToLog:(NSString *)str
{
    _logField.stringValue = [_logField.stringValue stringByAppendingString:str];
}

- (void)receivedData:(NSNotification*)notif
{
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        /* if data is found, re-register for more data (and print) */
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self writeToLog:str];
        });
    }
};

- (void)installMissingLibraries
{
    /*
     * setup the installer script task
     */
    NSPipe *outputPipe = [[NSPipe alloc] init];
    NSPipe *errorPipe = [[NSPipe alloc] init];
    
    NSString *scriptPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/InstallLibraries.sh"];
    
    NSTask *script = [[NSTask alloc] init];
    [script setLaunchPath:@"/bin/sh"];
    [script setArguments:@[scriptPath]];
    [script setStandardOutput:outputPipe];
    [script setStandardError:errorPipe];
    
    NSFileHandle *outputHandle = [outputPipe fileHandleForReading];
    NSFileHandle *errorHandle = [errorPipe fileHandleForReading];
    
    [outputHandle waitForDataInBackgroundAndNotify];
    [errorHandle waitForDataInBackgroundAndNotify];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name:NSFileHandleDataAvailableNotification object:outputHandle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name:NSFileHandleDataAvailableNotification object:errorHandle];
    
    [script setTerminationHandler:^(NSTask *task) {
        dispatch_async(dispatch_get_main_queue(),
                       ^{
                           [_progressIndicator stopAnimation:nil];
                           
                           NSAlert *alert = [[NSAlert alloc] init];
                           [alert setMessageText:@"Conky Finished Installing"];
                           [alert beginSheetModalForWindow:_window completionHandler:^(NSModalResponse returnCode)
                            {
                                NSError *error = nil;
                                NSFileManager *fm = [[NSFileManager alloc] init];
                                
                                if (![fm createSymbolicLinkAtPath:@"/usr/local/bin/conky" withDestinationPath:@"/Applications/ConkyX.app/Contents/Resources/conky" error:&error])
                                {
                                    NSLog(@"Error creating symbolic link to /usr/local/bin: %@", error);
                                }
                                
                                [_doneButton setEnabled:YES];
                            }];
                       });
    }];
    
    /*
     * run the installer script
     */
    [script launch];
}

- (void)beginInstalling
{
    [_progressIndicator startAnimation:nil];
    
    /*
     * detect if Homebrew is installed
     */
    if (access(HOMEBREW_PATH, F_OK) != 0)
    {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://brew.sh"]];
        
        NSExtendedAlert *hbalert = [[NSExtendedAlert alloc] init];
        [hbalert setMessageText:@"Homebrew missing"];
        [hbalert setInformativeText:@"Install Homebrew first using the link I opened in the browser.\nOnce you install click OK to continue"];
        [hbalert setAlertStyle:NSAlertStyleCritical];
        [hbalert runModalSheetForWindow:_window];
    }
    
    /*
     * detect if XQuartz is installed
     */
    if (access(XQUARTZ_PATH, F_OK) != 0)
    {
        [self writeToLog:@"XQuartz is missing, downloading...\n\n"];
        
        //
        // Publish some info for the Helper to know.
        //
        /*
#define SHARED_DEFAULTS_DATABASE_NAME       @"ManageConky-Helper"
#define XQUARTZ_DOWNLOAD_URL_ENV_VARIABLE   @"CONKYX_XQUARTZ_DOWNLOAD_URL"
        NSUserDefaults *helperAndMeSharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:SHARED_DEFAULTS_DATABASE_NAME];
        [helperAndMeSharedDefaults setObject:@"https://dl.bintray.com/xquartz/downloads/XQuartz-2.7.11.dmg" forKey:XQUARTZ_DOWNLOAD_URL_ENV_VARIABLE];
        [helperAndMeSharedDefaults synchronize]; */

        //
        // Must start the Helper
        //
#define kSMJOBBLESSHELPER_IDENTIFIER @"org.npyl.ManageConkySMJobBlessHelper"
#define SMJOBBLESSHELPER_IDENTIFIER "org.npyl.ManageConkySMJobBlessHelper"
        
        CFErrorRef error = nil;
        if (!blessHelperWithLabel(kSMJOBBLESSHELPER_IDENTIFIER, &error))
        {
            NSLog(@"Failed to bless helper. Error: %@", (__bridge NSError *)error);
            return;
        }
        
        xpc_connection_t connection = xpc_connection_create_mach_service(SMJOBBLESSHELPER_IDENTIFIER, NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
        if (!connection)
        {
            NSLog(@"Failed to create XPC connection.");
            return;
        }
        
        /* set the event handler */
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            xpc_type_t type = xpc_get_type(event);
            
            if (type == XPC_TYPE_ERROR)
            {
                /*
                 * We don't care what error it is,
                 * Cancel the connection!
                 */
                xpc_connection_cancel(connection);
                
                /*
                 * Show the user we failed!
                 */
                //[self writeToLog:@"Something failed!\n"];
                //[_doneButton setEnabled:YES];
            }
            else
            {
                /*
                 * We either got data from the Helper (stdout)
                 *  or we got the "I am done here..." message which
                 *  means we can continue with the rest here.
                 */
                
                /* get the message */
                const char* response = xpc_dictionary_get_string(event, "msg");
                
#define HELPER_FINISHED_MESSAGE "I am done here..."
                if (strcmp(response, HELPER_FINISHED_MESSAGE) == 0)
                {
                    [self installMissingLibraries];
                }
                else
                {
                    [self writeToLog:[[NSString stringWithUTF8String:response] stringByAppendingString:@"\n"]];
                }
            }
            
        });
        
        /* resume/start communication */
        xpc_connection_resume(connection);
        
        /* send a initial message to trigger HELPER's event handler */
        xpc_object_t downloadURL = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(downloadURL, "url", "https://dl.bintray.com/xquartz/downloads/XQuartz-2.7.11.dmg");
        xpc_connection_send_message(connection, downloadURL);
    }
    else
    {
        /*
         *  XQuartz is already installed so we can
         *  start installing missing libraries right away.
         */
        [self installMissingLibraries];
    }
}

- (IBAction)doneButtonPressed:(id)sender
{
    [[self window] close];
}

@end
