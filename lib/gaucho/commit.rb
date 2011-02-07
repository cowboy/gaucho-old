# A wrapper for Grit::Commit
module Gaucho
  class Commit
    include ShortSha

    attr_reader :page, :pageset

    def initialize(page, commit_id)
      @page = page
      @pageset = page.pageset
      @commit_id = commit_id
    end

    # Pretty inspection.
    def inspect
      s = shown? ? '*' : ''
      %Q{#<Gaucho::Commit#{s} "#{url}" "#{committed_date}" "#{short_message}">}
    end

    # Use a shortened SHA for the id.
    def id
      short_sha(@commit_id)
    end

    # URL for the page at this Commit.
    def url
      %Q{/#{id}#{page.url}}
    end

    # Is this commit the most recent commit for the Page?
    def latest?
      self == page.commits.last
    end

    # Is this commit the currently shown commit for the Page?
    def shown?
      self == page.commit
    end

    # Metadata for the Page at this Commit, parsed from "file" (Grit::Blob)
    # named "index.___"
    def meta
      unless @meta
        index = tree.blobs.find {|blob| blob.name =~ /^index\./}
        @meta = page.class.build_metadata(index)
      end
      @meta
    end

    # Contents of "file" (Grit::Blob) at the specified path under the Page at
    # this Commit.
    def /(file)
      files[file] or raise Gaucho::FileNotFound.new(file)
    end

    # The underlying Grit::Commit instance for this Commit.
    def commit
      @commit ||= pageset.commit(@commit_id)
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
    
    # Pass-through all other methods to the underlying Grit::Commit instance.
    def method_missing(name, *args)
      commit.send(name, *args) if commit.respond_to?(name)
    end

    private

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
        text = pageset.git.native(:ls_tree, {:r => true, :t => true}, @commit_id, page.page_path)
        text.split("\n").each do |line|
          thing = pageset.tree.content_from_string(pageset.repo, line)
          if thing.kind_of?(Grit::Blob) && !File.basename(thing.name).start_with?('.')
            if thing.name =~ %r{^#{page.page_path}/(.*)}
              files[$1] = thing.data
            end
          end
        end
        
        files
      end
  end
end
