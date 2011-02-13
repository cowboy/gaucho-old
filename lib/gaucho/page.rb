module Gaucho
  class Page
    include ShortSha
    include StringUtils

    attr_reader :pageset, :id, :path, :tree, :commits, :commit, :shown

    def initialize(pageset, id, path, commit_ids)
      @pageset = pageset
      @id = id
      @path = path
      @tree = pageset.tree/id
      @commits = commit_ids.collect {|commit_id| Gaucho::Commit.new(self, commit_id)}
      self.shown = nil
    rescue
      raise Gaucho::PageNotFound
    end

    def to_s
      %Q{#<Gaucho::Page "#{url}" "#{commit.id}">}
    end

    # Canonical URL for this Page. Replace any dashes in leading YYYY-,
    # YYYY-MM- or YYYY-MM-DD- with slashes.
    def url
      url = path.sub(%r{^(\d{4}(?:-\d{2}){0,2}-)}) {|d| d.gsub('-', '/')}
      "/#{url}"
    end

    # Set the current Page to show the specified commit. Specifying nil
    # sets the view to the latest commit.
    def shown=(commit_id)
      @shown = commit_id

      @commit = nil
      if commit_id.nil?
        @meta = @files = nil if pageset.check_mods
      else
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

    # If the PageSet "check_mods" option is set and the shown commit is nil,
    # check to see if the local filesystem has modificiations by building a
    # filesystem-based file index and comparing it with the file index of the
    # last Commit.
    def has_local_mods?
      if pageset.check_mods
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
    def method_missing(*args)
      meta.public_send(*args)
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

    protected

    # Build page file index from filesystem.
    def build_file_index
      files = {}

      # Iterate over all files, recursively.
      Find.find(abs_page_path) do |path|
        if !FileTest.directory?(path) && !File.basename(path).start_with?('.')
          if path =~ %r{^#{abs_page_path}/(.*)}
            files[$1] = fix_encoding(IO.read(path))
          end
        end
      end

      files
    end
  end
end