//
//  ViewController.m
//  Manage Conky
//
//  Created by Nickolas Pylarinos on 08/09/2017.
//  Copyright © 2017 Nickolas Pylarinos. All rights reserved.
//

#import "ViewController.h"

#define MC_PID_NOT_SET (-100)

@implementation MCThemeOrWidget
+ (instancetype)themeOrWidgetWithPid:(pid_t)pid andPath:(NSString * _Nullable)path
{
    id res = [[self alloc] init];
    [res setPid:pid];
    [res setItemPath:path];
    return res;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    /*
     * Setup stuff
     */
    
    whatToShow = widgetsThemesTableShowWidgets; /* initial value */
    
    [self fillWidgetsThemesArrays];
    
    [_widgetsThemesTable setDelegate:self];
    [_widgetsThemesTable setDataSource:self];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

//
// DATA ARRAYS CONTROL
//

- (void)emptyWidgetsThemesArrays
{
    [widgetsArray removeAllObjects];
    [themesArray removeAllObjects];
}

- (void)fillWidgetsThemesArrays
{
    widgetsArray = [[NSMutableArray alloc] init];
    themesArray = [[NSMutableArray alloc] init];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator;
    
    NSString *basicSearchPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"configsLocation"];
    NSArray *additionalSearchPaths = [[NSUserDefaults standardUserDefaults] objectForKey:@"additionalSearchPaths"];
    
    if (!basicSearchPath)
        return;
    
    enumerator = [fm enumeratorAtPath:basicSearchPath];
    for (NSString *path in enumerator)
    {
        /* fullpath */
        NSString *fullpath = [NSString stringWithFormat:@"%@/%@", basicSearchPath, path];
        
        BOOL isDirectory = NO;
        [fm fileExistsAtPath:fullpath isDirectory:&isDirectory];
        if (isDirectory)
            continue;
        
        if ([path isEqualToString:@".DS_Store"])
            continue;
        
        MCThemeOrWidget *themeOrWidget = [MCThemeOrWidget themeOrWidgetWithPid:MC_PID_NOT_SET andPath:fullpath];
        
        /*
         * Empty extension means we found conky config file
         */
        if ([[path pathExtension] isEqualToString:@""] || [[path pathExtension] isEqualToString:@"conf"])
            [widgetsArray addObject:themeOrWidget];
        else if ([[path pathExtension] isEqualToString:@"cmtheme"])
            [themesArray addObject:themeOrWidget];
        else continue;
        
    }
    
    for (NSString *additionalPath in additionalSearchPaths)
    {
        enumerator = [fm enumeratorAtPath:additionalPath];
        for (NSString *path in enumerator)
        {
            /* fullpath */
            NSString *fullpath = [NSString stringWithFormat:@"%@/%@", additionalPath, path];
            
            BOOL isDirectory = NO;
            [fm fileExistsAtPath:fullpath isDirectory:&isDirectory];
            if (isDirectory)
                continue;
            
            if ([path isEqualToString:@".DS_Store"])
                continue;
            
            MCThemeOrWidget *themeOrWidget = [MCThemeOrWidget themeOrWidgetWithPid:MC_PID_NOT_SET andPath:fullpath];
            
            /*
             * Empty extension means we found conky config file
             */
            if ([[path pathExtension] isEqualToString:@""] || [[path pathExtension] isEqualToString:@"conf"])
                [widgetsArray addObject:themeOrWidget];
            else if ([[path pathExtension] isEqualToString:@"cmtheme"])
                [themesArray addObject:themeOrWidget];
            else continue;
        }
    }
}

//
// TABLE CONTROL
//

/**
 * Change to themes list or widgets list
 **/
- (IBAction)changeTableContents:(id)sender
{
    if ([[sender title] isEqualToString:@"Themes"])
        whatToShow = widgetsThemesTableShowThemes;
    if ([[sender title] isEqualToString:@"Widgets"])
        whatToShow = widgetsThemesTableShowWidgets;
    
    [_widgetsThemesTable reloadData];
}

/*
 * Applies a theme to computer by:
 *  - applying conky config
 *  - applying wallpaper
 *
 * supports two types of themes:
 *  - original conky-manager themes (plain files with minimal info) (backwards compatibility)
 *  - plist based (support many parameters/features in a native macOS way)
 */
