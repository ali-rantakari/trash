//
//  ANSIEscapeHelper.m
//
//  Created by Ali Rantakari on 18.3.09.

/*
The MIT License

Copyright (c) 2008-2009 Ali Rantakari

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

/*
 todo:
 
 - don't add useless "reset" escape codes to the string in
   -ansiEscapedStringWithAttributedString:
 
 */



#import "ANSIEscapeHelper.h"


@implementation ANSIEscapeHelper

@synthesize font;
@synthesize ansiColors;
@synthesize defaultStringColor;

- (id) init
{
	if (( self = [super init] ))
	{
		self.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
		self.defaultStringColor = [NSColor blackColor];
		self.ansiColors = [NSMutableDictionary dictionary];
	}
	
	return self;
}

- (void) dealloc
{
	self.font = nil;
	self.ansiColors = nil;
	self.defaultStringColor = nil;
	[super dealloc];
}



- (NSAttributedString*) attributedStringWithANSIEscapedString:(NSString*)aString
{
	if (aString == nil)
		return nil;
	
	NSString *cleanString;
	NSArray *attributesAndRanges = [self attributesForString:aString cleanString:&cleanString];
	NSMutableAttributedString *attributedString = [[[NSMutableAttributedString alloc]
													initWithString:cleanString
													attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                self.font, NSFontAttributeName,
                                                                self.defaultStringColor, NSForegroundColorAttributeName,
                                                                nil
																]
													] autorelease];
	
	NSDictionary *thisAttributeDict;
	for (thisAttributeDict in attributesAndRanges)
	{
		[attributedString
		 addAttribute:[thisAttributeDict objectForKey:kAttrDictKey_attrName]
		 value:[thisAttributeDict objectForKey:kAttrDictKey_attrValue]
		 range:[[thisAttributeDict objectForKey:kAttrDictKey_range] rangeValue]
		 ];
	}
	
	return attributedString;
}



- (NSString*) ansiEscapedStringWithAttributedString:(NSAttributedString*)aAttributedString;
{
	NSRange limitRange;
	NSRange effectiveRange;
	id attributeValue;
	
	NSMutableArray *codesAndLocations = [NSMutableArray array];
	
	NSArray *attrNames = [NSArray arrayWithObjects:
						  NSFontAttributeName, NSForegroundColorAttributeName,
						  NSBackgroundColorAttributeName, NSUnderlineStyleAttributeName,
						  nil
						  ];
	NSString *thisAttrName;
	for (thisAttrName in attrNames)
	{
		limitRange = NSMakeRange(0, [aAttributedString length]);
		while (limitRange.length > 0)
		{
			attributeValue = [aAttributedString
							  attribute:thisAttrName
							  atIndex:limitRange.location
							  longestEffectiveRange:&effectiveRange
							  inRange:limitRange
							  ];
			
			enum sgrCode thisSGRCode = SGRCodeNoneOrInvalid;
			
			if ([thisAttrName isEqualToString:NSForegroundColorAttributeName])
			{
				if (attributeValue != nil)
					thisSGRCode = [self closestSGRCodeForColor:attributeValue isForegroundColor:YES];
				else
					thisSGRCode = SGRCodeFgReset;
			}
			else if ([thisAttrName isEqualToString:NSBackgroundColorAttributeName])
			{
				if (attributeValue != nil)
					thisSGRCode = [self closestSGRCodeForColor:attributeValue isForegroundColor:NO];
				else
					thisSGRCode = SGRCodeBgReset;
			}
			else if ([thisAttrName isEqualToString:NSFontAttributeName])
			{
				// we currently only use NSFontAttributeName for bolding so
				// here we assume that the formatting "type" in ANSI SGR
				// terms is indeed intensity
				if (attributeValue != nil)
					thisSGRCode = ([[NSFontManager sharedFontManager] weightOfFont:attributeValue] >= kBoldFontMinWeight)
									? SGRCodeIntensityBold : SGRCodeIntensityNormal;
				else
					thisSGRCode = SGRCodeIntensityNormal;
			}
			else if ([thisAttrName isEqualToString:NSUnderlineStyleAttributeName])
			{
				if (attributeValue != nil)
				{
					if ([attributeValue intValue] == NSUnderlineStyleSingle)
						thisSGRCode = SGRCodeUnderlineSingle;
					else if ([attributeValue intValue] == NSUnderlineStyleDouble)
						thisSGRCode = SGRCodeUnderlineDouble;
					else
						thisSGRCode = SGRCodeUnderlineNone;
				}
				else
					thisSGRCode = SGRCodeUnderlineNone;
			}
			
			if (thisSGRCode != SGRCodeNoneOrInvalid)
			{
				[codesAndLocations addObject:
				 [NSDictionary dictionaryWithObjectsAndKeys:
				  [NSNumber numberWithInt:thisSGRCode], kCodeDictKey_code,
				  [NSNumber numberWithUnsignedInteger:effectiveRange.location], kCodeDictKey_location,
				  nil
				 ]
				];
			}
			
			limitRange = NSMakeRange(NSMaxRange(effectiveRange),
									 NSMaxRange(limitRange) - NSMaxRange(effectiveRange));
		}
	}
	
	NSString *ansiEscapedString = [self ansiEscapedStringWithCodesAndLocations:codesAndLocations cleanString:[aAttributedString string]];
	
	return ansiEscapedString;
}


