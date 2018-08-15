# app/helpers/special_collections_requests_helper.rb

require 'uva'

# Definitions to support */app/views/special_collections_requests/**.erb* view
# templates.
#
# @see SpecialCollectionsRequestsController
#
module SpecialCollectionsRequestsHelper

  include UVA
  include UVA::Helper::SpecialCollections
  include UVA::Util::Json

  # sc_json_location
  #
  # @param [UVA::IndexDoc] doc
  #
  # @return [Array<String>]
  #
  def sc_json_location(doc)
    holdings = doc.values_for(:special_collections_holding_display).first
    holdings &&= json_parse(holdings)
    holdings ||= []
    holdings.map do |holding|
      holding['special_collections_location']
    end
  end

end
