module Gaucho
  # TODO: BETTER ERRORS
  # TODO: HANDLE SUBDIR ("Pages" class maybe)
  # TODO: "PARENT" REPO OBJECT?
  # TODO: ADD DEFAULT OPTIONS
  class Page
    include ShortSha

    attr_reader :repo, :id, :meta, :shown
    attr_accessor :options

    @@default_branch = 'master' # TODO: ??

    def initialize(repo, id, treeish = nil, options = {})
      @repo = repo
      @options = options
      if id.class == Grit::Tree
        @fixed_tree = true
        @id = id.name
        @tree = id
      else
        @id = id
      end
      self.shown = treeish
    end

    # Pretty inspection.
    def inspect
      %Q{#<Gaucho::Page "#{commit.id}" "#{id}" "#{url}">}
    end

    # A hash of all commits for this page.
    def commits
      repo.commits(id.to_sym)
    end

    # A hash of all commits ids for this page.
    def commit_ids
      repo.commit_ids(id.to_sym)
    end

    # Set the current Page to show the specified tree-ish. Specifying nil
    # sets the view to the latest commit.
    #
    # NOTE: This will only work if the page was originally built with a string
    # id (via direct Page.new call), and not as the result of Pages.all, which
    # gets all pages at a specified tree-ish.
    def shown=(treeish)
      @shown = treeish
      build_metadata
    end

    # The currently-viewed (or specified) commit SHA for this page.
    def commit_id(sha = nil)
      if sha.nil? && show_local_mods
        :filesystem
      else
        sha = repo.rev_parse(sha || @shown)
        if commit_ids.index(sha)
          sha
        else
          commits.last.id
        end
      end
    end

    # The currently-viewed (or specified) commit for this page.
    def commit(sha = nil)
      if show_local_mods
        commits.last
      else
        sha = commit_id(sha)
        commits[commit_ids.index(sha)]
      end
    end

    # Sort pages by last commit date (most recent first) by default.
    def <=>(other_page)
      other_page.commits.last.committed_date <=> commits.last.committed_date
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

      if sha == :filesystem
        url
      else
        "/#{short_sha(sha)}/#{id}"
      end
    end

    # Contents of "file" (Blob) at the specified path under this Content.
    def /(file)
      build_file_index
      @files[commit_id.to_sym][file] or raise Gaucho::FileNotFound.new(file)
    end

    # Show content from local filesyste. Note: git ignores untracked files,
    # so git add must be used on new files.
    def show_local_mods
      if options[:check_local_mods]
        @shown.nil? && has_local_mods
      else
        false
      end
    end

    # Does this Page have local, uncommitted modifications?
    def has_local_mods
      return @has_local_mods unless @has_local_mods.nil?
      @has_local_mods = repo.has_local_mods(id)
    end

    # Pass-through all other methods to the underlying metadata object.
    def method_missing(name, *args)
      meta.send(name, *args) if meta.respond_to?(name)
    end

    private
      # Build page metadata from index asset.
      def build_metadata
        #pp 'BUILDING METADATA'

        begin
          if show_local_mods
            # Iterate over files.
            root = File.join(repo.repo_path, id)
            index = Gaucho::Config.new
            index.name = Dir.entries(root).find {|file| file =~ /^index\./}
            index.data = IO.read(File.join(root, index.name))
          else
            # Iterate over Blobs.
            tree = repo.pages_tree(shown)/id
            index = tree.blobs.find {|blob| blob.name =~ /^index\./}
          end
        rescue
          raise Gaucho::PageNotFound
        end

        raise Gaucho::PageNotFound unless index.data

        docs = []
        YAML.each_document(index.data) {|doc| docs << doc} rescue nil
        docs = [{}, index.data] unless docs.length == 2
        @meta = Gaucho::Config.new(docs.first)
        @meta.index_name = index.name
        
        # meta.excerpt is anything before <!--more-->, meta.content is everything.
        parts = docs.last.split(/^\s*<!--\s*more\s*-->\s*$/im)
        @meta.excerpt = parts[0]
        @meta.content = parts.join('')
      end

      # Build page sub-file index at the current treeish.
      def build_file_index
        @files ||= {}
        key = commit_id.to_sym
        return if @files[key]

        start_time = Time.now
        @files[key] = {}

        if show_local_mods
          # Iterate over all files, recursively.
          root = File.join(repo.repo_path, id)
          Find.find(root) do |path|
            if !FileTest.directory?(path) && !File.basename(path).start_with?('.')
              if path =~ Regexp.new("^#{root}/(.*)")
                #pp [$1]
                @files[key][$1] = IO.read(path)
              end
            end
          end
        else
          # Parse the raw output from git ls-tree.
          text = repo.git.native(:ls_tree, {:r => true, :t => true}, commit_id, id)
          text.split("\n").each do |line|
            thing = repo.tree.content_from_string(repo.repo, line)
            if thing.kind_of?(Grit::Blob) && !File.basename(thing.name).start_with?('.')
              if thing.name =~ Regexp.new("^#{id}/(.*)")
                #pp [$1, thing.data.length]
                @files[key][$1] = thing.data
              end
            end
          end
        end
        pp "BUILT FILE INDEX IN #{Time.now - start_time} SEC"
      end
  end
end