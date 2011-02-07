require 'sinatra'

require 'grit'
require 'haml'
require 'mime/types'
require 'delegate'
require 'diffy'

require 'awesome_print'
require 'pp'
require 'profiler'

require './lib/gaucho'

# Diffy limitation workaround (the inability to specify an actual diff)
module Diffy
  class Diff
    attr_writer :diff
  end
end

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

    #$pageset = Gaucho::PageSet.new(File.expand_path('../db/test'))

    #$pageset = Gaucho::PageSet.new(File.expand_path('../db/test1'), subdir: 'yay')
    $pageset = Gaucho::PageSet.new(File.expand_path('../db/test1'), subdir: 'nay')

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
      # Render diffs for page revision history.
      def render_diff(diff)
        data = diff.data
        data.force_encoding('utf-8')
        if data.valid_encoding?
          d = Diffy::Diff.new('','')
          d.diff = data
          d.to_s(:html)
        else
          'Binary data' # TODO: CHANGE?
        end
      end
    end

    not_found do
      "<h1>OMG 404</h1>#{' '*512}"
    end

    # INDEX
    get %r{^(?:/([0-9a-f]{7}))?/?$} do |sha|
      pp ['index', params[:captures]]
      #start_time = Time.now
      @pages = $pageset.pages(true)
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
      @pages = $pageset.pages(true)
      @pages.reject! {|p| p.tags.index(tag).nil?}.sort
      @title = %Q{Stuff tagged &ldquo;#{tag}&rdquo;}
      @tags = [tag]
      @cats = @pages.collect {|cat| cat.categories}.flatten.uniq.sort
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
      @pages = $all_pages.select {|page| page.date?([year, month, day].compact)}
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
    get %r{^(?:/([0-9a-f]{7}))?/((?:\d{4}(?:/\d{2}){0,2}/)?[-\w]+)(?:/(.+))?$} do |sha, name, file|
      pp ['page', params[:captures]]

      #@page = $cache.get("page-#{name}") {$pageset.page(name)}
      @page = $pageset.page(name)
      @page.check_local_mods
      @page.shown = sha

      begin
        if sha
          # cache heavily if in production
        end

        if file
          content_type File.extname(file) rescue content_type :txt
          @page/file
        else
          @commit = @page.commit
          @commits = @page.commits
          @title = @page.title
          @content = @page.render(@page.content, {no_highlight: true})

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
