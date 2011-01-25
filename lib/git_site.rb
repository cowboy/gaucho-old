require 'grit'
require 'yaml'

# 7-character SHAs should be long enough.
module ShortSha
  def short_sha
    id[0..6]
  end
end

=begin
  class << self
    def categories
      pages.each do |page|
        pp page.meta
      end
    end
  end
=end

class Page
  attr_reader :name, :commits

  def initialize(name, commit_id = nil) #TODO: CHANGE TO TREEISH?
    @name = name
    @commit_id = commit_id

    raise StandardError, "Unable to find page index" if index.nil?
    #raise StandardError, "Unable to load page metadata" if meta.nil?
  end

  # Pretty inspection.
  def inspect
    %Q{#<Page "#{commit.short_sha}" "#{name}" "#{url}">}
  end

  # Filesystem path in the repo for this Page.
  def path
    File.join(subdir, name)
  end

  # The commit (branch, etc) that this Page's should reflect.
  def pointer=(commit_id)
    raise StandardError, "Invalid pointer for this page" if commit(commit_id).nil?
    @commit_id = commit_id
  end

  # Git tree for this Page.
  def tree
    commit.tree/path
  end

  # Page assets.
  def assets
    PageAsset.assets(self, tree.blobs)
  end

  # URL for this page.
  def url
    if commit.latest?
      canonical
    else
      permalink
    end
  end

  # Canonical URL for this page. TODO: define in global config.
  def canonical
    "/#{name}"
  end

  # Permalink URL for this page. TODO: define in global config.
  def permalink
    "/#{name}/#{commit.short_sha}"
  end

  # The "index" PageAsset for this Page.
  def index
    assets.find {|asset| asset.name =~ /^index\./}
  end

  # Page metadata, including the raw index file content.
  def meta
    docs = []
    YAML.each_document(index.data) {|doc| docs << doc} rescue nil
    docs = [{}, index.data] unless docs.length == 2
    meta = ConfigObj.new(docs.first)
    meta.raw = docs.last
    meta
  end

  # This gets overridden :)
  def to_html
    meta.raw
  end

  # All PageCommit objects for this Page.
  def commits
    commits = repo.log(nil, path)
    PageCommit.commits(self, commits)
  end

  # The selected PageCommit object.
  def commit(commit_id = @commit_id)
    commits = repo.log(commit_id, path)
    PageCommit.commits(self, commits).first
  end

  # Instance accessors for class variables.
  def repo; @@repo; end
  def branch; @@branch; end # TODO: USE
  def subdir; @@subdir; end

  class << self
    def repo=(path)
      @@repo = Grit::Repo.new(path)
      @@branch = 'master'
      @@subdir = 'pages'
    end

    def repo; @@repo; end
    def branch; @@branch; end
    def subdir; @@subdir; end

    # All Page objects.
    def pages
      (repo.tree/subdir).trees.collect do |tree|
        Page.new(tree.name)
      end
    end
    
    # Utility methods
    def data_for_sha(sha)
      repo.git.native(:show, {raise: true}, sha)
    end

    def full_sha(sha)
      repo.git.native(:rev_parse, {raise: true}, sha) rescue nil
    end
  end

  class PageAsset
    include ShortSha
    attr_reader :blob, :page

    def initialize(page, blob)
      @page = page
      @blob = blob
    end

    # Pretty inspection.
    def inspect
      %Q{#<PageAsset "#{short_sha}" "#{name}" "#{url}">}
    end

    # URL for this asset. TODO: define in global config.
    def url
      "/#{short_sha}/#{name}"
    end

    # Pass-through all methods to the underlying Grit::Blob instance.
    def method_missing(name, *args)
      blob.send(name, *args) if blob.respond_to?(name)
    end

    class << self
      # Get an array of PageAsset instances.
      def assets(page, blobs)
        blobs.collect {|blob| self.new(page, blob)}.compact
      end
    end
  end

  class PageCommit
    include ShortSha
    attr_reader :commit, :page, :diffs

    def initialize(page, commit)
      @page = page
      @commit = commit
      @diffs = PageDiff.diffs(page, commit.diffs)
    end

    # Pretty inspection.
    def inspect
      %Q{#<PageCommit "#{short_sha}" "#{committed_date}" "#{short_message}">}
    end

    # Is this commit the most recent commit for the Page?
    def latest?
      id == page.commits.first.id
    end

    # Is this commit the currently pointed-to commit for the Page?
    def pointer?
      id == page.commit.id
    end

    # Pass-through all methods to the underlying Grit::Commit instance.
    def method_missing(name, *args)
      commit.send(name, *args) if commit.respond_to?(name)
    end

    class << self
      # Get an array of PageCommit instances.
      def commits(page, commits)
        commits.collect {|commit| self.new(page, commit)}.compact
      end
    end
  end

  class PageDiff
    attr_reader :diff, :page, :name, :created, :deleted, :contents

    def initialize(page, diff)
      @page = page
      @diff = diff
    end

    # Pretty inspection.
    def inspect
      status = created? ? 'created' : deleted? ? 'deleted' : 'updated'
      %Q{#<PageDiff "#{name}" "#{status}">}
    end

    # Filename for this diff.
    def name
      diff.a_path.sub(Regexp.new("^#{page.path}/(.*)"), '\1')
    end

    # Short method names for accessing the diff's methods.
    def created?; diff.new_file; end
    def deleted?; diff.deleted_file; end
    def contents; diff.diff; end

    class << self
      # Return a PageDiff instance if the diff in question is relevant to
      # the current page, otherwise nil.
      def diff(page, diff)
        path = File.join(page.path, '')
        self.new(page, diff) if diff.a_path.start_with? path
      end

      # Get an array of PageDiff instances.
      def diffs(page, diffs)
        diffs.collect {|diff| self.diff(page, diff)}.compact
      end
    end
  end
end

# More friendly looking dot-syntax access for hash keys.
# http://mjijackson.com/2010/02/flexible-ruby-config-objects

class ConfigObj
  def initialize(data={})
    @data = {}
    update!(data)
  end

  def update!(data)
    data.each {|key, value| self[key] = value}
  end

  def [](key)
    @data[key.to_sym]
  end

  def []=(key, value)
    if value.class == Hash
      @data[key.to_sym] = self.class.new(value)
    else
      @data[key.to_sym] = value
    end
  end

  def method_missing(name, *args)
    if name.to_s =~ /(.+)=$/
      self[$1] = args.first
    else
      self[name]
    end
  end

  def responds_to?(name)
    false
  end

  def inspect
    @data
  end
end

=begin
Page.repo = File.expand_path('../db1')

page = Page.new('c', '6fa70c2')
pp page.url
pp Page.pages
pp '==='
#pp page.commits
pp page
pp page.commits.length
pp page.commit
pp page.commit.latest?
pp page.commit.diffs
pp page.commit('680d7c8')
pp page.commit('680d7c8').diffs
pp '==='
page.pointer = '680d7c8'
pp page
pp page.commit
pp page.commit.latest?
pp page.commit.diffs
pp page.meta
pp '==='
page.pointer = nil
pp page
pp page.commit
pp page.commit.latest?
pp page.commit.diffs
pp page.meta
pp page.assets
pp page.index
=end