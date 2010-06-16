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


#import "HGCLIAutoUpdater.h"
#import "HGCLIUtils.h"

NSComparisonResult versionNumberCompare(NSString *first, NSString *second)
{
	if (first != nil && second != nil)
	{
		int i;
		
		NSMutableArray *firstComponents = [NSMutableArray arrayWithCapacity:3];
		[firstComponents addObjectsFromArray:[first componentsSeparatedByString:@"."]];
		
		NSMutableArray *secondComponents = [NSMutableArray arrayWithCapacity:3];
		[secondComponents addObjectsFromArray:[second componentsSeparatedByString:@"."]];
		
		if ([firstComponents count] != [secondComponents count])
		{
			NSMutableArray *shorter;
			NSMutableArray *longer;
			if ([firstComponents count] > [secondComponents count])
			{
				shorter = secondComponents;
				longer = firstComponents;
			}
			else
			{
				shorter = firstComponents;
				longer = secondComponents;
			}
			
			NSUInteger countDiff = [longer count] - [shorter count];
			
			for (i = 0; i < countDiff; i++)
				[shorter addObject:@"0"];
		}
		
		for (i = 0; i < [firstComponents count]; i++)
		{
			int firstComponentIntVal = [[firstComponents objectAtIndex:i] intValue];
			int secondComponentIntVal = [[secondComponents objectAtIndex:i] intValue];
			if (firstComponentIntVal < secondComponentIntVal)
				return NSOrderedAscending;
			else if (firstComponentIntVal > secondComponentIntVal)
				return NSOrderedDescending;
		}
		return NSOrderedSame;
	}
	else
		return NSOrderedSame;
}




@implementation HGCLIAutoUpdater

@synthesize delegate;
@synthesize ansiEscapeHelper;
@synthesize appName;
@synthesize versionCheckHeaderName;
@synthesize currentVersionStr;
@synthesize latestVersionStr;


- (id) initWithAppName:(NSString *)aAppName
	 currentVersionStr:(NSString *)aCurrentVersionStr
{
	if (!(self = [super init]))
		return nil;
	
	// set defaults
	self.ansiEscapeHelper = [[[ANSIEscapeHelper alloc] init] autorelease];
	self.versionCheckHeaderName = @"Orghassegsoftwarelatestversion";
	
	self.appName = aAppName;
	self.currentVersionStr = aCurrentVersionStr;
	
	return self;
}

- (void) dealloc
{
	self.delegate = nil;
	self.ansiEscapeHelper = nil;
	self.versionCheckHeaderName = nil;
	self.appName = nil;
	self.currentVersionStr = nil;
	self.latestVersionStr = nil;
	[super dealloc];
}


- (NSString *) latestUpdateVersionOnServerWithError:(NSError **)error;
{
	// check if delegate gives us the URL where we can get the latest version
	NSURL *versionCheckURL = nil;
	if (self.delegate != nil && [self.delegate respondsToSelector:@selector(latestVersionCheckURLWithCurrentVersion:)])
		versionCheckURL = [self.delegate latestVersionCheckURLWithCurrentVersion:self.currentVersionStr];
	
	NSCAssert((versionCheckURL != nil), @"delegate returned nil for latestVersionCheckURLWithCurrentVersion:");
	
	NSURLRequest *request = [NSURLRequest
		requestWithURL:versionCheckURL
		cachePolicy:NSURLRequestReloadIgnoringCacheData
		timeoutInterval:kServerConnectTimeout
		];
	
	NSHTTPURLResponse *response = nil;
	NSError *connError = nil;
	[NSURLConnection
		sendSynchronousRequest:request
		returningResponse:&response
		error:&connError
		];
	
	if (connError == nil && response != nil)
	{
		NSInteger statusCode = [response statusCode];
		if (statusCode >= 400)
		{
			if (error != NULL)
				*error = [NSError
					errorWithDomain:kHGCLIAutoUpdateErrorDomain
					code:0
					userInfo:[NSDictionary
						dictionaryWithObject:[NSString
							stringWithFormat:@"HTTP connection failed. Status code %d: \"%@\"",
							statusCode,
							[NSHTTPURLResponse localizedStringForStatusCode:statusCode]]
						forKey:NSLocalizedDescriptionKey
						]
					];
			return nil;
		}
		else
		{
			NSString *thisLatestVersionString = [[response allHeaderFields] valueForKey:self.versionCheckHeaderName];
			
			if (thisLatestVersionString == nil)
			{
				if (error != NULL)
					*error = [NSError
						errorWithDomain:kHGCLIAutoUpdateErrorDomain
						code:0
						userInfo:[NSDictionary
							dictionaryWithObject:@"Error reading latest version number from HTTP header field."
							forKey:NSLocalizedDescriptionKey
							]
						];
				return nil;
			}
			else
			{
				if (versionNumberCompare(self.currentVersionStr, thisLatestVersionString) == NSOrderedAscending)
					return thisLatestVersionString;
			}
		}
	}
	else
	{
		if (error != NULL)
		{
			if (connError != nil)
				*error = connError;
			else
				*error = [NSError
					errorWithDomain:kHGCLIAutoUpdateErrorDomain
					code:0
					userInfo:[NSDictionary
						dictionaryWithObject:@"No response from server."
						forKey:NSLocalizedDescriptionKey
						]
					];
		}
		return nil;
	}
	
	return nil;
}




