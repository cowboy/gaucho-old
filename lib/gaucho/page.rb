module Gaucho
  class Page
    include ShortSha
    include StringUtils

    attr_reader :pageset, :id, :path, :commit, :shown, :files_last_modified

    def initialize(pageset, id, path, commit_ids)
      @pageset = pageset
      @id = id
      @path = path
      @commit_ids = commit_ids
      self.shown = nil
    rescue
      raise Gaucho::PageNotFound
    end

    def to_s
      %Q{#<Gaucho::Page "#{url}" "#{commit.id}">}
    end

    # Canonical URL for This Page. Replace any dashes and underscore in
    # leading date (YYYY_ or YYYY-MM_ or YYYY-MM-DD_) with slashes.
    def url
      parts = id.split ?_
      parts[0].gsub!(/-/, ?/) if parts[1]
      "/#{parts.join ?/}"
    end

    # Set the current Page to show the specified commit. Specifying nil
    # sets the view to the latest commit.
    def shown=(commit_id)
      @shown = commit_id

      @commit = nil
      if commit_id.nil?
        @meta = @files = @commits = nil if check_fs_mods?
      else
        @commit = commits.find {|commit| commit.id.start_with? commit_id}
      end

      @commit ||= commits.last
    end

    # Get all Commits for this Page. If the Page hasn't yet been committed or
    # it has local modifications, append a simulated Commit.
    def commits
      unless @commits
        @commits = @commit_ids.collect {|commit_id| Gaucho::Commit.new(self, commit_id)}
        if has_fs_mods?
          @commits << Gaucho::Commit.new(self)
        end
      end
      @commits
    end

    # The most recent actual (not simulated) commit for this Page.
    def latest_actual_commit
      commits.reverse.find {|commit| !commit.simulated?}
    end

    # Returns true if this Page's id matches the passed date. If no date is
    # passed, returns true if this Page's id begins with a date.
    def date?(date_arr = nil)
      if date_arr
        date_arr.split!(/\D+/) if date_arr.class == String
        id.start_with?("#{date_arr.join('-')}_")
      else
        !!%r{^\d{4}(?:-\d{2}){0,2}_}.match(id)
      end
    end

    # Metadata for the Page at the currently "shown" Commit, or from the index
    # file in the filesystem if shown_fs_mods? is true.
    def meta
      if shown_fs_mods?
        unless @meta
          index = Gaucho::Config.new
          index.name = Dir.entries(abs_page_path).find {|file| file =~ /^index\./}
          index.data = IO.read(File.join(abs_page_path, index.name))
          @meta = self.class.build_metadata(index)
        end
        @meta
      else
        commit.meta
      end
    end

    # File listing for the Page at the currently "shown" Commit, or from the
    # filesystem if shown_fs_mods? is true.
    def files
      if shown_fs_mods?
        @files
      else
        commit.files
      end
    end

    # Because page/'foo.txt' looks cooler than page.files['foo.txt'].
    def /(file)
      files[file] or raise Gaucho::FileNotFound.new(file)
    end

    # Either the last commit's committed date, or the most recent file last
    # modified time (or metadata-specified date) if shown_fs_mods? is true.
    def date
      if shown_fs_mods?
        commits.last.date
      else
        latest_actual_commit.date
      end
    end

    # Relative (to repo root) filesystem path for this Page.
    def page_path
      if pageset.subdir_path != ''
        File.join(pageset.subdir_path, id)
      else
        id
      end
    end

    # Absolute filesystem path for this Page.
    def abs_page_path
      File.join(pageset.abs_subdir_path, id)
    end

    # Has this page been committed yet?
    def committed?
      !@commit_ids.empty?
    end

    # Is the PageSet "check_fs_mods" option set?
    def check_fs_mods?
      pageset.check_fs_mods
    end

    # If check_fs_mods? is true and the shown commit is nil, check to see if the
    # local filesystem has modificiations by building a filesystem-based file
    # index and comparing it with the file index of the last Commit.
    def has_fs_mods?
      if check_fs_mods?
        build_file_index!
        !committed? || @files != latest_actual_commit.files
      end
    end

    # Are local modifications currently being shown?
    def shown_fs_mods?
      shown.nil? && has_fs_mods?
    end

    # Sort pages by last commit date (most recent first) by default.
    def <=>(other)
      other.date <=> date
    end

    # Pass-through all other methods to the underlying metadata object.
    def method_missing(*args)
      meta.public_send(*args)
    end

    # Parse metadata and content from a Page index file.
    def self.build_metadata(index = nil)
      raise Gaucho::PageNotFound unless index

      docs = []
      YAML.each_document(index.data) {|doc| docs << doc} rescue nil
      docs = [{}, index.data] unless docs.length == 2
      docs.first.each do |key, value|
        docs.first[key] = value.collect {|e| e.to_s} if value.class == Array
      end
      meta = Gaucho::Config.new(docs.first)
      meta.index_name = index.name

      # meta.excerpt is anything before <!--more-->, meta.content is everything
      # before + everything after.
      parts = docs.last.split(/^\s*<!--\s*more\s*-->\s*$/im)
      meta.excerpt = parts[0]
      meta.content = parts.join('')

      meta
    end

    protected

    # Build page file index from filesystem.
    def build_file_index!
      return if @files

      @files = {}
      @files_last_modified = nil

      # Iterate over all files, recursively.
      Find.find(abs_page_path) do |path|
        if !FileTest.directory?(path) && !File.basename(path).start_with?('.')
          if path =~ %r{^#{abs_page_path}/(.*)}
            @files_last_modified = [@files_last_modified, File.new(path).mtime].compact.max
            @files[$1] = fix_encoding(IO.read(path))
          end
        end
      end
    end
  end
end