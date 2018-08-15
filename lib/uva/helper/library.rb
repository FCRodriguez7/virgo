# lib/uva/helper/library.rb

require 'uva'

module UVA::Helper

  # UVA::Library
  #
  module Library

    include UVA
    include UVA::Helper::Links

    extend self

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # All libraries listed by Solr and/or Sirsi (Firehose).
    LIBRARY_TABLE_PATH = 'lib/config/library.yml'.freeze

    # Used to signify all library facet values are applicable.  When received
    # by AccessAnyConcern#cleanup_parameters this causes the library facet
    # parameter to be removed.
    ALL_LIBRARIES = '*'.freeze

    # Used to signify a combination of UVA Libraries.  When received
    # by AccessAnyConcern#cleanup_parameters this causes the library facet
    # parameter to be removed.
    UVA_LIBRARIES = 'UVA'.freeze

    # Used to signify 'UVA-LIB' for online items.
    UVA_ONLINE_ONLY = 'UVA online'.freeze

    # Informational link for Clemons renovation closure.
    CLEMONS = {
      label:  'Learn more',
      title:  'Learn more about accessing collections during Clemons ' \
                'construction',
      url:    'http://xxx.virginia.edu/xxx/' \
                'clemons-library-will-continue-service-during-summer-closure'
    }.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    class << self
      include ActionView::Helpers::UrlHelper
    end

    # Overrides for availability information based on the status of an item's
    # library, location or other workflow-related status.  Each array entry is
    # a hash with the following fields:
    #
    #   name:                 [String]    - Currently for documentation
    #                                         purposes only.
    #   active:               [Boolean]   - If *false* (or missing) then the
    #                                         entry is ignored.
    #   condition:            [Hash]      - Availability properties that
    #                                         determine whether the status
    #                                         entry applies to a given item.
    #   status_note:          [String]    - Text to display after the
    #                                         availability listing; if *nil*
    #                                         then no text will be displayed.
    #   availability_mode:    [String]    - The CSS class for availability
    #                                         text; if *nil* then this value
    #                                         will be determined as usual.
    #   availability_label:   [String]    - String to use as the availability
    #                                         label; if *nil* then this value
    #                                         will be determined as usual.
    #   make_status_markers:  [Boolean]   - If *true*, the shelf browse item
    #                                         tile shows a 'U' marker.
    #
    # The :condition entry may have any combination of the following keys:
    #
    #   :library
    #   :home_location
    #   :current_location
    #
    # If the condition does *not* have a value for one of the keys then it is
    # not used to limit the number of matches -- specifically, if the condition
    # is an empty Hash then it matches *all* possible holdings and the workflow
    # status will apply to all holdings.
    #
    # If the value is a String or a Regexp, then only holdings matching that
    # pattern will be selected.
    #
    # If the value is an Array<String>, then holdings matching any of the array
    # elements will be selected.  If the first entry of the array is 'NOT',
    # then the match is reversed -- only holdings matching *none* of the array
    # elements will be selected.
    #
    # @see self#workflow_status
    # @see self#status_note
    # @see UVA::Helper::Availability#availability_mode
    # @see UVA::Helper::Availability#availability_label
    # @see UVA::Helper::ShelfBrowse#make_status_markers
    #
    WORKFLOW_STATUS = [

      {
        name:        'Music Library temporary closure',
        active:      false,
        condition:   { library: 'MUSIC' },
        status_note: %Q(
          Music Library items are temporarily unavailable due to facilities
          work.
          Music Library materials will be available when the building reopens
          on August 14, 2017.
          For more information or assistance, please see the
          #{out_link('Music Guide', URL::MUSIC_GUIDE)}.
        ).squish.html_safe,
        availability_mode:   'unavailable',
        make_status_markers: true,
      },

      CLEMONS_STATUS = {
        name:        'Clemons temporary closure',
        active:      true,
        condition:   { library: 'CLEMONS' },
        status_note: %Q(
          Clemons Library is closed to the public during Summer 2018.
          [&hairsp;#{
            out_link(CLEMONS[:label], CLEMONS[:url], title: CLEMONS[:title])
          }&hairsp;]
        ).squish.html_safe
      },

      CLEMONS_BY_REQUEST = {
        name:        'Clemons temporary closure - By request from Ivy Annex',
        active:      CLEMONS_STATUS[:active],
        condition:   { library: 'CLEMONS', current_location: 'BY-REQUEST' },
        status_note: %Q(
          To request titles normally found only in Clemons, please use the
          "<strong>Request from Ivy</strong>" button;
          <br/>
          when necessary, use "<strong>Request Item</strong>" to recall an item
          currently checked-out to another patron.
        ).squish.html_safe
      },

      CLEMONS_BY_REQUEST.merge(
        name:        'Clemons temporary closure - By request checked-out',
        condition:   { library: 'CLEMONS', current_location: 'CHECKEDOUT',
                       home_location: 'BY-REQUEST' }
      ),

      {
        name:        'Clemons temporary closure - Clemons Reserve items',
        active:      CLEMONS_STATUS[:active],
        condition:   { library: 'CLEMONS', current_location: 'CLEM-RESV' },
        status_note: %Q(
          Clemons Reserves items will be unavailable until mid-August.
        ).squish.html_safe,
        availability_mode:   'unavailable',
        availability_label:  'Unavailable',
        make_status_markers: true,
      },

      {
        name:        'Medium rare items',
        active:      true,
        condition:   { library: 'IVY', home_location: 'LOCKEDSTKS' },
        status_note: %Q(
          This item does not circulate.
          When you request this item, it will be delivered to the
          #{out_link('Small Special Collections Library', URL::SC_LIBRARY)}
          for use in the Reading Room only.
        ).squish.html_safe
      },

      {
        name:        'Medium rare delivered items',
        active:      true,
        condition:   { library: 'SPEC-COLL', home_location: 'LOCKEDSTKS' },
        status_note: %Q(
          This item has been delivered to the
          #{out_link('Small Special Collections Library', URL::SC_LIBRARY)}
          Reading Room.
        ).squish.html_safe
      },

    ].deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The library code derived from the given argument.
    #
    # @param [Firehose::Holding, Firehose::Library, String] arg
    #
    # @return [String]
    # @return [nil]                   For invalid argument types.
    #
    def library_code(arg)
      case arg
        when String            then arg.upcase
        when Firehose::Library then arg.code
        when Firehose::Holding then arg.library.code
      end
    end

    # The code for the home location derived from the given argument.
    #
    # @param [Firehose::Copy, Firehose::HomeLocation, String] arg
    #
    # @return [String]
    # @return [nil]                   For invalid argument types.
    #
    def home_location_code(arg)
      case arg
        when String                 then arg.upcase
        when Firehose::Copy         then arg.home_location.code
        when Firehose::HomeLocation then arg.code
      end
    end

    # The code for the current location derived from the given argument.
    #
    # @param [Firehose::Copy, Firehose::CurrentLocation, String] arg
    #
    # @return [String]
    # @return [nil]                   For invalid argument types.
    #
    def current_location_code(arg)
      case arg
        when String                    then arg.upcase
        when Firehose::Copy            then arg.current_location.code
        when Firehose::CurrentLocation then arg.code
      end
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Find all workflow status entries matching the given criteria.
    #
    # @param [Firehose::Holding, Firehose::Library, String]  holding
    # @param [Firehose::Copy, Firehose::Location, String]    copy
    #
    # @return [Array<Hash>]           Zero or more non-nil status entries.
    #
    # @see self#WORKFLOW_STATUS
    #
    def workflow_status(holding = nil, copy = nil)
      holding_values = {
        library:          library_code(holding),
        home_location:    home_location_code(copy),
        current_location: current_location_code(copy),
      }
      WORKFLOW_STATUS.select do |status|
        next unless status && status[:active] && (entry = status[:condition])
        holding_values.all? do |holding_key, holding_value|
          if !entry.has_key?(holding_key)
            true
          elsif (condition = entry[holding_key]).is_a?(Array)
            if condition.first.casecmp('NOT').zero?
              condition[1..-1].none? { |c| holding_value == c }
            else
              condition.any? { |c| holding_value == c }
            end
          elsif condition.is_a?(Regexp)
            holding_value =~ condition
          else
            holding_value == condition
          end
        end
      end
    end

    # Extract the given field from all workflow status entries matching the
    # given criteria.
    #
    # @param [Symbol]                                        field
    # @param [Firehose::Holding, Firehose::Library, String]  holding
    # @param [Firehose::Copy, Firehose::Location, String]    copy
    #
    # @return [Array<Hash>]           Zero or more unique non-blank values.
    #
    # @see self#workflow_status
    #
    def workflow_status_field(field, holding = nil, copy = nil)
      workflow_status(holding, copy).map { |status|
        status[field]
      }.reject(&:blank?).uniq
    end

    # Notice(s) to be displayed near the bottom of the availability information
    # based on the status of an item's library, location or other
    # workflow-related status.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                         If the holdings of *doc* matches
    #                                         none of the workflow status
    #                                         entries.
    #
    # @see self#workflow_status
    #
    def status_note(doc)
      status = (doc.availability if doc.is_a?(UVA::IndexDoc))
      status &&= status.holdings
      status &&=
        status.flat_map { |holding|
          holding.copies.flat_map do |copy|
            workflow_status_field(__method__, holding, copy).presence
          end
        }.compact.uniq
      return if status.blank?
      status.map { |note|
        content_tag(:div, note, class: 'holdings policy-explanation')
      }.join(NEWLINE).html_safe
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Libraries that will be reported by Solr.
    #
    # @return [Array<String>]
    #
    def solr_libraries
      solr_library_table.map { |_, entry| entry[:name] }.sort
    end

    # Libraries that will be reported by Sirsi via Firehose.
    #
    # @return [Hash]
    #
    def ils_libraries
      ils_library_table.map { |_, entry| entry[:ils_name] }.sort
    end

    # Libraries that will be reported by Solr omitting sources which are not
    # actually associated with a UVA library.
    #
    # @return [Hash]
    #
    def uva_libraries
      uva_library_table.map { |_, entry| entry[:name] }.sort
    end

    # Libraries that will be reported by Solr.
    #
    # @return [Hash{Symbol=>Hash}]
    #
    def solr_library_table
      library_table.select { |_, entry| entry[:name].present? }
    end

    # Libraries that will be reported by Sirsi via Firehose.
    #
    # @return [Hash]
    #
    def ils_library_table
      library_table.select { |_, entry| entry[:ils_name].present? }
    end

    # Libraries that will be reported by Solr omitting sources which are not
    # actually associated with a UVA library.
    #
    # @return [Hash{Symbol=>Hash}]
    #
    def uva_library_table
      solr_library_table.select do |_, entry|
        entry[:checkouts] && entry[:on_grounds]
      end
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # For Hash#deep_symbolize_keys.
    class << self
      require 'i18n/core_ext/hash'
    end

    # Load information from the YAML configuration file.
    #
    # @param [String] path            Relative or absolute path to the file.
    #
    # @return [Hash]                  Contents of the YAML file.
    # @return [nil]                   If there was a problem.
    #
    def self.load_table(path = nil)
      path ||= LIBRARY_TABLE_PATH
      config = (path if path.start_with?('/')) || Rails.root.join(path)
      YAML.load_file(config).deep_symbolize_keys
    rescue => e
      Rails.logger.error { "Error reading #{config.inspect} - #{e.message}" }
      nil
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Eager-loaded configuration information.
    LIBRARY_TABLE = (load_table || {}).deep_freeze

    # admin_table
    #
    # @return [Hash]
    #
    def library_table
      @library_table ||= LIBRARY_TABLE
    end

  end

end