- (NSArray*) escapeCodesForString:(NSString*)aString cleanString:(NSString**)aCleanString
{
	if (aString == nil)
		return nil;
	if ([aString length] <= [kANSIEscapeCSI length])
	{
		*aCleanString = [NSString stringWithString:aString];
		return [NSArray array];
	}
	
	NSString *cleanString = @"";
	
	// find all escape sequence codes from aString and put them in this array
	// along with their start locations within the "clean" version of aString
	NSMutableArray *formatCodes = [NSMutableArray array];
	
	NSUInteger aStringLength = [aString length];
	NSUInteger coveredLength = 0;
	NSRange searchRange = NSMakeRange(0,aStringLength);
	NSRange thisEscapeSequenceRange;
	do
	{
		thisEscapeSequenceRange = [aString rangeOfString:kANSIEscapeCSI options:NSLiteralSearch range:searchRange];
		if (thisEscapeSequenceRange.location != NSNotFound)
		{
			// adjust range's length so that it encompasses the whole ANSI escape sequence
			// and not just the Control Sequence Initiator (the "prefix") by finding the
			// final byte of the control sequence (one that has an ASCII decimal value
			// between 64 and 126.) at the same time, read all formatting codes from inside
			// this escape sequence (there may be several, separated by semicolons.)
			NSMutableArray *codes = [NSMutableArray array];
			unsigned int code = 0;
			unsigned int lengthAddition = 1;
			NSUInteger thisIndex;
			for (;;)
			{
				thisIndex = (NSMaxRange(thisEscapeSequenceRange)+lengthAddition-1);
				if (thisIndex >= aStringLength)
					break;
				
				int c = (int)[aString characterAtIndex:thisIndex];
				
				if ((48 <= c) && (c <= 57)) // 0-9
				{
					int digit = c-48;
					code = (code == 0) ? digit : code*10+digit;
				}
				
				// ASCII decimal 109 is the SGR (Select Graphic Rendition) final byte
				// ("m"). this means that the code value we've just read specifies formatting
				// for the output; exactly what we're interested in.
				if (c == 109)
				{
					[codes addObject:[NSNumber numberWithUnsignedInt:code]];
					break;
				}
				else if ((64 <= c) && (c <= 126)) // any other valid final byte
				{
					[codes removeAllObjects];
					break;
				}
				else if (c == 59) // semicolon (;) separates codes within the same sequence
				{
					[codes addObject:[NSNumber numberWithUnsignedInt:code]];
					code = 0;
				}
				
				lengthAddition++;
			}
			thisEscapeSequenceRange.length += lengthAddition;
			
			NSUInteger locationInCleanString = coveredLength+thisEscapeSequenceRange.location-searchRange.location;
			
			NSUInteger iCode;
			for (iCode = 0; iCode < [codes count]; iCode++)
			{
				[formatCodes addObject:
				 [NSDictionary dictionaryWithObjectsAndKeys:
				  [codes objectAtIndex:iCode], kCodeDictKey_code,
				  [NSNumber numberWithUnsignedInteger:locationInCleanString], kCodeDictKey_location,
				  nil
				  ]
				 ];
			}
			
			NSUInteger thisCoveredLength = thisEscapeSequenceRange.location-searchRange.location;
			if (thisCoveredLength > 0)
				cleanString = [cleanString stringByAppendingString:[aString substringWithRange:NSMakeRange(searchRange.location, thisCoveredLength)]];
			
			coveredLength += thisCoveredLength;
			searchRange.location = NSMaxRange(thisEscapeSequenceRange);
			searchRange.length = aStringLength-searchRange.location;
		}
	}
	while(thisEscapeSequenceRange.location != NSNotFound);
	
	if (searchRange.length > 0)
		cleanString = [cleanString stringByAppendingString:[aString substringWithRange:searchRange]];
	
	*aCleanString = cleanString;
	
	return formatCodes;
}




