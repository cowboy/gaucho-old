require 'sinatra'

require 'haml'
require 'mime/types'
require 'diffy'
require 'rb-pygments'

require '../lib/gaucho'

# Diffy limitation workaround (the inability to specify an actual diff)
module Diffy
  class Diff
    attr_writer :diff
  end
end

# Pygments limitation workaround (the inability to handle the -a argument for an
# html style.
module Pygments
  def self.style(style, formatter, options = [])
    execute(["-S", style, "-f", formatter] + options)
  end
end

module Gaucho
  # A basic syntax highlighter "code" filter.
  module Renderer
    filter_map[:code] = [:js, :css, :php, :rb, :applescript]
    def self.code(o)
      return invalid_encoding(o) unless valid_data?(o)
      # TODO: figure out options: hl_lines: [1,3,5], linenostart
      code = Pygments.highlight(o.data, File.extname(o.name)[1..-1], :html,
        linenos: :table, anchorlinenos: true, lineanchors: o.name)
      %Q{#{code}<div class="highlight-link">#{link(o)}</div>}
    end
  end

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

    #$pageset = Gaucho::PageSet.new(File.expand_path('test_repo'), subdir: 'yay')
    #$pageset = Gaucho::PageSet.new(File.expand_path('test_repo'), subdir: 'nay')
    $pageset = Gaucho::PageSet.new(File.expand_path('../spec/test_repo'))

=begin
    p Renderer.filter_from_name('foo.txt')
    p Renderer.filter_from_name('foo.text')
    p Renderer.filter_from_name('foo.js')
    p Renderer.filter_from_name('foo.css')
    p Renderer.filter_from_name('foo.markdown')
    p Renderer.filter_from_name('foo.html')
    p Renderer.filter_from_name('foo.bar')
    pg = $pageset['unicode-article']
    pg.check_local_mods
    p pg.title
    p '== files =='
    pg.files.each do |name, data|
      p [name, data.encoding.name, data.length, data.size, data.bytesize]
    end
    p '== commit =='
    pg.commits.last.files.each do |name, data|
      p [name, data.encoding.name, data.length, data.size, data.bytesize]
    end
    p $pageset.first.commit.diffs
    p $pageset.first.files
    p $pageset.subdir_path
    p $pageset.abs_subdir_path
    p $pageset.tree
    p $pageset.last
    p $pageset.length
    c = $pageset.first.commit
    p c.author.name
    p c.author.email
    p c.authored_date
    p c.committer.name
    p c.committer.email
    p c.committed_date
=end

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
        unless diff.binary?
          d = Diffy::Diff.new('', '')
          d.diff = diff.data
          d.to_s(:html)
        end
      end
    end

    not_found do
      "<h1>OMG 404</h1>#{' '*512}"
    end

    # INDEX
    get %r{^(?:/([0-9a-f]{7}))?/?$} do |sha|
      p ['index', params[:captures]]
      #start_time = Time.now
      @pages = $pageset.reset_shown
      @tags = @pages.collect {|c| c.tags}.flatten.uniq.sort
      @cats = @pages.collect {|c| c.categories}.flatten.uniq.sort
      #@pages = pages_categorized('music')
      @title = 'omg index'
      haml :index
    end

    # TAGS
    # /content-tagged-{tag}
    get %r{^/stuff-tagged-([-\w]+)} do |tag|
      p ['tag', params[:captures]]
      @pages = $pageset.reset_shown
      @pages.reject! {|p| p.tags.index(tag).nil?}.sort
      @title = %Q{Stuff tagged &ldquo;#{tag}&rdquo;}
      @tags = [tag]
      @cats = @pages.collect {|cat| cat.categories}.flatten.uniq.sort
      @index_back = true
      haml :index
    end

    # CATEGORIES
    # /{category}
    get %r{^/([-\w]+)} do |cat|
      p ['cat', params[:captures]]
      @pages = $pageset.reset_shown
      @pages.reject! {|p| p.categories.index(cat).nil?}.sort
      pass if @pages.empty?
      @title = %Q{Stuff categorized &ldquo;#{cat}&rdquo;}
      @tags = @pages.collect {|tag| tag.tags}.flatten.uniq.sort
      @cats = [cat]
      @index_back = true
      haml :index
    end

=begin
    # RECENT CHANGES
    # /recent-changes
    get '/recent-changes' do
      p ['recent-changes']
      @pages = $all_pages
      @pages.each {|page| p page.commits.last.message}
      @tags = []
      @cats = []
      @index_back = true
      haml :index
    end
=end

    # DATE LISTING
    # /{YYYY}
    # /{YYYY}/{MM}
    # /{YYYY}/{MM}/{DD}
    get %r{^/(\d{4})(?:/(\d{2}))?(?:/(\d{2}))?/?$} do |year, month, day|
      p ['date', params[:captures]]
      date_arr = [year, month, day].compact
      @pages = $pageset.reset_shown.select {|page| page.date?(date_arr)}
      @title = %Q{Stuff dated &ldquo;#{date_arr.join('-')}&rdquo;}
      @tags = []
      @cats = []
      @index_back = true
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
      p ['page', params[:captures]]

      begin
        @page = $pageset[name]
        @page.check_local_mods if development?
        @page.shown = sha

        if sha && production?
          # cache heavily
        end

        if file
          content_type File.extname(file) rescue content_type :txt
          @page/file
        else
          @commit = @page.commit
          @commits = @page.commits
          @title = @page.title
          @content = @page.render(@page.content) #, generate_toc: false)
          @index_back = true
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
