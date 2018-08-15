# lib/uva.rb

require 'blacklight'

# The top-level UVA module ensures that all of the UVA modules will be loaded
# as they are needed.
#
# === Usage
# Any class or module that depends upon UVA definitions must have
#
#   <i>Rails and/or gem-related includes...</i>
#   <code><b>include UVA</b></code>
#
# near the top of its definition.  This ensures that all UVA modules will be
# autoloaded as needed and also mixes critical UVA modules into the calling
# class or module.
#
module UVA

  # Autoload all modules from the "lib/uva" directory.
  LIB_UVA_AUTOLOADS ||= {
    Accessibility:      'uva/accessibility',
    AccessRestrictions: 'uva/access_restrictions',
    Administration:     'uva/administration',
    AdvancedSearch:     'uva/advanced_search',
    Article:            'uva/article',
    ArticleDoc:         'uva/article_doc',
    BlacklightOverride: 'uva/blacklight_override',
    Cache:              'uva/cache',
    Classic:            'uva/classic',
    Config:             'uva/config',
    CoverImage:         'uva/cover_image',
    Exceptions:         'uva/exceptions',
    Fedora:             'uva/fedora',
    Helper:             'uva/helper',
    Illiad:             'uva/illiad',
    IndexDoc:           'uva/index_doc',
    Lcc:                'uva/lcc',
    Ldap:               'uva/ldap',
    Marc:               'uva/marc',
    Networks:           'uva/networks',
    Piwik:              'uva/piwik',
    Portal:             'uva/portal',
    Scope:              'uva/scope',
    ShelfBrowse:        'uva/shelf_browse',
    Solr:               'uva/solr',
    SolrBrowseNearby:   'uva/solr_browse_nearby',
    StarredItems:       'uva/starred_items',
    Util:               'uva/util',
    View:               'uva/view',
    Xml:                'uva/xml',
    Xsl:                'uva/xsl',
  }.each_pair { |name, path| autoload(name, path) }

  # If *true*, displays console output for each class/module that has
  # `include 'UVA'`, which displays the module and also the application parts
  # of the call stack that lead to the inclusion.
  #
  # This is only intended for debugging execution call flow and/or timing and
  # is not intended to be turned on for normal development and especially not
  # for production.
  DEBUG_INCLUDE = false # = Virgo.desktop_development?

  # ===========================================================================
  # :section: Module methods
  # ===========================================================================

  public

  # Assert that *condition* is true.
  #
  # @param [Boolean]       condition  A condition that must be true.
  # @param [Array<String>] message    Error message lines.
  #
  # @return [true]                    If *condition* is *true*.
  #
  # @raise [RuntimeError]             If *condition* is *false*.
  #
  # === Usage Notes
  # The primary use for this method is within a module/class definition to
  # ensure that a value has been configured correctly.
  #
  def self.assert(condition, *message)
    return true if condition
    message += Array(yield) if block_given?
    if message.empty?
      message.unshift('FATAL ERROR')
    else
      message[0] = 'FATAL: ' + message[0]
    end
    message.unshift("\n")
    message.push("\n")
    raise message.join("\n")
  end

  # Actions taken when this module is included.
  #
  # @param [Module] base              The including module or class.
  #
  # @return [void]
  #
  def self.included(base) # :nodoc:
    debug_include(base) if DEBUG_INCLUDE
    [Accessibility, Util, Config, Helper, View].each do |mod|
      base.send(:include, mod) unless base.include?(mod)
    end
  end

  # ===========================================================================
  # :section: Module methods
  # ===========================================================================

  private

  # If self#DEBUG_INCLUDE is true, choose the output to show.  Choices are:
  #
  #   :simple   Just the class/module being loaded.  (This is default if
  #               DEBUG_INCLUDE_MODE is *nil* or missing.)
  #
  #   :basic    Annotate with the originating controller class or module.
  #
  #   :trace    Follow with a partial stack trace through the lines of
  #               application code.
  #
  DEBUG_INCLUDE_MODE = :simple

  # Call stack line containing this patterns are not included.
  UVA_STACK_ANTI_PATTERNS ||= [
    %r{/config/},
    %r{/script/},
    %r{/config\.ru:},
  ].deep_freeze

  # Regular expression for extracting the name of the module which caused the
  # this module to be included.
  UVA_ORIGIN_EXPR ||= /^(.*)\.rb:\d+:.*$/.freeze

  # Display the module including this module.
  #
  # @param [Module] base              The including module or class.
  #
  # @return [void]
  #
  def self.debug_include(base, mode = nil)
    mode ||= DEBUG_INCLUDE_MODE if defined?(DEBUG_INCLUDE_MODE)
    details =
      if mode && (mode != :simple)
        root = Rails.root.to_s
        call_path =
          caller(5).select do |v|
            v.start_with?(root) &&
              !UVA_STACK_ANTI_PATTERNS.find { |pattern| v =~ pattern }
          end
        if call_path.present?
          case mode
            when :basic
              origin =
                call_path.last.split('/').last.gsub(UVA_ORIGIN_EXPR, '\1')
              " from #{origin.camelcase}" if origin.present?
            when :trace
              newline = "\n  "
              newline + call_path.join(newline)
          end
        end
      end
    console_output("load #{base}#{details}")
  end

end
