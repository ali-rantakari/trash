//
//  ANSIEscapeHelper.h
//  AnsiColorsTest
//
//  Created by Ali Rantakari on 18.3.09.
//
//  Version 0.9.4
// 
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

#import <Cocoa/Cocoa.h>


// the CSI (Control Sequence Initiator) -- i.e. "escape sequence prefix".
// (add your own CSI:Miami joke here)
#define kANSIEscapeCSI			@"\033["

// the end byte of an SGR (Select Graphic Rendition)
// ANSI Escape Sequence
#define kANSIEscapeSGREnd		@"m"


// color definition helper macros
#define kBrightColorBrightness	1.0
#define kBrightColorSaturation	0.4
#define kBrightColorAlpha		1.0
#define kBrightColorWithHue(h)	[NSColor colorWithCalibratedHue:(h) saturation:kBrightColorSaturation brightness:kBrightColorBrightness alpha:kBrightColorAlpha]

// default colors
#define kDefaultANSIColorFgBlack	[NSColor blackColor]
#define kDefaultANSIColorFgRed		[NSColor redColor]
#define kDefaultANSIColorFgGreen	[NSColor greenColor]
#define kDefaultANSIColorFgYellow	[NSColor yellowColor]
#define kDefaultANSIColorFgBlue		[NSColor blueColor]
#define kDefaultANSIColorFgMagenta	[NSColor magentaColor]
#define kDefaultANSIColorFgCyan		[NSColor cyanColor]
#define kDefaultANSIColorFgWhite	[NSColor whiteColor]

#define kDefaultANSIColorFgBrightBlack		[NSColor colorWithCalibratedWhite:0.337 alpha:1.0]
#define kDefaultANSIColorFgBrightRed		kBrightColorWithHue(1.0)
#define kDefaultANSIColorFgBrightGreen		kBrightColorWithHue(1.0/3.0)
#define kDefaultANSIColorFgBrightYellow		kBrightColorWithHue(1.0/6.0)
#define kDefaultANSIColorFgBrightBlue		kBrightColorWithHue(2.0/3.0)
#define kDefaultANSIColorFgBrightMagenta	kBrightColorWithHue(5.0/6.0)
#define kDefaultANSIColorFgBrightCyan		kBrightColorWithHue(0.5)
#define kDefaultANSIColorFgBrightWhite		[NSColor whiteColor]

#define kDefaultANSIColorBgBlack	[NSColor blackColor]
#define kDefaultANSIColorBgRed		[NSColor redColor]
#define kDefaultANSIColorBgGreen	[NSColor greenColor]
#define kDefaultANSIColorBgYellow	[NSColor yellowColor]
#define kDefaultANSIColorBgBlue		[NSColor blueColor]
#define kDefaultANSIColorBgMagenta	[NSColor magentaColor]
#define kDefaultANSIColorBgCyan		[NSColor cyanColor]
#define kDefaultANSIColorBgWhite	[NSColor whiteColor]

#define kDefaultANSIColorBgBrightBlack		kDefaultANSIColorFgBrightBlack
#define kDefaultANSIColorBgBrightRed		kDefaultANSIColorFgBrightRed
#define kDefaultANSIColorBgBrightGreen		kDefaultANSIColorFgBrightGreen
#define kDefaultANSIColorBgBrightYellow		kDefaultANSIColorFgBrightYellow
#define kDefaultANSIColorBgBrightBlue		kDefaultANSIColorFgBrightBlue
#define kDefaultANSIColorBgBrightMagenta	kDefaultANSIColorFgBrightMagenta
#define kDefaultANSIColorBgBrightCyan		kDefaultANSIColorFgBrightCyan
#define kDefaultANSIColorBgBrightWhite		kDefaultANSIColorFgBrightWhite

// dictionary keys for the SGR code dictionaries that the array
// escapeCodesForString:cleanString: returns contains
#define kCodeDictKey_code			@"code"
#define kCodeDictKey_location		@"location"

// dictionary keys for the string formatting attribute
// dictionaries that the array attributesForString:cleanString:
// returns contains
#define kAttrDictKey_range			@"range"
#define kAttrDictKey_attrName		@"attributeName"
#define kAttrDictKey_attrValue		@"attributeValue"

// minimum weight for an NSFont for it to be considered bold
#define kBoldFontMinWeight			9




/*!
 @enum			sgrCode
 
 @abstract		SGR (Select Graphic Rendition) ANSI control codes.
 */
enum sgrCode
{
	SGRCodeNoneOrInvalid =		-1,
	
