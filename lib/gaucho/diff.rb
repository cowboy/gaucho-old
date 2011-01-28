# A wrapper for Grit::Diff
module Gaucho
  class Diff
    attr_reader :content, :diff, :name, :created, :deleted, :data

    def initialize(content, diff)
      @content = content
      @diff = diff
    end

    # Pretty inspection.
    def inspect
      status = created? ? 'created' : deleted? ? 'deleted' : 'updated'
      %Q{#<Gaucho::Diff "#{name}" "#{status}">}
    end

    # Filename for this diff.
    def name
      diff.a_path.sub(Regexp.new("^#{content.path}/(.*)"), '\1')
    end

    # Short method names for accessing the diff's methods.
    def created?; diff.new_file; end
    def deleted?; diff.deleted_file; end
    def data; diff.diff; end

    # Return a Diff instance if the diff in question is relevant to
    # the current content, otherwise nil.
    def self.diff(content, diff)
      path = File.join(content.path, '')
      self.new(content, diff) if diff.a_path.start_with? path
    end

    # Get an array of Diff instances.
    def self.diffs(content, diffs)
      diffs.collect {|diff| self.diff(content, diff)}.compact
    end
  end
end
