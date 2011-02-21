# A wrapper for Grit::Commit
module Gaucho
  class Commit
    include ShortSha
    include StringUtils
    extend Forwardable

    attr_reader :page, :pageset
    
    # Forward Commit methods to @commit (via the commit method) so that this
    # class feels as Grit::Commit-like as possible.
    def_delegators :commit, *Grit::Commit.public_instance_methods(false)

    def initialize(page, commit_id = nil)
      @page = page
      @pageset = page.pageset
      @commit_id = commit_id
    end

    def to_s
      s = shown? ? '*' : ''
      %Q{#<Gaucho::Commit#{s} "#{url}" "#{committed_date}" "#{short_message}">}
    end

    # Use a shortened SHA for the id, fabricating one if necessary.
    def id
      if simulated?
        'simulated'
      else
        short_sha(@commit_id)
      end
    end

    # URL for the page at this Commit. If the commit is simulated, omit the id
    # from the URL.
    def url
      if simulated?
        page.url
      else
        %Q{/#{id}#{page.url}}
      end
    end

    # If a commit_id wasn't passed, this commit is simulated. This should only
    # be used when a new Page, with no commits, is being previewd from the
    # filesystem, using check_fs_mods.
    def simulated?
      @commit_id.nil?
    end

    # Is this commit the most recent actual (not simulated) commit for the Page?
    def latest?
      self == page.latest_actual_commit
    end

    # Is this commit the currently shown commit for the Page?
    def shown?
      self == page.commit
    end
    
    # Metadata for the Page at this Commit, parsed from "file" (Grit::Blob)
    # named "index.___". If the commit is simulated, create an empty metadata
    # object so that things don't break.
    def meta
      @meta ||= if simulated?
        Gaucho::Config.new
      else
        index = tree.blobs.find {|blob| blob.name =~ /^index\./}
        page.class.build_metadata(index)
      end
    end

    # Contents of "file" (Grit::Blob) at the specified path under the Page at
    # this Commit.
    def /(file)
      files[file] or raise Gaucho::FileNotFound.new(file)
    end

    # The author of this Commit. A specified metadata "author" will be used
    # first, with a fallback to the actual Grit::Commit committer (Grit::Actor).
    def author
      if meta.author.nil?
        commit.committer
      else
        Grit::Actor.from_string(meta.author)
      end
    end

    # The date of this Commit. A specified metadata "date" will be used first,
    # with a fallback to the actual Grit::Commit committed_date.
    def date
      if meta.date.nil? || meta.date.empty?
        commit.committed_date
      else
        Time.parse(meta.date)
      end
    end

    # The underlying Grit::Commit instance for this Commit. If this commit is
    # simulated, create a completely fabricated Grit::Commit instance.
    def commit
      @commit ||= if simulated?
        sha = 'f' * 40
        actor = Grit::Actor.from_string('John Q. Author')
        time = page.files_last_modified
        Grit::Commit.new(pageset.repo, sha, [sha], sha, actor, time, actor, time,
          %w{This commit is simulated!})
      else
        pageset.repo.commit(@commit_id)
      end
    end

    # The Grit::Commit message, with its encoding "fixed."
    def message
      fix_encoding(commit.message)
    end

    # The Grit::Tree instance representing the Page at this Commit.
    def tree
      @tree ||= if pageset.subdir
        commit.tree/pageset.subdir/page.id
      else
        commit.tree/page.id
      end
    end

    # All the diffs for this Commit relevant to the Page.
    def diffs
      @diffs ||= build_diffs
    end

    # Hash of all "file" (Grit::Blob) objects under the Page at this Commit.
    def files
      @files ||= build_file_index
    end
    
    protected

    # Build an array of Gaucho::Diff instances that are relevant to the
    # Page. at this Commit.
    def build_diffs
      diffs = commit.show.collect do |diff|
        Gaucho::Diff.new(self, diff) if Gaucho::Diff.is_diff_relevant(diff, page)
      end
      diffs.compact
    end

    # Build "file" (Grit::Blob) index for the Page at this Commit.
    def build_file_index
      files = {}

      # Parse the raw output from git ls-tree.
      text = pageset.repo.git.native(:ls_tree, {:r => true, :t => true}, @commit_id, page.page_path)
      text.split("\n").each do |line|
        thing = pageset.tree.content_from_string(pageset.repo, line)
        if thing.kind_of?(Grit::Blob) && !File.basename(thing.name).start_with?('.')
          if thing.name =~ %r{^#{page.page_path}/(.*)}
            files[$1] = fix_encoding(thing.data)
          end
        end
      end
      
      files
    end
  end
end
