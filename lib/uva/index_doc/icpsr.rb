# lib/uva/index_doc/icpsr.rb

require 'uva'

module UVA

  # Special handling for digital ICPSR items.
  #
  # @see https://www.icpsr.umich.edu
  #
  module ICPSR

    # Actions taken when this module is included.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      [Interface].each do |mod|
        base.send(:include, mod) unless base.include?(mod)
      end
    end

  end

  # ===========================================================================
  # :section: IIIF IndexDoc mixin
  # ===========================================================================

  public

  module ICPSR::Interface

    include UVA

    # The :digital_collection_facet value for applicable items.
    ICPSR_FACET =
      'Inter-university Consortium for Political and Social Research'.freeze

    # =========================================================================
    # :section: Document methods
    # =========================================================================

    public

    # Indicate whether the current document is an ICPSR item.
    #
    def is_icpsr?(*)
      values_for(:digital_collection_facet).include?(ICPSR_FACET)
    end

    # Apply HTML sanitization to each element of an array.
    #
    # @param [String, Array<String>] text
    #
    # @return [Array<String>]
    #
    def sanitize_array(text)
      Array(text).map { |v| sanitize_html(v) if v }.compact
    end

  end

  # ===========================================================================
  # :section: ICPSR Blacklight (SolrDocument) extension
  # ===========================================================================

  public

  module ICPSR::Extension

    include UVA
    include UVA::ICPSR::Interface

    # Solr fields associated with this content type.
    SOLR_FIELDS = []

    # Translate tags from ICPSR descriptions into HTML tags.
    #
    ICPSR_TAG_TRANSLATIONS = {
      'list type="ordered"' => 'ol',
      'list'                => 'ul',
      'itm'                 => 'li',
      'hi'                  => 'b',
      'emph'                => 'i',
    }.map { |tag, new_tag|
      [%r{<(/?)#{tag}(\s+[^>]*)?>}, "<\\1#{new_tag}\\2>"]
    }.deep_freeze

    # Pairs of regular expressions and their substitutions.
    #
    ICPSR_OTHER_TRANSLATIONS = [

      # Don't maintain newlines because they will be translated into HTML
      # breaks by UVA::Util::HtmlMethods#sanitize_html.
      [/[\r\n]/, ''],

    ].deep_freeze

    # Pairs of regular expressions and their substitutions.
    #
    ICPSR_TRANSLATIONS =
      (ICPSR_TAG_TRANSLATIONS + ICPSR_OTHER_TRANSLATIONS).freeze

    # HTML element tags allowed to make it through sanitization in addition
    # to UVA::Util::HtmlMethods#ALLOWED_TAGS.
    #
    ICPSR_TAGS = %w(ol ul li).deep_freeze

    # Options to UVA::Util::HtmlMethods#sanitize_html.
    #
    ICPSR_SANITIZE_OPTS = {
      elements:   ICPSR_TAGS,
      translate:  ICPSR_TRANSLATIONS
    }.freeze

    # =========================================================================
    # :section: Document methods
    # =========================================================================

    public

    # Indicate whether the current document is an ICPSR item.
    #
    def is_icpsr?
      true
    end

    # Apply HTML sanitization to each element of an array.
    #
    # For ICPSR content that contains HTML fragments, this includes translating
    # some observed "XML" element tags into appropriate HTML element tags.
    #
    # @param [String, Array<String>] text
    #
    # @return [Array<String, Hash>]
    #
    def sanitize_array(text)
      Array(text).map { |v|
        post_process(sanitize_html(v, ICPSR_SANITIZE_OPTS)) if v
      }.compact
    end

    # =========================================================================
    # :section: Document methods
    # =========================================================================

    protected

    # Inline styling adjustment definitions.
    ICPSR_POST_TRANSLATIONS = {
      'ul' => 'list-style-type: disc;',
      'li' => 'list-style-type: inherit; list-style-position: inside;'
    }.map { |tag, style|
      [/<#{tag}>/, "<#{tag} style=\"#{style}\">"]
    }.deep_freeze

    # Apply styles on certain elements to overcome general styling.
    #
    # @param [String] text
    #
    # @return [String]
    #
    # === Implementation Notes
    # This is probably not the best way to applying styling specific to ICPSR
    # records, but any better alternative would probably involve some careful
    # redesign of the CSS assets.
    #
    def post_process(text)
      ICPSR_POST_TRANSLATIONS.each { |pair| text.gsub!(pair[0], pair[-1]) }
      text.sub(%r{\s*Cf\.?:\s*#{icpsr_url}\s*}i, '')
    end

    # The URL to this item without the UVA proxy prefix.
    #
    # @return [String]
    #
    def icpsr_url
      @icpsr_url ||=
        get_url.first.to_s.sub(%r{#{URL::UVA_PROXY_ROOT}/login\?url=}, '')
    end

    # =========================================================================
    # :section: SolrDocument overrides
    # =========================================================================

    public

    # Sanitizes the results of SolrDocument#get_abstract (including element
    # tag translations where needed).
    #
    def get_abstract
      sanitize_array(super)
    end

    # Sanitizes the results of SolrDocument#get_plot_summary (including element
    # tag translations where needed).
    #
    def get_plot_summary
      sanitize_array(super)
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Actions taken when this module is included.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      Rails.logger.debug { "#{base}: included extension UVA::ICPSR" }
    end

  end
end