- (void) checkForUpdatesWithUI
{
	Printf(@"Checking for updates... ");
	
	NSError *versionCheckError = nil;
	self.latestVersionStr = [self latestUpdateVersionOnServerWithError:&versionCheckError];
	
	if (self.latestVersionStr == nil && versionCheckError != nil)
	{
		PrintfErr(@"...%@", [versionCheckError localizedDescription]);
		return;
	}
	
	if (self.latestVersionStr == nil)
	{
		Printf(@"...you're up to date! (current & latest: %@)\n\n", self.currentVersionStr);
		return;
	}
	
	Printf(@"...update found! (latest: %@  current: %@)\n\n", self.latestVersionStr, self.currentVersionStr);
	
	// check if delegate gives us the URL for a 'latest version' release info web page
	NSURL *latestVersionInfoWebURL = nil;
	if (self.delegate != nil && [self.delegate respondsToSelector:@selector(latestVersionInfoWebURLWithCurrentVersion:latestVersion:)])
		latestVersionInfoWebURL = [self.delegate latestVersionInfoWebURLWithCurrentVersion:self.currentVersionStr latestVersion:self.latestVersionStr];
	
	// check if delegate gives us the URL for a 'latest version' release ZIP archive
	NSURL *latestVersionZIPURL = nil;
	if (self.delegate != nil && [self.delegate respondsToSelector:@selector(latestVersionZIPURLWithCurrentVersion:latestVersion:)])
		latestVersionZIPURL = [self.delegate latestVersionZIPURLWithCurrentVersion:self.currentVersionStr latestVersion:self.latestVersionStr];
	
	
	if (latestVersionInfoWebURL != nil)
		Printf(
			@"Navigate to the following URL to see the release notes and download the latest version:\n\n%@\n\n",
			latestVersionInfoWebURL
			);
	
	Printf(@"What would you like to do?\n");
	if (latestVersionInfoWebURL != nil)
		Printf(@"  w = open the release info website in my browser\n");
	Printf(@"  q = quit\n");
	if (latestVersionZIPURL != nil)
	{
		Printf(@"  a = show a list of what's changed since the current\n");
		Printf(@"      version and then choose whether to automatically\n");
		Printf(@"      download and install the latest version\n");
	}
	
	if (latestVersionInfoWebURL == nil && latestVersionZIPURL == nil)
		return;
	
	char inputChar;
	for(;;)
	{
		Printf(@"[selection]: ");
		scanf("%s&*c",&inputChar);
		
		if (inputChar == 'q' || inputChar == 'Q')
			return;
		
		if (latestVersionZIPURL != nil
			&& (inputChar == 'a' || inputChar == 'A'))
		{
			[self autoUpdateSelfFromURL:latestVersionZIPURL];
			break;
		}
		
		if (latestVersionInfoWebURL != nil
			&& (inputChar == 'W' || inputChar == 'w'))
		{
			[[NSWorkspace sharedWorkspace] openURL:latestVersionInfoWebURL];
			break;
		}
	}
}




