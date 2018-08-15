# app/models/special_collections_user.rb

require 'uva'

# SpecialCollectionsUser
#
# A library staff member who can manage Special Collections requests.
#
# @see SpecialCollectionsRequest
# @see SpecialCollectionsRequestItem
# @see SpecialCollectionsRequestsInternalUser
#
class SpecialCollectionsUser < ActiveRecord::Base

  include UVA

  scope :admins, -> {where is_admin: true}

end
