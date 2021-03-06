//
//  MCObjects.m
//  Manage Conky
//
//  Created by npyl on 13/04/2018.
//  Copyright © 2018 Nickolas Pylarinos. All rights reserved.
//

#import "MCObjects.h"

#import <pwd.h>
#import <grp.h>
#import "Shared.h"
#import "../ViewController.h"
#import <Foundation/Foundation.h>
#import <AHLaunchCtl/AHLaunchCtl.h>
#import <NPTask/NSAuthenticatedTask.h>
#import "../Extensions/NSString+Relative.h"

/** `Helper function`
 * Check if Xquartz and conky are installed
 * and if not, show an alert and return NO.
 */
BOOL isXquartzAndConkyInstalled(void)
{
    BOOL res1 = (access(XQUARTZ, R_OK) == 0);
    BOOL res2 = (access(CONKY_SYMLINK.UTF8String, R_OK) == 0);
    
    NSAlert *alert = [[NSAlert alloc] init];
    
    if (!res1)
    {
        [alert setMessageText:@"Xquartz is missing!"];
        [alert setInformativeText:@"You need to reinstall Xquartz from https://www.xquartz.org/"];
        [alert setAlertStyle:NSAlertStyleCritical];
        [alert runModal];
    }

    if (!res2)
    {
        [alert setMessageText:@"conky is missing!"];
        [alert setInformativeText:@"You need to reinstall conky from `Conky Preferences`→`Install conky`"];
        [alert setAlertStyle:NSAlertStyleCritical];
        [alert runModal];
    }

    return (res1 && res2);
}

// taken from https://stackoverflow.com/questions/11025559/how-to-determine-if-the-process-owner-is-an-administrator-on-mac-os-x-in-c
BOOL userIsAdmin(void)
{
    // A user cannot be member in more than NGROUPS groups,
    // not counting the default group (hence the + 1)
    gid_t groupIDs[NGROUPS + 1];
    // ID of user who started the process
    uid_t userID = getuid();
    // Get user password info for that user
    struct passwd * pw = getpwuid(userID);
    
    int groupCount;
    if (pw) {
        // Look up groups that user belongs to
        groupCount = NGROUPS + 1;
        // getgrouplist returns ints and not gid_t and
        // both may not necessarily have the same size
        int intGroupIDs[NGROUPS + 1];
        getgrouplist(pw->pw_name, pw->pw_gid, intGroupIDs, &groupCount);
        // Copy them to real array
        for (int i = 0; i < groupCount; i++) groupIDs[i] = intGroupIDs[i];
        
    } else {
        // We cannot lookup the user but we can look what groups this process
        // currently belongs to (which is usually the same group list).
        groupCount = getgroups(NGROUPS + 1, groupIDs);
    }
    
    for (int i = 0; i < groupCount; i++) {
        // Get the group info for each group
        struct group * group = getgrgid(groupIDs[i]);
        if (!group) continue;
        // An admin user is member of the group named "admin"
        if (strcmp(group->gr_name, "admin") == 0) return true;
    }
    return false;
}

/*
 * Logging
 * =======
 */
BOOL shouldLogToFile = NO;
NSString *logfile = nil;
void NPLog(NSString *format, ...)
{
    va_list vargs;
    va_start(vargs, format);
    NSString* formattedMessage = [[NSString alloc] initWithFormat:format arguments:vargs];
    va_end(vargs);
    
    if (shouldLogToFile)
    {
        NSError *error = nil;
        
        /* create logfile if it doesn't exist */
        if (access(logfile.UTF8String, R_OK) != 0)
            [[NSFileManager defaultManager] createFileAtPath:logfile contents:nil attributes:nil];
        
        /* read contents */
        NSString *contents = [NSString stringWithContentsOfFile:logfile encoding:NSUTF8StringEncoding error:&error];
        
        if (error)
        {
            printf("Error opening logfile(%s): %s\n", logfile.UTF8String, error.localizedDescription.UTF8String);
            error = nil;    // re-use
        }
        
        /* write to file */
        contents = [contents stringByAppendingFormat:@"%@\n", formattedMessage];
        [contents writeToFile:logfile atomically:YES encoding:NSUTF8StringEncoding error:&error];
        
        if (error)
        {
            printf("Error writing to logfile(%s): %s\n", logfile.UTF8String, error.localizedDescription.UTF8String);
        }
    }
    else
    {
        printf("%s\n", formattedMessage.UTF8String);
    }
}

