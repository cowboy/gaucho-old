require 'sinatra'
require 'grit'
require 'haml'
require 'rdiscount'

require 'mime/types'
require 'pp'

$:.unshift(File.join(File.dirname(__FILE__),'lib'))
require 'git_site'

Page.repo = File.expand_path('../db1')

set :haml, format: :html5, attr_wrapper: '"'
enable :inline_templates

#GitSite.repo = File.expand_path('../db1')
#pp GitSite.categories

not_found do
  '<h1>OMG 404</h1>' + ' ' * 512
end

# BLOB
# /{sha}/{file}
get %r{^/([0-9a-f]{7})/(.+)$} do |sha, file|
  pp ['blob', params[:captures]]
  content_type File.extname(file) rescue content_type :txt
  Page.data_for_sha(sha)
  # TODO: cache heavily
end

# PAGE
# /{name}
# /{name}/{sha}
get %r{^/([-\w]+)(?:/([0-9a-f]{7}))?$} do |name, sha|
  pp ['page', params[:captures]]
  begin
    @page = Page.new(name, sha)
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
