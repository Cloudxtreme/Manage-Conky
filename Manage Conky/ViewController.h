//
//  ViewController.h
//  Manage Conky
//
//  Created by Nickolas Pylarinos on 08/09/2017.
//  Copyright © 2017 Nickolas Pylarinos. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <unistd.h>

typedef enum {
    widgetsThemesTableShowWidgets,
    widgetsThemesTableShowThemes,
} MCWidgetThemesTableShow;

/*
 * MCThemeOrWidget
 *
 * An object that holds the path of a widget/theme
 *  and the pid of the instance of conky that
 *  was launched with the specific widget/theme.
 */
@interface MCThemeOrWidget : NSObject

@property pid_t pid;
@property NSString *itemPath;

+ (instancetype)themeOrWidgetWithPid:(pid_t)pid andPath:(NSString * _Nullable)path;
@end

@interface ViewController : NSViewController<NSTableViewDelegate, NSTableViewDataSource>
{
    NSMutableArray<MCThemeOrWidget*> *themesArray;
    NSMutableArray<MCThemeOrWidget*> *widgetsArray;
    MCWidgetThemesTableShow whatToShow;
}

@property (weak) IBOutlet NSTableView *widgetsThemesTable;

@end
