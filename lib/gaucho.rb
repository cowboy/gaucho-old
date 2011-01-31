$:.unshift File.dirname(__FILE__) # For use/testing when no gem is installed

# External stuff.
require 'grit'
require 'yaml'
require 'find'

# Gaucho stuff.
require 'gaucho/util'
require 'gaucho/page'
require 'gaucho/renderer'
#require 'gaucho/content'
#require 'gaucho/repo'
require 'gaucho/commit'
require 'gaucho/diff'
#require 'gaucho/blob'

module Gaucho
  VERSION = '0.0.1'

  def self.version
    VERSION
  end
end