// This function is subject to buffer overflows and quoting issues (see the
// calls to system() and especially the snprintf() calls before them) but
// this shouldn't be an issue as long as the URLs don't have double quotes
// in them and they are not too long.
// 
- (void) autoUpdateSelfFromURL:(NSURL *)latestVersionZIPURL
{
	NSCAssert((self.appName != nil), @"self.appName is nil");
	NSCAssert((self.currentVersionStr != nil), @"self.currentVersionStr is nil");
	NSCAssert((self.latestVersionStr != nil), @"self.latestVersionStr is nil");
	
	NSString *tempDir = NSTemporaryDirectory();
	if (tempDir == nil)
		tempDir = @"/tmp";
	
	BOOL updateSuccess = NO;
	int exitStatus = 0;
	size_t CMD_SIZE = 10000;
	char cmd [CMD_SIZE];
	NSString *archiveFilename = [NSString stringWithFormat:@"%@-autoUpdate-archive.zip", escapeDoubleQuotes(self.appName)];
	NSString *archivePath = [tempDir stringByAppendingPathComponent:archiveFilename];
	NSString *archiveExtractDirname = [NSString stringWithFormat:@"%@-autoUpdate-tempdir", escapeDoubleQuotes(self.appName)];
	NSString *archiveExtractPath = [tempDir stringByAppendingPathComponent:archiveExtractDirname];
	
	
	// check if delegate gives us the URL for changelog HTML data
	NSURL *whatsChangedHTMLURL = nil;
	if (self.delegate != nil && [self.delegate respondsToSelector:@selector(releaseNotesHTMLURLWithCurrentVersion:latestVersion:)])
		whatsChangedHTMLURL = [self.delegate releaseNotesHTMLURLWithCurrentVersion:self.currentVersionStr latestVersion:self.latestVersionStr];
	
	if (whatsChangedHTMLURL != nil)
	{
		Printf(@"\n\n");
		Printf(@"CHANGES SINCE THE CURRENT VERSION (%@):\n", currentVersionStr);
		Printf(@"=============================================\n");
		Printf(@"\n");
		
		NSURLRequest *whatsChangedRequest = [NSURLRequest
			requestWithURL:whatsChangedHTMLURL
			cachePolicy:NSURLRequestReloadIgnoringCacheData
			timeoutInterval:kServerConnectTimeout
			];
		
		NSHTTPURLResponse *whatsChangedResponse = nil;
		NSError *whatsChangedError = nil;
		NSData *whatsChangedData = [NSURLConnection
			sendSynchronousRequest:whatsChangedRequest
			returningResponse:&whatsChangedResponse
			error:&whatsChangedError
			];
		
		if (whatsChangedError == nil && whatsChangedResponse != nil && whatsChangedData != nil)
		{
			NSInteger statusCode = [whatsChangedResponse statusCode];
			if (statusCode >= 400)
			{
				PrintfErr(@"\n\nFailed to load list of changes from server (HTTP status code: %d \"%@\")\n\n",
					statusCode,
					[NSHTTPURLResponse localizedStringForStatusCode:statusCode]
					);
				return;
			}
			else
			{
				NSAttributedString *whatsChangedAttrStr = [[[NSAttributedString alloc]
					initWithHTML:whatsChangedData
					documentAttributes:NULL
					] autorelease];
				NSMutableAttributedString *whatsChangedMAttrStr = [[[NSMutableAttributedString alloc] init] autorelease];
				[whatsChangedMAttrStr appendAttributedString:whatsChangedAttrStr];
				
				// fix bullet points (replace tabs after bullets with spaces)
				replaceInMutableAttrStr(whatsChangedMAttrStr, @"•\t", ATTR_STR(@"• "));
				
				wordWrapMutableAttrStr(whatsChangedMAttrStr, 80);
				
				NSString *whatsChangedFinalOutput = [self.ansiEscapeHelper ansiEscapedStringWithAttributedString:whatsChangedMAttrStr];
				
				Print(whatsChangedFinalOutput);
			}
		}
		else
		{
			PrintfErr(@"\n\nFailed to load list of changes from server (error: %@)\n\n",
				(whatsChangedError != nil)?[whatsChangedError localizedDescription]:@"?"
				);
			goto cleanup;
		}
	}
	
	Printf(@"\n\n");
	Printf(@"=============================================\n");
	Printf(@"Do you want to automatically download and\n");
	Printf(@"install the latest version (%@) ?\n", latestVersionStr);
	
	char inputChar = '\0';
	while(inputChar != 'y' && inputChar != 'Y' &&
		  inputChar != 'n' && inputChar != 'N' &&
		  inputChar != '\n'
		  )
	{
		Printf(@"[y/n]: ");
		scanf("%s&*c",&inputChar);
	}
	
	if (inputChar != 'y' && inputChar != 'Y')
		goto cleanup;
	
	NSString *zipURLStr = [latestVersionZIPURL absoluteString];
	
	Printf(@"\n\n");
	Printf(@">> Downloading distribution archive...\n");
	Printf(@"--------------------------------------------\n");
	Printf(@" - downloading from: %@\n", zipURLStr);
	Printf(@" - saving archive to: %@\n", archivePath);
	Printf(@"\n");
	
	snprintf(
		cmd, CMD_SIZE,
		"curl \"%s\" > \"%s\"",
		[escapeDoubleQuotes(zipURLStr) UTF8String],
		[archivePath UTF8String]
		);
	exitStatus = system(cmd);
	
	if (exitStatus != 0)
	{
		PrintfErr(@"\n\nAutomatic update failed with exit status %i\n\n", exitStatus);
		goto cleanup;
	}
	
	Printf(@"\n\n");
	Printf(@">> Extracting distribution archive...\n");
	Printf(@"--------------------------------------------\n");
	Printf(@" - extracting to: %@\n", archiveExtractPath);
	Printf(@"\n");
	
	snprintf(
		cmd, CMD_SIZE,
		"mkdir -p \"%s\" && unzip \"%s\" -d \"%s\"",
		[archiveExtractPath UTF8String],
		[archivePath UTF8String],
		[archiveExtractPath UTF8String]
		);
	exitStatus = system(cmd);
	
	if (exitStatus != 0)
	{
		PrintfErr(@"\n\nAutomatic update failed with exit status %i\n\n", exitStatus);
		goto cleanup;
	}
	
	Printf(@"\n\n");
	Printf(@">> Running installation script...\n");
	Printf(@"--------------------------------------------\n");
	
	// check if delegate gives us the command for running the installer
	NSString *installCmd = @"./install.command"; // default
	if (self.delegate != nil && [self.delegate respondsToSelector:@selector(commandToRunInstaller)])
		installCmd = [self.delegate commandToRunInstaller];
	
	// notify delegate
	if (self.delegate != nil && [self.delegate respondsToSelector:@selector(autoUpdater:willInstallVersion:)])
		[self.delegate autoUpdater:self willInstallVersion:self.latestVersionStr];
	
	snprintf(
		cmd, CMD_SIZE,
		"cd \"%s\" && %s",
		[archiveExtractPath UTF8String],
		[installCmd UTF8String]
		);
	exitStatus = system(cmd);
	
	if (exitStatus != 0)
	{
		PrintfErr(@"\n\nAutomatic update failed with exit status %i\n\n", exitStatus);
		goto cleanup;
	}
	
	updateSuccess = YES;
	
cleanup:
	Printf(@"\n\n");
	Printf(@">> Cleaning up...\n");
	Printf(@"--------------------------------------------\n");
	
	BOOL fileDeleteSuccess = NO;
	if (archivePath != nil && [[NSFileManager defaultManager] fileExistsAtPath:archivePath])
	{
		Printf(@" - Moving distribution archive to trash\n");
		fileDeleteSuccess = moveFileToTrash(archivePath);
		if (!fileDeleteSuccess)
			PrintfErr(@"   Could not move to trash.\n");
	}
	
	if (archiveExtractPath != nil && [[NSFileManager defaultManager] fileExistsAtPath:archiveExtractPath])
	{
		Printf(@" - Moving temporary extract folder for distribution archive to trash\n");
		fileDeleteSuccess = moveFileToTrash(archiveExtractPath);
		if (!fileDeleteSuccess)
			PrintfErr(@"   Could not move to trash.\n");
	}
	
	if (updateSuccess)
	{
		Printf(@"\n\n");
		Printf(@"=======================\n");
		Printf(@"%@ has been successfully updated to v%@!\n", self.appName, self.latestVersionStr);
		Printf(@"\n");
		
		// notify delegate
		if (self.delegate != nil && [self.delegate respondsToSelector:@selector(autoUpdater:didInstallVersion:)])
			[self.delegate autoUpdater:self didInstallVersion:self.latestVersionStr];
	}
	else
	{
		// notify delegate
		if (self.delegate != nil && [self.delegate respondsToSelector:@selector(autoUpdater:didFailToInstallVersion:)])
			[self.delegate autoUpdater:self didFailToInstallVersion:self.latestVersionStr];
	}
}




@end

