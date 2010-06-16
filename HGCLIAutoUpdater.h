// CLI app auto-update code
// 
// http://hasseg.org/
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

#import <Cocoa/Cocoa.h>
#import "ANSIEscapeHelper.h"


#define kHGCLIAutoUpdateErrorDomain @"org.hasseg.autoUpdate"
#define kServerConnectTimeout 10.0

// helper method: compare three-part version number strings (e.g. "1.12.3")
NSComparisonResult versionNumberCompare(NSString *first, NSString *second);


@interface HGCLIAutoUpdater : NSObject
{
	ANSIEscapeHelper *ansiEscapeHelper;
	NSString *versionCheckHeaderName;
	
	NSString *appName;
	NSString *currentVersionStr;
	NSString *latestVersionStr;
	
	id delegate;
}

@property(retain) id delegate;
@property(retain) ANSIEscapeHelper *ansiEscapeHelper;
@property(copy) NSString *appName;
@property(copy) NSString *versionCheckHeaderName;
@property(copy) NSString *currentVersionStr;
@property(copy) NSString *latestVersionStr;

- (id) initWithAppName:(NSString *)aAppName currentVersionStr:(NSString *)aCurrentVersionStr;

- (void) checkForUpdatesWithUI;

// initiate auto-update
- (void) autoUpdateSelfFromURL:(NSURL *)latestVersionZIPURL;

// returns latest version number (as string) if an update is found online,
// or nil if no update was found. on error, errorStr will contain
// an error message.
- (NSString *) latestUpdateVersionOnServerWithError:(NSError **)error;


@end


@interface NSObject (HGCLIAutoUpdaterDelegate)

- (NSURL *) latestVersionCheckURLWithCurrentVersion:(NSString *)currentVersionStr;
- (NSURL *) latestVersionInfoWebURLWithCurrentVersion:(NSString *)currentVersionStr latestVersion:(NSString *)latestVersionStr;
- (NSURL *) releaseNotesHTMLURLWithCurrentVersion:(NSString *)currentVersionStr latestVersion:(NSString *)latestVersionStr;
- (NSURL *) latestVersionZIPURLWithCurrentVersion:(NSString *)currentVersionStr latestVersion:(NSString *)latestVersionStr;
- (NSString *) commandToRunInstaller;

- (void) autoUpdater:(HGCLIAutoUpdater *)autoUpdater willInstallVersion:(NSString *)latestVersionStr;
- (void) autoUpdater:(HGCLIAutoUpdater *)autoUpdater didInstallVersion:(NSString *)latestVersionStr;
- (void) autoUpdater:(HGCLIAutoUpdater *)autoUpdater didFailToInstallVersion:(NSString *)latestVersionStr;

@end
