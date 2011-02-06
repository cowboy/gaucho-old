# A wrapper for Grit::Repo
module Gaucho
  # TODO: BETTER ERRORS
  # TODO: HANDLE SUBDIR ("Pages" class maybe)
  class Repo
    attr_reader :repo_path, :repo, :tree
    attr_accessor :default_branch, :subdir

    def initialize(repo_path, options = {})
      @repo_path = repo_path
      @repo = Grit::Repo.new(repo_path)
      @tree = @repo.tree

      # Initialize from options, overriding these defaults.
      {
        default_branch: 'master', # TODO: MAKE THIS WORK
        #subdir: 'content'
      }.merge(options).each {|key, value| self.send("#{key}=".to_sym, value)}

      build_commit_index
    end

    # Pretty inspection.
    def inspect
      %Q{#<Gaucho::Repo "#{repo_path}">}
    end

    # Get a specific page. This will create a new Page instance if one doesn't
    # already exist.
    def page(page_id)
      page_id.gsub!('/', '-')
      build_page(page_id)
      @pages_by_id[page_id]
    end

    # Get all pages. This will create new Page instances for any that don't
    # already exist. This could take a while.
    def pages(reset_shown = false)
      build_page
      @pages.each {|page| page.shown = nil} if reset_shown
      @pages
    end

    # Sort commits. TODO: REMOVE?
    def sort_commits(shas)
      shas.sort {|a, b| @commit_order[a].to_i <=> @commit_order[b].to_i}
    end

    # Pass-through all other methods to the underlying repo object.
    def method_missing(name, *args)
      repo.send(name, *args) if repo.respond_to?(name)
    end

    private

      # Build commit index for this repo.
      def build_commit_index
        return if @commits_by_page

        @commit_order = {}
        @commits_by_page = {}

        current_id = nil
        added = nil
        idx = 0

        log = git.native(:log, {pretty: 'oneline', name_only: true,
          parents: true, reverse: true, timeout: false})

        log.split("\n").each do |line|
          if /^([0-9a-f]{40})/.match(line)
            parent_ids = line.scan(/([0-9a-f]{40})/).flatten # TODO: REMOVE?
            current_id = parent_ids.shift
            @commit_order[current_id] = idx += 1
            added = false
          elsif !added
            added = true
            line =~ %r{^(.*?)/} # TODO: HANDLE SUBDIR??
            @commits_by_page[$1] ||= []
            @commits_by_page[$1] << current_id
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
        elsif !page_ids.respond_to?('each')
          page_ids = [page_ids]
        end

        page_ids.each do |page_id|
          @pages_by_id[page_id] ||= Gaucho::Page.new(self, page_id, @commits_by_page[page_id])
        end

        @pages = []
        @pages_by_id.each {|page_id, page| @pages << page}
        @pages.sort!
      end
  end
end
