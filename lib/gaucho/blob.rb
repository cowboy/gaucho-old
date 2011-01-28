# A wrapper for Grit::Blob
module Gaucho
  class Blob
    include Gaucho::ShortSha
    attr_reader :page, :blob

    def initialize(page, blob)
      @page = page
      @blob = blob
    end

    # Pretty inspection.
    def inspect
      %Q{#<Gaucho::Blob "#{short_sha}" "#{name}" "#{url}">}
    end

    # URL for this blob.
    def url
      "#{page.url}/#{name}"
    end

    # Pass-through all methods to the underlying Grit::Blob instance.
    def method_missing(name, *args)
      blob.send(name, *args) if blob.respond_to?(name)
    end

    # Get a single Blob instance.
    def self.blob(repo, blob)
      self.new(repo, blob)
    end

    # Get an array of Blob instances.
    def self.blobs(page, blobs)
      blobs.collect {|blob| self.blob(page, blob)}.compact
    end
  end
end