- (NSString*) ansiEscapedStringWithCodesAndLocations:(NSArray*)aCodesArray cleanString:(NSString*)aCleanString
{
	NSMutableString* retStr = [NSMutableString stringWithCapacity:[aCleanString length]];
	
	NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:kCodeDictKey_location ascending:YES] autorelease];
	NSArray *codesArray = [aCodesArray sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	
	NSUInteger aCleanStringIndex = 0;
	NSUInteger aCleanStringLength = [aCleanString length];
	NSDictionary *thisCodeDict;
	for (thisCodeDict in codesArray)
	{
		if (!(	[[thisCodeDict allKeys] containsObject:kCodeDictKey_code] &&
				[[thisCodeDict allKeys] containsObject:kCodeDictKey_location]
			))
			continue;
		
		enum sgrCode thisCode = [[thisCodeDict objectForKey:kCodeDictKey_code] unsignedIntValue];
		NSUInteger formattingRunStartLocation = [[thisCodeDict objectForKey:kCodeDictKey_location] unsignedIntegerValue];
		
		if (formattingRunStartLocation > aCleanStringLength)
			continue;
		
		if (aCleanStringIndex < formattingRunStartLocation)
			[retStr appendString:[aCleanString substringWithRange:NSMakeRange(aCleanStringIndex, formattingRunStartLocation-aCleanStringIndex)]];
		[retStr appendString:kANSIEscapeCSI];
		[retStr appendString:[NSString stringWithFormat:@"%d", thisCode]];
		[retStr appendString:kANSIEscapeSGREnd];
		
		aCleanStringIndex = formattingRunStartLocation;
	}
	
	if (aCleanStringIndex < aCleanStringLength)
		[retStr appendString:[aCleanString substringFromIndex:aCleanStringIndex]];
	
	return retStr;
}





