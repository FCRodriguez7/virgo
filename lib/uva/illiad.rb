# lib/uva/illiad.rb

require 'uva'

module UVA

  # UVA::Illiad - support for web access to ILLiad
  #
  # === References
  # For information on the web API functionality see the following:
  # @see https://prometheus.atlas-sys.com/display/illiad/ILLiad+Web+DLL+Tags
  # @see https://prometheus.atlas-sys.com/display/illiad/Customizing+the+Web+Interface
  # @see https://www.oclc.org/developer/develop/web-services/worldcat-knowledge-base-api/openurl-resource.en.html
  #
  module Illiad

    include UVA

    require_relative 'illiad/definitions'
    require_relative 'illiad/query'
    require_relative 'illiad/session'

    # =========================================================================
    # The Session ID is taken by ILLiad from the request URL and assigned to
    # the *CitedIn* field.  This value is used by the ILL department to route
    # the requests to different queues -- one for Ivy Stacks requests and one
    # for everything else (implicitly LEO requests).  On the other hand, Health
    # Sciences ILL sees the same SID regardless of whether it is an Ivy Stacks
    # request or not
    # =========================================================================

    UVA_SID = 'UNICORN-UVA:a2721664'.freeze
    HSL_SID = 'UNICORN-HSL:a2721664'.freeze
    IVY_SID = 'IVY-UVA:a2721664'.freeze

    # =========================================================================
    # Configuration entries for specific ILLiad systems.
    # =========================================================================

    # Main UVA Library ILLiad host configuration entry.
    UVA_ILLIAD = {
      label:   'All UVA users',
      host:    'uva.hosts.atlas-sys.com',
      sid:     UVA_SID,
      sid_ivy: IVY_SID,
      openurl: true,
      has_sso: false,
      active:  true
    }.with_indifferent_access.deep_freeze

    # UVA Health Science Library ILLiad host configuration entry.
    HSL_ILLIAD = {
      label:   'Health Sciences users only',
      host:    'healthsystem.virginia.hosts.atlas-sys.com',
      sid:     HSL_SID,
      sid_ivy: HSL_SID,
      openurl: false,
      has_sso: false,
      active:  true
    }.with_indifferent_access.deep_freeze

    # Legacy Continuing Education ILLiad settings configuration entry.
    CED_ILLIAD =
      UVA_ILLIAD.merge(
        label:  'Continuing Education users only',
        active: false
      ).deep_freeze

    # =========================================================================
    # Overall configuration is a map of keys to specific ILLiad entries.
    # =========================================================================

    DEFAULT_KEY = :uva

    # Map of ILLiad configurations
    CONFIGURATION = {
      uva: UVA_ILLIAD,
      hsl: HSL_ILLIAD,
      ced: CED_ILLIAD
    }.with_indifferent_access.deep_freeze

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    # Access configuration values for the default ILLiad system.
    #
    # @return [Hash]
    #
    def self.default_entry
      CONFIGURATION[DEFAULT_KEY]
    end

    # Indicate whether the provided configuration entry key is the default key.
    #
    # @param [String, Symbol] key     ILLiad configuration entry key.
    #
    def self.default_key?(key)
      key.to_s == DEFAULT_KEY.to_s
    end

    # Indicate whether the provided value is an active configuration entry.
    #
    # @param [Hash] entry             ILLiad configuration entry.
    #
    def self.active?(entry)
      entry.is_a?(Hash) && entry[:active]
    end

    # Indicate whether the provided configuration entry is the also the one
    # referenced by the default configuration entry key.
    #
    # @param [Hash] entry             ILLiad configuration entry.
    #
    def self.default?(entry)
      active?(entry) && (entry[:label] == default_entry[:label])
    end

  end

end
