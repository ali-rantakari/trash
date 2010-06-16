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

#import "HGCLIAutoUpdaterDelegate.h"
#import "HGCLIAutoUpdater.h"
#import "HGCLIUtils.h"


#define kAppSiteURLPrefixFormat @"http://hasseg.org/%@/"


@implementation HGCLIAutoUpdaterDelegate

- (id) initWithAppName:(NSString *)aAppName
{
	if (!(self = [super init]))
		return nil;
	
	appName = [aAppName copy];
	
	return self;
}

- (void) dealloc
{
	[appName release], appName = nil;
	[super dealloc];
}



- (NSString *) appSiteURLPrefix
{
	return [NSString stringWithFormat:kAppSiteURLPrefixFormat, appName];
}


- (NSURL *) latestVersionCheckURLWithCurrentVersion:(NSString *)currentVersionStr
{
	return [NSURL URLWithString:strConcat([self appSiteURLPrefix], @"?versioncheck=y", nil)];
}

- (NSURL *) latestVersionInfoWebURLWithCurrentVersion:(NSString *)currentVersionStr latestVersion:(NSString *)latestVersionStr
{
	return [NSURL URLWithString:strConcat([self appSiteURLPrefix], @"?currentversion=", currentVersionStr, nil)];
}

- (NSURL *) releaseNotesHTMLURLWithCurrentVersion:(NSString *)currentVersionStr latestVersion:(NSString *)latestVersionStr
{
	return [NSURL URLWithString:strConcat([self appSiteURLPrefix], @"?whatschanged=y&currentversion=", currentVersionStr, nil)];
}

- (NSURL *) latestVersionZIPURLWithCurrentVersion:(NSString *)currentVersionStr latestVersion:(NSString *)latestVersionStr
{
	NSString *urlStr = strConcat(
		[self appSiteURLPrefix],
		[NSString stringWithFormat:@"%@/%@-v%@.zip", latestVersionStr, appName, latestVersionStr],
		nil
		);
	return [NSURL URLWithString:urlStr];
}

- (NSString *) commandToRunInstaller
{
	return @"./install.command -y";
}


@end

