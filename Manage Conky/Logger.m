//
//  Logger.m
//  Manage Conky
//
//  Created by Nickolas Pylarinos Stamatelatos on 17/12/2018.
//  Copyright © 2018 Nickolas Pylarinos. All rights reserved.
//

#import "Shared.h"
#import "Logger.h"

#define UPDATE_INTERVAL 5   // sec

/*
 * File Handles Registry
 */
static NSMutableArray<NSFileHandle *> *fileHandleRegistry;

BOOL done;

@implementation Logger

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        fileHandleRegistry = [NSMutableArray array];
        
        if (![super openWindowed])
        {
            [_closeButton setHidden:NO];
        }
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSLog(@"Starting to read all fh's");
    
    /*
     * Start reading all file handles
     */
//    while (!done)
//    {
//        sleep(UPDATE_INTERVAL);
//    }
}

+ (void)addFilehandleForReading:(NSFileHandle *)fh
{
    if (fh) [fileHandleRegistry addObject:fh];
}

@end
