module Gaucho
  # TODO: BETTER ERRORS
  # TODO: HANDLE SUBDIR ("Pages" class maybe)
  # TODO: SHORT SHAS
  # TODO: "PARENT" REPO OBJECT?
  class Page
    attr_reader :id, :tree, :meta, :content

    @@commits_by_page = nil
    @@default_branch = 'master' # TODO: ??

    def initialize(id, treeish = nil)
      if id.class == Grit::Tree
        @fixed_tree = true
        @id = id.name
        @tree = id
      else
        @id = id
      end
      self.shown = treeish
    end

    # A hash of all commits for this page.
    def commits
      Page.build_commit_index
      @@commits_by_page[id.to_sym]
    end

    # A hash of all commits ids for this page.
    def commit_ids
      Page.build_commit_index
      @@commit_ids_by_page[id.to_sym]
    end

    # Set the current Page to show the specified tree-ish. Specifying nil
    # sets the view to the latest commit.
    #
    # NOTE: This will only work if the page was originally built with a string
    # id (via direct Page.new call), and not as the result of Pages.all, which
    # gets all pages at a specified tree-ish.
    def shown=(treeish)
      @treeish = treeish
      unless @fixed_tree
        @tree = Page.parent_tree(treeish)/id
        raise Gaucho::PageNotFound unless @tree
      end
      build_metadata
    end

    # The currently-viewed (or specified) commit SHA for this page.
    def commit_id(sha = nil)
      sha = Page.rev_parse(sha || @treeish)
      if commit_ids.index(sha)
        sha
      else
        commits.last.id
      end
    end

    # The currently-viewed (or specified) commit for this page.
    def commit(sha = nil)
      sha = commit_id(sha)
      commits[commit_ids.index(sha)]
    end

    # Canonical URL for this Page.
    def url
      "/#{id}"
    end

    # URL for this Page at the specified (or most recent) commit.
    def url_at_commit(sha = nil)
      sha = if sha.class.to_s =~ /^Gaucho::Commit/
        # Gaucho::Commit or Gaucho::CommitLater
        sha.id
      else
        commit_id(sha)
      end
      "/#{sha[0..6]}/#{id}"
    end

    # Contents of "file" (Blob) at the specified path under this Content.
    def /(file)
      build_file_index
      @files[commit_id.to_sym][file] or raise Gaucho::FileNotFound.new(file)
    end

    # Pass-through all other methods to the underlying metadata object.
    def method_missing(name, *args)
      meta.send(name, *args) if meta.respond_to?(name)
    end

    def self.repo_path
      Gaucho.repo_path
    end

    def self.repo
      Gaucho.repo
    end

    # All Page objects for this repo.
    def self.all(treeish = nil)
      parent_tree(treeish).trees.collect {|tree| Page.new(tree, treeish)}
    end

    # The parent Tree that contains all page trees.
    def self.parent_tree(treeish = nil)
      repo.tree(treeish || @@default_branch)
    end

    # A Grit::Commit object for the specified tree-ish.
    def self.commit(treeish = nil)
      repo.commit(treeish)
    end

    # Full SHA for the given tree-ish.
    def self.rev_parse(treeish = nil)
      native_git(:rev_parse, {raise: true}, treeish).chomp rescue nil
    end

    # Native git command
    def self.native_git(*args)
      repo.git.native(*args)
    end

    private
      # Build page metadata from index asset.
      def build_metadata
        #pp 'BUILDING METADATA'

        index = tree.blobs.find {|blob| blob.name =~ /^index\./} # TODO: FS
        raise Gaucho::PageNotFound unless index

        docs = []
        YAML.each_document(index.data) {|doc| docs << doc} rescue nil
        docs = [{}, index.data] unless docs.length == 2
        @meta = Gaucho::Config.new(docs.first)
        @meta.index_name = index.name
        @content = docs.last
      end

      # Build page sub-file index at the current treeish.
      def build_file_index
        @files ||= {}
        cur = commit_id.to_sym
        return if @files[cur]

        pp 'BUILDING FILE INDEX'
        @files[cur] = {}

        # Parse the raw output from git ls-tree.
        text = Page.native_git(:ls_tree, {:r => true, :t => true}, commit_id, id)
        text.split("\n").each do |line|
          thing = Page.repo.tree.content_from_string(Page.repo, line)
          if thing.kind_of?(Grit::Blob) && !File.basename(thing.name).start_with?('.')
            if thing.name =~ Regexp.new("^#{id}/(.*)")
              #pp [$1, thing.data.length]
              @files[cur][$1] = thing.data
            end
          end
        end
      end

      # Build per-page commit index from pre-rendered ".git/file-index" file.
      def self.build_commit_index
        return if @@commits_by_page

        pp 'BUILDING COMMIT INDEX'
        #native_git(:log, {pretty: 'oneline', name_only: true, parents: true, reverse: true})
        @@commits_by_page = {}
        @@commit_ids_by_page = {}

        current_id = nil # block local workaround
        added = nil # block local workaround

        index_file = File.join(repo_path, '.git', 'file-index')
        #i = 0
        File.foreach(index_file) do |line|
          #i += 1
          #break if i > 100
          #pp line
          if /^([0-9a-f]{40})/.match(line)
            parent_ids = line.scan(/([0-9a-f]{40})/).flatten # TODO: REMOVE?
            current_id = parent_ids.shift
            added = false
          elsif !added
            added = true
            line =~ %r{^(.*?)/} # TODO: HANDLE SUBDIR??
            page_id = $1.to_sym
            #pp [page_id, current_id]
            commit = Gaucho::CommitLater.new(current_id) {|c| commit(c)}
            @@commits_by_page[page_id] ||= []
            @@commits_by_page[page_id] << commit
            @@commit_ids_by_page[page_id] ||= []
            @@commit_ids_by_page[page_id] << current_id
          end
        end

        @@latest_commit = current_id # TODO: REMOVE?
      end
  end
end