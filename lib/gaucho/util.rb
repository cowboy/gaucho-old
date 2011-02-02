module Gaucho
  # Standardize on 7-character SHAs across-the-board. Change this if you
  # want different length short SHAs.
  module ShortSha
    def short_sha(sha = id)
      sha[0..6]
    end
  end

  # I'm lazy, and my data likes to be lazy too.
  class Later < SimpleDelegator
    def initialize(*args, &block)
      @args = args
      @block = block
    end

    def __getobj__
      unless @lookedup
        __setobj__ @block.call(*@args)
        @lookedup = true
      end
      super
    end
  end

  # Because Gaucho::CommitLater.new is nicer than Gaucho::Later.new.
  class CommitLater < Later; end

  # More friendly looking dot-syntax access for hash keys.
  # http://mjijackson.com/2010/02/flexible-ruby-config-objects
  class Config
    def initialize(data = {})
      @data = {}
      update!(data)
    end

    def update!(data)
      data.each {|key, value| self[key] = value}
    end

    def [](key)
      @data[key.to_sym]
    end

    def []=(key, value)
      if value.class == Hash
        @data[key.to_sym] = self.class.new(value)
      else
        @data[key.to_sym] = value
      end
    end

    def method_missing(name, *args)
      if name.to_s =~ /(.+)=$/
        self[$1] = args.first
      else
        self[name]
      end
    end

    def respond_to?(name)
      self[name] != nil
    end

    def inspect
      @data
    end
  end

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
end
