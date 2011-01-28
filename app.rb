require 'sinatra'
require 'grit'
require 'haml'
require 'rdiscount'

require 'mime/types'
require 'pp'

require './lib/gaucho'

set :haml, format: :html5, attr_wrapper: '"'
enable :inline_templates

=begin
# Redefine Content/Asset URLs if necessary.
module Gaucho
  class Content
    def url
      commit.latest? ? canonical : permalink
    end
    def canonical
      "/#{name}"
    end
    def permalink
      "/#{name}/#{commit.short_sha}"
    end
  end
  class Asset
    def url
      "/#{short_sha}/#{name}"
    end
  end
end
=end
#Grit.debug = true
repo = Gaucho::Repo.new(File.expand_path('../db/test'), subdir: false)

not_found do
  "<h1>OMG 404</h1>#{' '*512}"
end

=begin
# BLOB
# /{sha}/{file}
get %r{^/([0-9a-f]{7})/(.+)$} do |sha, file|
  pp ['blob', params[:captures]]
  blob = repo.blob(sha)
  if blob.nil?
    pass
  else
    content_type File.extname(file) rescue content_type :txt
    blob.data
    # TODO: cache heavily
  end
end

# PAGE
# /{name}
# /{name}/{sha}
get %r{^/([-\w]+)(?:/([0-9a-f]{7}))?$} do |name, sha|
  pp ['page', params[:captures]]
  begin
    @page = repo.content(name, sha)
    pp @page
    @page.to_html
    #@title = @page.meta[:title]
    #@content = @page.to_html
    #haml :page
  rescue Exception => e
    #raise e
    pp e
    pass
  end
end
=end

helpers do
  def date_format(date)
    #ugly = date.strftime('%a, %d %b 1970 00:00:00 GMT-0400')
    ugly = date.strftime('%s')
    pretty = date.strftime('%b %e, %Y at %l:%M%P')
    %Q{<span data-date="#{ugly}">#{pretty}</span>}
  end
  def tag_url(tag)
    "/content-tagged-#{tag}"
  end
  def cat_url(cat)
    "/categorized-as-#{cat}"
  end
end

# INDEX
# /
get '/' do
  @contents = repo.contents
  @recent_contents = @contents.sort do |a, b|
    b.commit.committed_date <=> a.commit.committed_date
  end
  @tags = @contents.collect {|c| c.meta.tags}.flatten.uniq.sort
  @categories = []#@contents.each{|c| c.meta.categories }.flatten.uniq
  haml :index
end

# TAGS
# /content-tagged-{tag}
get %r{^/content-tagged-([-\w]+)} do |tag|
  pp ['tag', params[:captures]]
  @contents = repo.contents.select {|c| c.meta.tags.include?(tag)}
  pp @contents
  tag
end

# RECENT
# /recent-changes

# PAGE
# /{name}
# /{sha}/{name}
# /{sha}/{name}/{file}
# /__fs__/{name}
# /__fs__/{name}/{file}
get %r{^(?:/(__fs__|[0-9a-f]{7}))?/([-\w]+)(?:/(.+))?$} do |sha, name, file|
  pp ['content', params[:captures]]
  begin
    @content = repo.content(name, sha)
    if file
      content_type File.extname(file) rescue content_type :txt
      @content/file
    else
      @title = @content.meta.title
      @rendered = @content.render # render content
      haml :content
    end
    # cache heavily if sha was passed and no failure
  #rescue Exception => e
    #pp e
    #pass
  end
end

=begin
#Grit.debug = true
content = repo.content('c', '680d7c8')
content.commit.diffs.each do |diff|
  pp diff.diff.diff
end

p '========================'
c = repo.content('c')
pp c.commits
p '========================'
c = repo.content('c', '__fs__')
pp c.commits

c = repo.content('c', '680d7c8')
pp c.treeish
pp c.id
pp c.short_sha

pp Gaucho::Renderer.filter_map
c = repo.content('c', '680d7c8')
pp c
pp c.contents
pp c.commits

c = repo.content('a','90cc550')
pp c
pp c.index
pp c/'index.md'
pp c/'test.txt'
pp c/'foo/'
pp c/'foo/a.txt'
#pp (c/'foo/a.txt').name
pp c/'foo/b.txt'
pp c/'bar/b.txt'
pp c/'bar/c.txt'
#c.commits.each {|commit| pp commit; pp commit.diffs}

#pp repo.content('c').files
=end
=begin
repo = Gaucho::Repo.new(File.expand_path('../db1'), subdir: 'pages')

b = repo.blob('0364790')
pp b
pp b.data
pp repo.blob('9999999')
pp '==='
content = repo.content('c', '6fa70c2')
pp content.url
pp repo.contents
pp '==='
#pp content.commits
pp content
pp content.commits.length
pp content.commit
pp content.commit.latest?
pp content.commit.diffs
pp content.commit('680d7c8')
pp content.commit('680d7c8').diffs
pp '==='
content.pointer = '680d7c8'
pp content
pp content.commit
pp content.commit.latest?
pp content.commit.diffs
pp content.meta
pp '==='
content.pointer = nil
pp content
pp content.commit
pp content.commit.latest?
pp content.commit.diffs
pp content.meta
pp content.assets
pp content.index
=end