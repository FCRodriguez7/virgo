# lib/uva/view.rb

require 'uva'

module UVA

  # Namespace for display field classes.
  #
  module View

    # One time only: autoload all modules from the "lib/uva/view"
    # subdirectory.  (This isn't done by enumerating over the contents of the
    # directory because the modules are sensitive to load order.)
    LIB_UVA_VIEW_AUTOLOADS ||= {
      Constants:      'uva/view/constants',
      HtmlAttributes: 'uva/view/html_attributes',
      Field:          'uva/view/field',
      FieldSet:       'uva/view/field_set',
      ItemTooltip:    'uva/view/item_tooltip',
    }.each_pair { |name, path| autoload(name, path) }

  end

end