- (NSArray*) attributesForString:(NSString*)aString cleanString:(NSString**)aCleanString
{
	if (aString == nil)
		return nil;
	if ([aString length] <= [kANSIEscapeCSI length])
	{
		if (aCleanString != NULL)
			*aCleanString = [NSString stringWithString:aString];
		return [NSArray array];
	}
	
	NSMutableArray *attrsAndRanges = [NSMutableArray array];
	
	NSString *cleanString;
	
	NSArray *formatCodes = [self escapeCodesForString:aString cleanString:&cleanString];
	
	// go through all the found escape sequence codes and for each one, create
	// the string formatting attribute name and value, find the next escape
	// sequence that specifies the end of the formatting run started by
	// the currently handled code, and generate a range from the difference
	// in those codes' locations within the clean aString.
	NSUInteger iCode;
	for (iCode = 0; iCode < [formatCodes count]; iCode++)
	{
		NSDictionary *thisCodeDict = [formatCodes objectAtIndex:iCode];
		enum sgrCode thisCode = [[thisCodeDict objectForKey:kCodeDictKey_code] unsignedIntValue];
		NSUInteger formattingRunStartLocation = [[thisCodeDict objectForKey:kCodeDictKey_location] unsignedIntegerValue];
		
		// the attributed string attribute name for the formatting run introduced
		// by this code
		NSString *thisAttributeName = nil;
		
		// the attributed string attribute value for this formatting run introduced
		// by this code
		NSObject *thisAttributeValue = nil;
		
		// set attribute name
		switch(thisCode)
		{
			case SGRCodeFgBlack:
			case SGRCodeFgRed:
			case SGRCodeFgGreen:
			case SGRCodeFgYellow:
			case SGRCodeFgBlue:
			case SGRCodeFgMagenta:
			case SGRCodeFgCyan:
			case SGRCodeFgWhite:
			case SGRCodeFgBrightBlack:
			case SGRCodeFgBrightRed:
			case SGRCodeFgBrightGreen:
			case SGRCodeFgBrightYellow:
			case SGRCodeFgBrightBlue:
			case SGRCodeFgBrightMagenta:
			case SGRCodeFgBrightCyan:
			case SGRCodeFgBrightWhite:
				thisAttributeName = NSForegroundColorAttributeName;
				break;
			case SGRCodeBgBlack:
			case SGRCodeBgRed:
			case SGRCodeBgGreen:
			case SGRCodeBgYellow:
			case SGRCodeBgBlue:
			case SGRCodeBgMagenta:
			case SGRCodeBgCyan:
			case SGRCodeBgWhite:
			case SGRCodeBgBrightBlack:
			case SGRCodeBgBrightRed:
			case SGRCodeBgBrightGreen:
			case SGRCodeBgBrightYellow:
			case SGRCodeBgBrightBlue:
			case SGRCodeBgBrightMagenta:
			case SGRCodeBgBrightCyan:
			case SGRCodeBgBrightWhite:
				thisAttributeName = NSBackgroundColorAttributeName;
				break;
			case SGRCodeIntensityBold:
			case SGRCodeIntensityNormal:
				thisAttributeName = NSFontAttributeName;
				break;
			case SGRCodeUnderlineSingle:
			case SGRCodeUnderlineDouble:
				thisAttributeName = NSUnderlineStyleAttributeName;
				break;
			default:
				continue;
				break;
		}
		
		// set attribute value
		switch(thisCode)
		{
			case SGRCodeBgBlack:
			case SGRCodeFgBlack:
			case SGRCodeBgRed:
			case SGRCodeFgRed:
			case SGRCodeBgGreen:
			case SGRCodeFgGreen:
			case SGRCodeBgYellow:
			case SGRCodeFgYellow:
			case SGRCodeBgBlue:
			case SGRCodeFgBlue:
			case SGRCodeBgMagenta:
			case SGRCodeFgMagenta:
			case SGRCodeBgCyan:
			case SGRCodeFgCyan:
			case SGRCodeBgWhite:
			case SGRCodeFgWhite:
			case SGRCodeBgBrightBlack:
			case SGRCodeFgBrightBlack:
			case SGRCodeBgBrightRed:
			case SGRCodeFgBrightRed:
			case SGRCodeBgBrightGreen:
			case SGRCodeFgBrightGreen:
			case SGRCodeBgBrightYellow:
			case SGRCodeFgBrightYellow:
			case SGRCodeBgBrightBlue:
			case SGRCodeFgBrightBlue:
			case SGRCodeBgBrightMagenta:
			case SGRCodeFgBrightMagenta:
			case SGRCodeBgBrightCyan:
			case SGRCodeFgBrightCyan:
			case SGRCodeBgBrightWhite:
			case SGRCodeFgBrightWhite:
				thisAttributeValue = [self colorForSGRCode:thisCode];
				break;
			case SGRCodeIntensityBold:
				{
				NSFont *boldFont = [[NSFontManager sharedFontManager] convertFont:self.font toHaveTrait:NSBoldFontMask];
				thisAttributeValue = boldFont;
				}
				break;
			case SGRCodeIntensityNormal:
				{
				NSFont *unboldFont = [[NSFontManager sharedFontManager] convertFont:self.font toHaveTrait:NSUnboldFontMask];
				thisAttributeValue = unboldFont;
				}
				break;
			case SGRCodeUnderlineSingle:
				thisAttributeValue = [NSNumber numberWithInteger:NSUnderlineStyleSingle];
				break;
			case SGRCodeUnderlineDouble:
				thisAttributeValue = [NSNumber numberWithInteger:NSUnderlineStyleDouble];
				break;
			default:
				break;
		}
		
		
		// find the next sequence that specifies the end of this formatting run
		NSInteger formattingRunEndLocation = -1;
		if (iCode < ([formatCodes count]-1))
		{
			NSUInteger iEndCode;
			NSDictionary *thisEndCodeCandidateDict;
			unichar thisEndCodeCandidate;
			for (iEndCode = iCode+1; iEndCode < [formatCodes count]; iEndCode++)
			{
				thisEndCodeCandidateDict = [formatCodes objectAtIndex:iEndCode];
				thisEndCodeCandidate = [[thisEndCodeCandidateDict objectForKey:kCodeDictKey_code] unsignedIntValue];
				
				if ([self sgrCode:thisEndCodeCandidate endsFormattingIntroducedByCode:thisCode])
				{
					formattingRunEndLocation = [[thisEndCodeCandidateDict objectForKey:kCodeDictKey_location] unsignedIntegerValue];
					break;
				}
			}
		}
		if (formattingRunEndLocation == -1)
			formattingRunEndLocation = [cleanString length];
		
		// add attribute name, attribute value and formatting run range
		// to the array we're going to return
		[attrsAndRanges addObject:
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSValue valueWithRange:NSMakeRange(formattingRunStartLocation, (formattingRunEndLocation-formattingRunStartLocation))], kAttrDictKey_range,
		  thisAttributeName, kAttrDictKey_attrName,
		  thisAttributeValue, kAttrDictKey_attrValue,
		  nil
		 ]
		];
	}
	
	if (aCleanString != NULL)
		*aCleanString = cleanString;
	
	return attrsAndRanges;
}





