//  fileSize.m
//
//  Created by Ali Rantakari
//  http://hasseg.org/trash
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


#import "fileSize.h"

NSUInteger sizeOfDirectoryFSRef(FSRef *theFileRef, BOOL asPhysicalSize)
{
    FSIterator iterator = NULL;
    NSUInteger totalSize = 0;
    
    // Iterate the directory contents, recursing as necessary
    if (FSOpenIterator(theFileRef, kFSIterateFlat, &iterator) != noErr)
        return totalSize;
    
    const ItemCount kMaxEntriesPerFetch = 40;
    ItemCount actualFetched;
    FSRef fetchedRefs[kMaxEntriesPerFetch];
    FSCatalogInfo fetchedInfos[kMaxEntriesPerFetch];
    
    OSErr getCatInfoErr = FSGetCatalogInfoBulk(
        iterator,
        kMaxEntriesPerFetch,
        &actualFetched,
        NULL,
        kFSCatInfoDataSizes | kFSCatInfoNodeFlags | kFSCatInfoRsrcSizes,
        fetchedInfos,
        fetchedRefs,
        NULL,
        NULL
        );
    while ((getCatInfoErr == noErr) || (getCatInfoErr == errFSNoMoreItems))
    {
        ItemCount thisIndex;
        for (thisIndex = 0; thisIndex < actualFetched; thisIndex++)
        {
            // Recurse if folder; add size to total if file:
            if (fetchedInfos[thisIndex].nodeFlags & kFSNodeIsDirectoryMask)
            {
                totalSize += sizeOfDirectoryFSRef(&fetchedRefs[thisIndex], asPhysicalSize);
            }
            else
            {
                if (asPhysicalSize)
                {
                    totalSize += fetchedInfos[thisIndex].dataPhysicalSize;
                    totalSize += fetchedInfos[thisIndex].rsrcPhysicalSize;
                }
                else
                {
                    totalSize += fetchedInfos[thisIndex].dataLogicalSize;
                    totalSize += fetchedInfos[thisIndex].rsrcLogicalSize;
                }
            }
        }
        
        if (getCatInfoErr == errFSNoMoreItems)
            break;
        
        // Get more items
        getCatInfoErr = FSGetCatalogInfoBulk(
            iterator,
            kMaxEntriesPerFetch,
            &actualFetched,
            NULL,
            kFSCatInfoDataSizes | kFSCatInfoNodeFlags | kFSCatInfoRsrcSizes,
            fetchedInfos,
            fetchedRefs,
            NULL,
            NULL
            );
    }
    
    FSCloseIterator(iterator);
    return totalSize;
}


static FSRef fsrefFromFilePath(NSString *filePath)
{
    FSRef fsRef;
    FSPathMakeRefWithOptions(
        (const UInt8 *)[filePath fileSystemRepresentation],
        kFSPathMakeRefDoNotFollowLeafSymlink,
        &fsRef,
        NULL // Boolean *isDirectory
        );
    return fsRef;
}


NSUInteger sizeOfFolder(NSString *folderPath, BOOL asPhysicalSize)
{
    FSRef theFileRef = fsrefFromFilePath(folderPath);
    return sizeOfDirectoryFSRef(&theFileRef, asPhysicalSize);
}






