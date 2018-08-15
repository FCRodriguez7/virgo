# lib/uva/util.rb

require 'uva'

module UVA

  # Namespace for utility modules and classes.
  #
  module Util

    # One time only: autoload all modules from the "lib/uva/util"
    # subdirectory.  (This isn't done by enumerating over the contents of the
    # directory because the modules are sensitive to load order.)
    LIB_UVA_UTIL_AUTOLOADS ||= {
      TextConstants: 'uva/util/text_constants',
      DateMethods:   'uva/util/date_methods',
      HtmlMethods:   'uva/util/html_methods',
      RouteMethods:  'uva/util/route_methods',
      StringMethods: 'uva/util/string_methods',
      Json:          'uva/util/json',
      Dev:           'uva/util/dev',
      Log:           'uva/util/log',
    }.each_pair { |name, path| autoload(name, path) }

    # Bring in specialized Array extensions.
    require 'uva/util/array_ext'

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Actions taken when this module is included.
    #
    # TextConstants and StringMethods will be automatically included in the
    # calling module; other UVA::Util modules must be explicitly included.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      [TextConstants, StringMethods, Log].each do |mod|
        base.send(:include, mod) unless base.include?(mod)
      end
    end

  end

end
