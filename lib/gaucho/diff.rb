# A wrapper for Grit::Diff
module Gaucho
  class Diff
    attr_reader :page, :diff

    def initialize(page, diff)
      @page = page
      @diff = diff
    end

    # Pretty inspection.
    def inspect
      %Q{#<Gaucho::Diff "#{file}" "#{status}">}
    end

    # Filename for this Diff.
    def file
      diff.a_path.sub(Regexp.new("^#{page.id}/(.*)"), '\1')
    end

    # What happened?
    def status
      created? ? 'created' : deleted? ? 'deleted' : 'updated'
    end

    # Prettier method names for accessing the underlying Grit::Diff instance
    # methods.
    def created?; diff.new_file; end
    def deleted?; diff.deleted_file; end
    def data; diff.diff; end

    # Return a Gaucho::Diff instance if the diff in question is relevant to
    # the current page, otherwise nil.
    def self.diff(page, diff)
      self.new(page, diff) if diff.a_path.start_with? File.join(page.id, '')
    end

    # Get an array of Gaucho::Diff instances.
    def self.diffs(page, diffs)
      diffs.collect {|diff| self.diff(page, diff)}.compact
    end
  end
end
