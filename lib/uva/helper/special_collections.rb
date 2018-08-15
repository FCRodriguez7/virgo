# lib/uva/helper/special_collections.rb

require 'uva'

module UVA::Helper

  # UVA::Helper::SpecialCollections
  #
  module SpecialCollections

    include UVA

    SC_LOCATION_TEXT = {
      default:    'Special Collections',
      in_process: 'Contact Special Collections',
      sc_ivy:     'Request from Ivy'
    }.deep_freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the user is a Special Collections user.
    #
    # @params [User, String] user               By default, `current_user`.
    #
    def sc_user?(user = nil)
      user ||= current_user
      id = (user.is_a?(User) ? user.login : user.to_s).presence
      id && SpecialCollectionsUser.find_by_computing_id(id).present?
    end

    # Makes a link to the Special Collections request if appropriate.
    #
    # @param [UVA::IndexDoc] doc
    # @param [Hash]          opt      Link options.
    #
    # @return [ActiveSupport::SafeBuffer]
    # @return [nil]                   If the link should not be displayed.
    #
    def sc_request_link(doc, opt = nil)
      return unless display_sc_request_link?(doc)
      opt = opt ? opt.dup : {}
      css_class = 'sc-request-link'
      opt[:class] = [css_class, *opt[:class]].reject(&:blank?).uniq.join(SPACE)
      label = opt.delete(:label) || '&rarr; Request this Item &larr;'.html_safe
      path  = start_special_collections_request_path(doc.doc_id)
      content_tag(:div, opt) do
        link_to(label, path, class: 'initiate-sc-request')
      end
    end

    # Show access restrictions for Special Collections items.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @return [ActiveSupport::SafeBuffer]  Empty string if no restrictions.
    #
    def access_restriction_text(doc)
      restrictions =
        if special_collections_lens?
          doc && doc.marc_display && doc.marc_display.access_restriction
        end
      Array(restrictions).map { |v|
        content_tag(:div, v) if v.present?
      }.compact.join(NEWLINE).html_safe
    end

    # The location to display in availability results for an item copy.
    #
    # @param [Firehose::Holding] holding
    # @param [Firehose::Copy]    copy
    #
    # @return [String]
    # @return [nil]
    #
    # @see UVA::Helper::CourseReserve#reserve_email_availability
    #
    def location_text(holding, copy)
      return unless holding && copy
      sc = holding.library.is_special_collections? && !copy.sc_exhibit?
      sc ? sc_location_text(copy) : copy.current_location.name
    end

    # Determines if the given availability only has one holding with one copy.
    #
    # @param [Firehose::Availability] availability
    #
    def one_copy?(availability)
      holdings =
        if special_collections_lens?
          availability.special_collections_holdings
        else
          availability.holdings
        end
      (holdings.size == 1) && (holdings.first.copies.size == 1)
    end

    # =========================================================================
    # :section: Special Collections
    # =========================================================================

    public

    # Indicate whether the Special Collections request link should be
    # displayed.
    #
    # @param [UVA::IndexDoc] doc
    #
    # @see self#sc_request_link
    #
    def display_sc_request_link?(doc)
      doc.is_a?(UVA::IndexDoc) &&
        special_collections_lens? &&
        (availability = doc.availability) &&
        (holdings = availability.special_collections_holdings).present? &&
        holdings.any? { |holding| holding.copies.any?(&:sc_requestable?) }
    end

    # Determines and returns special collections location text.
    #
    # The rules for what to display are:
    #
    # - If home location is SC-IVY and current location is SC-IVY,
    #     then location should read 'Request from Ivy'.
    # - If home location is SC-IVY and current location is SC-IN-PROC,
    #     then location should read 'Contact Special Collections'.
    # - If home location is SC-IVY and current location is IN-PROCESS,
    #     then location should read 'Contact Special Collections'.
    #
    # Otherwise, display "Special Collections".
    #
    # @param [Firehose::Copy] copy
    #
    # @return [String]
    #
    # @see self#location_text
    #
    def sc_location_text(copy)
      result =
        if copy.home_location.sc_ivy?
          if copy.current_location.sc_ivy?
            SC_LOCATION_TEXT[:sc_ivy]
          elsif copy.in_process?
            SC_LOCATION_TEXT[:in_process]
          end
        end
      result || SC_LOCATION_TEXT[:default]
    end

    # Look through the items of a Special Collections request to see if this
    # location and call number are included.
    #
    # @param [SpecialCollectionsRequest] sc_request
    # @param [String]                    location
    # @param [String]                    call_number
    # @param [String]                    barcode
    #
    def item_included?(sc_request, location, call_number, barcode)
      sc_request.special_collections_request_items.any? do |item|
        location.include?(item.location) && # TODO: Is this right?
          (call_number == item.call_number) &&
          (barcode     == item.barcode)
      end
    end

  end

end
