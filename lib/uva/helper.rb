# lib/uva/helper.rb

require 'uva'

module UVA

  # Definitions used by /app/controllers/concerns/*.rb and /app/helpers/*.rb.
  #
  # === Usage
  # Because UVA::Helper is automatically included via `include UVA`, there is
  # no need to use `include UVA::Helper` before referencing UVA::Helper::*
  # modules -- they can be included directly; _e.g._:
  #
  #   <code>include UVA</code>
  #   <i>Other UVA includes...</i>
  #   <code><b>include UVA::Helper::Module1</b></code>
  #   <code><b>include UVA::Helper::Module2</b></code>
  #
  # === Implementation Notes
  # The autoload mechanism scans the /lib/uva/helper subdirectory for all *.rb
  # files to set up the autoloads.
  #
  # This makes it possible to add new modules without needing to update
  # "/lib/uva/helper.rb", but this requires that the module defined in the file
  # has a name which is the direct "camel-case" equivalent of the file name.
  #
  # (_E.g._, "UVA::Helper::XML" could not be defined in /lib/uva/helper/xml.rb
  # because "xml" camel-cased is "Xml".  To support that module name, the file
  # would have to be named /lib/uva/helper/x_m_l.rb.)
  #
  module Helper

    # One time only: autoload all modules from "lib/uva/helper".
    LIB_UVA_HELPER_AUTOLOADS ||=
      begin
        dir = File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'))
        Dir["#{dir}/*.rb"].each do |path|
          name = File.basename(path, '.rb').camelcase.to_sym
          autoload(name, path)
        end
      end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Actions taken when this module is included.
    #
    # @param [Module] base            The including module or class.
    #
    # @return [void]
    #
    def self.included(base) # :nodoc:
      [UVA::Accessibility].each do |mod|
        base.send(:include, mod) unless base.include?(mod)
      end
    end

  end

end
