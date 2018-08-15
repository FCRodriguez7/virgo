# lib/uva/illiad/session.rb

require 'uva'

# Support for web access to ILLiad.
#
# === References
# For information on the web API functionality see the following:
# @see https://prometheus.atlas-sys.com/display/illiad/ILLiad+Web+DLL+Tags
# @see https://prometheus.atlas-sys.com/display/illiad/Customizing+the+Web+Interface
# @see https://www.oclc.org/developer/develop/web-services/worldcat-knowledge-base-api/openurl-resource.en.html
#
module UVA::Illiad

  # UVA::Illiad::Session
  #
  # An instance of this type is stored in the session to track which system
  # should be the target of ILLiad requests.
  #
  class Session

    include UVA
    include UVA::Illiad

    # =========================================================================
    # :section: Attributes
    # =========================================================================

    public

    # Get the specifier for the selected ILLiad entry.
    #
    # @return [String]
    #
    attr_accessor :selection

    # The document associated with the current ILLiad session.
    #
    # @return [SolrDocument]
    # @return [nil]
    #
    attr_accessor :document

    # The document URL associated with the current ILLiad session.
    #
    # @return [String]
    # @return [nil]
    #
    attr_accessor :referrer

    # If *true*, the session ID is indexed by :sid_ivy; otherwise by :sid.
    #
    # @return [Boolean]
    #
    attr_accessor :ivy

    # Get a label describing the selected ILLiad.
    #
    # @return [String]
    #
    def label
      @config[:label]
    end

    # Get the hostname for the selected ILLiad.
    #
    # @return [String]
    #
    def host
      @config[:host]
    end

    # Get the request queue for the selected ILLiad.
    #
    # @param [Symbol]  sid            Default: :sid.
    #
    # @return [String]
    #
    def queue(sid = nil)
      case sid
        when true  then sid = :sid_ivy
        when false then sid = :sid
        when nil   then sid = @ivy ? :sid_ivy : :sid
      end
      @config[sid]
    end

    # Indicate whether OpenURL should be used with the selected ILLiad.
    #
    def openurl?
      !!@config[:openurl]
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Initialize a new Session.
    #
    # @param [String]       illiad_key    ILLiad entry specifier.
    # @param [SolrDocument] doc           Item associated with current session.
    # @param [String]       referring_url Canonical URL for *doc*.
    # @param [Boolean]      ivy
    #
    # @raise [ArgumentError]          If api_command is missing.
    #
    def initialize(illiad_key = nil, doc = nil, referring_url = nil, ivy = nil)
      @selection = illiad_key || DEFAULT_KEY
      @document  = doc
      @referrer  = referring_url
      @ivy       = !!ivy
      @config    = CONFIGURATION[@selection]
      unless @config
        raise ArgumentError, "Invalid argument: illiad_key='#{@selection}'"
      end
    end

    # General request for an item.
    #
    # @param [SolrDocument] doc           Requested item.
    # @param [String]       referring_url Virgo item details show page.
    # @param [Boolean]      ivy_request   If true, request is for Ivy Stacks.
    #
    # @return [String]                ILLiad request URL for item.
    #
    def request_url(doc = nil, referring_url = nil, ivy_request = nil)
      unless doc && doc.is_a?(SolrDocument)
        referring_url = doc
        doc           = nil
      end
      unless referring_url && referring_url.is_a?(String)
        ivy_request   = referring_url
        referring_url = nil
      end
      doc           ||= @document
      referring_url ||= @referrer
      sid = queue(ivy_request)
      if openurl?
        openurl_url(doc, referring_url, sid)
      else
        action_url(CMD_REQUEST_LEO, doc, referring_url, sid)
      end
    end

    # Get the OpenURL version of the ILLiad request URL.
    #
    # @param [SolrDocument] document       Requested item.
    # @param [String]       sid            Session ID.
    # @param [String]       referring_url  Virgo item details show page.
    #
    # @return [String]
    #
    def openurl_url(document, sid = nil, referring_url = nil)
      sid ||= queue
      query = create_query(true, document, sid, referring_url)
      illiad_url(OPENURL_PATH, query)
    end

    # Get the ILLiad URL for an action.
    #
    # @param [Array<(Numeric, Numeric, String)>] command
    # @param [SolrDocument] document       Requested item.
    # @param [String]       sid            Session ID.
    # @param [String]       referring_url  Virgo item details show page.
    #
    # @return [String]
    #
    # @raise [ArgumentError]          If api_command is missing
    #
    def action_url(command, document = nil, sid = nil, referring_url = nil)
      # Validate arguments
      raise ArgumentError, 'missing "command" argument' unless command
      sid ||= queue

      # Construct the URL query from the command value(s)
      action, form, value = command
      query =  query_part('Action', action, nil)
      query << query_part('Form',   form)
      query << query_part('Value',  value)
      query << create_query(false, document, sid, referring_url) if document

      # Return the full ILLiad URL
      illiad_url(STANDARD_PATH, query)
    end

    # Generate the entire URL that leads to a filled-out ILLiad form.
    #
    # @param [String] path            The path portion of the URL.
    # @param [String] query           The query portion of the URL.
    #
    # @return [String]
    #
    def illiad_url(path, query = nil)
      URI::HTTPS.build(host: host, path: path, query: query).to_s
    end

    # Get the base ILLiad URL with no query portion.
    #
    # @return [String]
    #
    def base_url
      illiad_url(STANDARD_PATH)
    end

    # =========================================================================
    # :section: ILLiad Request URL
    # =========================================================================

    public

    #--
    # rubocop:disable Style/SingleLineMethods
    #++

    def about_url;                action_url(CMD_ABOUT);              end
    def about_faq;                action_url(CMD_FAQ);                end
    def main_menu_url;            action_url(CMD_MAIN_MENU);          end
    def logoff_url;               action_url(CMD_LOGOFF);             end

    # -------------------------------------------------------------------------
    # ILLiad scanning requests
    # -------------------------------------------------------------------------

    def scan_pdf_url;             action_url(CMD_SCAN_PDF);           end
    def scan_pdf_collab_url;      action_url(CMD_SCAN_COLLAB);        end

    # -------------------------------------------------------------------------
    # ILLiad account status
    # -------------------------------------------------------------------------

    def all_requests_url;         action_url(CMD_VIEW_ALL);           end
    def active_requests_url;      action_url(CMD_VIEW_OUTSTANDING);   end
    def cancelled_requests_url;   action_url(CMD_VIEW_CANCELLED);     end
    def checkouts_url;            action_url(CMD_VIEW_CHECKED_OUT);   end
    def downloads_url;            action_url(CMD_VIEW_DOWNLOADS);     end
    def notifications_url;        action_url(CMD_VIEW_NOTIFICATIONS); end

    # -------------------------------------------------------------------------
    # ILLiad account maintenance
    # -------------------------------------------------------------------------

    def user_registration_url;    action_url(CMD_USER_REGISTRATION);  end
    def user_information_url;     action_url(CMD_USER_INFORMATION);   end
    def user_accounts_url;        action_url(CMD_USER_ACCOUNTS);      end
    def user_password_change_url; action_url(CMD_USER_PWD_CHANGE);    end
    def user_password_forget_url; action_url(CMD_USER_PWD_FORGET);    end
    def user_password_new_url;    action_url(CMD_USER_PWD_NEW);       end

    #--
    # rubocop:enable Style/SingleLineMethods
    #++

    # -------------------------------------------------------------------------
    # ILLiad system status
    # -------------------------------------------------------------------------

    def system_info_url
      illiad_url(STANDARD_PATH, 'GetBuildInfo')
    end

  end

end
