# A wrapper for Grit::Repo
module Gaucho
  # TODO: BETTER ERRORS
  class PageSet
    include Enumerable

    attr_reader :repo_path, :repo, :tree, :subdir
    attr_accessor :default_branch

    def initialize(repo_path, options = {})
      @repo_path = repo_path
      @repo = Grit::Repo.new(repo_path)

      # Initialize from options, overriding these defaults.
      { default_branch: 'master', # TODO: MAKE THIS WORK
        subdir: nil
      }.merge(options).each do |key, value|
        instance_variable_set("@#{key}".to_sym, value)
      end

      @tree = if subdir.nil?
        repo.tree
      else
        repo.tree/subdir
      end

      build_commit_index
    end

    def to_s
      %Q{#<Gaucho::PageSet "#{abs_subdir_path}">}
    end

    # Expose the underlying pages array.
    def pages
      build_page
      @pages
    end

    # Get a specific page. This will create a new Page instance internally if
    # one doesn't already exist.
    def [](page_id)
      page_id.gsub!('/', '-')
      build_page(page_id)
      @pages_by_id[page_id]
    end

    # Get all pages. This will create new Page instances internally for any that
    # don't already exist. This could take a while.
    def each
      if block_given? then
        pages.each {|page| yield page}
      else
        to_enum(:each)
      end
    end

    # Reset all Pages "shown" to their latest commit.
    def reset_shown
      each {|page| page.shown = nil}
    end

    # Relative (to repo root) filesystem path for all Pages in this PageSet.
    def subdir_path
      if @subdir.nil?
        ''
      else
        File.join(@subdir, '')
      end
    end

    # Absolute filesystem path for all Pages in this PageSet.
    def abs_subdir_path
      if subdir
        File.join(repo_path, subdir)
      else
        repo_path
      end
    end

    # Sort commits. TODO: REMOVE?
    def sort_commits(shas)
      shas.sort {|a, b| @commit_order[a].to_i <=> @commit_order[b].to_i}
    end

    # Pass-through all other methods to the underlying pages Array.
    def method_missing(name, *args)
      pages.send(name, *args) if pages.respond_to?(name)
    end

    protected

    # Build commit index for this repo.
    def build_commit_index
      return if @commits_by_page

      @commit_order = {}
      @commits_by_page = {}

      current_id = nil
      added = nil
      idx = 0

      log = repo.git.native(:log, {pretty: 'oneline', name_only: true,
        parents: true, reverse: true, timeout: false})

      log.split("\n").each do |line|
        if line =~ /^([0-9a-f]{40})/
          current_id = $1
          @commit_order[current_id] = idx += 1
          added = false
        elsif !added
          added = true
          if line =~ %r{^#{subdir_path}(.*?)/}
            @commits_by_page[$1] ||= []
            @commits_by_page[$1] << current_id
          end
        end
      end
    end

    # Build page index for this repo. If nil is passed, build all pages,
    # otherwise build the specified page(s).
    def build_page(page_ids = nil)
      @pages_by_id ||= {}

      if page_ids.nil?
        page_ids = []
        @commits_by_page.each {|page_id, commits| page_ids << page_id}
      end

      [*page_ids].each do |page_id|
        @pages_by_id[page_id] ||= Gaucho::Page.new(self, page_id, @commits_by_page[page_id])
      end

      @pages = []
      @pages_by_id.each {|page_id, page| @pages << page}
      @pages.sort!
    end
  end
end
