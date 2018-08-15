# lib/uva/helper/semester_at_sea.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::SemesterAtSea
  #
  module SemesterAtSea

    include UVA

    SAS_AVAILABILITY_SHORT = 'SAS Only'.freeze
    SAS_AVAILABILITY_LONG  = 'Available to Semester-At-Sea Only'.freeze
    SAS_AVAILABILITY_FULL  =
      'This item is only available to Semester-At-Sea participants.'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the holding/copy belongs to Semester-At-Sea.
    #
    # @param [Firehose::Holding] holding
    # @param [Firehose::Copy]    copy
    #
    # @return [Boolean]
    #
    def is_sas(holding, copy = nil)
      result = holding && holding.library && holding.library.is_sas?
      result &&= !copy.pending? if copy.present?
      result.present?
    end

    # Text to display if the item only has Semester-At-Sea holdings.
    #
    # @param [Array] args             First argument is *doc*; others ignored.
    #
    # @return [String]
    # @return [nil]
    #
    # @see UVA::Helper::Requests#leo_and_recall_links
    #
    def sas_only_text(*args)
      doc = args.shift
      SAS_AVAILABILITY_FULL if doc && doc.sas_only?
    end

  end

end
