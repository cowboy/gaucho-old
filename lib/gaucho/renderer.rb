module Gaucho
  class Page
    def render(data = nil, options = {})
      Gaucho::Renderer.render_page(self, data, options)
    end
  end

  # Render a Page.
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
  #   * multiple "| filter" can be specified (is there any value to this?)
  #   * whitespace is insignificant and will be removed.
  #
  module Renderer
    extend StringUtils

    # Embed markdown.
    #
    # {{ content.md | markdown }}
    def self.markdown(o)
      # Convert options passed to Page#render into arguments for RDiscount.
      opts = {
        smart: true,
        generate_toc: true
      }.merge(o.options)
      args = opts.to_a.map{|key, value| value ? key : nil}.compact

      rd = RDiscount.new(o.data, *args)
      content = rd.to_html

      return content unless opts[:generate_toc]

      toc = fix_encoding(rd.toc_content)
      # Since the largest header used in content is typically H2, remove the
      # extra unnecessary <ul> created by RDiscount when a H1 doesn't exist in
      # the content.
      toc.sub!(%r{^(\s+)(<ul>)\n\n\1\2(.*)\n(\s+)</li>\n\4</ul>\n$}m, "\\1\\2\\3\n")

      # Tweak generated TOC links/ids so that they look a bit cleaner, replacing
      # any unicode chars with their "non-unicode equivalent" and changing any
      # runs of non-alphanumeric chars to hyphens.
      block = lambda do |m|
        a, z = $1, $3
        id = transliterate($2).downcase
        id = id.gsub(/['"]/, '').gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
        "#{a}#{id}#{z}"
      end
      toc.gsub!(/(<a href="#)([^"]+)(")/, &block)
      content.gsub!(/(<h\d id=")([^"]+)(")/, &block)

      # Insert generated TOC into content.
      content.gsub(/<!--TOC_PLACEHOLDER-->/, toc)
    end

    # Replace any {{ toc }} placeholder with the RDiscount-generated TOC.
    #
    # {{ toc }}
    def self.toc(o)
      %Q{<!--TOC_PLACEHOLDER-->}
    end

    # Embed html.
    #
    # {{ content.html | html }}
    def self.html(o)
      return invalid_encoding(o) unless valid_data?(o)
      o.data
    end

    # Embed text, escaping any HTML.
    #
    # {{ content.txt | text }}
    # {{ content.txt | text(class="awesome-pre") }}
    def self.text(o)
      return invalid_encoding(o) unless valid_data?(o)
      %Q{<pre#{o.attrs}>#{escape(o)}</pre>}
    end

    # Escape HTML.
    #
    # {{ content.html | escape }}
    def self.escape(o)
      return invalid_encoding(o) unless valid_data?(o)
      CGI::escapeHTML(o.data)
    end

    # Get a raw Blob URL.
    #
    # <img src="{{ image.jpg | url }}">
    def self.url(o)
      if o.page.shown_local_mods?
        "#{o.page.url}/#{o.name}"
      else
        "#{o.page.commit.url}/#{o.name}"
      end
    end

    # Embed an asset script.
    #
    # {{ awesome.js | script }}
    # {{ awesome.js | script(id="test") }}
    def self.script(o)
      %Q{<script src="#{url(o)}"#{o.attrs}></script>}
    end

    # Embed an asset CSS stylesheet.
    #
    # {{ pretty.css | css }}
    # {{ pretty.css | css(media="screen") }}
    def self.css(o)
      %Q{<link href="#{url(o)}" rel="stylesheet" type="text/css"#{o.attrs}>}
    end

    # Embed an asset image.
    #
    # {{ image.jpg | image }}
    # {{ image.jpg | image(width="20" style="float:right") }}
    def self.image(o)
      %Q{<img src="#{url(o)}"#{o.attrs}>}
    end

    # Embed an asset link.
    #
    # {{ file.txt | link }}
    # {{ file.txt | link(class="popup") }}
    def self.link(o, download = false)
      query_string = download ? '?dl=1' : ''
      %Q{<a href="#{url(o)}#{query_string}"#{o.attrs}>#{o.name}</a>}
    end

    # Embed a downloadable asset link.
    #
    # {{ file.txt | download }}
    # {{ file.txt | download(class="external") }}
    def self.download(o)
      link(o, true)
    end

    # Which filter should be used, by default, for a given file extension? If
    # a matching filter isn't found, the @@filter_default value is used.
    @@filter_default = :text
    @@filter_map = {
      toc: [:toc], # hackish
      markdown: [:md],
      html: [:htm],
      text: [:txt],
      image: [:jpg, :jpeg, :gif, :png],
    }

    # Expose @@filter_map and @@filter_default to allow modifications.
    def self.filter_default=(value); @@filter_default = value; end
    def self.filter_default; @@filter_default; end
    def self.filter_map; @@filter_map; end

    # Render content recursively, starting with index.
    def self.render_page(page, data = nil, options = {}, name = nil, filter = nil, arg = nil)
      data = page.content if data.nil?
      name = page.meta.index_name if name.nil?
      filter = filter_from_name(name) if filter.nil?
      #p [name, filter, arg, data.class, data.valid_encoding?]

      if data.valid_encoding? && data =~ /\{\{/
        # Process all {{ ... }} substrings.
        data.gsub!(/\{\{\s*(.*?)\s*\}\}/) do |match|
          # Parse into a name plus array of zero or more filters. I can't really
          # think of a good reason to have multiple filters, but why not, right?
          name, *filters = $1.split(/\s*\|\s*/)

          # Parse filters into filter/argument pairs.
          filters.collect! do |f|
            f =~ /^([a-z][a-z0-9_]*?)(?:\((.*)\))?$/
            [ $1, $2 ] unless $1.nil?
          end
          filters.compact!

          # If no filter was specified, choose a default filter based on the
          # filename and @@filter_map.
          filters = [filter_from_name(name)] if filters.empty?

          result = page/name rescue invalid_file(name)
          filters.each do |f, a|
            #p ['*', name, f, a]
            result = render_page(page, result, options, name, f.to_sym, a)# rescue '12345'
          end

          result
        end
      end

      # If a filter exists to handle this request, use it, otherwise error.
      if respond_to?(filter)
        public_send(filter, filter_metadata(page, data, options, name, arg))
      else
        invalid_filter(filter, name)
      end
    end

    # Create a metadata object to be passed into a filter method.
    def self.filter_metadata(page, data, options, name, arg)
      # Split arg on commas into an array of "args".
      args = (arg || '').split(/\s*,\s*/)

      # If arg contains HTML attributes, add a space to the beginning.
      attrs = arg ? " #{arg}" : ''

      # Build hash of "flags" from args.
      flags = {}
      args.each {|key| flags[key] = true}

      Gaucho::Config.new({
        options: options,
        page: page,
        data: data,
        name: name,
        arg: arg,
        args: args,
        attrs: attrs,
        flags: flags
      })
    end

    # Get the appropriate filter for a give filename.
    def self.filter_from_name(name = '')
      return nil unless name =~ /([^.]+)$/

      ext = $1.downcase.to_sym

      type = filter_map.collect do |filter, exts|
        filter if filter == ext || exts.find {|e| e == ext}
      end

      type = type.compact.first || filter_default
    end

    # Ensure that data is not binary or invalidly encoded.
    def self.valid_data?(o)
      o.data.encoding.name != 'ASCII-8BIT' && o.data.valid_encoding?
    end

    # Handle binary or invalidly encoded data in a helpful way.
    def self.invalid_encoding(o)
      %Q{<b style="color:red">Invalid encoding: #{o.name}</b>}
    end

    # Handle invalid files in a helpful way.
    def self.invalid_file(file)
      %Q{<b style="color:red">Invalid file: #{file}</b>}
    end

    # Handle invalid filters in a helpful way.
    def self.invalid_filter(filter, file)
      %Q{<b style="color:red">Invalid filter: #{filter} (#{file})</b>}
    end
  end
end