void MCError(NSError **error) MC_OVERLOADABLE
{
    NSLog(@"%@", *error);
    error = nil;    // allow re-use from caller
}

void MCError(NSError **error, NSString *format, ...) MC_OVERLOADABLE
{
    va_list vargs;
    va_start(vargs, format);
    NSString* formattedMessage = [[NSString alloc] initWithFormat:format arguments:vargs];
    va_end(vargs);
    
    NSLog(@"%@: \n%@\n", formattedMessage, *error);
    error = nil;    // allow re-use from caller
}

@implementation MCSettings

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        windowVector = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)sharedSettings
{
    static id res = nil;
    if (!res)
        res = [[self alloc] init];
    return res;
}

- (void)setConkyRunsAtStartup:(BOOL)a
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:a] forKey:kMCRunConkyAtStartupKey];
}
- (BOOL)conkyRunsAtStartup
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kMCRunConkyAtStartupKey] boolValue];
}

- (void)setKeepAliveConky:(BOOL)a
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:a] forKey:kMCKeepAliveConkyKey];
}
- (BOOL)keepAliveConky
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kMCKeepAliveConkyKey] boolValue];
}

- (void)setConkyStartupDelay:(NSInteger)startupDelay
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:startupDelay] forKey:kMCConkyStartupDelayKey];
}
- (NSInteger)conkyStartupDelay
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kMCConkyStartupDelayKey] integerValue];
}

- (void)setConfigsLocation:(NSString *)a
{
    [[NSUserDefaults standardUserDefaults] setObject:a forKey:kMCConkyConfigsLocationKey];
}
- (NSString *)configsLocation
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kMCConkyConfigsLocationKey];
}

- (NSArray *)additionalSearchPaths
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kMCConkyAdditionalSearchPathsKey];
}
- (void)addAdditionalSearchPath:(NSString *)path
{
    NSMutableArray *arr = [[[NSUserDefaults standardUserDefaults] objectForKey:kMCConkyAdditionalSearchPathsKey] mutableCopy];
    if (arr)
        [arr addObject:path];
    else
        arr = [NSMutableArray arrayWithObject:path];
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:kMCConkyAdditionalSearchPathsKey];
}
- (void)setAdditionalSearchPaths:(NSArray *)array
{
    [[NSUserDefaults standardUserDefaults] setObject:array forKey:kMCConkyAdditionalSearchPathsKey];
}

- (void)setMainViewController:(ViewController *)vc
{
    MC_RUN_ONLY_ONCE({
        mainViewController = vc;
        beenHereAgain = YES;
    })
}
- (ViewController *)mainViewController
{
    return mainViewController;
}

- (void)setCanResizeWindow:(BOOL)a
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:a] forKey:kMCCanResizeWindow];
}
- (BOOL)canResizeWindow
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kMCCanResizeWindow] boolValue];
}

- (void)setUsesAbsolutePaths:(BOOL)a
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:a] forKey:kMCUsesAbsolutePaths];
}
- (BOOL)usesAbsolutePaths
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kMCUsesAbsolutePaths] boolValue];
}

- (void)installManageConkyFilesystem
{
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *ConkyXPath = [[NSBundle mainBundle] pathForResource:@"ConkyX" ofType:@"app"];
    NSString *conkyPath = [[NSBundle bundleWithPath:ConkyXPath] pathForResource:@"conky" ofType:nil];
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"SetupFilesystem" ofType:@"sh"];
    
    if (userIsAdmin())
    {
        /* Remove old files first */
        [[MCSettings sharedSettings] uninstallManageConkyFilesystem];
        
        /*
         * Create symbolic link to install ConkyX to Applications
         * Run script that setups basic paths as administrator
         */
        if (![fm createSymbolicLinkAtPath:CONKYX withDestinationPath:ConkyXPath error:&error])
        {
            MCError(&error, @"Error creating symlink to Applications for ConkyX");
        }

        /*
         * Create /usr/local/bin dir;
         * Ensure that we are going to get the symlink in place.
         */
        if (![fm createDirectoryAtPath:@"/usr/local/bin" withIntermediateDirectories:YES attributes:nil error:&error])
        {
            MCError(&error);
        }
    }
    else
    {
        /*
         * Run script that setups basic paths as administrator
         */
        NSAuthenticatedTask *script = [[NSAuthenticatedTask alloc] init];
        script.launchPath = @"/bin/bash";
        script.arguments = @[scriptPath,
                             ConkyXPath];
        [script launchAuthenticated];
        [script waitUntilExit];
    }
    
    /*
     * Create symbolic link to allow using from terminal
     */
    if (![fm createSymbolicLinkAtPath:CONKY_SYMLINK withDestinationPath:conkyPath error:&error])
    {
        MCError(&error, @"Error creating symbolic link to /usr/local/bin");
    }
}

