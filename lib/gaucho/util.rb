module Gaucho
  # Standardize on 7-character SHAs across-the-board. Change this if you
  # want different length short SHAs.
  module ShortSha
    def short_sha(sha = id)
      sha[0..6]
    end
  end

  module StringUtils
    # Attempt to fix string encoding using this simple (and possibly horribly
    # flawed logic): If a UTF-8 string has invalid encoding, it's binary data.
    # Otherwise, it's valid UTF-8.
    def fix_encoding(str)
      copy = str.dup.force_encoding('UTF-8')
      if copy.valid_encoding?
        copy
      else
        copy.force_encoding('ASCII-8BIT')
      end
    end

    # Ensure that data is not binary or invalidly encoded.
    def valid_data?(str)
      str.encoding.name != 'ASCII-8BIT' && str.valid_encoding?
    end

    # Transliterate a Unicode string to its non-fancy, non-unicode counterpart.
    def transliterate(str)
      UnicodeUtils.nfkd(str).gsub(/[^\x00-\x7F]/, '').to_s
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
      data.each {|key, value| self[key.downcase] = value}
    end

    def [](key)
      @data[key.downcase.to_sym]
    end

    def []=(key, value)
      @data[key.downcase.to_sym] = if value.class == Hash
        Config.new(value)
      else
        value
      end
    end

    def to_hash
      @data
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
