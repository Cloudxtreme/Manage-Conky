//
//  Shared.h
//  Manage Conky
//
//  Created by npyl on 27/03/2018.
//  Copyright © 2018 Nickolas Pylarinos. All rights reserved.
//

#ifndef Shared_h
#define Shared_h

#import <Cocoa/Cocoa.h>
#import "Extensions/NSAlert+runModalSheet.h"

//
// Contains stuff used by more than one subprojects or files
//

#define HELPER_FINISHED_MESSAGE "I am done here..."     /* msg sent when Helper is quitting */

#define kSMJOBBLESSHELPER_IDENTIFIER @"org.npyl.ManageConkySMJobBlessHelper"
#define SMJOBBLESSHELPER_IDENTIFIER "org.npyl.ManageConkySMJobBlessHelper"

void showErrorAlertWithMessageForWindow(NSString* msg, NSWindow* window);

#endif /* Shared_h */