- (void)setShouldLogToFile:(BOOL)a
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:a] forKey:kMCConkyShouldLogToFileKey];
}
- (BOOL)shouldLogToFile
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kMCConkyShouldLogToFileKey] boolValue];
}

- (void)setLogfile:(NSString *)logfile
{
    [[NSUserDefaults standardUserDefaults] setObject:logfile forKey:kMCConkyLogfileLocationKey];
}
- (NSString *)logfile
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kMCConkyLogfileLocationKey];
}

- (void)uninstallManageConkyFilesystem
{
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"UninstallFilesystem" ofType:@"sh"];

    if (userIsAdmin())
    {
        NSError *error = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        
        [fm removeItemAtPath:CONKYX error:&error];
        if (error) { MCError(&error, @"Error removing ConkyX"); }

        [fm removeItemAtPath:CONKY_SYMLINK error:&error];
        if (error) { MCError(&error, @"Error removing symlink"); }
    }
    else
    {
        /*
         * Run script that setups basic paths as administrator
         */
        NSAuthenticatedTask *script = [[NSAuthenticatedTask alloc] init];
        script.launchPath = @"/bin/bash";
        script.arguments = @[scriptPath];
        [script launchAuthenticated];
        [script waitUntilExit];
    }
}

- (void)uninstallCompletelyManageConkyFilesystem
{
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    [self uninstallManageConkyFilesystem];
    
    [fm removeItemAtPath:MANAGE_CONKY error:&error];
    if (error) { MCError(&error, @"Error removing Manage Conky"); }
}

/* Windows Vector */
- (void)pushWindow:(NSWindow *)window       { [windowVector addObject:window]; }
- (void)popWindow                           { [windowVector removeLastObject]; }
- (NSWindow *)currentWindow                 { return [windowVector lastObject]; }

/* Wallpaper */
- (NSString *)wallpaper
{
    return [[NSWorkspace sharedWorkspace] desktopImageURLForScreen:NSScreen.mainScreen].path;
}
- (void)setOldWallpaper:(NSString *)old
{
    [[NSUserDefaults standardUserDefaults] setObject:old forKey:kMCOldWallpaperKey];
}
- (NSString *)oldWallpaper
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kMCOldWallpaperKey];
}
- (BOOL)setWallpaper:(NSString *)wallpaper withScaling:(MCWallpaperScaling)scaling error:(NSError **)error
{
    /*
     * based on https://github.com/sindresorhus/macos-wallpaper
     */
    
    NSWorkspace *sw = [NSWorkspace sharedWorkspace];
    NSScreen *screen = [NSScreen mainScreen];
    NSMutableDictionary *so = [sw desktopImageOptionsForScreen:screen].mutableCopy;
    
    switch (scaling)
    {
        case FillScreen:
            [so setObject:[NSNumber numberWithInt:NSImageScaleProportionallyUpOrDown] forKey:NSWorkspaceDesktopImageScalingKey];
            [so setObject:[NSNumber numberWithBool:YES] forKey:NSWorkspaceDesktopImageAllowClippingKey];
            break;
        case FitToScreen:
            [so setObject:[NSNumber numberWithInt:NSImageScaleProportionallyUpOrDown] forKey:NSWorkspaceDesktopImageScalingKey];
            [so setObject:[NSNumber numberWithBool:NO] forKey:NSWorkspaceDesktopImageAllowClippingKey];
            break;
        case StretchToFillScreen:
            [so setObject:[NSNumber numberWithInt:NSImageScaleAxesIndependently] forKey:NSWorkspaceDesktopImageScalingKey];
            [so setObject:[NSNumber numberWithBool:YES] forKey:NSWorkspaceDesktopImageAllowClippingKey];
            break;
        case Centre:
            [so setObject:[NSNumber numberWithInt:NSImageScaleNone] forKey:NSWorkspaceDesktopImageScalingKey];
            [so setObject:[NSNumber numberWithBool:NO] forKey:NSWorkspaceDesktopImageAllowClippingKey];
            break;
        case Tile:
            // TODO: to emulate the tiling behaviour,
            //  probably we could create a new .png with the wallpaper
            //  small tiles (create the tiling ourselves).
            //  Then, load the custom wallpaper.
            break;
        case MAX_SCALING_KEYS:
        default:
            break;
    }
    
    return [sw setDesktopImageURL:[NSURL fileURLWithPath:wallpaper]
                        forScreen:screen
                          options:so
                            error:error];
}
- (BOOL)wallpaperIsNotFromMCTheme:(NSString *)wallpaper
{
    ViewController *vc = [[ViewController alloc] init];
    [vc fillWidgetsThemesArrays];
    for (MCTheme *theme in vc.themes)
    {
        /* Ok, wallpaper passed is an MCTheme wallpaper */
        if ([theme.wallpaper isEqualToString:wallpaper])
            return NO;
    }
    /* Ok, wallpaper passed is a wallpaper set by user himself */
    return YES;
}
@end

