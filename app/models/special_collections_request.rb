# app/models/special_collections_request.rb

require 'uva'

# SpecialCollectionsRequest
#
# @see SpecialCollectionsRequestItem
# @see SpecialCollectionsUser
# @see SpecialCollectionsRequestsInternalUser
#
class SpecialCollectionsRequest < ActiveRecord::Base

  include UVA

  has_many :special_collections_request_items, dependent: :destroy

  # ===========================================================================
  # :section: Validations
  # ===========================================================================

  validates :user_id, :document_id, presence: true

  # ===========================================================================
  # :section: Callbacks
  # ===========================================================================

  before_update :set_processed_at

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # The requested item.
  #
  # @return [SolrDocument]
  #
  attr_accessor :document

  # The title of the requested item.
  #
  # @return [String]
  #
  def document_title
    result = @document && @document.export_title
    result = '???' if result.blank?
    result
  end

  # The first author of the requested item.
  #
  # @return [String]
  #
  def document_author
    result = @document && @document.get_authors.first
    result = '' if result.blank?
    result
  end

  # Locations and call numbers are submitted via a web form as a hash keyed on
  # item location.
  #
  # @param [Hash{String=>Hash{String=>Array}}] request_params
  #
  # @return [Array<SpecialCollectionsRequestItem>]
  # @return [nil]                   If *locations_with_call_numbers* was *nil*.
  #
  # @example
  #
  #   {
  #     "SC-STKS"   => { "X030761746" => ["PS3623 .R539 S48 2010"] },
  #     "SC-BARR-X" => { "X004958786" => ["MSS 6251 -- 6251-bn"],
  #                      "X004958758" => ["MSS 6251 -- 6251-bn Box 2"] }
  #   }
  #
  # Build these out into request items and add those items to this request
  # object.
  #
  def build(request_params)
    return if request_params.blank?
    request_params.each_pair do |location, barcodes|
      next if barcodes.blank?
      barcodes.each_pair do |barcode, call_numbers|
        Array(call_numbers).each do |call_number|
          next if call_number.blank?
          self.special_collections_request_items <<
            SpecialCollectionsRequestItem.new(
              location:    location,
              call_number: call_number,
              barcode:     barcode
            )
        end
      end
    end
    self.special_collections_request_items
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Save current timestamp.
  #
  # @param [Time] time                Default: `Time.current`.
  #
  # @return [Time]
  #
  def set_processed_at(time = nil)
    time ||= Time.current
    self.processed_at = time
  end

end
