# A wrapper for Grit::Diff
module Gaucho
  class Diff
    attr_reader :commit, :diff

    def initialize(commit, diff)
      @commit = commit
      @diff = diff
    end

    # Pretty inspection.
    def inspect
      %Q{#<Gaucho::Diff "#{url}" "#{status}">}
    end

    # URL for this Diff's file.
    def url
      %Q{#{commit.url}/#{file}}
    end

    # Filename for this Diff.
    def file
      diff.a_path.sub(Regexp.new("^#{commit.page.id}/(.*)"), '\1')
    end

    # What happened (in a very general sense)?
    def status
      created? ? 'created' : deleted? ? 'deleted' : 'updated'
    end

    # Prettier method names for accessing the underlying Grit::Diff instance
    # methods.
    def created?; diff.new_file; end
    def deleted?; diff.deleted_file; end
    def updated?; !created? && !deleted?; end
    def data; diff.diff; end

    # Test whether or not the specified Grit::Diff is relevant to the
    # specified Gaucho::Page.
    def self.is_diff_relevant(diff, page)
      diff.a_path.start_with? File.join(page.id, '')
    end
  end
end