@implementation MCWidgetOrTheme
- (void)enable {}
- (void)reenable {}
- (void)kill {}
- (void)disable {}
- (BOOL)isEnabled { return YES; }

- (void)uninstall:(NSString *)path
{
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[path stringByDeletingLastPathComponent] error:&error];
    if (error)
        MCError(&error);
}

- (void)uninstall {}
- (void)configureMCSettingsHolder { MCSettingsHolder = [MCSettings sharedSettings]; }
@end

@implementation MCWidget
+ (instancetype)widgetWithPid:(pid_t)pid andRC:(NSString *)path
{
    NSString *realName = [path lastPathComponent];
    NSString *widgetName = [realName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    
    id res = [[self alloc] init];
    if (res)
    {
        [res setPid:pid];
        [res setItemPath:path];
        [res setRealName:realName];
        [res setWidgetName:widgetName];
        [res setWidgetLabel: [NSString stringWithFormat:@"%@.%@", LAUNCH_AGENT_PREFIX, widgetName]];
        [res configureMCSettingsHolder];
    }
    return res;
}

- (void)kill
{
    int stat_loc = 0;
    kill(_pid, SIGINT);
    waitpid(_pid, &stat_loc, WNOHANG);
    [self setPid:MC_PID_NOT_SET];
}

- (void)enable
{
    if (!isXquartzAndConkyInstalled())
        return;

    NSError *error = nil;
    
    /*
     * Custom-Normalise for our needs
     */
    NSString *correctedItemPath = MCNormalise(_itemPath);
    
    /*
     * IF conky is set to run at startup we must do LaunchAgent housekeeping...
     */
    if ([MCSettingsHolder conkyRunsAtStartup])
    {
        NSInteger startupDelay = [MCSettingsHolder conkyStartupDelay];
        BOOL keepAlive = [MCSettingsHolder keepAliveConky];

        /*
         * setup the LaunchAgent
         */
        createLaunchAgent(_widgetLabel,
                          @[CONKY_SYMLINK, @"-c", correctedItemPath],
                          keepAlive,
                          startupDelay,
                          [_itemPath stringByDeletingLastPathComponent],
                          error);
        
        if (error)
            MCError(&error);
    }
    else
    {
        NSString *cmd = [NSString stringWithFormat:@"%@ -c %@", CONKY_SYMLINK, correctedItemPath];
        
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/bin/bash"];
        [task setArguments:@[@"-l",
                             @"-c",
                             cmd]];
        [task setCurrentDirectoryPath:[_itemPath stringByDeletingLastPathComponent]];
        [task setEnvironment:[NSProcessInfo processInfo].environment];          /*
                                                                                 * Some conky widgets like Conky-Vision
                                                                                 * (original: https://github.com/zagortenay333/conky-Vision)
                                                                                 * use external executables thus we need to
                                                                                 * provide the basic environment for them
                                                                                 * like environment-variables.
                                                                                 */
        [task launch];
        
        pid_t pid = [task processIdentifier];
        [self setPid:pid];
    }
}

/**
 * re-enable
 *
 * Restart widget
 */
- (void)reenable
{
    [self disable];
    [self enable];
    
    /*
     Although we have a workaround for #29 we still can't rely on
     SIGUSR1 because it has some side-effects such as causing the
     Gotham Widget to be non-draggable.  If https://github.com/Conky-for-macOS/conky-for-macOS/issues/29
     gets a proper solution (e.g. the XDamage incompatibilities get
     fixed) this should be the optimal solution to restarting the
     widget:
     
    kill(_pid, SIGUSR1);
     */
}

- (void)disable
{
    /*
     * IF conky is set to run at startup we must do LaunchAgent housekeeping...
     */
    if ([MCSettingsHolder conkyRunsAtStartup])
    {
        removeLaunchAgent(_widgetLabel);
    }
    else
    {
        [self kill];
    }
}

- (BOOL)isEnabled
{
    /*
     * IF conky is set to run at startup we must do LaunchAgent housekeeping...
     */
    if ([MCSettingsHolder conkyRunsAtStartup])
    {
        return isLaunchAgentEnabled(_widgetLabel);
    }
    else return (_pid != MC_PID_NOT_SET) ? YES : NO;
}

- (void)uninstall
{
    [super uninstall:_itemPath];
}

@end

@implementation MCTheme
+ (instancetype)themeWithResourceFile:(NSString *)themeRC
                         conkyConfigs:(NSArray *)configs
                            arguments:(NSArray *)args
                         startupDelay:(NSInteger)startupDelay
                            wallpaper:(NSString *)wallpaper
                              creator:(NSString *)creator
                               source:(NSString *)source
                           andScaling:(MCWallpaperScaling)scaling;
{
    id res = [[self alloc] init];

    if (res)
    {
        NSMutableArray *refinedConfigs = [NSMutableArray arrayWithArray:configs];

        /*
         * Preparation...
         * =====================================================
         * Here we manipulate the provided data before we create
         * a theme object with these.
         *
         * REFINE is the process of converting a relative path to
         * full.
         */
        
        /*
         * REFINE conky configs (when required)
         */
        for (NSString *config in configs)
        {
            if ([config isRelative])
            {
                /*
                 * OH! We have a relative path, lets fix this...
                 * Internally, we only will use full paths
                 */
                NSUInteger index = [refinedConfigs indexOfObject:config];
                refinedConfigs[index] = [NSString stringWithFormat:@"%@/%@", themeRC.stringByDeletingLastPathComponent, config];
            }
        }
        
        /*
         * REFINE the wallpaper, too!
         */
        if ([wallpaper isRelative])
        {
            wallpaper = [themeRC.stringByDeletingLastPathComponent stringByAppendingPathComponent:wallpaper];
        }
        
        /*
         * General properties
         * ==================
         */
        [res setThemeRC:themeRC];
        [res setConkyConfigs:refinedConfigs];
        [res setArguments:args];
        [res setStartupDelay:startupDelay];
        [res setWallpaper:wallpaper];
        [res setCreator:creator];
        [res setSource:source];
        [res setScaling:scaling];
        
        [res configureMCSettingsHolder];
        
        /*
         * themeName
         */
        [res setThemeName:[[themeRC stringByDeletingLastPathComponent] lastPathComponent]];
        [res setRealName:[res themeName]];  /* for themes they are the same; Why though? */
        
        /*
         * isEnabled?
         * Try accessing the Theme's lock
         */
        NSString *lock = [NSHomeDirectory() stringByAppendingFormat:@"/Library/ManageConky/%@.theme.lock", [res themeName]];
        [res setIsEnabled: (access([lock UTF8String], R_OK) == 0)];
    }
    
    return res;
}

+ (instancetype)themeRepresentationForThemeRC:(NSString *)themeRC
{
    /*
     * Information to be extracted from theme rc file
     */
    NSInteger startupDelay = 0;
    NSArray *conkyConfigs = [NSArray array];
    NSArray *arguments = [NSArray array];
    NSString *wallpaper = nil;
    __block NSString *strScaling = nil;
    MCWallpaperScaling scaling = FillScreen;
    NSString *creator = @"unknown";
    NSString *source = @"unknown";
    
    macScalingKeys = @[@"FillScreen",
                       @"FitToScreen",
                       @"StretchToFillScreen",
                       @"Centre",
                       @"Tile",
                       ];
    
    /*
     * Is it modern or legacy theme?
     */
    BOOL useMCThemeRCFile = [[themeRC pathExtension] isEqualToString:@"plist"] ? YES : NO;
    
    if (useMCThemeRCFile)
    {
        /*
         * Doing it the ManageConky way...
         */
        NSDictionary *rc = [NSDictionary dictionaryWithContentsOfFile:themeRC];
        startupDelay = [[rc objectForKey:kMCThemeStartupDelayKey] integerValue];
        
        /* Try to standardize paths read first. */
        NSMutableArray *conkyConfigsUnstandardized = [rc objectForKey:kMCThemeConfigsKey];   // must be Array, not Dictionary because each arguments list corresponds to specific conkyConfig

        for (NSUInteger i = 0; i < [conkyConfigsUnstandardized count]; i++)
        {
            conkyConfigsUnstandardized[i] = [conkyConfigsUnstandardized[i] stringByStandardizingPath];
        }

        conkyConfigs = [conkyConfigsUnstandardized copy];   /* now write them standardized */
        arguments = [rc objectForKey:kMCThemeArgumentsKey];   /* must be Array, not Dictionary because each arguments list corresponds to specific conkyConfig */
        wallpaper = [[rc objectForKey:kMCThemeWallpaperKey] stringByExpandingTildeInPath];
        source = [rc objectForKey:kMCThemeSourceKey];
        creator = [rc objectForKey:kMCThemeCreatorKey];
        strScaling = [rc objectForKey:kMCThemeScalingKey];
    }
    else
    {
        /*
         * Doing it the conky-manager way...
         */
        NSString *themeRoot = [themeRC stringByDeletingLastPathComponent];
        
        NSError *error = nil;
        NSMutableArray *lines = [NSMutableArray array];
        
        [[NSString stringWithContentsOfFile:themeRC
                                   encoding:NSUTF8StringEncoding
                                      error:&error] enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
            /* We need to avoid empty lines */
            if (![line isEqualToString:@""])
                [lines addObject:line];
        }];
        
        if ([lines count] == 0)
            return nil;
        
        /* pretty index */
        NSInteger i = [lines count] - 1;
        
        /*
         * Take scaling (last line)
         */
        strScaling = [[lines objectAtIndex:i] substringFromIndex:18];
        
        /*
         * Take wallpaper which is always the line before-last;
         */
        i -= 1;
        wallpaper = [[lines objectAtIndex:i] stringByExpandingTildeInPath];
        
        /*
         * Remove scaling & wallpaper;
         * Leave only configs inside
         */
        [lines removeLastObject];
        [lines removeLastObject];
        
        /*
         * Take configs
         */
        /* first expand tilde */
        for (int i = 0; i < [lines count]; i++)
        {
            [lines setObject:[[lines objectAtIndex:i] stringByExpandingTildeInPath] atIndexedSubscript:i];
        }
        conkyConfigs = lines;
        
        source = [NSString stringWithContentsOfFile:[themeRoot stringByAppendingString:@"/source.txt"] encoding:NSUTF8StringEncoding error:nil];
        if (!source)
            source = @"unknown";
        creator = [NSString stringWithContentsOfFile:[themeRoot stringByAppendingString:@"/creator.txt"] encoding:NSUTF8StringEncoding error:nil];
        if (!creator)
            creator = @"unknown";
    }
    
    /*
     * Lookup scaling string in keys
     */
    if (![macScalingKeys containsObject:strScaling])
    {
        // definitely not a modernScalingKey BUT
        // This means either using a legacyKey or
        // not a valid one.  Either way, `scalingKeyConvertLegacyToModern`
        // will handle that, too!
        strScaling = [self scalingKeyConvertLegacyToModern:strScaling];
    }
    
    scaling = [macScalingKeys indexOfObject:strScaling];
    
    /*
     * create theme representation
     */
    return [self themeWithResourceFile:themeRC
                          conkyConfigs:conkyConfigs
                             arguments:arguments
                          startupDelay:startupDelay
                             wallpaper:wallpaper
                               creator:creator
                                source:source
                            andScaling:scaling];
}

