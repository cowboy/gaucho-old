require 'grit'
require 'yaml'
require 'page_grit'
require 'config_obj'

# Page
#   .repo=          Set repo path
#   .options        Set repo options
#
# page
#   .id             The current page id
#   .meta           Hash of metadata from meta.yaml
#   .commit         Commit being currently viewed
#   .commits        All commits (array of "commit", newest -> oldest)
#   .sha            Get abbreviated SHA
#   .assets         Hash of assets { name => contents, ... }
#   .index          Name of index asset
#   .to_html        Rendered page content
#   .url            URL of the page at the current commit
#   .url_canonical  Canonical URL of the page
#   .url_asset      URL of the asset at the current commit
#
# commit
#   .latest?        Is the commit the latest commit for this page?
#   .current?       Is the commit the currently-viewed commit
#
# diff

class Page
  attr_reader :id
  attr_reader :meta
  attr_reader :commit
  attr_reader :commits
  attr_reader :assets

  def initialize(id, sha = nil)
    pp '=== INIT ==='
    @id = id

    # Get current commit (the one being viewed).
    @commit = @@repo.log(sha, path).first
    raise ArgumentError, "Invalid page id or sha specified" if @commit.nil?

    extend_commit!(@commit)

    # Get all commits for this page.
    @commits = @@repo.log(@@options[:default_branch], path)
    @commits.each {|commit| extend_commit!(commit)}

    # All assets for the current page.
    @assets = {}
    (@commit.tree/path).blobs.each do |blob|
      unless blob.name.start_with?('.') || parse_meta(blob)
        @assets[blob.name] = blob.data
      end
    end

    raise StandardError, "Unable to find page index" if index.nil?
    #raise StandardError, "Unable to load page metadata" if @meta.nil?
  end

  # Get this page's HTML (overridden in page_render.rb).
  def to_html
    @assets[index]
  end

  # Get path of the index asset.
  def index
    @assets.keys.find { |k| k =~ /^index\./ }
  end

  # Get URL for current page or current page + asset, including commit sha.
  def url(options = {})
    parts = ['']

    # Canonical URL never includes the SHA
    unless options[:canonical]
      if options[:sha]
        # A specific SHA was passed into this method.
        parts << sha(options[:sha])
      elsif !@commit.latest?
        # A specific SHA was passed in Page.new.
        parts << @commit.sha
      end
    end

    parts << @id
    parts << options[:asset_path] unless options[:asset_path].nil?
    File.join(*parts)
  end

  # Get canonical URL.
  def url_canonical(options = {})
    url(options.update({canonical: true}))
  end

  # Get asset URL.
  def url_asset(asset_path, options = {})
    url(options.update({asset_path: asset_path}))
  end

  # We don't REALLY need all 40 chars of the SHA.
  def sha(sha = nil)
    if sha
      commit = extend_commit!(@@repo.log(sha, path).first)
      commit.sha unless commit.nil?
    else
      @commit.sha
    end
  end

  # Get path from the DB root of current page or current page + asset.
  def path(asset_path = nil)
    parts = [@@options[:subdir], @id]
    parts << asset_path unless asset_path.nil?
    File.join(*parts)
  end

  private

  # Parse metadata out of meta.yaml file.
  def parse_meta(blob)
    if blob.name =~ /^meta.ya?ml$/
      @meta = ConfigObj.new(YAML.load(blob.data))
    end
  end

  class << self
    # Initialize repo.
    def repo=(repo_path, options = {})
      @@repo_path = repo_path
      @@repo = Grit::Repo.new(repo_path)
    end

    # Get repo. (remove?)
    def repo
      @@repo
    end

    # Default options.
    @@options = {
      default_branch: 'master',
      subdir: 'pages',
    }

    # Update options (if necessary).
    def options=(options = {})
      @@options.update(options)
    end
  end
end
