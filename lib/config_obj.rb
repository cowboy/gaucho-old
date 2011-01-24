# More friendly looking dot-syntax access for hash keys.
# http://mjijackson.com/2010/02/flexible-ruby-config-objects

class ConfigObj
  def initialize(data={})
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

  def responds_to?(name)
    false
  end
end