/*
 * Method that converts a legacy-key (conky-manager) to a modern-mac key (ManageConky)
 
 v0.1: Doesn't support XFCE
 */
+ (NSString *)scalingKeyConvertLegacyToModern:(NSString *)legacyKey
{
    enum
    {
        none = 0,
        centered,
        tiled,
        stretched,
        scaled,
        zoomed,
    };
    
    NSString *modernKey = @"";
    
    /*
     * From conky-manager's source code:
     */
                                                    // macScalingKeys Index
    NSArray *legacyScalingKeys = @[@"none",         // N/A ->           0
                                   @"centered",     // ->               3
                                   @"tiled",        // ->               4
                                   @"stretched",    // ->               2
                                   @"scaled",       // N/A ->           0
                                   @"zoomed",       // N/A ->           0
                                   
                                   // XFCE
                                   @"0",
                                   @"1",
                                   @"2",
                                   @"3",
                                   @"4",
                                   @"5",
                                   ];
    
    // If nothing is found default to `FillScreen`
    if (![legacyScalingKeys containsObject:legacyKey])
        return macScalingKeys[0];
    
    NSUInteger index = [legacyScalingKeys indexOfObject:legacyKey];
    
    switch (index)
    {
        case none:
        case scaled:
        case zoomed:
        default:
            modernKey = macScalingKeys[0];
            break;

        case centered:
            modernKey = macScalingKeys[3];
            break;

        case tiled:
            modernKey = macScalingKeys[4];
            break;

        case stretched:
            modernKey = macScalingKeys[2];
            break;
    }
    
    return modernKey;
}

