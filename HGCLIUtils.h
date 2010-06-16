// CLI app utils
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


extern NSStringEncoding outputStrEncoding;


// helper function macros
#define kEmptyMutableAttributedString 	[[[NSMutableAttributedString alloc] init] autorelease]
#define MUTABLE_ATTR_STR(x)				[[[NSMutableAttributedString alloc] initWithString:(x)] autorelease]
#define ATTR_STR(x)						[[[NSAttributedString alloc] initWithString:(x)] autorelease]
#define WHITESPACE(x)					[@"" stringByPaddingToLength:(x) withString:@" " startingAtIndex:0]



void Print(NSString *aStr);
void Printf(NSString *aStr, ...);
void PrintfErr(NSString *aStr, ...);

NSString *strConcat(NSString *firstStr, ...);
NSString *escapeDoubleQuotes(NSString *str);

void replaceInMutableAttrStr(NSMutableAttributedString *str, NSString *searchStr, NSAttributedString *replaceStr);
void wordWrapMutableAttrStr(NSMutableAttributedString *mutableAttrStr, NSUInteger width);

BOOL moveFileToTrash(NSString *filePath);

