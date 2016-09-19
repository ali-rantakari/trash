//  trash.m
//
//  Created by Ali Rantakari
//  http://hasseg.org/trash
//

/*
The MIT License

Copyright (c) 2010 Ali Rantakari

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/


#include <AppKit/AppKit.h>
#include <ScriptingBridge/ScriptingBridge.h>
#import <libgen.h>
#import "Finder.h"
#import "HGUtils.h"
#import "HGCLIUtils.h"
#import "fileSize.h"

// (Apple reserves OSStatus values outside the range 1000-9999 inclusive)
#define kHGAppleScriptError         9999
#define kHGNotAllFilesTrashedError  9998

static const int VERSION_MAJOR = 0;
static const int VERSION_MINOR = 8;
static const int VERSION_BUILD = 6;

static BOOL arg_verbose = NO;




static void VerbosePrintf(NSString *aStr, ...)
{
    if (!arg_verbose)
        return;
    va_list argList;
    va_start(argList, aStr);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
    NSString *str = [
        [[NSString alloc]
            initWithFormat:aStr
            locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
            arguments:argList
            ] autorelease
        ];
#pragma clang diagnostic pop
    va_end(argList);

    [str writeToFile:@"/dev/stdout" atomically:NO encoding:outputStrEncoding error:NULL];
}


static char promptForChar(const char *acceptableChars)
{
    const char *acceptableCharsLowercase = @(acceptableChars).lowercaseString.UTF8String;

    for (;;)
    {
        putchar('[');
        size_t numAcceptableChars = strlen(acceptableChars);
        for (size_t i = 0; i < numAcceptableChars; i++)
        {
            putchar(acceptableChars[i]);
            if (i < (numAcceptableChars - 1))
                putchar('/');
        }
        printf("]: ");
        
        char *line = NULL;
        size_t lineLength = 0;
        ssize_t numCharsWritten = getline(&line, &lineLength, stdin);
        char inputCharLowercase = (0 < numCharsWritten) ? tolower(line[0]) : '\0';
        free(line);

        if (numCharsWritten == 0)
            continue;

        if (strchr(acceptableCharsLowercase, inputCharLowercase))
            return inputCharLowercase;
    }
}


static void checkForRoot()
{
    if (getuid() != 0)
        return;

    Printf(@"You seem to be running as root. Any files trashed\n"
           @"as root will be moved to root's trash folder instead\n"
           @"of your trash folder. Are you sure you want to continue?\n");

    char inputChar = promptForChar("yN");
    if (inputChar != 'y')
        exit(1);
}


static FinderApplication *getFinderApp()
{
    static FinderApplication *cached = nil;
    if (cached != nil)
        return cached;
    cached = [SBApplication applicationWithBundleIdentifier:@"com.apple.Finder"];
    return cached;
}


static void printDiskUsageOfFinderItems(NSArray *finderItems)
{
    NSUInteger totalPhysicalSize = 0;

    Printf(@"\nCalculating total disk usage of files in trash...\n");
    for (FinderItem *item in finderItems)
    {
        NSUInteger size = 0;
        NSString *path = [[NSURL URLWithString:(NSString *)[item URL]] path];

        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
            continue;

        if (!isDir)
            size = [item physicalSize];
        else
            size = sizeOfFolder(path, YES);

        totalPhysicalSize += size;
    }

    // Format the bytes with thousand separators:
    NSNumberFormatter* numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSString *formattedBytes = [numberFormatter stringFromNumber:[NSNumber numberWithUnsignedInteger:totalPhysicalSize]];

    Printf(@"Total: %@ (%@ bytes)\n",
        stringFromFileSize(totalPhysicalSize),
        formattedBytes
        );
}


static void listTrashContents(BOOL showAdditionalInfo)
{
    FinderApplication *finder = getFinderApp();
    NSArray *itemsInTrash = [finder.trash items];
    for (FinderItem *item in itemsInTrash)
    {
        NSString *path = [[NSURL URLWithString:(NSString *)[item URL]] path];
        Printf(@"%@\n", path);
    }

    if (showAdditionalInfo)
        printDiskUsageOfFinderItems(itemsInTrash);
}


static OSStatus emptyTrash(BOOL securely, BOOL skipPrompt)
{
    FinderApplication *finder = getFinderApp();

    NSUInteger trashItemsCount = [[finder.trash items] count];
    if (trashItemsCount == 0)
    {
        Printf(@"The trash is already empty.\n");
        return noErr;
    }

    if (!skipPrompt)
    {
        BOOL plural = (trashItemsCount > 1);
        Printf(
            @"There %@ currently %i item%@ in the trash.\nAre you sure you want to permanently%@ delete %@ item%@?\n",
            plural?@"are":@"is",
            trashItemsCount,
            plural?@"s":@"",
            securely?@" (and securely)":@"",
            plural?@"these":@"this",
            plural?@"s":@""
            );
        Printf(@"(y = permanently empty the trash, l = list items in trash, n = don't empty)\n");

        for (;;)
        {
            char inputChar = promptForChar("ylN");

            if (inputChar == 'l')
                listTrashContents(NO);
            else if (inputChar != 'y')
                return kHGNotAllFilesTrashedError;
            else
                break;
        }
    }

    if (securely)
        Printf(@"(secure empty trash will take a long while so please be patient...)\n");

    BOOL warnsBeforeEmptyingOriginalValue = finder.trash.warnsBeforeEmptying;
    finder.trash.warnsBeforeEmptying = NO;
    [finder.trash emptySecurity:securely];
    finder.trash.warnsBeforeEmptying = warnsBeforeEmptyingOriginalValue;

    return noErr;
}



// return absolute path for file *without* following possible
// leaf symlink
static NSString *getAbsolutePath(NSString *filePath)
{
    NSString *parentDirPath = nil;
    if (![filePath hasPrefix:@"/"]) // relative path
    {
        NSString *currentPath = [NSString stringWithUTF8String:getcwd(NULL,0)];
        parentDirPath = [[currentPath stringByAppendingPathComponent:[filePath stringByDeletingLastPathComponent]] stringByStandardizingPath];
    }
    else // already absolute -- we just want to standardize without following possible leaf symlink
        parentDirPath = [[filePath stringByDeletingLastPathComponent] stringByStandardizingPath];

    return [parentDirPath stringByAppendingPathComponent:[filePath lastPathComponent]];
}


static ProcessSerialNumber getFinderPSN()
{
    ProcessSerialNumber psn = {0, 0};

    NSEnumerator *appsEnumerator = [[[NSWorkspace sharedWorkspace] launchedApplications] objectEnumerator];
    NSDictionary *appInfoDict = nil;
    while ((appInfoDict = [appsEnumerator nextObject]))
    {
        if ([[appInfoDict objectForKey:@"NSApplicationBundleIdentifier"] isEqualToString:@"com.apple.finder"])
        {
            psn.highLongOfPSN = [[appInfoDict objectForKey:@"NSApplicationProcessSerialNumberHigh"] longValue];
            psn.lowLongOfPSN  = [[appInfoDict objectForKey:@"NSApplicationProcessSerialNumberLow"] longValue];
            break;
        }
    }

    return psn;
}


static OSStatus askFinderToMoveFilesToTrash(NSArray *filePaths, BOOL bringFinderToFront)
{
    // Here we manually send Finder the Apple Event that tells it
    // to trash the specified files all at once. This is roughly
    // equivalent to the following AppleScript:
    //
    //   tell application "Finder" to delete every item of
    //     {(POSIX file "/path/one"), (POSIX file "/path/two")}
    //
    // First of all, this doesn't seem to be possible with the
    // Scripting Bridge (the -delete method is only available
    // for individual items there, and we don't want to loop
    // through items, calling that method for each one because
    // then Finder would prompt for authentication separately
    // for each one).
    //
    // The second approach I took was to construct an AppleScript
    // string that looked like the example above, but this
    // seemed a bit volatile. 'has' suggested in a comment on
    // my blog that I could do something like this instead,
    // and I thought it was a good idea. Seems to work just
    // fine and this is noticeably faster this way than generating
    // and executing some AppleScript was. I also don't have
    // to worry about input sanitization anymore.
    //

    // generate list descriptor containting the file URLs
    NSAppleEventDescriptor *urlListDescr = [NSAppleEventDescriptor listDescriptor];
    NSInteger i = 1;
    for (NSString *filePath in filePaths)
    {
        NSURL *url = [NSURL fileURLWithPath:getAbsolutePath(filePath)];
        NSAppleEventDescriptor *descr = [NSAppleEventDescriptor
            descriptorWithDescriptorType:'furl'
            data:[[url absoluteString] dataUsingEncoding:NSUTF8StringEncoding]
            ];
        [urlListDescr insertDescriptor:descr atIndex:i++];
    }

    // generate the 'top-level' "delete" descriptor
    ProcessSerialNumber finderPSN = getFinderPSN();
    NSAppleEventDescriptor *targetDesc = [NSAppleEventDescriptor
        descriptorWithDescriptorType:'psn '
        bytes:&finderPSN
        length:sizeof(finderPSN)
        ];
    NSAppleEventDescriptor *descriptor = [NSAppleEventDescriptor
        appleEventWithEventClass:'core'
        eventID:'delo'
        targetDescriptor:targetDesc
        returnID:kAutoGenerateReturnID
        transactionID:kAnyTransactionID
        ];

    // add the list of file URLs as argument
    [descriptor setDescriptor:urlListDescr forKeyword:'----'];

    if (bringFinderToFront)
        [getFinderApp() activate];

    // send the Apple Event synchronously
    AppleEvent replyEvent;
    OSStatus sendErr = AESendMessage([descriptor aeDesc], &replyEvent, kAEWaitReply, kAEDefaultTimeout);
    if (sendErr != noErr)
        return sendErr;

    // check reply in order to determine return value
    AEDesc replyAEDesc;
    OSStatus getReplyErr = AEGetParamDesc(&replyEvent, keyDirectObject, typeWildCard, &replyAEDesc);
    if (getReplyErr != noErr)
        return getReplyErr;

    NSAppleEventDescriptor *replyDesc = [[[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&replyAEDesc] autorelease];
    if ([replyDesc numberOfItems] == 0
        || ([filePaths count] > 1 && ([replyDesc descriptorType] != typeAEList || [replyDesc numberOfItems] != (NSInteger)[filePaths count])))
        return kHGNotAllFilesTrashedError;

    return noErr;
}


static FSRef getFSRef(NSString *filePath)
{
    FSRef fsRef;
    FSPathMakeRefWithOptions(
        (const UInt8 *)[filePath fileSystemRepresentation],
        kFSPathMakeRefDoNotFollowLeafSymlink,
        &fsRef,
        NULL // Boolean *isDirectory
        );
    return fsRef;
}

static OSStatus moveFileToTrashFSRef(FSRef fsRef)
{
    // We use FSMoveObjectToTrashSync() directly instead of
    // using NSWorkspace's performFileOperation:... (which
    // uses FSMoveObjectToTrashSync()) because the former
    // returns us an OSStatus describing a possible error
    // and the latter only returns a BOOL describing success
    // or failure.
    //
    OSStatus ret = FSMoveObjectToTrashSync(&fsRef, NULL, kFSFileOperationDefaultOptions);
    return ret;
}


static NSString *osStatusToErrorString(OSStatus status)
{
    // GetMacOSStatusCommentString() generally shouldn't be used
    // to provide error messages to users but using it is much better
    // than manually writing a long switch statement and typing up
    // the error messages -- the messages returned by this function
    // are 'good enough' for this program's supposed users.
    //
    return [[NSString stringWithUTF8String:GetMacOSStatusCommentString(status)]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}


static void verbosePrintPaths(NSArray *arr)
{
    for (NSString *path in arr)
    {
        VerbosePrintf(@"%@\n", path);
    }
}


static NSString* versionNumberStr()
{
    return [NSString stringWithFormat:@"%d.%d.%d", VERSION_MAJOR, VERSION_MINOR, VERSION_BUILD];
}

static char *myBasename;
static void printUsage()
{
    Printf(@"usage: %s [-avlesy] <file> [<file> ...]\n", myBasename);
    Printf(@"\n"
           @"  Move files/folders to the trash.\n"
           @"\n"
           @"  Options to use with <file>:\n"
           @"\n"
           @"  -a  Use system API for trashing files instead of asking\n"
           @"      Finder to do it. (Faster, but the 'put back' feature\n"
           @"      in the Finder trash will not work if files are trashed\n"
           @"      using this method.) Finder is still used for trashing\n"
           @"      files you have no access rights for.\n"
           @"  -v  Be verbose (show files as they are trashed, or if\n"
           @"      used with the -l option, show additional information\n"
           @"      about the trash contents)\n"
           @"\n"
           @"  Stand-alone options (to use without <file>):\n"
           @"\n"
           @"  -l  List items currently in the trash (add the -v option\n"
           @"      to see additional information)\n"
           @"  -e  Empty the trash (asks for confirmation)\n"
           @"  -s  Securely empty the trash (asks for confirmation)\n"
           @"  -y  Skips the confirmation prompt for -e and -s.\n"
           @"      CAUTION: Deletes permanently instantly.\n"
           @"\n"
           @"  Options supported by `rm` are silently accepted.\n"
           @"\n"
           @"Version %@\n"
           @"Copyright (c) 2010 Ali Rantakari, http://hasseg.org/trash\n"
           @"\n", versionNumberStr());
}



int main(int argc, char *argv[])
{
    NSAutoreleasePool *autoReleasePool = [[NSAutoreleasePool alloc] init];

    int exitValue = 0;
    myBasename = basename(argv[0]);

    if (argc == 1)
    {
        printUsage();
        return 0;
    }

    BOOL arg_list = NO;
    BOOL arg_empty = NO;
    BOOL arg_emptySecurely = NO;
    BOOL arg_skipPrompt = NO;
    BOOL arg_useFinderForAll = YES;

    char *optstring =
        "avlesy" // The options we support
        "dfirPRW" // Options supported by `rm`
        ;

    int opt;
    while ((opt = getopt(argc, argv, optstring)) != EOF)
    {
        switch (opt)
        {
            case 'a':   arg_useFinderForAll = NO;
                break;
            case 'v':   arg_verbose = YES;
                break;
            case 'l':   arg_list = YES;
                break;
            case 'e':   arg_empty = YES;
                break;
            case 's':   arg_emptySecurely = YES;
                break;
            case 'y':   arg_skipPrompt = YES;
                break;
            case 'd':
            case 'f':
            case 'i':
            case 'r':
            case 'P':
            case 'R':
            case 'W':
                // Silently accept `rm`'s arguments
                break;
            case '?':
            default:
                printUsage();
                return 1;
        }
    }


    if (arg_list)
    {
        listTrashContents(arg_verbose);
        return 0;
    }
    else if (arg_empty || arg_emptySecurely)
    {
        OSStatus status = emptyTrash(arg_emptySecurely, arg_skipPrompt);
        return (status == noErr) ? 0 : 1;
    }

    if (!arg_useFinderForAll)
        checkForRoot();

    // Always separate restricted and other items and call askFinderToMoveFilesToTrash() for
    // both groups separately because if the user cancels the authentication any files listed
    // after the first restricted item are not trashed at all
    NSMutableArray *nonRestrictedPathsForFinder = [NSMutableArray arrayWithCapacity:argc];
    NSMutableArray *restrictedPathsForFinder = [NSMutableArray arrayWithCapacity:argc];

    int i;
    for (i = optind; i < argc; i++)
    {
        // Note: don't standardize the path! we don't want to expand leaf symlinks.
        NSString *path = [[NSString stringWithUTF8String:argv[i]] stringByExpandingTildeInPath];
        if (path == nil)
        {
            PrintfErr(@"trash: %s: invalid path\n", argv[i]);
            continue;
        }

        if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            PrintfErr(@"trash: %s: path does not exist\n", argv[i]);
            exitValue = 1;
            continue;
        }

        FSRef fsRef = getFSRef(path);

        if (arg_useFinderForAll)
        {
            // get file info
            FSCatalogInfo catInfo;
            OSErr getCatalogStatus = FSGetCatalogInfo(
                &fsRef,
                kFSCatInfoUserPrivs|kFSCatInfoPermissions,
                &catInfo,
                NULL, // HFSUniStr255 *outName
                NULL, // FSSpecPtr fsSpec
                NULL // FSRef *parentRef
                );
            if (getCatalogStatus != noErr)
            {
                PrintfErr(
                    @"trash: %s: cannot get file privileges (%i: %@)\n",
                    argv[i],
                    getCatalogStatus,
                    osStatusToErrorString(getCatalogStatus)
                    );
                exitValue = 1;
                continue;
            }

            BOOL deletable = ((catInfo.userPrivileges & kioACUserNoMakeChangesMask) == 0);

            if (!deletable)
                [restrictedPathsForFinder addObject:path];
            else
                [nonRestrictedPathsForFinder addObject:path];

            continue;
        }

        OSStatus status = moveFileToTrashFSRef(fsRef);
        if (status == afpAccessDenied)
            [restrictedPathsForFinder addObject:path];
        else if (status != noErr)
        {
            exitValue = 1;
            PrintfErr(
                @"trash: %s: can not move to trash (%i: %@)\n",
                argv[i],
                status,
                osStatusToErrorString(status)
                );
        }
        else
            VerbosePrintf(@"%@\n", path);
    }


    if ([nonRestrictedPathsForFinder count] > 0)
    {
        OSStatus status = askFinderToMoveFilesToTrash(nonRestrictedPathsForFinder, NO);
        if (status != noErr)
            exitValue = 1;
        else
            verbosePrintPaths(nonRestrictedPathsForFinder);

        if (status == kHGNotAllFilesTrashedError)
            PrintfErr(@"trash: some files were not moved to trash\n");
        else if (status != noErr)
            PrintfErr(@"trash: error %i\n", status);
    }

    if ([restrictedPathsForFinder count] > 0)
    {
        OSStatus status = askFinderToMoveFilesToTrash(restrictedPathsForFinder, YES);
        if (status != noErr)
            exitValue = 1;
        else
            verbosePrintPaths(restrictedPathsForFinder);

        if (status == kHGNotAllFilesTrashedError)
            PrintfErr(@"trash: some files were not moved to trash (authentication cancelled?)\n");
        else if (status != noErr)
            PrintfErr(@"trash: error %i\n", status);
    }


    [autoReleasePool release];
    return exitValue;
}








