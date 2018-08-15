# lib/uva/fedora.rb

require 'uva'

module UVA

  # UVA::Fedora
  #
  module Fedora

    require 'rest_client'
    require 'nokogiri'

    include UVA

    XPATH_RESULT = "//*[local-name()='result']".freeze
    XPATH_OBJECT = "./*[local-name()='object']/@uri".freeze
    XPATH_TITLE  = "./*[local-name()='supp']/text()[1]".freeze
    XPATH_DESC   = "./*[local-name()='desc']/text()[1]".freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Runs a SPARQL query on a Fedora object to get the PID for the title page
    # or other image that exemplifies the item.
    #
    # @param [String] repo_url        Base URL of the Fedora repository API.
    #
    # @param [String] pid             The PID of the Fedora aggregation
    #                                   object(the book, manuscript, etc. for
    #                                   which we want to display page images).
    #
    # @return [String]                If no RDF found then returns *pid*; if
    #                                   multiple PIDs were found only the first
    #                                   is returned.
    #
    def get_exemplar(repo_url, pid)

      return pid if repo_url.blank? || pid.blank?

      type = 'djatoka:jp2CModel'
      response = sparql_query_self(repo_url, pid, 'hasExemplar', type)
      unless response.to_s.include?('info:fedora')
        response = sparql_query_self(repo_url, pid, 'hasCatalogRecordIn', type)
      end

      # Because we've used format=CSV above, the response is in plain text
      # format with a header line and then one pid per line, like so:
      #
      #   "object"
      #   info:fedora/uva-lib:1234
      #   info:fedora/uva-lib:1235
      #   info:fedora/uva-lib:1236
      #
      # Convert to an array of pid values, as in
      # ["uva-lib:1234", "uva-lib:1235", "uva-lib:1236"].
      #
      # The Fedora response doesn't seem to return the pids in any particular
      # order, but order shouldn't matter as there should only be one entry per
      # item.  Fedora doesn't seem to offer anything akin to a METS
      # <structMap>, but we will split the pid grabbing the integer localname
      # and using it to build an ordered list.
      #
      # N.B.: The SPARQL query returns the word "object" with each query, and
      # this method looks for that.
      if response.to_s.include?('info:fedora')
        get_pids_from_csv(response).first
      else
        logger.debug { "#{__method__} failed: returning #{pid}" }
        pid
      end
    end

    # get_pids_from_sparql
    #
    # @param [String] response
    #
    # @return [Array<Hash{Symbol=>String}>]
    # @return [nil]                   - If *response* was nil.
    #
    def get_pids_from_sparql(response)
      return if response.blank?
      doc = Nokogiri::XML(response)
      if doc.errors.present?
        logger.warn { 'SPARQL query response XML parse errors' }
      end
      doc.xpath(XPATH_RESULT).map do |n|
        {
          pid:         n.xpath(XPATH_OBJECT).to_s.gsub(%r{info:fedora/}, ''),
          title:       n.xpath(XPATH_TITLE).text,
          description: n.xpath(XPATH_DESC).text
        }
      end
    end

    # Extract and sort pids from the response object.
    #
    # @param [String] response
    #
    # @return [Array<String>]
    #
    def get_pids_from_csv(response)
      response.to_s.sub(/"object"\s*/, '').split
        .map { |s| s.sub(%r{info:fedora/}, '') }
        .reject(&:blank?)
        .sort_by { |pid|
          if (digit = pid.index(/\d/))
            alpha  = pid[0, digit]
            number = pid[digit..-1].to_i
          else
            alpha  = pid
            number = 0
          end
          [alpha, number]
        }
    end

    # Runs a SPARQL query on Fedora objects to get pid(s) for objects
    # mentioning *pid*.
    #
    # @param [String] repo_url        Base URL of the Fedora repository API.
    # @param [String] pid             The PID of the Fedora object.
    # @param [String] relationship
    # @param [Hash]   options
    #
    # @option options [String] :type  Passes a content model to the Resource
    #                                     Index.
    # @option options [String] :supp
    # @option options [String] :desc
    # @option options [String] :limit Sets the number of results.
    #
    # @return [String]
    #
    # @note If this query returns nil, query for the first child object.
    #
    def sparql_query_others(repo_url, pid, relationship, options = {})

      supp  = options[:supp]
      desc  = options[:desc]
      type  = options[:type]
      limit = options[:limit] || '10000'

      # This Fedora URN will restrict queries to data objects (excludes
      # cModels, sDefs, etc.).
      type = 'fedora-system:FedoraObject-3.0' if type.blank?

      # Search the Fedora repository's Resource Index (using a SPARQL query)
      # to query an item's own RDF triples and select any values for
      # hasExemplar (triple should contain pid of another item which has a JP2K
      # stream).

      state = 'fedora-model:Active'
      pid   = "info:fedora/#{pid}"
      type  = "info:fedora/#{type}"
      relationship = "#{FEDORA_REST_URL}/relationships##{relationship}"

      terms = '$object'
      terms << ' $supp' if supp
      terms << ' $desc' if desc

      query = []
      query << "SELECT #{terms} FROM <#ri> WHERE {"
      query << "$object <fedora-model:state> <#{state}> ."
      query << "$object <fedora-model:hasModel> <#{type}> ." if type
      query << "$object <#{supp}> $supp ." if supp
      query << "$object <#{relationship}> <#{pid}> ."
      query << "OPTIONAL { $object <#{desc}> $desc . }" if desc
      query << "} ORDER BY $object limit #{limit}"

      sparql_query(repo_url, *query)
    end

    # Runs a SPARQL query on Fedora objects to get pid(s) for objects
    # mentioning *pid*.
    #
    # @param [String]  repo_url       Base URL of the Fedora repository API.
    # @param [String]  pid            The PID of the Fedora object.
    # @param [Boolean] placeholder
    #
    # @return [String]
    # @return [nil]
    #
    # @note If this query returns nil, query for the first child object.
    #
    def sparql_query_others_ead(repo_url, pid, placeholder = true)

      supp = 'dc:title'
      desc = 'dc:description'

      # Search the Fedora repository's Resource Index (using a SPARQL query)
      # to query an item's own RDF triples and select any values for
      # hasExemplar (triple should contain pid of another item which has a JP2K
      # stream).

      state = 'fedora-model:Active'
      pid   = "info:fedora/#{pid}"
      is_placeholder_for = "#{FEDORA_REST_URL}/relationships#isPlaceholderFor"
      has_dig_rep = "#{FEDORA_REST_URL}/relationships#hasDigitalRepresentation"

      terms = '$object $supp $desc'

      query = []
      query << "SELECT #{terms} FROM <#ri> WHERE {"
      if placeholder
        query << "$group <fedora-model:state> <#{state}> ."
        query << "<#{pid}> <#{is_placeholder_for}> $group ."
        query << "$group <#{has_dig_rep}> $object ."
      else
        query << "$object <fedora-model:state> <#{state}> ."
        query << "<#{pid}> <#{has_dig_rep}> $object ."
      end
      query << "$object <#{supp}> $supp ." if supp
      query << "OPTIONAL { $object <#{desc}> $desc . }" if desc
      query << '} ORDER BY $object'

      sparql_query(repo_url, *query)
    end

    # Runs a SPARQL query on Fedora object 'pid' to fetch references to objects
    # based on the specified relationship.
    #
    # @param [String] repo_url        Base URL of the Fedora repository API.
    # @param [String] pid             The PID of the Fedora object.
    # @param [String] rel             Fedora relationship.
    # @param [String] type            Passes a content model to the Resource
    #                                   Index.
    # @param [Fixnum] limit           Sets the number of results.
    #
    # @return [String]
    # @return [nil]
    #
    # @note If this query returns nil, query for the first child object.
    #
    def sparql_query_self(repo_url, pid, rel, type = false, limit = 1000)

      if !type.is_a?(FalseClass) && type.blank?
        type = 'fedora-system:FedoraObject-3.0'
      end

      # Search the Fedora repository's Resource Index (using a SPARQL query)
      # to query an items own RDF triples and select any values for hasExemplar
      # (triple should contain pid of another item which has a JP2K stream)

      state = 'fedora-model:Active'
      pid   = "info:fedora/#{pid}"
      type  = "info:fedora/#{type}" if type
      relationship = "#{FEDORA_REST_URL}/relationships##{rel}"

      terms = '$object'

      query = []
      query << "SELECT #{terms} FROM <#ri> WHERE {"
      query << "$object <fedora-model:state> <#{state}> ."
      query << "$object <fedora-model:hasModel> <#{type}> ." if type
      query << "<#{pid}> <#{relationship}> $object ."
      query << "} limit #{limit}"

      sparql_query(repo_url, *query, format: 'CSV')
    end

    # Determine if the indicated policy allows the target *ip_address* to
    # access the object associated with the policy.
    #
    # @param [String] repo_url        Base URL of the Fedora repository API.
    # @param [String] policy_pid      The PID of the Fedora policy object.
    # @param [String] ip_address      Client address to evaluate.
    #
    # @return [Array<(Boolean, String, String)>]
    #   - First result is "true" if access is blocked.
    #   - Second result is the policy name (may be *nil*).
    #   - Third result is a description of the policy (may be *nil*).
    #
    def does_policy_block_access(repo_url, policy_pid, ip_address)
      object =
        "/objects/#{policy_pid}/methods" \
        '/uva-lib%3AxacmlPolicySDef/getAccessForResourceWithIPAddress' \
        "?method=&ip-address=#{ip_address}"
      response = get_object(repo_url, object, default: 'Unknown')
      logger.debug { "#{object} ==> ''#{response}''" }

      blocked     = (response != 'Permit')
      label       = get_policy_label(repo_url, policy_pid)
      description = get_policy_description(repo_url, policy_pid)
      return blocked, label, description
    end

    # Get the name of the indicated policy.
    #
    # @param [String] repo_url        Base URL of the Fedora repository API.
    # @param [String] policy_pid      The PID of the Fedora policy object.
    #
    # @return [String]
    # @return [nil]
    #
    def get_policy_label(repo_url, policy_pid)
      get_datastream_value(repo_url, policy_pid, 'policyLabel')
    end

    # Get the description of the indicated policy.
    #
    # @param [String] repo_url        Base URL of the Fedora repository API.
    # @param [String] policy_pid      The PID of the Fedora policy object.
    #
    # @return [String]
    # @return [nil]
    #
    def get_policy_description(repo_url, policy_pid)
      get_datastream_value(repo_url, policy_pid, 'policyDescription')
    end

    # Get a value from a Fedora datastream.
    #
    # @param [String] repo_url        Base URL of the Fedora repository API.
    # @param [String] object_pid      The PID of a Fedora object.
    # @param [String] ds_id           Datastream identifier.
    # @param [Hash]   opt             Options for #get_object.
    #
    # @return [String]
    # @return [nil]
    #
    def get_datastream_value(repo_url, object_pid, ds_id, opt = nil)
      path = "/objects/#{object_pid}/datastreams/#{ds_id}/content"
      result = get_object(repo_url, path, opt)
      result.strip if result.present?
    end

    # Performs a SPARQL query.
    #
    # @param [String]        repo_url   Base URL of the Fedora repository API.
    # @param [Array<String>] statement  May end with #get_object option hash.
    #
    # @return [String]
    #
    def sparql_query(repo_url, *statement)
      opt   = statement.last.is_a?(Hash) ? statement.pop.dup : {}
      fmt   = opt.delete(:format) || 'Sparql'
      query = CGI.escape(statement.compact.join(SPACE))
      path  = "/risearch?type=tuples&lang=sparql&format=#{fmt}&query=#{query}"
      get_object(repo_url, path, opt)
    end

    # Get object from Fedora.
    #
    # @param [String] repo_url
    # @param [String] repo_path
    # @param [Hash]   opt
    #
    # @option opt [String] :default   *nil* if not specified.
    # @option opt [String] :user      FEDORA_USERNAME if not specified.
    # @option opt [String] :password  FEDORA_PASSWORD if not specified.
    #
    # @return [String]
    # @return [opt[:default]]         If the value was not acquired or if the
    #                                   value was blank.
    #
    def get_object(repo_url, repo_path, opt = nil)
      opt = opt ? opt.dup : {}
      default = opt.delete(:default)
      opt[:user]     ||= FEDORA_USERNAME
      opt[:password] ||= FEDORA_PASSWORD
      resource = RestClient::Resource.new(repo_url, opt)
      result = resource[repo_path].get
      result.blank? ? default : result.strip
    rescue SocketError, EOFError
      raise # Handled by ApplicationController
    rescue Exception => e
      logger.debug { "#{__method__}: #{e}: #{e.message}" }
      default
    end

  end

end
