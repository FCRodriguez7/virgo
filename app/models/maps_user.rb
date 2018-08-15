# app/models/maps_user.rb

require 'uva'

# A person who is allowed to administer maps.
#
# This class derives from the schema of the *maps_users* database table.
#
# @see Map
# @see MapsUsers
#
class MapsUser < ActiveRecord::Base

  include UVA

end