- (BOOL) sgrCode:(enum sgrCode)endCode endsFormattingIntroducedByCode:(enum sgrCode)startCode
{
	switch(startCode)
	{
		case SGRCodeFgBlack:
		case SGRCodeFgRed:
		case SGRCodeFgGreen:
		case SGRCodeFgYellow:
		case SGRCodeFgBlue:
		case SGRCodeFgMagenta:
		case SGRCodeFgCyan:
		case SGRCodeFgWhite:
		case SGRCodeFgBrightBlack:
		case SGRCodeFgBrightRed:
		case SGRCodeFgBrightGreen:
		case SGRCodeFgBrightYellow:
		case SGRCodeFgBrightBlue:
		case SGRCodeFgBrightMagenta:
		case SGRCodeFgBrightCyan:
		case SGRCodeFgBrightWhite:
			return (endCode == SGRCodeAllReset || endCode == SGRCodeFgReset || 
					endCode == SGRCodeFgBlack || endCode == SGRCodeFgRed || 
					endCode == SGRCodeFgGreen || endCode == SGRCodeFgYellow || 
					endCode == SGRCodeFgBlue || endCode == SGRCodeFgMagenta || 
					endCode == SGRCodeFgCyan || endCode == SGRCodeFgWhite ||
					endCode == SGRCodeFgBrightBlack || endCode == SGRCodeFgBrightRed || 
					endCode == SGRCodeFgBrightGreen || endCode == SGRCodeFgBrightYellow || 
					endCode == SGRCodeFgBrightBlue || endCode == SGRCodeFgBrightMagenta || 
					endCode == SGRCodeFgBrightCyan || endCode == SGRCodeFgBrightWhite);
			break;
		case SGRCodeBgBlack:
		case SGRCodeBgRed:
		case SGRCodeBgGreen:
		case SGRCodeBgYellow:
		case SGRCodeBgBlue:
		case SGRCodeBgMagenta:
		case SGRCodeBgCyan:
		case SGRCodeBgWhite:
		case SGRCodeBgBrightBlack:
		case SGRCodeBgBrightRed:
		case SGRCodeBgBrightGreen:
		case SGRCodeBgBrightYellow:
		case SGRCodeBgBrightBlue:
		case SGRCodeBgBrightMagenta:
		case SGRCodeBgBrightCyan:
		case SGRCodeBgBrightWhite:
			return (endCode == SGRCodeAllReset || endCode == SGRCodeBgReset || 
					endCode == SGRCodeBgBlack || endCode == SGRCodeBgRed || 
					endCode == SGRCodeBgGreen || endCode == SGRCodeBgYellow || 
					endCode == SGRCodeBgBlue || endCode == SGRCodeBgMagenta || 
					endCode == SGRCodeBgCyan || endCode == SGRCodeBgWhite ||
					endCode == SGRCodeBgBrightBlack || endCode == SGRCodeBgBrightRed || 
					endCode == SGRCodeBgBrightGreen || endCode == SGRCodeBgBrightYellow || 
					endCode == SGRCodeBgBrightBlue || endCode == SGRCodeBgBrightMagenta || 
					endCode == SGRCodeBgBrightCyan || endCode == SGRCodeBgBrightWhite);
			break;
		case SGRCodeIntensityBold:
		case SGRCodeIntensityNormal:
			return (endCode == SGRCodeAllReset || endCode == SGRCodeIntensityNormal || 
					endCode == SGRCodeIntensityBold || endCode == SGRCodeIntensityFaint);
			break;
		case SGRCodeUnderlineSingle:
		case SGRCodeUnderlineDouble:
			return (endCode == SGRCodeAllReset || endCode == SGRCodeUnderlineNone || 
					endCode == SGRCodeUnderlineSingle || endCode == SGRCodeUnderlineDouble);
			break;
		default:
			return NO;
			break;
	}
	
	return NO;
}




