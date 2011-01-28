module Gaucho
  class Content
    include Gaucho::ShortSha
    attr_reader :repo, :name, :commits, :contents, :meta, :treeish

    def initialize(repo, name, treeish = nil)
      @repo = repo
      @name = name
      self.treeish = treeish
    end

    # Pretty inspection.
    def inspect
      %Q{#<Gaucho::Content "#{commit.short_sha}" "#{name}" "#{url}">}
    end

    # Filesystem path in the repo for this Content.
    def path
      repo.subdir ? File.join(repo.subdir, name) : name
    end

    # Blob or Tree at the specified path under this Content.
    def /(file)
      contents[file]
    end

    # The treeish (commit, branch, etc) at which to view this Content.
    def treeish=(treeish = nil)
      if treeish == repo.fs_treeish
        @treeish = treeish
      else
        treeish = repo.default_branch if treeish.nil?
        raise StandardError, %Q{content "#{name}" @ treeish "#{treeish}" not found} if commit(treeish).nil?
        @treeish = treeish
      end
      parse
    end

    # If set, load all content from the local filesystem instead of from Git.
    # Use this in development to keep from having to commit in order to see
    # your changes!
    def use_fs
      @treeish == repo.fs_treeish
    end

    # The full SHA for the commit at which this Content is being viewed.
    def id
      commit.id
    end

    # URL for this Content at the current treeish.
    def url(treeish = nil)
      p = if treeish.class == Gaucho::Commit
        treeish.short_sha
      elsif use_fs
        repo.fs_treeish
      else
        commit(treeish).short_sha
      end
      "/#{p}/#{name}"
    end

    # Canonical URL for this Content.
    def url_canonical
      "/#{name}"
    end

    # Content as raw data. Probably not very useful.
    def to_s
      meta.raw
    end

    # All Commit objects for this Content.
    def commits
      commits = repo.repo.log(nil, path)
      Gaucho::Commit.commits(self, commits)
    end

    # The selected Commit object.
    def commit(treeish = nil)
      treeish = @treeish if treeish.nil?
      treeish = nil if use_fs # TODO: fake a first commit if use_fs?
      commits = repo.repo.log(treeish, path)
      Gaucho::Commit.commits(self, commits).first
    end

    private
      # Parse metadata from index file as well as a hash of "file" Blobs.
      def parse
        @meta = nil
        construct_file_index
        raise StandardError, %Q{content "#{name}" index not found} if meta.nil?
      end

      # Build a hash of all files, and their contents, recursively for this
      # Content, at the current treeish. If treeish is false, pull filenames
      # and data directly off the filesystem.
      def construct_file_index
        @contents = {}

        if use_fs
          # Iterate over all files, recursively.
          root = File.join(repo.repo_path, path)
          Find.find(root) do |path|
            if !FileTest.directory?(path) && !File.basename(path).start_with?('.')
              if path =~ Regexp.new("^#{root}/(.*)")
                construct_contents($1, IO.read(path))
              end
            end
          end
        else
          # Parse the raw output from git ls-tree.
          text = repo.repo.git.native(:ls_tree, {:r => true, :t => true}, @treeish, path)
          text.split("\n").each do |line|
            thing = repo.repo.tree.content_from_string(repo.repo, line)
            if thing.kind_of?(Grit::Blob) && !File.basename(path).start_with?('.')
              if thing.name =~ Regexp.new("^#{path}/(.*)")
                construct_contents($1, thing.data)
              end
            end
          end
        end
      end

      # Build content hash from file names and data.
      def construct_contents(name, data)
        pp [name, data.length]
        @contents[name] = data

        # Parse the "index" Blob into Content metadata.
        if name =~ /^index\./
          docs = []
          YAML.each_document(data) {|doc| docs << doc} rescue nil
          docs = [{}, data] unless docs.length == 2
          @meta = Gaucho::Config.new(docs.first)
          @meta.index = { name: name, data: docs.last }
        end
      end
  end
end
