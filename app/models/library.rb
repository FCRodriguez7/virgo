# app/models/library.rb

require 'uva'

# A library that can be associated with a map guide.
#
# This class derives from the schema of the *libraries* database table.
#
# @see Map
# @see CreateLibraries
#
class Library < ActiveRecord::Base

  include UVA

  has_many :maps

end