- (NSColor*) colorForSGRCode:(enum sgrCode)code
{
	if (self.ansiColors != nil)
	{
		NSColor *preferredColor = [self.ansiColors objectForKey:[NSNumber numberWithInt:code]];
		if (preferredColor != nil)
			return preferredColor;
	}
	
	switch(code)
	{
		case SGRCodeFgBlack:
			return kDefaultANSIColorFgBlack;
			break;
		case SGRCodeFgRed:
			return kDefaultANSIColorFgRed;
			break;
		case SGRCodeFgGreen:
			return kDefaultANSIColorFgGreen;
			break;
		case SGRCodeFgYellow:
			return kDefaultANSIColorFgYellow;
			break;
		case SGRCodeFgBlue:
			return kDefaultANSIColorFgBlue;
			break;
		case SGRCodeFgMagenta:
			return kDefaultANSIColorFgMagenta;
			break;
		case SGRCodeFgCyan:
			return kDefaultANSIColorFgCyan;
			break;
		case SGRCodeFgWhite:
			return kDefaultANSIColorFgWhite;
			break;
		case SGRCodeFgBrightBlack:
			return kDefaultANSIColorFgBrightBlack;
			break;
		case SGRCodeFgBrightRed:
			return kDefaultANSIColorFgBrightRed;
			break;
		case SGRCodeFgBrightGreen:
			return kDefaultANSIColorFgBrightGreen;
			break;
		case SGRCodeFgBrightYellow:
			return kDefaultANSIColorFgBrightYellow;
			break;
		case SGRCodeFgBrightBlue:
			return kDefaultANSIColorFgBrightBlue;
			break;
		case SGRCodeFgBrightMagenta:
			return kDefaultANSIColorFgBrightMagenta;
			break;
		case SGRCodeFgBrightCyan:
			return kDefaultANSIColorFgBrightCyan;
			break;
		case SGRCodeFgBrightWhite:
			return kDefaultANSIColorFgBrightWhite;
			break;
		case SGRCodeBgBlack:
			return kDefaultANSIColorBgBlack;
			break;
		case SGRCodeBgRed:
			return kDefaultANSIColorBgRed;
			break;
		case SGRCodeBgGreen:
			return kDefaultANSIColorBgGreen;
			break;
		case SGRCodeBgYellow:
			return kDefaultANSIColorBgYellow;
			break;
		case SGRCodeBgBlue:
			return kDefaultANSIColorBgBlue;
			break;
		case SGRCodeBgMagenta:
			return kDefaultANSIColorBgMagenta;
			break;
		case SGRCodeBgCyan:
			return kDefaultANSIColorBgCyan;
			break;
		case SGRCodeBgWhite:
			return kDefaultANSIColorBgWhite;
			break;
		case SGRCodeBgBrightBlack:
			return kDefaultANSIColorBgBrightBlack;
			break;
		case SGRCodeBgBrightRed:
			return kDefaultANSIColorBgBrightRed;
			break;
		case SGRCodeBgBrightGreen:
			return kDefaultANSIColorBgBrightGreen;
			break;
		case SGRCodeBgBrightYellow:
			return kDefaultANSIColorBgBrightYellow;
			break;
		case SGRCodeBgBrightBlue:
			return kDefaultANSIColorBgBrightBlue;
			break;
		case SGRCodeBgBrightMagenta:
			return kDefaultANSIColorBgBrightMagenta;
			break;
		case SGRCodeBgBrightCyan:
			return kDefaultANSIColorBgBrightCyan;
			break;
		case SGRCodeBgBrightWhite:
			return kDefaultANSIColorBgBrightWhite;
			break;
		default:
			break;
	}
	
	return kDefaultANSIColorFgBlack;
}


