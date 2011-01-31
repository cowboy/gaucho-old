module Gaucho
  # Standardize on 7-character SHAs across-the-board. Change this if you
  # want different length short SHAs.
  module ShortSha
    def short_sha
      id[0..6]
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
  
  # Exception handlers.
  #class NotFound < Exception; end

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
end
