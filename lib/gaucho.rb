$:.unshift File.dirname(__FILE__) # For use/testing when no gem is installed

# External stuff.
require 'grit'
require 'yaml'
require 'find'
require 'zlib'

# For the renderer.
require 'rdiscount'
require 'rb-pygments'
# For the escape_html helper.
require 'rack'
include Rack::Utils

# Gaucho stuff.
require 'gaucho/util'
require 'gaucho/repo'
require 'gaucho/page'
require 'gaucho/renderer'
require 'gaucho/commit'
require 'gaucho/diff'

module Gaucho
  VERSION = '0.0.1'

  def self.version
    VERSION
  end
end
