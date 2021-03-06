# RubyFilter

This is a framework for filtering mail, possibly modifying it, and
delivering it to various mailbox formats.

RubyFilter is available at:

    https://github.com/matta/rubyfilter/

RubyFilter depends on RubyMail, available at:

    https://github.com/matta/rubymail/

# Why?

The world needs alternatives to procmail.  I wanted one that allowed
me to write a mail filter in a fully capable scripting language.

# Status

This package is currently very raw.  All API is subject to change.  I
very much appreciate suggestions and comments.

However, I do use this for all of my own mail filtering.

# Requirements

Ruby 1.6.* or Ruby 1.8.*.  Only tested under Linux, should be fine
under any Unix.

# Documentation

See the doc/ subdirectory for HTML documentation.

# Install

Type the following while in the package directory:

```sh
ruby install.rb config
ruby install.rb setup
ruby install.rb install
```

You may need special permissions to execute the last line.  If you
want to just install RubyMail to a custom location, just copy the
rmail subdirectory manually.

# Tests?

This package has a complete unit test suite (requires RubyUnit to
run).

# License

Copyright (c) 2003, 2021 Matt Armstrong.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Support

To reach the author of RubyFilter, send mail to gmatta@gmail.com.
