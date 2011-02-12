# A wrapper for Grit::Diff
module Gaucho
  class Diff
    include StringUtils

    attr_reader :commit, :diff

    def initialize(commit, diff)
      @commit = commit
      @diff = diff
    end

    def to_s
      %Q{#<Gaucho::Diff "#{url}" "#{status}">}
    end

    # URL for this Diff's file.
    def url
      %Q{#{commit.url}/#{file}}
    end

    # Filename for this Diff.
    def file
      diff.a_path[%r{^#{commit.page.page_path}/(.*)}, 1]
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
    def binary?; diff.diff.start_with? 'Binary files'; end
    
    # The Grit::Diff diff text, with its encoding "fixed."
    def data
      fix_encoding(diff.diff)
    end

    # Test whether or not the specified Grit::Diff is relevant to the
    # specified Gaucho::Page.
    def self.is_diff_relevant(diff, page)
      diff.a_path.start_with? page.page_path
    end
  end
end
