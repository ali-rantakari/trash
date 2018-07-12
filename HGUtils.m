// 
// http://hasseg.org/
//

/*
The MIT License

Copyright (c) 2011 Ali Rantakari

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


#import "HGUtils.h"


NSString *stringFromFileSize(long long aSize)
{
    CGFloat size = aSize;
    
    // Finder uses SI prefixes for file sizes and disk capacities
    // (since Snow Leopard) so we'll do the same here.
    //
    if (NSClassFromString(@"NSByteCountFormatter")) {
        return [NSByteCountFormatter
            stringFromByteCount: aSize
            countStyle: NSByteCountFormatterCountStyleFile];
    }
    
    CGFloat kilo = 1000.0;
    
    if (size < kilo)
        return([NSString stringWithFormat:@"%1.0f bytes", size]);
    size = size / kilo;
    if (size < kilo)
        return([NSString stringWithFormat:@"%1.1f KB", size]);
    size = size / kilo;
    if (size < kilo)
        return([NSString stringWithFormat:@"%1.1f MB", size]);
    size = size / kilo;
    if (size < kilo)
        return([NSString stringWithFormat:@"%1.1f GB", size]);
    size = size / kilo;
        
    return([NSString stringWithFormat:@"%1.1f TB", size]);
}


