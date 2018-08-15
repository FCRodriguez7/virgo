# app/controllers/concerns/access_any_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving search and access to any kind of
# item based on UVA::IndexDoc.
#
module AccessAnyConcern

  extend ActiveSupport::Concern

  # Hints for RubyMine (skipped during execution).
  include Blacklight::Catalog unless ONLY_FOR_DOCUMENTATION

  include UVA
  include UVA::BlacklightOverride
  include UVA::Scope
  include UVA::Helper::AdvancedSearch
  include UVA::Helper::Constraints
  include UVA::Helper::Export
  include UVA::Helper::Facets

  # ===========================================================================
  # :section: Blacklight::Catalog overrides
  # ===========================================================================

  public

  # This nullifies the Blacklight method to prevent any changes to the session
  # after the template has been rendered.  This logic has been moved into
  # AccessIndexConcern#get_document_list so that the total number of results
  # can be included in the `session` variable as soon as possible.
  #
  # @return [void]
  #
  # === Usage Notes
  # This is called as an after_filter from CatalogController and
  # ArticlesController.
  #
  # @see Blacklight::Catalog#set_additional_search_session_values
  #
  def set_additional_search_session_values
  end

  # This nullifies the Blacklight method in order to defer the updating of
  # `session[:search]` until `session` is settled and any redirect(s) will have
  # already occurred.
  #
  # @return [nil]
  #
  # === Usage Notes
  # This is called as a before_filter by controllers which include module
  # Blacklight::Catalog.
  #
  # @see Blacklight::Catalog#delete_or_assign_search_session_params
  #
  def delete_or_assign_search_session_params
  end

  # This seems to be unused in Blacklight; this override ensures that invoking
  # the method does not result in needlessly adding :results_view into
  # `session[:search]`.
  #
  # @return [nil]
  #
  # === Usage Notes
  # This is called by controllers which include module Blacklight::Catalog
  # that have not overridden Blacklight::Catalog#update.
  #
  # @see Blacklight::Catalog#adjust_for_results_view
  #
  def adjust_for_results_view
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Attempt to fix imbalanced double quotes if a query was supplied.
  #
  # @param [Hash] url_params          Default: `params`.
  #
  # @return [String]                  Corrected search string.
  # @return [nil]                     No user search string in *url_params*.
  #
  def update_query!(url_params = nil)
    url_params ||= params
    q = url_params[:q]
    url_params[:q] = balance_double_quotes(q) unless null_search_term?(q)
  end

  # Accumulator for the URL parameters to be used for redirection after
  # "before" filters have been run.
  #
  # @param [String, Hash] url
  #
  # @return [true]                    Default setting which will cause the
  #                                     final state of `params` to be used by
  #                                     self#conditional_redirect.
  # @return [false]                   Setting by an intermediate filter
  # @return [String]
  # @return [Hash]
  #
  # @see self#conditional_redirect
  #
  def will_redirect(url = nil)
    if url.present?
      session[:redirect] = url
    else
      session[:redirect] ||= true
    end
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # update_show_page_context
  #
  # @param [String, Hash] redirect_path
  #
  # @return [void]
  #
  def update_show_page_context(redirect_path = nil)
    extract_search_properties!
    set_search_counter
    will_redirect(redirect_path || portal_show_path)
  end

  # Restores the proper page counter if browser "back" is performed.
  #
  # @return [void]
  #
  # @see self#update_show_page_context
  # @see ArticlesController#update_show_page_context
  #
  def adjust_for_search_context
    update_show_page_context if params[:index] || params[:counter]
  end

  # Controls whether user sees show/hide metadata feature.
  #
  # @return [void]
  #
  def adjust_for_full_view
    return unless params.key?(:full_view)
    if true_value?(params.delete(:full_view))
      session[:full_view] = true
    else
      session.delete(:full_view)
    end
    will_redirect
  end

  # Validate posted form data and redirect back if there were errors.
  #
  # @return [void]
  #
  def validate_advanced
    return unless params[:commit] == 'Search'
    errors = []
    advanced_range_values(params, errors)
    if errors.present?
      # Display validation errors on the advanced search form.
      flash[:error] = errors
      redirect_to :back
    elsif params[:op].to_s.upcase == 'AND'
      # Clean up the default Solr logical operation indicator.
      params.delete(:op)
      will_redirect
    end
  end

  # For RSS, defaults to 'received' unless specified as 'published'.
  # For :digital_collection_facet, defaults to 'published'.
  # Otherwise, default to 'relevancy' but only if there was a query.
  # As a fallback, sort on 'received'
  #
  # @return [void]
  #
  def resolve_sort
    return if home_page?
    sort_key  = params[:sort_key]
    relevancy = relevancy_sort_key
    received  = date_received_sort_key
    published = 'published'
    if rss_view?
      # Special case for RSS; otherwise sort by date_received.
      sort_key = received unless sort_key == published
    elsif extended_query_terms.present?
      # If there is a query, sort by relevancy unless a sort was specified.
      sort_key = relevancy unless sort_key.present?
    else
      # If there is no query, sorting by relevancy doesn't make sense; by
      # default, sort digital collections by published date.
      dig_coll = params[:f] && params[:f].include?(:digital_collection_facet)
      def_sort = dig_coll ? published : received
      sort_key = def_sort if sort_key.blank? || (sort_key == relevancy)
    end
    params[:sort_key] = sort_key
  end

  # Clean up URL parameters and redirect.
  #
  # This eliminates "noise" parameters injected by the advanced search forms
  # and other situations where empty or unneeded parameters accumulate.
  #
  # In addition, this filter corrects "old-style" facets which are often
  # generated by robots harvesting links from external web pages that have old
  # Virgo search links.  Two prominent cases are:
  #
  # @example Peer-reviewed facet
  #   "f[tlevel][0]=peer_reviewed" is rewritten as "f[tlevel][]=peer_reviewed"
  #
  # @example Format facets with non-array values
  #   "f[subject_facet]=value" is rewritten as "f[subject_facet][]=value"
  #
  # @see UVA::Helper::Constraints#remove_filter_link
  #
  def cleanup_parameters

    changed = false
    original_size = params.size

    # Adjust exclusive facet values if necessary.
    key = :f
    if params.key?(key)
      old = params[key]
      if !old.is_a?(Hash)
        # A bad parameter, probably generated either mistakenly or maliciously
        # by an outside search site.
        params.delete(key)
        Rails.logger.info {
          "#{__method__}: rejecting #{key}=#{old.inspect}"
        }
      elsif old.values.any? { |v| !v.is_a?(Array) }
        # Fix old-style facet references by ensuring that facet values are in
        # the form of an array.
        params[key] = new =
          old.map { |facet, value|
            value = value.first.last if value.is_a?(Hash)
            value = Array.wrap(value)
            [facet, value]
          }.to_h
        changed = true
        Rails.logger.debug {
          "#{__method__}: #{key}=#{old.inspect} -> #{key}=#{new.inspect}"
        }
      end
    end

    # Adjust inclusive facet values if necessary.
    key = :f_inclusive
    if params.key?(key)
      old = params[key]
      if !old.is_a?(Hash)
        # A bad parameter, probably generated either mistakenly or maliciously
        # by an outside search site.
        params.delete(key)
        Rails.logger.info {
          "#{__method__}: rejecting #{key}=#{old.inspect}"
        }
      elsif old.values.any? { |v| !v.is_a?(Hash) }
        # Fix "Virgo Classic" lens browse library facet references.
        params[key] = new =
          old.map { |facet, value|
            unless value.is_a?(Hash)
              values = Array.wrap(value)
              next if values.include?('*')
              value = values.map { |v| [v, '1'] }.uniq.to_h
            end
            [facet, value]
          }.compact.to_h
        changed = true
        Rails.logger.debug {
          "#{__method__}: #{key}=#{old.inspect} -> #{key}=#{new.inspect}"
        }
      end
    end

    # Rewrite search from search box.
    if params[:controller] == catalog_portal
      select = params[:catalog_select]
      if [articles_portal, catalog_portal].include?(select)
        params[:controller] = articles_portal if select == articles_portal
        params.delete(:catalog_select)
      end
    end

    # Eliminate hidden form fields that are not needed for search and empty
    # parameters (keys with no values or values with no keys).
    params.delete_if { |k, v| k.blank? || v.blank? }
    %w(utf8).each { |k| params.delete(k) }
    reset_search = (params.delete(:commit) == 'Search')

    # If parameters are clean, save them now in `session[:search]`; otherwise
    # redirect to the corrected URL.
    if changed || (params.size != original_size)
      will_redirect
    else
      reset_search ||= home_page? || new_search?
    end
    if reset_search && !print_view?
      clear_search_context
      clear_search_session
    end
  end

  # To be run after all before_filters that modify params and require a
  # redirect in order to "correct" the Virgo URL.
  #
  # @return [void]
  #
  # @see self#will_redirect
  #
  def conditional_redirect
    path = session.delete(:redirect)
    path = params     if path.is_a?(TrueClass)
    redirect_to(path) if path.present?
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  protected

  # Indicate whether search parameters have changed within the same search
  # context.
  #
  # If this is *true* then `session[:portal]` will be wiped, which means that
  # all "Switch to" links will be re-created based on a translation of the
  # current search.
  #
  # If this is *false* then searches saved in `session[:portal]` will be used
  # for the "Switch to" links to preserve search fields and facet selections
  # which would be lost in translation.
  #
  def new_search?
    current_portal = current_portal_key
    if search_context == current_portal
      old_params = without_search_refinements(search_session(current_portal))
      new_params = without_search_refinements(params)
      old_params != new_params
    end
  end

  # URL parameters that are treated as "search refinements", that is, if only
  # one or more of these parameters have changed then the current search is not
  # considered a "new" search which would trigger a reset of `session[:portal]`
  SEARCH_REFINEMENTS = [
    :action,
    :controller,
    :counter,
    :index,
    :peer_reviewed,
    :per_page,
    :sort_key,
    :total,
  ].freeze

  # Remove URL parameters that are treated as "search refinements".
  #
  # @param [Hash] url_params
  #
  # @return [Hash]
  #
  # @see self#SEARCH_REFINEMENTS
  # @see self#new_search?
  #
  def without_search_refinements(url_params)
    remove_tlevel!(url_params.except(*SEARCH_REFINEMENTS).rdup)
  end

end
