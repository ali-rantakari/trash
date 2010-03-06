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






#define kNeedsHelpErr            1
#define kInvalidArgumentErr        2
#define kInvalidDestinationErr    3
#define kCouldNotCreateCFString    4
#define kCouldNotGetStringData    5
#define MAX_PATH                1024

// this code is from an apple sample project:
// http://developer.apple.com/mac/library/samplecode/FSCopyObject/listing8.html
// 
static OSErr ConvertCStringToHFSUniStr(const char* cStr, HFSUniStr255 *uniStr)
{
    OSErr err = noErr;
    CFStringRef tmpStringRef = CFStringCreateWithCString( kCFAllocatorDefault, cStr, kCFStringEncodingMacRoman );
    if( tmpStringRef != NULL )
    {
        if( CFStringGetCString( tmpStringRef, (char*)uniStr->unicode, sizeof(uniStr->unicode), kCFStringEncodingUnicode ) )
            uniStr->length = CFStringGetLength( tmpStringRef );
        else
            err = kCouldNotGetStringData;
            
        CFRelease( tmpStringRef );
    }
    else
        err = kCouldNotCreateCFString;
    
    return err;
}


// this code is from an apple sample project:
// http://developer.apple.com/mac/library/samplecode/FSCopyObject/listing8.html
//
// Due to a bug in the X File Manager, 2489632,
// FSPathMakeRef doesn't handle symlinks properly.  It
// automatically resolves it and returns an FSRef to the
// symlinks target, not the symlink itself.  So this is a
// little workaround for it...
//
// We could call lstat() to find out if the object is a
// symlink or not before jumping into the guts of the
// routine, but its just as simple, and fast when working
// on a single item like this, to send everything through
// this routine
static OSErr MyFSPathMakeRef( const unsigned char *path, FSRef *ref )
{
	FSRef tmpFSRef;
	char tmpPath[ MAX_PATH ],
		*tmpNamePtr;
	OSErr err;
	
	// Get local copy of incoming path
	strcpy( tmpPath, (char*)path );
	
	// Get the name of the object from the given path
	// Find the last / and change it to a '\0' so
	// tmpPath is a path to the parent directory of the
	// object and tmpNamePtr is the name
	tmpNamePtr = strrchr( tmpPath, '/' );
	if( *(tmpNamePtr + 1) == '\0' ) // in case the last character in the path is a /
	{
		*tmpNamePtr = '\0';
		tmpNamePtr = strrchr( tmpPath, '/' );
	}
	*tmpNamePtr = '\0';
	tmpNamePtr++;
	
	// Get the FSRef to the parent directory
	err = FSPathMakeRef( (unsigned char*)tmpPath, &tmpFSRef, NULL );
	if( err == noErr )
	{
		// Convert the name to a Unicode string and pass it
		// to FSMakeFSRefUnicode to actually get the FSRef
		// to the object (symlink)
		HFSUniStr255    uniName;
		err = ConvertCStringToHFSUniStr( tmpNamePtr, &uniName );
		if( err == noErr )
			err = FSMakeFSRefUnicode( &tmpFSRef, uniName.length, uniName.unicode, kTextEncodingUnknown, &tmpFSRef );
	}
	
	if( err == noErr )
		*ref = tmpFSRef;
	
	return err;
}




OSStatus moveFileToTrash(unsigned char *filePath)
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
	
	// path to FSRef
	FSRef fsRef;
	MyFSPathMakeRef(filePath, &fsRef);
	
	/*
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
	*/
	
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
	
	BOOL atLeastOneValidPath = NO;
	int i;
	for (i = 1; i < argc; i++)
	{
		unsigned char *path = (unsigned char *)argv[i];
		
		// note: don't standardize the paths! we don't want to expand symlinks.
		//NSString *nspath = [[NSString stringWithUTF8String:path] stringByExpandingTildeInPath];
		//path = (unsigned char *)[nspath UTF8String];
		
		OSStatus status = moveFileToTrash(path);
		if (status == noErr)
			atLeastOneValidPath = YES;
		else
		{
			exitValue = 1;
			
			/*
			if (fnfErr == status)
			{
				// We get a 'file not found' also in the case
				// where the user lacks execute privileges to the
				// parent folder so let's check for those cases
				// separately.
				// 
				NSString *parentDirPath = [nspath stringByDeletingLastPathComponent];
				if (![[NSFileManager defaultManager] isExecutableFileAtPath:parentDirPath])
					status = afpAccessDenied;
			}
			*/
			
			PrintfErr(@"Error: can not delete: %s (%@)\n", path, osStatusToErrorString(status));
		}
	}
	
	if (!atLeastOneValidPath)
		printUsage();
	
	
cleanUpAndExit:
	[autoReleasePool release];
	return exitValue;
}








