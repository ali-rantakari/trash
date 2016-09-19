# Trash

This is a small command-line program for OS X that moves files or folders to the trash.

See [my blog post][post] for more info on some initial implementation details and design decisions.

[post]: http://hasseg.org/blog/post/406/trash-files-from-the-os-x-command-line/


## Installing

Via [Homebrew]:

    brew install trash

Manually:

    $ make
    $ cp trash /usr/local/bin/
    $ make docs
    $ cp trash.1 /usr/local/share/man/man1/


[Homebrew]: http://brew.sh


## The “put back” feature

By default, `trash` asks Finder to move the specified files/folders to the trash instead of calling the system API to do this because of the _"put back"_ feature that only works when trashing files through Finder.

If you supply the `-a` argument, `trash` will first try the system API and only call on Finder to trash files you lack access rights for.



## The MIT License

Copyright (c) Ali Rantakari

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
