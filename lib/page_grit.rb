class Page
  private
    # Extend a Grit::Commit with PageCommit.
    def extend_commit!(commit)
      commit.extend PageCommit
      commit.page = self
      commit
    end
end

# Used to extend Grit::Commit instances, as-needed.
module PageCommit
  # A list of diffs for this page, for this commit. Built in page=.
  attr_reader :diffs

  # Link the Page instance to this PageCommit instance.
  def page=(page)
    @page = page

    # Build diff list.
    @diffs = []
    path = File.join(@page.path, '')
    self.show.each do |diff|
      # Only add diffs that involve this page!
      if diff.a_path =~ Regexp.new("^#{path}(.*)")
        # Extend a Grit::Diff with PageDiff.
        diff.extend PageDiff
        diff.asset = $1
        diffs << diff
      end
    end
  end

  # Pretty inspection.
  def inspect
    %Q{#<PageCommit "#{sha}" "#{id}">}
  end

  # 40 character SHAs are kinda overkill.
  def sha
    return id[0..6]
  end

  # Is this commit the page's current commit?
  def current?
    true if id == @page.commit.id
  end

  # Is this commit the page's most recent commit?
  def latest?
    true if id == @page.commits.first.id
  end
end

# Used to extend Grit::Diff instances, as-needed.
module PageDiff
  # Just the asset filename, no path.
  attr_accessor :asset

  # Pretty inspection.
  def inspect
    %Q{#<PageDiff "#{@asset}">}
  end

  # Less typing.
  def created
    @created_file
  end

  # Less typing.
  def deleted
    @deleted_file
  end
end
