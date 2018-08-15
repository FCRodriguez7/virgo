# app/models/location.rb

require 'uva'

# A location that can be associated with a call number range.
#
# This class derives from the schema of the *locations* database table.
#
# @see CallNumberRange
# @see CreateLocations
#
class Location < ActiveRecord::Base

  include UVA

  has_many :call_number_ranges

end