- (enum sgrCode) sgrCodeForColor:(NSColor*)aColor isForegroundColor:(BOOL)aForeground
{
	if (self.ansiColors != nil)
	{
		NSArray *codesForGivenColor = [self.ansiColors allKeysForObject:aColor];
		
		if (codesForGivenColor != nil && [codesForGivenColor count] > 0)
		{
			NSNumber *thisCode;
			for (thisCode in codesForGivenColor)
			{
				BOOL thisIsForegroundColor = ([thisCode intValue] < 40);
				if (aForeground == thisIsForegroundColor)
					return [thisCode intValue];
			}
		}
	}
	
	if (aForeground)
	{
		if ([aColor isEqual:kDefaultANSIColorFgBlack])
			return SGRCodeFgBlack;
		else if ([aColor isEqual:kDefaultANSIColorFgRed])
			return SGRCodeFgRed;
		else if ([aColor isEqual:kDefaultANSIColorFgGreen])
			return SGRCodeFgGreen;
		else if ([aColor isEqual:kDefaultANSIColorFgYellow])
			return SGRCodeFgYellow;
		else if ([aColor isEqual:kDefaultANSIColorFgBlue])
			return SGRCodeFgBlue;
		else if ([aColor isEqual:kDefaultANSIColorFgMagenta])
			return SGRCodeFgMagenta;
		else if ([aColor isEqual:kDefaultANSIColorFgCyan])
			return SGRCodeFgCyan;
		else if ([aColor isEqual:kDefaultANSIColorFgWhite])
			return SGRCodeFgWhite;
		else if ([aColor isEqual:kDefaultANSIColorFgBrightBlack])
			return SGRCodeFgBrightBlack;
		else if ([aColor isEqual:kDefaultANSIColorFgBrightRed])
			return SGRCodeFgBrightRed;
		else if ([aColor isEqual:kDefaultANSIColorFgBrightGreen])
			return SGRCodeFgBrightGreen;
		else if ([aColor isEqual:kDefaultANSIColorFgBrightYellow])
			return SGRCodeFgBrightYellow;
		else if ([aColor isEqual:kDefaultANSIColorFgBrightBlue])
			return SGRCodeFgBrightBlue;
		else if ([aColor isEqual:kDefaultANSIColorFgBrightMagenta])
			return SGRCodeFgBrightMagenta;
		else if ([aColor isEqual:kDefaultANSIColorFgBrightCyan])
			return SGRCodeFgBrightCyan;
		else if ([aColor isEqual:kDefaultANSIColorFgBrightWhite])
			return SGRCodeFgBrightWhite;
	}
	else
	{
		if ([aColor isEqual:kDefaultANSIColorBgBlack])
			return SGRCodeBgBlack;
		else if ([aColor isEqual:kDefaultANSIColorBgRed])
			return SGRCodeBgRed;
		else if ([aColor isEqual:kDefaultANSIColorBgGreen])
			return SGRCodeBgGreen;
		else if ([aColor isEqual:kDefaultANSIColorBgYellow])
			return SGRCodeBgYellow;
		else if ([aColor isEqual:kDefaultANSIColorBgBlue])
			return SGRCodeBgBlue;
		else if ([aColor isEqual:kDefaultANSIColorBgMagenta])
			return SGRCodeBgMagenta;
		else if ([aColor isEqual:kDefaultANSIColorBgCyan])
			return SGRCodeBgCyan;
		else if ([aColor isEqual:kDefaultANSIColorBgWhite])
			return SGRCodeBgWhite;
		else if ([aColor isEqual:kDefaultANSIColorBgBrightBlack])
			return SGRCodeBgBrightBlack;
		else if ([aColor isEqual:kDefaultANSIColorBgBrightRed])
			return SGRCodeBgBrightRed;
		else if ([aColor isEqual:kDefaultANSIColorBgBrightGreen])
			return SGRCodeBgBrightGreen;
		else if ([aColor isEqual:kDefaultANSIColorBgBrightYellow])
			return SGRCodeBgBrightYellow;
		else if ([aColor isEqual:kDefaultANSIColorBgBrightBlue])
			return SGRCodeBgBrightBlue;
		else if ([aColor isEqual:kDefaultANSIColorBgBrightMagenta])
			return SGRCodeBgBrightMagenta;
		else if ([aColor isEqual:kDefaultANSIColorBgBrightCyan])
			return SGRCodeBgBrightCyan;
		else if ([aColor isEqual:kDefaultANSIColorBgBrightWhite])
			return SGRCodeBgBrightWhite;
	}
	
	return SGRCodeNoneOrInvalid;
}



// helper struct typedef and a few functions for
// -closestSGRCodeForColor:isForegroundColor:

typedef struct _HSB {
	CGFloat hue;
	CGFloat saturation;
	CGFloat brightness;
} HSB;

HSB makeHSB(CGFloat hue, CGFloat saturation, CGFloat brightness)
{
	HSB outHSB;
	outHSB.hue = hue;
	outHSB.saturation = saturation;
	outHSB.brightness = brightness;
	return outHSB;
}

HSB getHSBFromColor(NSColor *color)
{
	CGFloat hue = 0.0;
	CGFloat saturation = 0.0;
	CGFloat brightness = 0.0;
	[[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace]
		getHue:&hue
		saturation:&saturation
		brightness:&brightness
		alpha:NULL
		];
	return makeHSB(hue, saturation, brightness);
}

BOOL floatsEqual(CGFloat first, CGFloat second, CGFloat maxAbsError)
{
	return (fabs(first-second)) < maxAbsError;
}

#define MAX_HUE_FLOAT_EQUALITY_ABS_ERROR 0.000001

