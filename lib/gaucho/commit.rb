# A wrapper for Grit::Commit
module Gaucho
  class Commit
    include Gaucho::ShortSha
    attr_reader :content, :commit, :diffs

    def initialize(content, commit)
      @content = content
      @commit = commit
      @diffs = Gaucho::Diff.diffs(content, commit.show)
    end

    # Pretty inspection.
    def inspect
      p = pointer? ? '*' : ''
      %Q{#<Gaucho::Commit#{p} "#{short_sha}" "#{committed_date}" "#{short_message}">}
    end

    # Is this commit the most recent commit for the Content?
    def latest?
      id == content.commits.first.id
    end

    # Is this commit the currently pointed-to commit for the Content?
    def pointer?
      id == content.commit.id
    end

    # Pass-through all methods to the underlying Grit::Commit instance.
    def method_missing(name, *args)
      commit.send(name, *args) if commit.respond_to?(name)
    end

    # Get a single Commit instance.
    def self.commit(content, commit)
      self.new(content, commit)
    end

    # Get an array of Commit instances.
    def self.commits(content, commits)
      commits.collect {|commit| self.commit(content, commit)}.compact
    end
  end
end