/**
 * enable
 *
 * Applies this Theme to computer by:
 *  - applying conky config(s)
 *  - applying wallpaper
 *
 * supports two types of Themes:
 *  - original conky-manager Themes (plain files with minimal info) (backwards compatibility)
 *  - plist-based (support many parameters/features in a native macOS way)
 */
- (void)enable
{
    if (!isXquartzAndConkyInstalled())
        return;
    
    /**
     * We create a LaunchAgent foreach conky-config of the Theme and
     * a lock indicating that the theme is enabled on this user account.
     */

    /*
     * create required directories
     */
    createUserLaunchAgentsDirectory();
    createMCDirectory();
    
    /*
     * Create LaunchAgent foreach config
     */
    for (NSString *config in _conkyConfigs)
    {
        NSString *correctedConfig = MCNormalise(config);
        NSString *configName = [[config lastPathComponent] stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        NSString *label = [NSString stringWithFormat:@"org.npyl.ManageConky.Theme.%@", configName];
        NSString *workingDirectory = [config stringByDeletingLastPathComponent];
        const BOOL keepAlive = YES;

        NSError *error = nil;

        createLaunchAgent(label,
                          @[CONKY_SYMLINK, @"-c", correctedConfig],
                          keepAlive,
                          _startupDelay,
                          workingDirectory,
                          error);
        
        if (error)
        {
            MCError(&error, @"applyTheme: Error creating agent");
            return;
        }
    }

    NSError *err = nil;
    
    /*
     * Remember old wallpaper (but, ONLY if it is not one of the ones used by MCThemes)
     */
    if ([MCSettingsHolder wallpaper] && [MCSettingsHolder wallpaperIsNotFromMCTheme:[MCSettingsHolder wallpaper]])
        [MCSettingsHolder setOldWallpaper:[MCSettingsHolder wallpaper]];

    /*
     * Apply new wallpaper
     */
    [MCSettingsHolder setWallpaper:_wallpaper
                       withScaling:_scaling
                             error:&err];
    if (err)
    {
        MCError(&err, @"applyTheme: Failed to apply wallpaper");
    }
    
    /*
     * Create a lock for theme
     */
    NSString *lock = [NSHomeDirectory() stringByAppendingFormat:@"/Library/ManageConky/%@.theme.lock", _themeName];
    
    [[NSFileManager defaultManager] createFileAtPath:lock
                                            contents:nil
                                          attributes:nil];
    
    _isEnabled = YES;
}

- (void)reenable
{
    if ([self isEnabled])
        [self disable];
    [self enable];
}

- (void)disable
{
    for (NSString *config in _conkyConfigs)
    {
        NSString *configName = [[config lastPathComponent] stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        NSString *label = [NSString stringWithFormat:@"org.npyl.ManageConky.Theme.%@", configName];
        removeLaunchAgent(label);
    }
    
    /*
     * Delete the lock
     */
    NSString *lock = [NSHomeDirectory() stringByAppendingFormat:@"/Library/ManageConky/%@.theme.lock", _themeName];
    unlink([lock UTF8String]);
    
    /*
     * Revert to old wallpaper
     */
    NSError *error = nil;
    [MCSettingsHolder setWallpaper:[MCSettingsHolder oldWallpaper]
                       withScaling:FillScreen
                             error:&error];
    if (error)
    {
        MCError(&error);
    }
    
    _isEnabled = NO;
}

- (void)uninstall
{
    [super uninstall:_themeRC];
}

@end
