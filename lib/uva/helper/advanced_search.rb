# lib/uva/helper/advanced_search.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::AdvancedSearch
  #
  module AdvancedSearch

    include UVA
    include UVA::Scope
    include UVA::AdvancedSearch
    include UVA::AdvancedSearch::AdvancedHelperOverride
    include UVA::AdvancedSearch::AdvancedSearchFields

    REFINE_SEARCH_LABEL = 'Refine&nbsp;search'.html_safe.freeze

    FACET_TO_SEARCH_FIELD = {
      # EBSCO facets
      tlevel:                   :peer_reviewed,
      PublicationYear:          :publication_date,
      SubjectEDS:               :subject,
      Journal:                  :journal,
      SubjectGeographic:        :subject,
      # Solr facets
      series_title_facet:       :title,
      call_number_broad_facet:  :call_number,
      year_multisort_i:         :publication_date,
    }

    # The :title for the facet header when the list is not expanded.
    FACET_TOOLTIP = 'Limit results to one or more %s.'.freeze

    # The :title for the facet header when the list is expanded.
    FACET_OPEN_TOOLTIP = 'Click to close the %s list.'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Render the appropriate "refine search" link.
    #
    # @param [Array<String>] args
    # - The first (non-hash) argument from *args* is used as the link label;
    #   if no argument is present, self#REFINE_SEARCH_LABEL is used.
    # - If options (if present) in *args* are passed to the link.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    # @see self#refine_search_hash
    #
    def refine_search_link(*args)
      html_opt = {
        class:  'refine-search-link',
        role:   'button',
        title:  "Modify or expand your #{portal_search_label} search."
      }
      html_opt.merge!(args.pop) if args.last.is_a?(Hash)
      link_label = args.first || REFINE_SEARCH_LABEL
      link_path  = advanced_path(current_portal_key, refine_search_hash)
      link_to(link_label, link_path, html_opt)
    end

    # HTML for a button to close the open facet.
    #
    # @param [String] facet_name
    # @param [Hash]   opt             HTML options passed to the element plus
    #                                   the following:
    #
    # @option opt [String, Array<String>] :class
    #                                 One or more CSS classes to be included
    #                                   with the definition.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def facet_close_button(facet_name, opt = nil)
      default_opt = {
        label:    'Close',
        title:    (FACET_OPEN_TOOLTIP % facet_name),
        class:    'close-button',
        role:     'button',
        tabindex: 0
      }
      html_opt = html_options(opt, default_opt)
      label = html_opt.delete(:label)
      html_opt[ARIA_LABEL] ||= html_opt[:title] || strip_html(label)
      content_tag(:div, label, html_opt)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # List of params to send to portal_advanced_path so that the advanced form
    # will re-populate as best it can.
    #
    # @return [Hash{Symbol=>String}]
    # @return [nil]
    #
    # @see self#refine_search_link
    #
    def refine_search_hash

      result = advanced_search_values

      # It should look like this:
      #   params[:f][library_facet][]=Clemons
      # except that advanced facets must be handled specially.
      (params[:f] || {}).each_pair do |facet, values|
        facet = facet.to_sym
        field = nil
        field ||= facet if facet == :published_date_facet
        field ||= :add_advanced_facet if advanced_facets.include?(facet.to_s)
        field ||= facet_to_search_field(facet)
        field ||= facet_to_advanced_field(facet)
        next unless field
        Array(values).each do |value|
          value = value.first if value.is_a?(Array)
          case field
            when :add_advanced_facet
              add_advanced_facet!(facet, value, result)
            when :published_date_facet
              result[:publication_date] = publication_era_range(value)
            when :publication_date
              result[field] = published_date_range(value, value)
            when :peer_reviewed
              result[field] = 'true'
            else
              result[field] = value
          end
        end
      end

      # It should look like this:
      #   params[:f_inclusive][library_facet][Alderman]=1
      # It comes through this way:
      #   { "library_facet" => { "Alderman" => "1" } }
      (params[:f_inclusive] || {}).each_pair do |facet, values|
        values = values.keys if values.is_a?(Hash)
        add_advanced_facet!(facet, values, result)
      end

      # Translate 'q' to the appropriate search field if applicable.
      q = params[:q]
      unless null_search_term?(q)
        field = params[:search_field] || (music_lens? ? :music : :keyword)
        result[field] = q
      end

      # Include some additional fields from params in the result.
      result.reject! { |_, v| v.blank? }
      if result.present?
        other_keys   = %w(op sort_key undiscoverable).map(&:to_sym)
        added_fields = params.slice(*other_keys).reject { |_, v| v.blank? }
        result.merge(added_fields)
      end

    end

    # facet_to_search_field
    #
    # @param [Symbol, String] facet
    #
    # @return [Symbol]
    # @return [nil]
    #
    def facet_to_search_field(facet)
      FACET_TO_SEARCH_FIELD[facet.to_s.to_sym]
    end

    # facet_to_advanced_field
    #
    # @param [Symbol, String] facet
    #
    # @return [Symbol]
    # @return [nil]
    #
    def facet_to_advanced_field(facet)
      name = facet.to_s.sub(/_facet$/, '')
      name.to_sym if advanced_search_fields.keys.include?(name)
    end

    # Expose the parts of a range value from the URL parameters associated
    # with the start/end of the range if available.  If the individual range
    # components are not available, attempt to extract them from the single
    # URL range display parameter.
    #
    # @param [Symbol] field
    # @param [Hash]   url_params      Default: `params`
    #
    # @return [Hash{Symbol=>String}]
    #
    def range_value(field, url_params = nil)
      url_params ||= params
      first, last =
        if url_params[field]
          url_params[field].to_s.split(' - ')
        else
          %w(start end).map { |p| url_params["#{field}_#{p}"] }
        end
      { start: first.to_s, end: last.to_s }
    end

    # Produce a date range from a "publication era" value.
    #
    # @param [String] publication_era
    #
    # @return [String]
    #
    def publication_era_range(publication_era)
      now  = DateTime.now
      last = now.year
      first =
        case publication_era.to_s.downcase
          when /last (\d+) months/ then (now - $1.to_i.months).year
          when /last (\d+) years/  then last - $1.to_i
          else                          last
        end
      published_date_range(first, last)
    end

    # Produce a date range.
    #
    # @param [String] first
    # @param [String] last
    #
    # @return [String]
    #
    def published_date_range(first, last = nil)
      first  = first.to_s
      last &&= last.to_s
      last ||= first
      first.include?(' - ') ? first : "#{first} - #{last}"
    end

  end

end
