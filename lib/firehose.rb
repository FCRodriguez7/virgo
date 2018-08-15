# lib/firehose.rb

require 'uva'

# The top-level Firehose module ensures that all of the Firehose modules will
# be loaded as they are needed.
#
# === Usage
# Any class or module that depends upon Firehose definitions must have
#
#   <i>Rails and/or gem-related includes...</i>
#   <i>UVA includes...</i>
#   <code><b>include Firehose</b></code>
#
# near the top of its definition.  This ensures that all Firehose modules will
# be autoloaded as needed and also mixes critical Firehose modules into the
# calling class or module.
#
module Firehose

  include UVA

  # Autoload all modules from the "lib/firehose" directory.
  LIB_FIREHOSE_AUTOLOADS ||= {
    API:          'firehose/api',
    Common:       'firehose/common',
    Availability: 'firehose/availability',
    Checkouts:    'firehose/checkouts',
    Holds:        'firehose/holds',
    Libraries:    'firehose/libraries',
    Patron:       'firehose/patron',
    Reserves:     'firehose/reserves',
  }.each_pair { |name, path| autoload(name, path) }

  # ===========================================================================
  # :section: Module methods
  # ===========================================================================

  public

  # Actions taken when this module is included.
  #
  # @param [Module] base              The including module or class.
  #
  # @return [void]
  #
  def self.included(base) # :nodoc:
    [Common].each do |mod|
      base.send(:include, mod) unless base.include?(mod)
    end
  end

end
