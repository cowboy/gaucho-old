#!/usr/bin/env rackup
require './app'
run Gaucho.new(File.expand_path('../db/test3'))
