module Gaucho
  class Page
    include ShortSha

    attr_reader :repo, :id, :tree, :commits, :commit, :shown

    def initialize(repo, id, commit_ids)
      @repo = repo
      @id = id
      @tree = repo.tree/id
      @commits = commit_ids.collect {|commit_id| Gaucho::Commit.new(self, commit_id)}
      self.shown = nil
    end

    # Pretty inspection.
    def inspect
      %Q{#<Gaucho::Page "#{url}" "#{commit.id}">}
    end

    # Canonical URL for this Page. Replace any dashes in leading YYYY-,
    # YYYY-MM- or YYYY-MM-DD- with slashes.
    def url
      url = id.sub(%r{^(\d{4}(?:-\d{2}){0,2}-)}) {|d| d.gsub('-', '/')}
      "/#{url}"
    end

    # Set the current Page to show the specified commit. Specifying nil
    # sets the view to the latest commit.
    def shown=(commit_id)
      @shown = commit_id

      @commit = nil
      unless commit_id.nil?
        @commit = commits.find {|commit| commit.id.start_with? commit_id}
      end

      @commit ||= commits.last
    end

    # Returns true if this Page's id matches the passed date. If no date is
    # passed, returns true if this Page's id begins with a date.
    def date?(date_arr = nil)
      if date_arr
        date_arr.split!(%r{[/-]}) if date_arr.class == String
        id.start_with?("#{date_arr.join('-')}-")
      else
        !!%r{^\d{4}-(?:\d{2}-){0,2}\D}.match(id)
      end
    end

    # Metadata for the Page at the currently "shown" Commit, or from the index
    # file in the filesystem if shown_local_mods? is true.
    def meta
      if shown_local_mods?
        unless @meta
          root = File.join(repo.repo_path, id)
          index = Gaucho::Config.new
          index.name = Dir.entries(root).find {|file| file =~ /^index\./}
          index.data = IO.read(File.join(root, index.name))
          @meta = self.class.build_metadata(index)
        end
        @meta
      else
        commit.meta
      end
    end

    # File listing for the Page at the currently "shown" Commit, or from the
    # filesystem if shown_local_mods? is true.
    def files
      if shown_local_mods?
        @files
      else
        commit.files
      end
    end

    # Because page/'foo.txt' looks cooler than page.files['foo.txt'].
    def /(file)
      files[file] or raise Gaucho::FileNotFound.new(file)
    end

    # Enable checking for local modifications. Calling this will also clear the
    # internal local modifications file and metadata caches.
    def check_local_mods(state = true)
      @check_local_mods = state
      @meta = nil
      @files = nil
    end

    # If the Repo "check_fs" option is set and the shown commit is nil, check to
    # see if the local filesystem has modificiations by building a filesystem-
    # based file index and comparing it with the file index of the last Commit.
    def has_local_mods?
      if @check_local_mods
        @files ||= build_file_index
        @files != commits.last.files
      end
    end

    # Are local modifications currently being shown?
    def shown_local_mods?
      shown.nil? && has_local_mods?
    end

    # Sort pages by last commit date (most recent first) by default.
    def <=>(other)
      other.commits.last.committed_date <=> commits.last.committed_date
    end

    # Pass-through all other methods to the underlying metadata object.
    def method_missing(name, *args)
      meta.send(name, *args) if meta.respond_to?(name)
    end

    # Parse metadata and content from a Page index file.
    def self.build_metadata(index)
      raise Gaucho::PageNotFound unless index.data

      docs = []
      YAML.each_document(index.data) {|doc| docs << doc} rescue nil
      docs = [{}, index.data] unless docs.length == 2
      meta = Gaucho::Config.new(docs.first)
      meta.index_name = index.name

      # meta.excerpt is anything before <!--more-->, meta.content is everything
      # before + everything after.
      parts = docs.last.split(/^\s*<!--\s*more\s*-->\s*$/im)
      meta.excerpt = parts[0]
      meta.content = parts.join('')

      meta
    end

    private

      # Build page file index from filesystem.
      def build_file_index
        files = {}

        # Iterate over all files, recursively.
        root = File.join(repo.repo_path, id)
        Find.find(root) do |path|
          if !FileTest.directory?(path) && !File.basename(path).start_with?('.')
            if path =~ Regexp.new("^#{root}/(.*)")
              files[$1] = IO.read(path)
            end
          end
        end

        files
      end
  end
end