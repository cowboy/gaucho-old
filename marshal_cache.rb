# Ruby MarshalCache - v0.1 - 02/2/2011
# http://benalman.com/
# 
# Copyright (c) 2011 "Cowboy" Ben Alman
# Dual licensed under the MIT and GPL licenses.
# http://benalman.com/about/license/

require 'zlib'

# A very basic cache that uses Marshal internally.
# Inspired by Marcus Westin's http://bit.ly/g3BLyp
class MarshalCache
  def initialize(root, gzip = false)
    @root = root
    @gzip = gzip
  end

  # If file at path exists, return its value, otherwise create it with the
  # value returned by the specified block.
  def get(path)
    path = File.join(@root, path)
    obj = nil
    if File.exist?(path)
      block = lambda {|file| obj = Marshal.load(file)}
      if @gzip
        Zlib::GzipReader.open(path, &block)
      else
        File.open(path, 'rb', &block)
      end
    elsif block_given?
      obj = yield
      block = lambda {|file| Marshal.dump(obj, file)}
      if @gzip
        Zlib::GzipWriter.open(path, &block)
      else
        File.open(path, 'wb', &block)
      end
    end
    obj
  end
end