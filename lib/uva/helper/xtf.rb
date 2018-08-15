# lib/uva/helper/xtf.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Xtf
  #
  module Xtf

    include UVA
    include UVA::Helper::Links

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Returns a properly encoded link to this document on the XTF server.
    #
    # @param [UVA::IndexDoc] doc
    # @param [String]        label    If not provided then the link label is
    #                                   the link URL.
    # @param [Hash]          opt      Link options.
    #
    # @option opt [String] :label     Used instead of the URL if *label* is not
    #                                   provided.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def xtf_link(doc, label = nil, opt = nil)
      if label.is_a?(Hash)
        opt = label
        label = nil
      else
        opt ||= {}
      end
      url = "#{URL::XTF}/view?docId=#{doc.fedora_doc_id}"
      query = extended_query_terms.join('+')
      url << "&query=#{h(query)}" if query.present?
      label ||= (opt = opt.dup).delete(:label) if opt.key?(:label)
      label ||= online_access_label(doc)
      external_link(label, url, opt)
    end

  end

end
