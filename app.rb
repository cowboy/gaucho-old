require 'delegate'
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
#repo = Gaucho::Repo.new(File.expand_path('../db/test'), subdir: false)

not_found do
  "<h1>OMG 404</h1>#{' '*512}"
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
=end

module Gaucho
  class << self
    attr_accessor :repo, :repo_path
  end

  def self.new(repo_path)
    self.repo_path = repo_path
    self.repo = Grit::Repo.new(repo_path)
    
    App
  end
  
  class PageNotFound < Sinatra::NotFound
  end
  
  class FileNotFound < Sinatra::NotFound
    def initialize(name)
      #p "FileNotFound: #{name}"
    end
  end
  
  class App < Sinatra::Base
    helpers do
      def date_format(date)
        #ugly = date.strftime('%a, %d %b 1970 00:00:00 GMT-0400')
        ugly = date.strftime('%s')
        pretty = date.strftime('%b %e, %Y at %l:%M%P')
        %Q{<span data-date="#{ugly}">#{pretty}</span>}
      end
      def page_commit_link(page, commit = nil)
        %Q{<a href="#{page.url_at_commit(commit)}">#{commit.id[0..6]}</a>}
      end
      def tag_url(tag)
        "/content-tagged-#{tag}"
      end
      def cat_url(cat)
        "/categorized-as-#{cat}"
      end
    end

    not_found do
      "<h1>OMG 404</h1>#{' '*512}"
    end

    get %r{^(?:/(__fs__|[0-9a-f]{7}))?/?$} do |sha|
      pp ['content', params[:captures]]
      #start_time = Time.now
      @pages = Gaucho::Page.all(sha)
      #pp "Time: #{Time.now - start_time}"
      @tags = @pages.collect {|c| c.tags}.flatten.uniq.sort
      @cats = @pages.collect {|c| c.categories}.flatten.uniq.sort
      @pages.sort! {|a,b| b.commits.last.committed_date <=> a.commits.last.committed_date}
      haml :index
    end

    # PAGE
    # /{name}
    # /{sha}/{name}
    # /{sha}/{name}/{file}
    # /__fs__/{name}
    # /__fs__/{name}/{file}
    get %r{^(?:/(__fs__|[0-9a-f]{7}))?/([-\w]+)(?:/(.+))?$} do |sha, name, file|
      pp ['content', params[:captures]]
      begin
        if file
          content_type File.extname(file) rescue content_type :txt
          (Gaucho::Page.parent_tree(sha)/name/file).data
          #Gaucho::Page.new(name, sha)/file#slower
        else
          @page = Gaucho::Page.new(name, sha)
          @commit = Gaucho::Commit.commit(@page, @page.commit)
          @commits = Gaucho::Commit.commits(@page, @page.commits)
          @title = @page.title
          #color = "%06x" % (rand * 0xffffff)
          #{}"<h1 style='color:##{color}'>#{Time.now.strftime('%b %e, %Y at %l:%M:%S %P')}</h1>" +
          @content = @page.render
          haml :page
        end
      #rescue
      #  raise Sinatra::NotFound
      end
    end

  end

end

#app = Gaucho.new(File.expand_path('../db/test'))
#app.commits



