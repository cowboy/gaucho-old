# When required directly.
$:.unshift File.dirname(__FILE__)

# Stuff that comes with Ruby.
require 'cgi'
require 'yaml'
require 'find'
require 'time'
require 'forwardable'

# External stuff.
require 'grit'
require 'rdiscount'
require 'unicode_utils'

# Gaucho stuff.
require 'gaucho/version'
require 'gaucho/util'
require 'gaucho/pageset'
require 'gaucho/page'
require 'gaucho/renderer'
require 'gaucho/commit'
require 'gaucho/diff'
