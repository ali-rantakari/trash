//  trash.m
//
//  Created by Ali Rantakari
//  http://hasseg.org
//

/*
The MIT License

Copyright (c) 2008-2010 Ali Rantakari

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
#import <libgen.h>


const int VERSION_MAJOR = 0;
const int VERSION_MINOR = 9;
const int VERSION_BUILD = 0;

char *myBasename;



// helper methods for printing to stdout and stderr

void Print(NSString *aStr)
{
	if (aStr == nil)
		return;
	[aStr writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

void Printf(NSString *aStr, ...)
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
	
	[str writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
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
		return NO;
	
	// path to FSRef
	FSRef fsRef;
	const char *filePathCString = [filePath UTF8String];
	CFURLRef filePathURL = CFURLCreateWithBytes(
		kCFAllocatorDefault,
		(const UInt8 *)filePathCString,
		strlen(filePathCString),
		kCFStringEncodingUTF8,
		NULL // CFURLRef baseURL
		);
	CFURLGetFSRef(filePathURL, &fsRef);
	CFRelease(filePathURL);
	
	// perform trashing, return OSStatus
	return FSMoveObjectToTrashSync(&fsRef, NULL, kFSFileOperationDefaultOptions);
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

void printUsage()
{
	Printf(@"usage: %s <file> ...\n", myBasename);
	Printf(@"\n");
	Printf(@"  Move files/folders to the trash.\n");
	Printf(@"\n");
	Printf(@"Version %@\n", versionNumberStr());
	Printf(@"Copyright (c) 2010 Ali Rantakari, http://hasseg.org/\n");
	Printf(@"\n");
}



int exitValue = 0;
#define EXIT(x)		exitValue = x; goto cleanUpAndExit;

int main(int argc, char *argv[])
{
	NSAutoreleasePool *autoReleasePool = [[NSAutoreleasePool alloc] init];
	
	myBasename = basename(argv[0]);
	
	if (argc == 1)
	{
		printUsage();
		EXIT(0);
	}
	
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:(NSUInteger)argc];
	
	int i;
	for (i = 1; i < argc; i++)
	{
		// note: don't standardize the paths! we don't want to expand symlinks.
		NSString *path = [[NSString stringWithUTF8String:argv[i]] stringByExpandingTildeInPath];
		if (path == nil)
		{
			PrintfErr(@"Error: invalid path: %s\n", argv[i]);
			continue;
		}
		[paths addObject:path];
	}
	
	if ([paths count] == 0)
	{
		printUsage();
		EXIT(1);
	}
	
	for (NSString *path in paths)
	{
		OSStatus status = moveFileToTrash(path);
		if (status != noErr)
		{
			exitValue = 1;
			
			if (fnfErr == status)
			{
				// We get a 'file not found' also in the case
				// where the user lacks execute privileges to the
				// parent folder so let's check for those cases
				// separately.
				// 
				NSString *parentDirPath = [path stringByDeletingLastPathComponent];
				if (![[NSFileManager defaultManager] isExecutableFileAtPath:parentDirPath])
					status = afpAccessDenied;
			}
			
			PrintfErr(@"Error: can not delete: %@ (%@)\n", path, osStatusToErrorString(status));
		}
	}
	
	
cleanUpAndExit:
	[autoReleasePool release];
	return exitValue;
}








