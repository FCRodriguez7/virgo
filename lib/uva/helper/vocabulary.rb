# lib/uva/helper/vocabulary.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Vocabulary
  #
  module Vocabulary

    include UVA
    include UVA::Accessibility

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Lookup a vocabulary term.
    #
    # If the term was found then its entry is returned with two added key-value
    # pairs: :key for the symbolized vocabulary entry key and :term for the
    # string value of the term.
    #
    # @param [String, Symbol] term
    #
    # @return [Hash{Symbol=>String}]  The matching vocabulary entry.
    # @return [nil]                   If the term was not in the vocabulary.
    #
    def vocabulary_lookup(term)
      return if term.blank?
      key   = term.to_sym
      entry = VOCABULARY_TERMS[key]
      entry.merge(key: key, term: term.to_s) if entry.present?
    end

    # Display a vocabulary word which shows the description when the mouse
    # hovers over it.  If a url is supplied, the word is also treated as a
    # link.
    #
    # If no description and URL were provided or could be discovered in the
    # vocabulary then the method returns with the original "term" value.  This
    # allow the method to be used safely as a replacement for the original
    # term even if it is not in the vocabulary.
    #
    # @param [Array<(String,String,String)>] args
    #
    # @option args [String] :term     First argument; via opt[:term] otherwise
    # @option args [String] :desc     Second argument; via opt[:desc] otherwise
    # @option args [String] :url      Third argument; via opt[:url] otherwise
    # @option args [Hash]   :opt      Fourth argument (optional)
    #
    # @option args.last [String]  :term     May be given in place of :term arg.
    # @option args.last [String]  :desc     May be given in place of :desc arg.
    # @option args.last [String]  :url      May be given in place of :url arg.
    # @option args.last [Numeric] :tabindex Passed to link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [term]
    #
    def vocabulary_term(*args)
      opt = args.last.is_a?(Hash) ? args.pop.dup : {}

      # Lookup the provided term and fill in any missing information.  If the
      # only argument was a hash then it is assumed that the hash came from a
      # previous invocation of #vocabulary_lookup.
      if args.empty?
        term, desc, url = nil
      else
        term, desc, url = args
        entry = vocabulary_lookup(term)
        opt.reverse_merge!(entry) if entry.present?
      end
      opt.delete(:key)

      # If present then :term forces an override of the text that is displayed
      # within the <span>.
      term = opt.delete(:term) if opt.key?(:term)
      return '' if term.blank?

      # If present then :desc is used as a fall-back but if its value is false
      # then it eliminates the tooltip title from the <span>.
      opt_desc = opt.delete(:desc)
      case opt_desc
        when nil   then # No change to *desc*.
        when false then desc = false
        else            desc ||= opt_desc
      end

      # If present then :url is used as a fall-back but if its value is false
      # then it eliminates the href from the <span>.
      opt_url = opt.delete(:url)
      case opt_url
        when nil   then # No change to *url*.
        when false then url = nil
        else            url ||= opt_url
      end

      # As a fall-back, if there is a URL specified but no description then use
      # the URL as the tooltip title for the <span>.  If there is neither a
      # description nor a URL, then the result is simply the bare term with no
      # <span> or link.
      case desc
        when nil   then desc = url
        when false then desc = nil
      end
      return term if desc.blank?

      # Include the required CSS class in the HTML options.
      css =
        if opt[:class].blank?
          VOCABULARY_CSS
        elsif !opt[:class].include?(VOCABULARY_CSS)
          case opt[:class]
            when String then VOCABULARY_CSS + SPACE + opt[:class]
            when Array  then [VOCABULARY_CSS] + opt[:class]
            else raise "unexpected opt[:class] type #{opt[:class].class}"
          end
        end
      css = css.join(SPACE) if css.is_a?(Array)
      opt[:class] = css

      # Unless explicitly indicated via options, the link (if created) will be
      # treated as a tab stop.
      tabindex = opt.delete(:tabindex) || 0
      outer_opt = { tabindex: tabindex, title: desc, ARIA_LABEL => desc }

      # Create the display element.  Unless explicitly indicated via options,
      # the link (if created) will not be treated as a tab stop.
      if url.present?
        out_link(url, outer_opt) { content_tag(:span, term, opt) }
      else
        content_tag(:span, term, opt.merge(outer_opt))
      end

    end

    # Display one or more vocabulary terms.
    #
    # Arguments may be a combination of single vocabulary words (to be looked
    # up) or combinations of ad hoc term definitions packaged as Arrays of up
    # to three elements (term, description, url) or Hashes with keys :term,
    # :desc, :url.
    #
    # @param [Array<String, Array, Hash>] args
    #
    # @option arg [String] :separator             Newline by default.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [Array<ActiveSupport::SafeBuffer>]  If :separator is *false*.
    #
    def vocabulary_terms(*args)

      # Extract options from the end of the argument list.  Except for
      # :separator, these are passed as HTML options to the <span> tag.
      opt = args.last.is_a?(Hash) ? args.pop.dup : {}
      separator = opt.key?(:separator) ? opt.delete(:separator) : true
      case separator
        when false then separator = nil
        when true  then separator = NEWLINE
      end

      # Create a display element for each term.
      result =
        args.map { |arg|
          term_args = []
          case arg
            when Array
              term_args += arg
            when Hash
              term_args << arg[:term]
              term_args << arg[:desc]
              term_args << arg[:url]
            else
              term_args << arg
          end
          term_args << opt
          vocabulary_term(*term_args)
        }.compact

      # Return a string or array as indicated by :separator.
      separator ? result.join(separator).html_safe : result
    end

    # Display a MARC field (for use in the MARC view).
    #
    # @param [String] tag
    # @param [String] desc            If *false* then there will be no tooltip.
    # @param [String] url             If *false* then there will be no link.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def marc_term(tag, desc = nil, url = nil)
      # Find the entry for this term (if any).
      entry = vocabulary_lookup(tag)
      term = tag.downcase
      unless entry
        case tag
          when /^4[^9].$/, /^49[^0]$/ then term = '4xx'
          when /^59.$/                then term = '59x'
          when /^9..$/                then term = '9xx'
        end
        entry = vocabulary_lookup(term) || {}
      end

      # Update the copy of the entry with parameters and generate the link.
      entry[:term] = tag
      entry[:desc] = desc unless desc.nil?
      entry[:desc] = (MARC_DESCRIPTION % tag) if entry[:desc].nil?
      entry[:url]  = url unless url.nil?
      entry[:url]  = "#{MARC_BASE_URL}/bd#{term}.html" if entry[:url].nil?
      vocabulary_term(entry)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Vocabulary term CSS class.
    VOCABULARY_CSS = 'vocabulary-term'.freeze

    # Base URL for MARC field tooltip URLs.
    MARC_BASE_URL = 'https://www.loc.gov/marc/bibliographic'.freeze

    # Title text (with embedded newlines) for MARC field tooltips.
    MARC_DESCRIPTION = %q(
      MARC %s - Click for more information.
      (Obsolete fields may return "Page Not Found".)
    ).squish.freeze

    VOCABULARY_TERMS ||= {

      # ==== MARC fields ====

      :'019' => {
        desc: 'MARC 019 - OCLC Control Number Cross-Reference',
        url:  'https://www.oclc.org/bibformats/en/0xx/019.html',
      },
      :'029' => {
        desc: 'MARC 029 - Other System Control Number',
        url:  'https://www.oclc.org/bibformats/en/0xx/029.html',
      },
      :'049' => {
        desc: 'MARC 049 - Information from original cataloging source',
        url:  'https://www.oclc.org/bibformats/en/0xx/049.html',
      },
      :'090' => {
        desc: 'MARC 090 - Locally Assigned LC-type Call Number',
        url:  'https://www.oclc.org/bibformats/en/0xx/090.html',
      },
      :'4xx' => {
        desc: nil,
        url:  'https://www.oclc.org/bibformats/en/4xx.html',
      },
      :'590' => {
        desc: 'MARC 590 - Local note',
        url:  'https://www.oclc.org/bibformats/en/5xx/590.html',
      },
      :'599' => {
        desc: 'MARC 599 - Differentiable Local Note',
        url:  'https://www.oclc.org/bibformats/en/5xx/599.html',
      },
      :'59x' => {
        desc: nil,
        url:  'https://www.loc.gov/marc/bibliographic/bd59x.html',
      },
      :'866' => {
        desc: 'MARC 866 - Textual Holdings--Basic Bibliographic Unit',
        url:  'https://www.oclc.org/bibformats/en/8xx/84x-87x.html',
      },
      :'868' => {
        desc: 'MARC 868 - Textual Holdings--Indexes',
        url:  'https://www.oclc.org/bibformats/en/8xx/84x-87x.html',
      },
      :'891' => {
        desc: 'MARC 891 - Publication Pattern Data',
        url:  'https://www.oclc.org/bibformats/en/8xx/891.html',
      },
      :'896' => {
        desc: 'MARC 896 - Local Series Added Entry--Personal Name',
        url:  'https://www.oclc.org/bibformats/en/8xx/896.html',
      },
      :'897' => {
        desc: 'MARC 897 - Local Series Added Entry--Corporate Name',
        url:  'https://www.oclc.org/bibformats/en/8xx/897.html',
      },
      :'898' => {
        desc: 'MARC 898 - Local Series Added Entry--Meeting Name',
        url:  'https://www.oclc.org/bibformats/en/8xx/898.html',
      },
      :'899' => {
        desc: 'MARC 899 - Local Series Added Entry--Uniform Title',
        url:  'https://www.oclc.org/bibformats/en/8xx/899.html',
      },
      :'994' => {
        desc: 'MARC 994 - OCLC-MARC Transaction Code',
        url:  'https://www.oclc.org/bibformats/en/9xx/994.html',
      },
      :'999' => {
        desc: 'MARC 999 - Local holdings data',
        url:  'https://www.oclc.org/bibformats/en/9xx.html',
      },
      :'9xx' => {
        desc: nil,
        url:  'https://www.oclc.org/bibformats/en/9xx.html',
      },

      # ==== Acronyms and other terms ====

      APA: {
        desc: 'American Psychological Association citation format',
        url:  'http://www.apastyle.org',
      },
      Chicago: {
        desc: 'Chicago Manual of Style citation format',
        url:  'http://www.chicagomanualofstyle.org',
      },
      DOI: {
        desc: 'Digital Object Identifier',
        url:  'https://www.doi.org',
      },
      ISBN: {
        desc: 'International Standard Book Number',
        url:  'https://wikipedia.org/wiki/International_Standard_Book_Number',
      },
      ISSN: {
        desc: 'International Standard Serial Number',
        url:  'http://www.issn.org',
      },
      MLA: {
        desc: 'Modern Language Association citation format',
        url:  'https://style.mla.org',
      },
      SuDoc: {
        desc: 'Superintendent of Documents classification',
        url:  'https://www.fdlp.gov/' \
              'catalogingandclassification/cataloging-articles/' \
              '1791-superintendent-of-documents-sudocs-classification-scheme',
      },
    }.deep_freeze

  end

end