	SGRCodeAllReset =			0,
	
	SGRCodeIntensityBold =		1,
	SGRCodeIntensityFaint =		2,
	SGRCodeIntensityNormal =	22,
	
	SGRCodeItalicOn =			3,
	
	SGRCodeUnderlineSingle =	4,
	SGRCodeUnderlineDouble =	21,
	SGRCodeUnderlineNone =		24,
	
	SGRCodeFgBlack =			30,
	SGRCodeFgRed =				31,
	SGRCodeFgGreen =			32,
	SGRCodeFgYellow =			33,
	SGRCodeFgBlue =				34,
	SGRCodeFgMagenta =			35,
	SGRCodeFgCyan =				36,
	SGRCodeFgWhite =			37,
	SGRCodeFgReset =			39,
	
	SGRCodeBgBlack =			40,
	SGRCodeBgRed =				41,
	SGRCodeBgGreen =			42,
	SGRCodeBgYellow =			43,
	SGRCodeBgBlue =				44,
	SGRCodeBgMagenta =			45,
	SGRCodeBgCyan =				46,
	SGRCodeBgWhite =			47,
	SGRCodeBgReset =			49,
	
	SGRCodeFgBrightBlack =		90,
	SGRCodeFgBrightRed =		91,
	SGRCodeFgBrightGreen =		92,
	SGRCodeFgBrightYellow =		93,
	SGRCodeFgBrightBlue =		94,
	SGRCodeFgBrightMagenta =	95,
	SGRCodeFgBrightCyan =		96,
	SGRCodeFgBrightWhite =		97,
	
	SGRCodeBgBrightBlack =		100,
	SGRCodeBgBrightRed =		101,
	SGRCodeBgBrightGreen =		102,
	SGRCodeBgBrightYellow =		103,
	SGRCodeBgBrightBlue =		104,
	SGRCodeBgBrightMagenta =	105,
	SGRCodeBgBrightCyan =		106,
	SGRCodeBgBrightWhite =		107
};






/*!
 @class		ANSIEscapeHelper
 
 @abstract	Contains helper methods for dealing with strings
			that contain ANSI escape sequences for formatting (colors,
			underlining, bold etc.)
 */
@interface ANSIEscapeHelper : NSObject
{
	NSFont *font;
	NSMutableDictionary *ansiColors;
    NSColor *defaultStringColor;
}

/*!
 @property		defaultStringColor
 
 @abstract		The default color used when creating an attributed string (default is black).
 */
@property(copy) NSColor *defaultStringColor;


/*!
 @property		font
 
 @abstract		The font to use when creating string formatting attribute values.
 */
@property(copy) NSFont *font;

/*!
 @property		ansiColors
 
 @abstract		The colors to use for displaying ANSI colors.
 
 @discussion	Keys in this dictionary should be NSNumber objects containing SGR code
				values from the sgrCode enum. The corresponding values for these keys
				should be NSColor objects. If this property is nil or if it doesn't
				contain a key for a specific SGR code, the default color will be used
				instead.
 */
@property(retain) NSMutableDictionary *ansiColors;


/*!
 @method		attributedStringWithANSIEscapedString:
 
 @abstract		Returns an attributed string that corresponds both in contents
				and formatting to a given string that contains ANSI escape
				sequences.
 
 @param aString			A String containing ANSI escape sequences
 
 @result		An attributed string that mimics as closely as possible
				the formatting of the given ANSI-escaped string.
 */
- (NSAttributedString*) attributedStringWithANSIEscapedString:(NSString*)aString;


/*!
 @method		ansiEscapedStringWithAttributedString:
 
 @abstract		Returns a string containing ANSI escape sequences that corresponds
				both in contents and formatting to a given attributed string.
 
 @param aAttributedString		An attributed string
 
 @result		A string that mimics as closely as possible
				the formatting of the given attributed string with
				ANSI escape sequences.
 */
- (NSString*) ansiEscapedStringWithAttributedString:(NSAttributedString*)aAttributedString;


/*!
 @method		escapeCodesForString:cleanString:
 
 @abstract		Returns an array of SGR codes and their locations from a
				string containing ANSI escape sequences as well as a "clean"
				version of the string (i.e. one without the ANSI escape
				sequences.)
 
 @param aString			A String containing ANSI escape sequences
 @param aCleanString	Upon return, contains a "clean" version of aString (i.e. aString
						without the ANSI escape sequences)
 
 @result		An array of NSDictionary objects, each of which has
				an NSNumber value for the key "code" (specifying an SGR code) and
				another NSNumber value for the key "location" (specifying the
				location of the code within aCleanString.)
 */
