# A wrapper for Grit::Commit
module Gaucho
  class Commit
    include ShortSha

    attr_reader :page, :commit, :diffs

    def initialize(page, commit)
      @page = page
      @commit = commit
      @diffs = Gaucho::Diff.diffs(page, commit.show)
    end

    # Pretty inspection.
    def inspect
      p = shown? ? '*' : ''
      %Q{#<Gaucho::Commit#{p} "#{id}" "#{committed_date}" "#{short_message}">}
    end

    # Is this commit the most recent commit for the Page?
    def latest?
      id == page.commit_ids.last
    end

    # Is this commit the currently shown commit for the Page?
    def shown?
      id == page.commit_id
    end

    # Pass-through all other methods to the underlying Grit::Commit instance.
    def method_missing(name, *args)
      commit.send(name, *args) if commit.respond_to?(name)
    end

    # Get a single Commit instance.
    def self.commit(page, commit)
      self.new(page, commit)
    end

    # Get an array of Commit instances.
    def self.commits(page, commits)
      commits.collect {|commit| self.commit(page, commit)}.compact
    end
  end
end