- (enum sgrCode) closestSGRCodeForColor:(NSColor *)color isForegroundColor:(BOOL)foreground
{
	if (color == nil)
		return SGRCodeNoneOrInvalid;
	
	enum sgrCode closestColorSGRCode = [self sgrCodeForColor:color isForegroundColor:foreground];
	if (closestColorSGRCode != SGRCodeNoneOrInvalid)
		return closestColorSGRCode;
	
	HSB givenColorHSB = getHSBFromColor(color);
	
	CGFloat closestColorHueDiff = FLT_MAX;
	CGFloat closestColorSaturationDiff = FLT_MAX;
	CGFloat closestColorBrightnessDiff = FLT_MAX;
	
	// (background SGR codes are +10 from foreground ones:)
	NSUInteger sgrCodeShift = (foreground)?0:10;
	NSArray *ansiFgColorCodes = [NSArray
		arrayWithObjects:
			[NSNumber numberWithInt:SGRCodeFgBlack+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgRed+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgGreen+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgYellow+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBlue+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgMagenta+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgCyan+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgWhite+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightBlack+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightRed+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightGreen+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightYellow+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightBlue+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightMagenta+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightCyan+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightWhite+sgrCodeShift],
			nil
		];
	for (NSNumber *thisSGRCodeNumber in ansiFgColorCodes)
	{
		enum sgrCode thisSGRCode = [thisSGRCodeNumber intValue];
		NSColor *thisColor = [self colorForSGRCode:thisSGRCode];
		
		HSB thisColorHSB = getHSBFromColor(thisColor);
		
		CGFloat hueDiff = fabs(givenColorHSB.hue - thisColorHSB.hue);
		CGFloat saturationDiff = fabs(givenColorHSB.saturation - thisColorHSB.saturation);
		CGFloat brightnessDiff = fabs(givenColorHSB.brightness - thisColorHSB.brightness);
		
		// comparison depends on hue, saturation and brightness
		// (strictly in that order):
		
		if (!floatsEqual(hueDiff, closestColorHueDiff, MAX_HUE_FLOAT_EQUALITY_ABS_ERROR))
		{
			if (hueDiff > closestColorHueDiff)
				continue;
			closestColorSGRCode = thisSGRCode;
			closestColorHueDiff = hueDiff;
			closestColorSaturationDiff = saturationDiff;
			closestColorBrightnessDiff = brightnessDiff;
			continue;
		}
		
		if (!floatsEqual(saturationDiff, closestColorSaturationDiff, MAX_HUE_FLOAT_EQUALITY_ABS_ERROR))
		{
			if (saturationDiff > closestColorSaturationDiff)
				continue;
			closestColorSGRCode = thisSGRCode;
			closestColorHueDiff = hueDiff;
			closestColorSaturationDiff = saturationDiff;
			closestColorBrightnessDiff = brightnessDiff;
			continue;
		}
		
		if (!floatsEqual(brightnessDiff, closestColorBrightnessDiff, MAX_HUE_FLOAT_EQUALITY_ABS_ERROR))
		{
			if (brightnessDiff > closestColorBrightnessDiff)
				continue;
			closestColorSGRCode = thisSGRCode;
			closestColorHueDiff = hueDiff;
			closestColorSaturationDiff = saturationDiff;
			closestColorBrightnessDiff = brightnessDiff;
			continue;
		}
		
		// If hue (especially hue!), saturation and brightness diffs all
		// are equal to some other color, we need to prefer one or the
		// other so we'll select the more 'distinctive' color of the
		// two (this is *very* subjective, obviously). I basically just
		// looked at the hue chart, went through all the points between
		// our main ANSI colors and decided which side the middle point
		// would lean on. (e.g. the purple color that is exactly between
		// the blue and magenta ANSI colors looks more magenta than
		// blue to me so I put magenta higher than blue in the list
		// below.)
		// 
		// subjective ordering of colors from most to least 'distinctive':
		int colorDistinctivenessOrder[6] = {
			SGRCodeFgRed+sgrCodeShift,
			SGRCodeFgMagenta+sgrCodeShift,
			SGRCodeFgBlue+sgrCodeShift,
			SGRCodeFgGreen+sgrCodeShift,
			SGRCodeFgCyan+sgrCodeShift,
			SGRCodeFgYellow+sgrCodeShift
			};
		int i;
		for (i = 0; i < 6; i++)
		{
			if (colorDistinctivenessOrder[i] == closestColorSGRCode)
				break;
			else if (colorDistinctivenessOrder[i] == thisSGRCode)
			{
				closestColorSGRCode = thisSGRCode;
				closestColorHueDiff = hueDiff;
				closestColorSaturationDiff = saturationDiff;
				closestColorBrightnessDiff = brightnessDiff;
			}
		}
	}
	
	return closestColorSGRCode;
}



@end