- (NSArray*) escapeCodesForString:(NSString*)aString cleanString:(NSString**)aCleanString;


/*!
 @method		ansiEscapedStringWithCodesAndLocations:cleanString:
 
 @abstract		Returns a string containing ANSI escape codes for formatting based
				on a string and an array of SGR codes and their locations within
				the given string.
 
 @param aCodesArray		An array of NSDictionary objects, each of which should have
						an NSNumber value for the key "code" (specifying an SGR
						code) and another NSNumber value for the key "location"
						(specifying the location of this SGR code in aCleanString.)
 @param aCleanString	The string to which to insert the ANSI escape codes
						described in aCodesArray.
 
 @result		A string containing ANSI escape sequences.
 */
- (NSString*) ansiEscapedStringWithCodesAndLocations:(NSArray*)aCodesArray cleanString:(NSString*)aCleanString;


/*!
 @method		attributesForString:cleanString:
 
 @abstract		Convert ANSI escape sequences in a string to string formatting attributes.
 
 @discussion	Given a string with some ANSI escape sequences in it, this method returns
				attributes for formatting the specified string according to those ANSI
				escape sequences as well as a "clean" (i.e. free of the escape sequences)
				version of this string.
 
 @param aString			A String containing ANSI escape sequences
 @param aCleanString	Upon return, contains a "clean" version of aString (i.e. aString
						without the ANSI escape sequences.) Pass in NULL if you're not
						interested in this.
 
 @result		An array containing NSDictionary objects, each of which has keys "range"
				(an NSValue containing an NSRange, specifying the range for the
				attribute within the "clean" version of aString), "attributeName" (an
				NSString) and "attributeValue" (an NSObject). You may use these as
				arguments for NSMutableAttributedString's methods for setting the
				visual formatting.
 */
- (NSArray*) attributesForString:(NSString*)aString cleanString:(NSString**)aCleanString;


/*!
 @method		sgrCode:endsFormattingIntroducedByCode:
 
 @abstract		Whether the occurrence of a given SGR code would end the formatting run
				introduced by another SGR code.
 
 @discussion	For example, SGRCodeFgReset, SGRCodeAllReset or any SGR code
				specifying a foreground color would end the formatting run
				introduced by a foreground color -specifying SGR code.
 
 @param endCode		The SGR code to test as a candidate for ending the formatting run
					introduced by startCode
 @param startCode	The SGR code that has introduced a formatting run
 
 @result		YES if the occurrence of endCode would end the formatting run
				introduced by startCode, NO otherwise.
 */
- (BOOL) sgrCode:(enum sgrCode)endCode endsFormattingIntroducedByCode:(enum sgrCode)startCode;


/*!
 @method		colorForSGRCode:
 
 @abstract		Returns the color to use for displaying a specific ANSI color.
 
 @discussion	This method first considers the values set in the ansiColors
				property and only then the standard basic colors (NSColor's
				redColor, blueColor etc.)
 
 @param code	An SGR code that specifies an ANSI color.
 
 @result		The color to use for displaying the ANSI color specified by code.
 */
- (NSColor*) colorForSGRCode:(enum sgrCode)code;


/*!
 @method		sgrCodeForColor:isForegroundColor:
 
 @abstract		Returns a color SGR code that corresponds to a given color.
 
 @discussion	This method matches colors to their equivalent SGR codes
				by going through the colors specified in the ansiColors
				dictionary, and if ansiColors is null or if a match is
				not found there, by comparing the given color to the
				standard basic colors (NSColor's redColor, blueColor
				etc.) The comparison is done simply by checking for
				equality.
 
 @param aColor			The color to get a corresponding SGR code for
 @param aForeground		Whether you want a foreground or background color code
 
 @result		SGR code that corresponds with aColor.
 */
- (enum sgrCode) sgrCodeForColor:(NSColor*)aColor isForegroundColor:(BOOL)aForeground;


/*!
 @method		closestSGRCodeForColor:isForegroundColor:
 
 @abstract		Returns a color SGR code that represents the closest ANSI
 				color to a given color.
 
 @discussion	This method attempts to find the closest ANSI color to
 				aColor and return its SGR code.
 
 @param aColor			The color to get a closest color SGR code match for
 @param aForeground		Whether you want a foreground or background color code
 
 @result		SGR code for the ANSI color that is closest to aColor.
 */
- (enum sgrCode) closestSGRCodeForColor:(NSColor *)color isForegroundColor:(BOOL)foreground;



@end
