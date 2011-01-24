require 'rdiscount'
require 'rb-pygments'

# For the escape_html helper.
require 'rack'
include Rack::Utils

# Override default Page to_html method.
class Page
  def to_html
    PageRender.new( self ).to_html
  end
end

# Render a Page recursively.
#
# All internal asset links processed via the {{...}} syntax will incorporate
# the current SHA when rendering, so be sure to use the {{...}} syntax for
# *all* internal asset linking.
#
#   {{ asset }}
#   {{ asset | filter }}
#   {{ asset | filter(arg) }}
#
# Notes:
#   * arg can be a comma-separated list of args or flags.
#   * whitespace is insignificant and will be removed.
#
class PageRender
  def initialize(page)
    @page = page
  end

  # Get rendered output.
  def to_html
    render(@page.index)
  end

  # Do the heavy lifting.
  def render(asset, filter = nil, arg = nil)
    if filter.nil?
      filter = self.class.get_filter(asset)
    end

    # Get asset contents, if possible.
    contents = @page.assets[asset]

    # Render sub-parts recursively.
    # Regex captures:
    #   $1 = asset
    #   $2 = filter
    #   $3 = arg
    unless contents.nil?
      regex = /\{\{\s*([^|\s]+)(?:\s*\|\s*([a-zA-Z0-9]+)(?:\(\s*(.*?)\s*\))?)?\s*\}\}/
      contents.gsub!(regex) do |match|
        render($1, $2, $3)
      end
    end

    # If a filter exists to handle this request, use it, otherwise error.
    if respond_to?(filter)
      #pp [ "filter", asset, filter, arg]
      send(filter, PageRenderData.new(asset, @page.assets[asset], arg))
    else
      self.class.invalid_filter(filter, asset)
    end
  end

  # Embed markdown.
  #
  # {{ content.md | markdown }}
  def markdown(d)
    rd = RDiscount.new(d.contents, :smart, :generate_toc)
    rd.to_html.sub(/<p>\{\{toc\}\}<\/p>/, rd.toc_content)
  end

  # Any {{toc}} placeholder will be replaced with the RDiscount-generated TOC.
  #
  # {{ toc }}
  def toc(d)
    '{{toc}}'
  end

  # Embed html.
  #
  # {{ content.html | html }}
  def html(d)
    d.contents
  end

  # Embed text.
  #
  # {{ content.txt | text }}
  def text(d)
    "<pre#{d.attrs}>#{escape_html(d.contents)}</pre>"
  end

  # Embed syntax-highlighted source code.
  #
  # {{ example.js | code }}
  def code(d)
    lang ||= File.extname(d.name)[1..-1]
    code = Pygments.highlight(d.contents, lang, :html, noclasses: true, linenos: :table)
    "#{code}<div class='highlight-link'>#{link(d)}</div>"
  end

  # Get a raw asset URL.
  #
  # <img src="{{ image.jpg | url }}">
  def url(d)
    "#{@page.url_asset(d.name)}"
  end

  # Embed an asset script.
  #
  # {{ awesome.js | script }}
  # {{ awesome.js | script(id="test") }}
  def script(d)
    "<script src='#{url(d)}'#{d.attrs}></script>"
  end

  # Embed an asset CSS stylesheet.
  #
  # {{ pretty.css | css }}
  # {{ pretty.css | css(media="screen") }}
  def css(d)
    "<link href='#{url(d)}' rel='stylesheet' type='text/css'#{d.attrs}>"
  end

  # Embed an asset image.
  #
  # {{ image.jpg | image }}
  # {{ image.jpg | image(width="20" style="float:right") }}
  def image(d)
    "<img src='#{url(d)}'#{d.attrs}>"
  end

  # Embed an asset link.
  #
  # {{ file.txt | link }}
  # {{ file.txt | link(class="popup") }}
  def link(d, download = false)
    query_string = download ? '?dl=1' : ''
    "<a href='#{url(d)}#{query_string}'#{d.attrs}>#{d.name}</a>"
  end

  # Embed a downloadable asset link.
  #
  # {{ file.txt | download }}
  # {{ file.txt | download(class="external") }}
  def download(d)
    link(d, true)
  end

  class << self
    # Which filter should be used, by default, for a given file extension?
    @@filters = {
      markdown: [:md],
      html: [:htm],
      text: [:txt],
      code: [:js, :css, :php, :rb, :applescript],
      image: [:jpg, :jpeg, :gif, :png],
    }

    # Expose @@filters so that it may be changed.
    def filters
      @@filters
    end

    # Access @@filters in an actually meaningful way.
    def get_filter(name = '')
      return nil unless name =~ /\.?([^.]+)$/

      type = $1.downcase.to_sym

      t = @@filters.find {|kv| kv[1].find {|i| i == type}}
      t.nil? ? type : t[0]
    end

    # Handle invalid filters in a helpful way.
    def invalid_filter(filter, asset)
      "<div class='error.filter'>Invalid filter: #{filter} (#{asset})</div>"
    end

    # Render diffs for page revision history.
    def diff(diff)
      unless diff.diff.start_with? 'Binary files'
        #Pygments.highlight(diff.diff, :diff, :html, noclasses: true)
        "<pre>#{escape_html(diff.diff)}</pre>"
      end
    end
  end

  # Access props as data.name, data.contents, data.arg instead of as
  # data[:name], data[:contents], data[:arg]. Also, data.args contains
  # a list of args (just arg split on commas), data.flags maps all args
  # to a hash with each arg-as-key set to true, and data.attrs is an
  # HTML attributes string.
  class PageRenderData
    attr_accessor :name, :contents, :arg, :args, :flags, :attrs

    def initialize(name, contents, arg)
      # Expose the standard stuff.
      @name = name
      @contents = contents
      @arg = arg

      # Split arg on commas into an array of "args".
      @args = (arg || '').split(/\s*,\s*/)

      # If arg contains HTML attributes, add a space to the beginning.
      @attrs = arg ? " #{arg}" : ''

      # Build hash of "flags" from args.
      @flags = {}
      unless @args.nil?
        @args.each {|key| @flags[key] = true}
      end
    end
  end
end
