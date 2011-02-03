require 'sinatra'

require 'grit'
require 'haml'
require 'mime/types'
require 'delegate'

require 'pp'
require 'profiler'

require './marshal_cache'
require './lib/gaucho'

module Gaucho
  class PageNotFound < Sinatra::NotFound
  end

  class FileNotFound < Sinatra::NotFound
    def initialize(name)
      #p "FileNotFound: #{name}"
    end
  end

  class App < Sinatra::Base
    #set :environment, :production

    set :root, File.dirname(__FILE__)
    set :haml, format: :html5, attr_wrapper: '"'

    $cache = MarshalCache.new('marshal_cache')

    $repo = $cache.get('repo') do
      repo = Gaucho::Repo.new(File.expand_path('../db/test'))
      repo.commits(nil) # force repo to init commits
      repo
    end
    $all_pages = $cache.get('all_pages') {$repo.pages}

    helpers do
      def date_format(date)
        ugly = date.strftime('%s')
        pretty = date.strftime('%b %e, %Y at %l:%M%P')
        %Q{<span data-date="#{ugly}">#{pretty}</span>}
      end
      def tag_url(tag)
        "/stuff-tagged-#{tag}"
      end
      def cat_url(cat)
        "/#{cat}"
      end
      def pages_categorized(cat)
        $all_pages.reject {|p| p.categories.index(cat).nil?}.sort
      end
      def pages_tagged(tag)
        $all_pages.reject {|p| p.tags.index(tag).nil?}.sort
      end
    end

    not_found do
      "<h1>OMG 404</h1>#{' '*512}"
    end

    # INDEX
    get %r{^(?:/([0-9a-f]{7}))?/?$} do |sha|
      pp ['index', params[:captures]]
      #start_time = Time.now
      @pages = $all_pages
      #pp @pages
      @tags = @pages.collect {|c| c.tags}.flatten.uniq.sort
      @cats = @pages.collect {|c| c.categories}.flatten.uniq.sort
      #@pages = pages_categorized('music')
      @title = 'omg index'
      haml :index
    end

    # TAGS
    # /content-tagged-{tag}
    get %r{^/stuff-tagged-([-\w]+)} do |tag|
      pp ['tag', params[:captures]]
      @pages = pages_tagged(tag)
      @title = %Q{Stuff tagged &ldquo;#{tag}&rdquo;}
      @tags = [tag]
      @cats = @pages.collect {|c| c.categories}.flatten.uniq.sort
      haml :index
    end

    # RECENT CHANGES
    # /recent-changes
    get '/recent-changes' do
      pp ['recent-changes']
      @pages = $all_pages
      @pages.each {|p| pp p.commits.last.message}
      @tags = []
      @cats = []
      haml :index
    end

    # DATE LISTING
    # /{YYYY}
    # /{YYYY}/{MM}
    # /{YYYY}/{MM}/{DD}
    get %r{^/(\d{4})(?:/(\d{2}))?(?:/(\d{2}))?/?$} do |year, month, day|
      pp ['date', params[:captures]]
      @pages = $all_pages.select {|page| page.id_date([year, month, day].compact)}
      @tags = []
      @cats = []
      haml :index
    end

    # PAGE
    # /{name}
    # /{sha}/{name}
    # /{sha}/{name}/{file}
    # "name" can be (slashes are just replaced with dashes):
    #   name
    #   YYYY/name
    #   YYYY/MM/name
    #   YYYY/MM/DD/name
    get %r{^(?:/([0-9a-f]{7}))?/(?:(\d{4}(?:/\d{2}){0,2})/)?([-\w]+)(?:/(.+))?$} do |sha, date, name, file|
      pp ['page', params[:captures]]
      options = {check_local_mods: true}
      #options = {}
      @render_opts = {no_highlight: true}
      #@render_opts = {}

      name = "#{date.gsub('/', '-')}-#{name}" if date
      #pp name

      @page = $cache.get("page-#{name}") {$repo.page(name)}
      @page.options = options
      @page.shown = sha

      begin
        if sha
          # cache heavily if in production
        end

        if file
          content_type File.extname(file) rescue content_type :txt
          @page/file
        else
          @page = @page
          @commit = Gaucho::Commit.commit(@page, @page.commit)
          @commits = Gaucho::Commit.commits(@page, @page.commits)
          @title = @page.title
          @content = @page.render(@page.content, @render_opts)

          haml(@page.layout || :page)
        end
      #rescue
      #  raise Sinatra::NotFound
      end
    end
  end
end

if $0 == __FILE__
  Gaucho::App.run! :host => 'localhost', :port => 4567
end
