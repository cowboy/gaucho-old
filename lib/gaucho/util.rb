module Gaucho
  # Standardize on 7-character SHAs across-the-board. Change this if you
  # want different length short SHAs.
  module ShortSha
    def short_sha(sha = id)
      sha[0..6]
    end
  end

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
      @data.has_key?(name)
    end
  end
end
