# lib/uva/helper/articles.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::Articles
  #
  module Articles

    include UVA
    include UVA::Cache
    include UVA::Helper::LoginSession

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Number of times to attempt to acquire results from the article search
    # provider.
    DEFAULT_ARTICLE_ATTEMPTS = 2

    # If true, general searches should be limited to peer-reviewed articles by
    # default (except in the case of advanced search, where this will be
    # determined explicitly by the user).
    DEFAULT_PEER_REVIEWED = true

    # =========================================================================
    # :section: Item details show page buttons
    # =========================================================================

    public

    # full_text_buttons
    #
    # @param [UVA::ArticleDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def full_text_buttons(doc)
      return unless doc.is_a?(UVA::ArticleDoc) && doc.full_text?
      login_needed = doc.download_text.blank?
      lbl = 'Full&nbsp;Text'.html_safe
      url = '#full-text'
      tip = 'Skip to full text of this article'
      triples = [[lbl, url, tip]]
      make_article_buttons(triples, '_top', login_needed)
    end

    # download_buttons
    #
    # @param [UVA::ArticleDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def download_buttons(doc)
      return unless doc.is_a?(UVA::ArticleDoc) && doc.download_formats.present?
      login_needed =
        doc.download_links.blank? || doc.download_links.first.url.blank?
      triples =
        if login_needed
          doc.download_formats.map do |format|
            lbl = format.html_safe.presence || 'Download'.html_safe
            url = '#'
            tip = lbl
            [lbl, url, tip]
          end
        else
          doc.download_links.map do |dl|
            lbl = dl.text.html_safe.presence
            url = dl.url
            tip = 'Download this article'.html_safe
            tip << " in #{lbl} format" if lbl
            lbl ||= 'Download'.html_safe
            [lbl, url, tip]
          end
        end
      make_article_buttons(triples, '_blank', login_needed)
    end

    # =========================================================================
    # :section: Item details show page buttons
    # =========================================================================

    protected

    # must_sign_in
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def must_sign_in
      UVA::Article::Ebsco::PLEASE_SIGN_IN.html_safe
    end

    # make_article_buttons
    #
    # Additionally, this contributes each link to the "skip navigation" menu.
    #
    # @param [Array<Array<(String,String,String)>>] triples
    # @param [String]                               target
    # @param [Boolean]                              login_needed
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]
    #
    def make_article_buttons(triples, target, login_needed)
      html_opt = {
        class: 'download-button'
      }
      html_opt[:class] << ' ' << 'link-disabled' if login_needed

      login_note  = ('login required'        if login_needed)
      extern_note = ('opens in a new window' if target == '_blank')

      triples.map { |triple|
        label, path, tooltip = triple
        if login_note
          tooltip += " (#{login_note})"
        elsif extern_note
          tooltip += " (#{extern_note})"
        end
        opt = { title: tooltip, target: target }
        skip_nav << link_to(label, path, opt)
        link_to(label, path, opt.merge(html_opt))
      }.join.html_safe
    end

    # =========================================================================
    # :section: Search API access
    # =========================================================================

    public

    # Number of times to attempt to make a request (including the first
    # attempt). This value should be greater than 0.
    #
    # @return [Fixnum]
    #
    def max_article_attempts
      DEFAULT_ARTICLE_ATTEMPTS
    end

    # Send a search request to the article provider.
    #
    # @param [Hash, String] search_params  Article search params or article id;
    #                                        if no value is given `params` is
    #                                        used.
    #
    # @return [Array<UVA::ArticleDoc::Response, nil>]
    #   If there was a failure to retrieve the item(s).
    #
    # @return [Array<UVA::ArticleDoc::Response, UVA::ArticleDoc>]
    #   If a single item was specified (*id* is a String).
    #
    # @return [Array<UVA::ArticleDoc::Response, Array<UVA::ArticleDoc>>]
    #   If multiple items are expected (*id* is an Array or *search_params* is
    #   a Hash).
    #
    def get_article_results(search_params = nil)

      # To properly leverage caching, requests for multiple items are handled
      # by invoking this method on each item separately then combining the
      # results into a single response.
      if search_params.is_a?(Array)
        article_ids = search_params
        to_delete = []
        response = nil
        articles =
          article_ids.map { |id|
            next if id.blank?
            article_response, article = get_article_results(id)
            next unless article_response.ok?
            response = article_response
            to_delete << id unless article
            article
          }.compact
        to_delete.each { |id| article_ids.delete(id) }
        response.docs = articles if response
        return response, articles
      end

      # If an *id* was provided, retrieve the indicated article; otherwise
      # perform a search with the given search parameters (or `params` by
      # default).
      id = nil
      case search_params
        when Hash
          dbid = search_params[:dbid]
          an   = search_params[:an]
          id = "#{dbid}:#{an}" if dbid.present? && an.present?
        when String
          id = search_params
        else
          search_params = params
      end
      search_params = id ? {} : normalize_search_query(search_params)

      # Send the request the article search provider, retrying if necessary.
      # (Each iteration will have new session :headers.)
      response = articles = nil
      max_article_attempts.times do
        if response
          restart_article_session
        elsif !session.key?(:ae_auth)
          start_article_session
        end
        ae = article_engine
        is_guest = authorized? ? 'n' : 'y'
        cache_params = search_params.merge(guest: is_guest)
        cache_params = Articles.generate_cache_params(ae, id, cache_params)
        response, articles =
          cache_fetch(cache_params) do
            request_params = search_params.merge(headers: session[:headers])
            request_params[:params]  ||= params.rdup
            request_params[:session] ||= session.to_hash
            if id
              ae.get_article_by_id(id, request_params)
            else
              ae.get_article_search_results(request_params)
            end
          end
        break if response.ok?
        articles = nil
        cache_discard(cache_params)
      end
      return response, articles
    end

    # Get a specific article from a list of articles.
    #
    # @param [Fixnum] index           Position of the item in the results list.
    # @param [Hash]   search_params
    #
    # @return [UVA::ArticleDoc]
    # @return [nil]                   If *index* was *nil* or the item could
    #                                   not be retrieved.
    #
    # Compare with:
    # @see UVA::Solr#get_single_doc_via_search
    #
    def get_article_by_index(index, search_params = nil)

      return if index.blank?

      # Create a temporary set of query parameters to pass to the
      # get_article_results method, adding in the article_index.
      skip = [:controller, :action, :id, :catalog_select, :counter, :total]
      search_params ||= params
      search_params = search_params.except(*skip).reject { |_, v| v.blank? }
      search_params[:index] = index

      # Get the article.
      _response, article = get_article_results(search_params)
      article.is_a?(Array) ? article.first : article

    end

    # =========================================================================
    # :section: Session management
    # =========================================================================

    public

    # This method will set the article engine if it is not already set, or
    # return the default engine.
    #
    # @param [String] ae              Selected article engine.
    #
    # @return [Module]                The new current article engine.
    #
    def article_engine(ae = nil)

      # Determine the current engine and the engine to switch to.
      current_ae = UVA::Article.provider
      new_ae = ae || session[:ae] || UVA::Article::DEFAULT_PROVIDER

      # EBSCO requires a session be opened and closed. We will open a session
      # when the EBSCO article engine is chosen and close that session if and
      # when another article provider is chosen.
      unless new_ae == current_ae
        stop_article_session  if current_ae
        session[:ae] = new_ae
        start_article_session if new_ae
      end

      # Return with the current engine.
      UVA::Article.engine

    end

    # Begin a session with the article provider.
    #
    # @return [void]
    #
    # @see UVA::Article::Engine#start_session
    #
    def start_article_session
      engine = UVA::Article.set_engine(session[:ae])
      if engine
        session[:ae_auth] = authorized = logged_in? || on_grounds?
        session[:headers] = engine.start_session(!authorized)
      end
      session.delete(:headers) if session[:headers].blank?
    end

    # End the current session with the article provider.
    #
    # @return [void]
    #
    # @see UVA::Article::Engine#stop_session
    #
    def stop_article_session
      engine = UVA::Article.engine
      engine.stop_session(session[:headers]) if engine
      session.delete(:ae_auth)
      session.delete(:headers)
    end

    # Start a new session with the article provider.
    #
    # @return [void]
    #
    def restart_article_session
      Rails.logger.info {
        "ARTICLES - restarting #{UVA::Article.provider_label} session..."
      }
      stop_article_session
      start_article_session
    end

    # Indicate whether the user is authorized for full access to articles (as
    # determined when the article session was established).
    #
    def authorized?
      session[:ae_auth]
    end

    # =========================================================================
    # :section: Search API access
    # =========================================================================

    private

    class << self

      include UVA
      include UVA::Cache

      IGNORED_PARAMETERS = [
        :canonical,
        :catalog_select,
        :complete,
        :controller,
        :counter,
        :format,
        :utf8,
        :view,
        :width,
      ].deep_freeze

      IGNORED_SETTINGS = {
        facet_sort: 'hits'
      }.deep_freeze

      DEFAULT_CACHE_OPT = {
        expires_in: SLOW_EXPIRE,
      }.deep_freeze

      # generate_cache_params
      #
      # @param [Module] ae
      # @param [String] id
      # @param [Hash]   search_params   May be modified.
      #
      # @return [Array<(String, Hash)>]
      #
      def generate_cache_params(ae, id, search_params)

        # Extract cache-specific options; what remains in *search_params* will
        # be used to generate the cache key.
        cache_opt = extract_cache_options(search_params)
        method = caller[0].to_s.sub(/^[^`]+`/, '').sub(/'$/, '')
        method = (cache_opt[:calling_method] ||= method)
        cache_opt[:namespace] ||= ae && ae.label.presence

        # Generate the cache key.
        search_params[:id] = id
        cache_key =
          search_params.map { |k, v|
            next if v.blank?
            k = k.to_sym
            next if IGNORED_PARAMETERS.include?(k)
            next if IGNORED_SETTINGS[k] == v.to_s
            %Q(#{k}=#{v.inspect})
          }.compact.sort.uniq.join(SPACE)
        Cache.log(:info, method) { "RAW ======> #{cache_key}" }
        cache_key = Digest::SHA2.hexdigest(cache_key)

        # Generate the rest of the cache options.
        Cache.log(:debug, method) { "KEY ======> #{cache_key}" }
        DEFAULT_CACHE_OPT.merge(cache_key: cache_key)

      end

    end

  end

end
