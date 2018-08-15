# app/helpers/folder_helper.rb

require 'uva'

# Definitions to support */app/views/folder/**.erb* view templates.
#
# @see FolderController
#
module FolderHelper

  include UVA
  include UVA::Helper::Accessibility
  include UVA::Helper::Export
  include UVA::Helper::Facets
  include UVA::Helper::StarredItems

end
