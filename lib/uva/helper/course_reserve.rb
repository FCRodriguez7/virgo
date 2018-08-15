# lib/uva/helper/course_reserve.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::CourseReserve
  #
  module CourseReserve

    include UVA
    include UVA::Helper::Availability
    include UVA::Helper::SpecialCollections

    SEMESTER_TERMS = [
      'Fall',
      'January',
      'Spring',
      'Summer I',
      'Summer II',
      'Summer III'
    ].deep_freeze

    LOAN_PERIOD_PROMPT = 'Please select'.freeze
    LOCATION_PROMPT    = 'Please select a location'.freeze
    SEMESTER_PROMPT    = 'Please select a semester'.freeze

    # =========================================================================
    # :section: Display
    # =========================================================================

    public

    # show_reserves_dropdowns?
    #
    def show_reserves_dropdowns?
      return unless params[:controller] == 'reserves'
      @use_reserves_dropdowns || (params[:action] == 'email')
    end

    # Elements for a drop-down list of reserve library options.
    #
    # @param [Boolean] include_prompt  Default *true*
    #
    # @return [Array<Array<(String,String)>>]
    #
    def reserve_library_list(include_prompt = true)
      list = ReserveItem.libraries
      prompt = []
      prompt << [LOCATION_PROMPT, ''] if include_prompt
      prompt + list.map { |item| [item.name, item.code] }
    end

    # Elements for a drop-down list of loan period options.
    #
    # @param [SolrDocument] doc
    # @param [Boolean]      include_prompt  Default *true*
    #
    # @return [Array<Array<(String,String)>>]
    #
    def reserve_loan_list(doc = nil, include_prompt = true)
      list = ReserveItem.loan_periods(doc)
      prompt = []
      prompt << [LOAN_PERIOD_PROMPT, ''] if include_prompt
      prompt + list.map { |item| [item.name, item.code] }
    end

    # Elements for a drop-down list of semesters for course reserves requests.
    #
    # @return [Array<Array<(String,String)>>]
    #
    def semester_list(include_prompt = true)
      prompt = []
      prompt << [SEMESTER_PROMPT, ''] if include_prompt
      prompt + SEMESTER_TERMS.map { |term| [term, term] }
    end

    # Drop-down list for loan period options that apply to all items.
    #
    # @return [ActiveSupport::SafeBuffer]
    #
    def all_reserve_loan_list
      name  = 'reserve_period_all'
      label = 'Loan Period'
      dl_options = options_for_select(reserve_loan_list)
      dl_class   = 'reserve-period-select'
      label(name, label) + select_tag(name, dl_options, class: dl_class)
    end

    # The library code to be selected for this reserve request and document.
    #
    # @param [ReserveRequest] request
    # @param [UVA::IndexDoc]  doc
    #
    # @return [String]
    # @return [nil]
    #
    def selected_reserve_library(request, doc)
      item = request && request.reserve_item(doc.doc_id)
      item && item.library && item.library.code
    end

    # The loan period to be selected for this reserve request and document.
    #
    # @param [ReserveRequest] request
    # @param [UVA::IndexDoc]  doc
    #
    # @return [String]
    # @return [nil]
    #
    def selected_reserve_loan_period(request, doc)
      item = request && request.reserve_item(doc.doc_id)
      item && item.loan_period && item.loan_period.code
    end

    # =========================================================================
    # :section: Email
    # =========================================================================

    public

    # reserve_email_for_auto_parse
    #
    # @param [ReserveRequest] request
    # @param [String]         coordinator_address
    #
    # @return [Array<(Fixnum,ActiveSupport::SafeBuffer)>]
    #
    # @see self#reserve_email_availability
    #
    def reserve_email_for_auto_parse(request, coordinator_address)
      index = 0
      holdings_count   = 0
      holdings_message =
        request.reserve_items_by_coordinators[coordinator_address].map { |item|

          doc = item && item.document
          next unless doc

          index += 1
          title  = doc.export_title
          author = doc.export_authors
          url    = canonical_url(doc, @host)

          record = [
            nil,
            index,
            [title, author].reject(&:blank?).join(' - '),
            item.library.name,
            item.loan_period.name,
            item.notes,
            " #{url} ",
            nil
          ].join('|')

          count, message = reserve_email_availability(doc, record.length)
          holdings_count = count if holdings_count < count

          record << message.join

        }.compact.join(NEWLINE).html_safe
      return holdings_count, holdings_message
    end

    # reserve_email_availability
    #
    # @param [UVA::IndexDoc] doc
    # @param [Fixnum]        length
    #
    # @return [Array<(Fixnum, Array<String>)>]
    #
    # @see self#reserve_email_for_auto_parse
    #
    def reserve_email_availability(doc, length)
      availability = doc && doc.availability
      holdings     = availability && availability.holdings
      holdings_message =
        if holdings.present?
          remaining_length = 998 - length
          holdings.flat_map { |holding|
            next unless remaining_length > 0
            lib     = holding.library && holding.library.name
            callnum = holding.call_number
            sas     = is_sas(holding)
            sas_avl = sas && SAS_AVAILABILITY_LONG
            holding.copies.map do |copy|
              next unless remaining_length > 0
              loc   = location_text(holding, copy)
              avail = sas_avl || availability_label(holding, copy)
              entry = "#{lib}|#{loc}|#{avail}|#{callnum}|"
              remaining_length -= entry.length
              entry unless remaining_length < 0
            end
          }.compact
        end
      if holdings_message.present?
        holdings_count   = holdings_message.size
      else
        holdings_count   = 0
        holdings_message = ['?|?|?|?|']
      end
      return holdings_count, holdings_message
    end

  end

end
