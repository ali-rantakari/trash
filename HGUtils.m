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


NSInteger OSVersion()
{
    static NSInteger cachedValue = 0;
    
    if (cachedValue > 0)
        return cachedValue;
    
    SInt32 major, minor, bugfix;
    
    if (Gestalt(gestaltSystemVersionMajor, &major) ||
        Gestalt(gestaltSystemVersionMinor, &minor) ||
        Gestalt(gestaltSystemVersionBugFix, &bugfix))
        return 0;
    
    cachedValue = ((major * 100) + minor) * 100 + bugfix;
    return cachedValue;
}


NSString *stringFromFileSize(long long aSize)
{
    CGFloat size = aSize;
    
    // Finder uses SI prefixes on Snow Leopard and the IEC 60027-2
    // binary prefixes on earlier OS X versions for file sizes
    // and disk capacities so we'll do the same here.
    // 
    CGFloat kilo = (OSVersion() >= kSnowLeopardOSVersion) ? 1000.0 : 1024.0;
    NSString *bytesSuffix = (kilo == 1000.0) ? @"B" : @"iB";
    
    if (size < kilo)
        return([NSString stringWithFormat:@"%1.0f bytes",size]);
    size = size / kilo;
    if (size < kilo)
        return([NSString stringWithFormat:@"%1.1f K%@",size,bytesSuffix]);
    size = size / kilo;
    if (size < kilo)
        return([NSString stringWithFormat:@"%1.1f M%@",size,bytesSuffix]);
    size = size / kilo;
    if (size < kilo)
        return([NSString stringWithFormat:@"%1.1f G%@",size,bytesSuffix]);
    size = size / kilo;
        
    return([NSString stringWithFormat:@"%1.1f T%@",size,bytesSuffix]);
}


