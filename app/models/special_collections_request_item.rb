# app/models/special_collections_request_item.rb

require 'uva'

# SpecialCollectionsRequestItem
#
# @see SpecialCollectionsRequest
# @see SpecialCollectionsUser
# @see SpecialCollectionsRequestsInternalUser
#
class SpecialCollectionsRequestItem < ActiveRecord::Base

  include UVA

  belongs_to :special_collections_request

end
