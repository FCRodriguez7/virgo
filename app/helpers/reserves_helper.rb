# app/helpers/reserves_helper.rb

require 'uva'

# Definitions to support */app/views/reserves/**.erb* view templates.
#
# @see ReservesController
#
module ReservesHelper

  include UVA
  include UVA::Helper::CourseReserve

end
