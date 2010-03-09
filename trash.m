//  trash.m
//
//  Created by Ali Rantakari
//  http://hasseg.org
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

// (Apple reserves OSStatus values outside the range 1000-9999 inclusive)
#define kHGAppleScriptError		9999
#define kHGUserCancelledError	9998

const int VERSION_MAJOR = 0;
const int VERSION_MINOR = 6;
const int VERSION_BUILD = 3;

BOOL arg_verbose = NO;



// helper methods for printing to stdout and stderr

// other Printf functions call this, and you call them
void RealPrintf(NSString *aStr, va_list args)
{
	NSString *str = [
		[[NSString alloc]
			initWithFormat:aStr
			locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
			arguments:args
			] autorelease
		];
	
	[str writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

void VerbosePrintf(NSString *aStr, ...)
{
	if (!arg_verbose)
		return;
	va_list argList;
	va_start(argList, aStr);
	RealPrintf(aStr, argList);
	va_end(argList);
}

void Printf(NSString *aStr, ...)
{
	va_list argList;
	va_start(argList, aStr);
	RealPrintf(aStr, argList);
	va_end(argList);
}

void PrintfErr(NSString *aStr, ...)
{
	va_list argList;
	va_start(argList, aStr);
	NSString *str = [
		[[NSString alloc]
			initWithFormat:aStr
			locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
			arguments:argList
			] autorelease
		];
	va_end(argList);
	
	[str writeToFile:@"/dev/stderr" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}



void checkForRoot()
{
	if (getuid() == 0)
	{
		Printf(@"You seem to be running as root. Any files trashed\n");
		Printf(@"as root will be moved to root's trash folder instead\n");
		Printf(@"of your trash folder. Are you sure you want to continue?\n");
		Printf(@"[y/N]: ");
		char inputChar;
		scanf("%s&*c",&inputChar);
		
		if (inputChar != 'y' && inputChar != 'Y')
			exit(0);
	}
}



OSStatus emptyTrash(BOOL securely)
{
	FinderApplication *finder = [SBApplication applicationWithBundleIdentifier:@"com.apple.Finder"];
	
	NSUInteger trashItemsCount = [[finder.trash items] count];
	if (trashItemsCount == 0)
	{
		Printf(@"The trash is already empty.\n");
		return noErr;
	}
	
	BOOL plural = (trashItemsCount > 1);
	Printf(
		@"There %@ currently %i item%@ in the trash.\nAre you sure you want to permanantly%@ delete %@ item%@?\n%@",
		plural?@"are":@"is",
		trashItemsCount,
		plural?@"s":@"",
		securely?@" (and securely)":@"",
		plural?@"these":@"this",
		plural?@"s":@"",
		securely?@"(secure empty trash will take a long while so be prepared to wait)\n":@""
		);
	
	Printf(@"[y/N]: ");
	char inputChar;
	scanf("%s&*c",&inputChar);
	
	if (inputChar != 'y' && inputChar != 'Y')
		return kHGUserCancelledError;
	
	finder.trash.warnsBeforeEmptying = NO;
	[finder.trash emptySecurity:securely];
	
	return noErr;
}

void listTrashContents()
{
	FinderApplication *finder = [SBApplication applicationWithBundleIdentifier:@"com.apple.Finder"];
	for (id item in [finder.trash items])
	{
		Printf(@"%@\n", [[NSURL URLWithString:(NSString *)[item URL]] path]);
	}
}


// return absolute path for file *without* following possible
// leaf symlink
NSString *getAbsolutePath(NSString *filePath)
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


OSStatus askFinderToMoveFilesToTrash(NSArray *filePaths)
{
	// If we only have one file, we'll use the Scripting
	// Bridge instead of constructing an AppleScript string,
	// compiling and executing it (which is slllow).
	// 
	
	if ([filePaths count] == 1)
	{
		FinderApplication *finder = [SBApplication applicationWithBundleIdentifier:@"com.apple.Finder"];
		[finder activate];
		NSString *absPath = getAbsolutePath([filePaths objectAtIndex:0]);
		NSURL *url = [NSURL fileURLWithPath:absPath];
		[[[finder items] objectAtLocation:url] delete];
		return noErr;
	}
	
	// More than one file to trash:
	// Construct AppleScript to trash all of the given files
	// at once (so that Finder would only ask for authentication
	// once instead of for each one separately). I don't know
	// how to do this with the Scripting Bridge.
	// 
	
	NSMutableString *asStr = [NSMutableString stringWithString:@"tell application \"Finder\"\nactivate\ndelete every item of {"];
	
	NSMutableArray *fileASList = [NSMutableArray arrayWithCapacity:[filePaths count]];
	for (NSString *filePath in filePaths)
	{
		NSString *absPath = getAbsolutePath(filePath);
		absPath = [absPath stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
		[fileASList addObject:[NSString stringWithFormat:@"(POSIX file \"%@\")", absPath]];
	}
	
	[asStr appendString:[fileASList componentsJoinedByString:@", "]];
	[asStr appendString:@"}\nend tell"];
	
	// execute
	NSDictionary *asError = nil;
	NSAppleScript *trashFilesAS = [[NSAppleScript alloc] initWithSource:asStr];
	NSAppleEventDescriptor *ed = [trashFilesAS executeAndReturnError:&asError];
	[trashFilesAS release];
	
	if (ed != nil)
	{
		if ([ed numberOfItems] == 0)
			return kHGUserCancelledError; // this is an informed guess
		if (asError == nil)
			return noErr;
	}
	
	PrintfErr(@"AppleScript error: %@\n", asError);
	return kHGAppleScriptError;
}


OSStatus moveFileToTrash(NSString *filePath)
{
	// We use FSMoveObjectToTrashSync() directly instead of
	// using NSWorkspace's performFileOperation:... (which
	// uses FSMoveObjectToTrashSync()) because the former
	// returns us an OSStatus describing a possible error
	// and the latter only returns a BOOL describing success
	// or failure.
	// 
	
	if (filePath == nil)
		return bdNamErr;
	
	FSRef fsRef;
	FSPathMakeRefWithOptions(
		(const UInt8 *)[filePath fileSystemRepresentation],
		kFSPathMakeRefDoNotFollowLeafSymlink,
		&fsRef,
		NULL // Boolean *isDirectory
		);
	OSStatus ret = FSMoveObjectToTrashSync(&fsRef, NULL, kFSFileOperationDefaultOptions);
	VerbosePrintf(@"%@\n", filePath);
	return ret;
}


NSString *osStatusToErrorString(OSStatus status)
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


NSString* versionNumberStr()
{
	return [NSString stringWithFormat:@"%d.%d.%d", VERSION_MAJOR, VERSION_MINOR, VERSION_BUILD];
}

char *myBasename;
void printUsage()
{
	Printf(@"usage: %s [-vles] <file> [<file> ...]\n", myBasename);
	Printf(@"\n");
	Printf(@"  Move files/folders to the trash.\n");
	Printf(@"\n");
	Printf(@"  Options:\n");
	Printf(@"\n");
	Printf(@"  -v  Be verbose; show files as they are deleted\n");
	Printf(@"  -l  List items currently in the trash\n");
	Printf(@"  -e  Empty the trash (asks for confirmation)\n");
	Printf(@"  -s  Securely empty the trash (asks for confirmation)\n");
	Printf(@"\n");
	Printf(@"Version %@\n", versionNumberStr());
	Printf(@"Copyright (c) 2010 Ali Rantakari, http://hasseg.org/trash\n");
	Printf(@"\n");
}



int main(int argc, char *argv[])
{
	NSAutoreleasePool *autoReleasePool = [[NSAutoreleasePool alloc] init];
	
	int exitValue = 0;
	myBasename = basename(argv[0]);
	
	checkForRoot();
	
	if (argc == 1)
	{
		printUsage();
		return 0;
	}
	
	BOOL arg_list = NO;
	BOOL arg_empty = NO;
	BOOL arg_emptySecurely = NO;
	
	int opt;
	while ((opt = getopt(argc, argv, "vles")) != EOF)
	{
		switch (opt)
		{
			case 'v':	arg_verbose = YES;
				break;
			case 'l':	arg_list = YES;
				break;
			case 'e':	arg_empty = YES;
				break;
			case 's':	arg_emptySecurely = YES;
				break;
			case '?':
			default:
				printUsage();
				return 1;
		}
	}
	
	
	if (arg_list)
	{
		listTrashContents();
		return 0;
	}
	else if (arg_empty || arg_emptySecurely)
	{
		OSStatus status = emptyTrash(arg_emptySecurely);
		return (status == noErr) ? 0 : 1;
	}
	
	
	NSMutableArray *restrictedPaths = [NSMutableArray arrayWithCapacity:argc];
	
	int i;
	for (i = optind; i < argc; i++)
	{
		// Note: don't standardize the path! we don't want to expand leaf symlinks.
		NSString *path = [[NSString stringWithUTF8String:argv[i]] stringByExpandingTildeInPath];
		if (path == nil)
		{
			PrintfErr(@"Error: invalid path: %s\n", argv[i]);
			continue;
		}
		
		OSStatus status = moveFileToTrash(path);
		if (status == afpAccessDenied)
			[restrictedPaths addObject:path];
		else if (status != noErr)
		{
			exitValue = 1;
			PrintfErr(@"Error: can not trash: %@ (%@)\n", path, osStatusToErrorString(status));
		}
	}
	
	if ([restrictedPaths count] > 0)
	{
		OSStatus status = askFinderToMoveFilesToTrash(restrictedPaths);
		if (status == kHGUserCancelledError)
		{
			for (NSString *path in restrictedPaths)
				PrintfErr(@"Error: authentication was cancelled: %@\n", path);
		}
	}
	
	
	[autoReleasePool release];
	return exitValue;
}








