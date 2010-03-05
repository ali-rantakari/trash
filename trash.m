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

// returns YES if success, NO if failure
BOOL moveFileToTrash(NSString *filePath)
{
	if (filePath == nil)
		return NO;
	
	NSString *fileDir = [filePath stringByDeletingLastPathComponent];
	NSString *fileName = [filePath lastPathComponent];
	
	// in 10.5, this uses FSMoveObjectToTrashSync()
	// 
	return [[NSWorkspace sharedWorkspace]
		performFileOperation:NSWorkspaceRecycleOperation
		source:fileDir
		destination:@""
		files:[NSArray arrayWithObject:fileName]
		tag:nil
		];
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
	else
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		
		for (NSString *path in paths)
		{
			if (!moveFileToTrash(path))
			{
				if (![fm fileExistsAtPath:path])
					PrintfErr(@"Error: path does not exist: %@\n", path);
				else
					PrintfErr(@"Error: can not delete %@\n", path);
				
				if (exitValue == 0)
					exitValue = 1;
			}
		}
	}
	
	
cleanUpAndExit:
	[autoReleasePool release];
	return exitValue;
}








