# lib/uva/helper/fedora.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Fedora
  #
  module Fedora

    include UVA
    include UVA::Fedora
    include UVA::Helper::Ead

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The URL of the Fedora proxy host.
    #
    # @return [String]
    #
    # @see self#fedora_proxy_object
    #
    def fedora_proxy_host
      URL::FEDORA_PROXY.tap do |url|
        url.prepend('http://') unless url =~ %r{^\w+://}
      end
    end

    # Base URL of the Fedora proxy service.
    #
    # @return [String]
    #
    # @see self#fedora_proxy_object
    #
    def fedora_proxy
      @fedora_proxy ||= File.join(fedora_proxy_host, 'fedora')
    end

    # Base URL for a Fedora proxy object.
    #
    # @param [SolrDocument, String] doc  Either a document or a pid.
    # @param [Array<String>]       path  URL path elements to append.
    #
    # @return [String]
    #
    # @see self#fedora_proxy_datastream
    #
    def fedora_proxy_object(doc, *path)
      pid = doc.is_a?(UVA::IndexDoc) ? doc.doc_id : doc
      result = [fedora_proxy, 'objects', pid]
      result += path.flat_map { |p| p.split('/') }
      result.compact.join('/')
    end

    # Base URL for a Fedora proxy object datastream.
    #
    # @param [SolrDocument, String] doc  Either a document or a pid.
    # @param [Array<String>]       path  Zero or more URL path elements to
    #                                      append.
    #
    # @return [String]
    #
    # @see UVA::Helper::Links#show_wsls_thumbnail
    #
    def fedora_proxy_datastream(doc, *path)
      fedora_proxy_object(doc, 'datastreams', *path)
    end

    # URL for a Fedora proxy object thumbnail.
    #
    # @param [SolrDocument, String] doc  Either a document or a pid.
    #
    # @return [String]                The thumbnail URL.
    # @return [nil]                   If an identifier was not provided.
    #
    def fedora_proxy_thumbnail(doc)
      pid = doc.is_a?(UVA::IndexDoc) ? doc.doc_id : doc
      "#{fedora_proxy}/get/#{pid}/djatoka:StaticSDef/getThumbnail" if pid
    end

  end

end
