# A wrapper for Grit::Repo
module Gaucho
  # TODO: BETTER ERRORS
  # TODO: BUILD A PAGE FROM FS WITHOUT ANY COMMITS
  class PageSet
    include Enumerable
    extend Forwardable

    attr_reader :repo, :tree, :subdir, :renames
    attr_accessor :check_mods

    # Forward Array methods to @pages (via the pages method) so that the PageSet
    # can feel as Array-like as possible.
    def_delegators :pages, *Array.public_instance_methods(false)

    def initialize(repo, options = {})
      @repo = if repo.class == Grit::Repo
        repo
      else
        Grit::Repo.new(repo)
      end

      # Initialize from options, overriding these defaults.
      { check_mods: false,
        renames: {},
        subdir: nil
      }.merge(options).each do |key, value|
        instance_variable_set("@#{key}".to_sym, value)
      end

      rebuild!
    end

    # Rebuild all internal commit / Page caches. Use this to force Gaucho to
    # show changes if the repo's commits / HEAD have been changed.
    def rebuild!
      @tree = if subdir.nil?
        repo.tree
      else
        repo.tree/subdir
      end

      # Map of renamed Page id (path) to original Page id.
      @page_paths = {}
      @tree.trees.each {|tree| @page_paths[tree.name] = tree.name}
      @renames.each {|page_id, path| @page_paths[path] = page_id}

      @pages = @pages_by_id = nil
      build_commit_index!
    end

    def to_s
      %Q{#<Gaucho::PageSet "#{abs_subdir_path}">}
    end

    # Expose the underlying pages array.
    def pages
      build_page!
      @pages
    end

    # Get a specific page. This will create a new Page instance internally if
    # one doesn't already exist. If the page has been renamed via the renames
    # options hash, return the new URL (for redirecting).
    def [](page_id)
      page_id.gsub!('/', '-')

      build_page!(page_id)
      page = @pages_by_id[page_id]

      if page.nil?
        nil
      elsif page.path == page_id
        page
      else
        page.url
      end
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
        File.join(repo.working_dir, subdir)
      else
        repo.working_dir
      end
    end

    protected

    # Build commit index for this repo.
    def build_commit_index!
      @commits_by_page = {}
      current_id = nil

      log = repo.git.native(:log, {pretty: 'oneline', name_only: true,
        reverse: true, timeout: false})

      log.split("\n").each do |line|
        if line =~ /^([0-9a-f]{40})/
          current_id = $1
        else
          if line =~ %r{^#{subdir_path}(.*?)/}
            @commits_by_page[$1] ||= []
            @commits_by_page[$1] << current_id
          end
        end
      end

      @commits_by_page.each {|p, commits| commits.uniq!}
    end

    # Build page index for this repo. If nil is passed, build all pages,
    # otherwise build the specified page.
    def build_page!(page_id = nil)
      page_id = if page_id
        @page_paths[page_id] || (check_mods && page_id)
      else
        @page_paths.map {|path, id| id}.uniq
      end

      return unless page_id

      @pages_by_id ||= {}

      [*page_id].each do |id|
        unless @pages_by_id[id]
          path = renames[id] || id
          @pages_by_id[id] = @pages_by_id[path] = Gaucho::Page.new(self, id, path, @commits_by_page[id])
        end
      end

      @pages = []
      @pages_by_id.each {|p_id, page| @pages << page}
      @pages = @pages.uniq.sort
    end
  end
end
