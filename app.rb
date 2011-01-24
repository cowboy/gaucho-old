require 'sinatra'
require 'grit'
require 'haml'
require 'rdiscount'

require 'mime/types'
require 'pp'

$:.unshift(File.join(File.dirname(__FILE__),'lib'))
require 'page'
require 'page_render'

Page.repo = File.expand_path('../db1')

not_found do
  '<h1>OMG 404</h1>' + ' ' * 512
end

# /id
# /sha/id
# /id/asset.ext
# /sha/id/asset.ext
get %r{^(?:/([0-9a-f]{6,40}))?(?:/([-\w]+))(?:/(.+\..+))?$} do |sha, id, asset|
  pp({sha: sha, id: id, asset: asset})
  begin
    @page = Page.new(id, sha)
    #pp @page
    if asset.nil?
      #pp @page.history
      @title = @page.meta[:title]
      @content = @page.to_html
      haml :page
    else
      @page.assets[asset]
    end
  rescue Exception => e
    #raise e
    pp e
    pass
  end
end
