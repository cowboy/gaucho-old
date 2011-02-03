# A wrapper for Grit::Repo
module Gaucho
  class Repo
    attr_reader :repo_path, :repo
    attr_accessor :default_branch, :subdir, :fs_treeish, :cache

    def initialize(repo_path, options = {})
      @repo_path = repo_path
      @repo = Grit::Repo.new(repo_path)
      @cache = {}

      # Initialize from options, overriding these defaults.
      {
        default_branch: 'master', # TODO: MAKE THIS WORK
        #subdir: 'content'
      }.merge(options).each {|k,v| self.send("#{k}=".to_sym, v)}
    end

    # A Gaucho::Page instance.
    def page(*args)
      # TODO: handle subdir
      Gaucho::Page.new(self, *args)
    end

    # All Gaucho::Page instances for this repo, at the specified tree-ish.
    def pages(treeish = nil, options = {})
      # TODO: handle subdir
      pages_tree(treeish).trees.collect {|tree| page(tree, treeish, options)}.sort
    end

    # A hash of all commits for the specified page.
    def commits(page_id)
      build_commit_index
      cache[:commits_by_page][page_id]
    end

    # A hash of all commits ids for the specified page.
    def commit_ids(page_id)
      build_commit_index
      cache[:commit_ids_by_page][page_id]
    end

    # The parent Tree that contains all page trees.
    def pages_tree(treeish = nil)
      cache[:pages_trees] ||= {}
      key = treeish.to_sym rescue :nil
      cache[:pages_trees][key] ||= tree(treeish || default_branch)
    end

    # Sort commits. TODO: REMOVE?
    def sort_commits(shas)
      shas.sort {|a, b| cache[:commit_order][a].to_i <=> cache[:commit_order][b].to_i}
    end

    # Does a given page have any local modifications?
    def has_local_mods(page_id)
      !git.native(:status, {chdir: repo_path, porcelain: true}, page_id).empty?
    end

    # Full SHA for the given tree-ish.
    def rev_parse(treeish = nil)
      git.native(:rev_parse, {raise: true}, treeish).chomp rescue nil
    end

    # Pass-through all other methods to the underlying repo object.
    def method_missing(name, *args)
      repo.send(name, *args) if repo.respond_to?(name)
    end

    private

      # Build per-page commit index from pre-rendered ".git/file-index" file.
      def build_commit_index
        return if cache[:commits_by_page]

        start_time = Time.now
        cache[:commits_by_page] = {}
        cache[:commit_ids_by_page] = {}
        cache[:commit_order] = {}

        current_id = nil # block local workaround
        added = nil # block local workaround
        idx = 0

        log = git.native(:log, {pretty: 'oneline', name_only: true, parents: true, reverse: true})
        log.split("\n").each do |line|
          if /^([0-9a-f]{40})/.match(line)
            parent_ids = line.scan(/([0-9a-f]{40})/).flatten # TODO: REMOVE?
            current_id = parent_ids.shift
            cache[:commit_order][current_id] = @idx
            idx += 1
            added = false
          elsif !added
            added = true
            line =~ %r{^(.*?)/} # TODO: HANDLE SUBDIR??
            page_id = $1.to_sym
            #pp [page_id, current_id]
            #commit = Gaucho::CommitLater.new(current_id) {|c| commit(c)}
            commit = commit(current_id)
            cache[:commits_by_page][page_id] ||= []
            cache[:commits_by_page][page_id] << commit
            cache[:commit_ids_by_page][page_id] ||= []
            cache[:commit_ids_by_page][page_id] << current_id
          end
        end

        cache[:latest_commit] = current_id # TODO: REMOVE?
        pp "BUILT COMMIT INDEX IN #{Time.now - start_time} SEC"
      end

  end
end
