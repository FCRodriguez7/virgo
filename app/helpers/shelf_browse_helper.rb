# app/helpers/shelf_browse_helper.rb

require 'uva'

# Definitions to support */app/views/shelf_browse/**.erb* view templates.
#
# @see ShelfBrowseController
#
module ShelfBrowseHelper

  include UVA
  include UVA::Helper::ActionResponses
  include UVA::Helper::Export
  include UVA::Helper::Layout
  include UVA::Helper::ShelfBrowse

end