- (void)applyTheme:(MCThemeOrWidget *)theme
{
    NSString *themeRoot = [[theme itemPath] stringByDeletingLastPathComponent];
    NSString *themeRCFile = [themeRoot stringByAppendingString:@"/themerc.plist"];
    
    /*
     * Information extracted from theme info file
     */
    NSInteger startupDelay = 0;
    NSString *conkyConfig = nil;
    NSArray *arguments = nil;
    NSString *wallpaper = nil;
    
    NSFileManager *fm = [NSFileManager defaultManager];

    /*
     * Check if we can use a themerc.plist
     */
    if ([fm fileExistsAtPath:themeRCFile])
    {
        /*
         * Doing it the ManageConky way...
         */
        
        NSDictionary *rc = [NSDictionary dictionaryWithContentsOfFile:themeRCFile];
        
        //startupDelay = [rc objectForKey:@"startupDelay"];
        conkyConfig = [rc objectForKey:@"config"];
        arguments = [rc objectForKey:@"args"];
        wallpaper = [rc objectForKey:@"wallpaper"];
    }
    else
    {
        /*
         * Doing it the conky-manager way...
         */
        themeRCFile = nil;
        
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:themeRoot];
        for (NSString *item in enumerator)
        {
            if ([[item pathExtension] isEqualToString:@"cmtheme"])
            {
                themeRCFile = [NSString stringWithFormat:@"%@/%@", themeRoot, item];
                break;
            }
        }
        
        /*
         * Check if we got something
         */
        if (!themeRCFile)
            return;
        
        /*
         * Start reading the file
         */
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    /*
     * Return if view is not Themes;
     * This function exists only to support
     *  controlling themes (start/restart/stop).
     */
    if (whatToShow != widgetsThemesTableShowThemes)
        return;
    
    NSInteger row = [_widgetsThemesTable selectedRow];
    MCThemeOrWidget *theme = [themesArray objectAtIndex:row];
    [self applyTheme:theme];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (whatToShow == widgetsThemesTableShowWidgets) ? [widgetsArray count] : [themesArray count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSArray *arr = (whatToShow == widgetsThemesTableShowWidgets) ? widgetsArray : themesArray;
    NSString *str = (whatToShow == widgetsThemesTableShowWidgets) ? [[arr objectAtIndex:row] itemPath] : [[arr objectAtIndex:row] itemPath];
    
    if ([[tableColumn identifier] isEqualToString:@"CollumnA"])
    {
        pid_t pid = [[arr objectAtIndex:row] pid];
        return [NSNumber numberWithBool:((pid == MC_PID_NOT_SET) ? NO : YES)];
    }
    else
    {
        NSTextFieldCell *cell = [tableColumn dataCellForRow:row];
        
        /*
         * check if already allocated
         */
        if (!cell)
            cell = [[NSTextFieldCell alloc] init];
        
        cell.stringValue = str;
        return cell;
    }
}


//
// CONKY CONTROL
//
- (IBAction)startOrRestartWidget:(id)sender
{
    NSString *path = [[widgetsArray objectAtIndex:[_widgetsThemesTable selectedRow]] itemPath];
    
    // check if already running to restart
    pid_t tmp = [[widgetsArray objectAtIndex:[_widgetsThemesTable selectedRow]] pid];
    if (tmp != MC_PID_NOT_SET)
        [self stopWidget:nil];
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/local/bin/conky"];
    [task setArguments:@[@"-c", path]];
    [task setCurrentDirectoryPath:[path stringByDeletingLastPathComponent]];
    [task launch];
    
    pid_t pid = [task processIdentifier];
    [[widgetsArray objectAtIndex:[_widgetsThemesTable selectedRow]] setPid:pid];
    [_widgetsThemesTable reloadData];
}
- (IBAction)stopWidget:(id)sender
{
    NSInteger i = [_widgetsThemesTable selectedRow];
    pid_t pid = [[widgetsArray objectAtIndex:i] pid];

    int stat_loc = 0;
    kill(pid, SIGINT);
    waitpid(pid, &stat_loc, WNOHANG);
    
    [[widgetsArray objectAtIndex:i] setPid:MC_PID_NOT_SET];
    [_widgetsThemesTable reloadData];
}
- (IBAction)stopAllWidgets:(id)sender
{
    for (MCThemeOrWidget *widget in widgetsArray)
    {
        pid_t pid = [widget pid];
        if (pid != MC_PID_NOT_SET)
        {
            int stat_loc = 0;
            kill(pid, SIGINT);
            waitpid(pid, &stat_loc, WNOHANG);
            
            [widget setPid:MC_PID_NOT_SET];
        }
    }
    
    [_widgetsThemesTable reloadData];
}

@end
