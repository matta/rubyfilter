#!/usr/bin/env ruby
#
#   Copyright (C) 2001, 2002, 2003 Matt Armstrong.  All rights reserved.
#
#   Permission is granted for use, copying, modification,
#   distribution, and distribution of modified versions of this work
#   as long as the above copyright notice is included.
#

$VERBOSE = true

Dir[File.join(File.dirname(__FILE__), 'test*.rb')].each {|f|
  require f
}
