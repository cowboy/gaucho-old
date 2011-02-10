# When required directly.
$:.unshift File.dirname(__FILE__)

# External stuff.
require 'grit'
require 'yaml'
require 'find'
require 'date'
require 'forwardable'

# For the renderer.
require 'rdiscount'
# For the renderer's escape_html helper.
require 'rack'
include Rack::Utils

# Gaucho stuff.
require 'gaucho/version'
require 'gaucho/util'
require 'gaucho/pageset'
require 'gaucho/page'
require 'gaucho/renderer'
require 'gaucho/commit'
require 'gaucho/diff'
