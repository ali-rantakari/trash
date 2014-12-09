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

#import "HGCLIUtils.h"


// the string encoding to use for output
NSStringEncoding outputStrEncoding = NSUTF8StringEncoding; // default


// helper methods for printing to stdout and stderr
//      from: http://www.sveinbjorn.org/objectivec_stdout
//      (modified to use non-deprecated version of writeToFile:...
//       and allow for using the "string format" syntax)

void Print(NSString *aStr)
{
    if (aStr == nil)
        return;
    [aStr writeToFile:@"/dev/stdout" atomically:NO encoding:outputStrEncoding error:NULL];
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
    
    [str writeToFile:@"/dev/stdout" atomically:NO encoding:outputStrEncoding error:NULL];
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
    
    [str writeToFile:@"/dev/stderr" atomically:NO encoding:outputStrEncoding error:NULL];
}
