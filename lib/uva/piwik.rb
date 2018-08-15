# lib/uva/piwik.rb

require 'uva'

module UVA

  # UVA::Piwik
  #
  module Piwik

    include UVA

    PIWIK_PROD_SITE = 1
    PIWIK_DEV_SITE  = 15

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether Piwik analytics are in use.
    #
    def self.enabled?
      site.present?
    end

    # Piwik host.
    #
    # @return [String]
    #
    def self.host
      URL::PIWIK_HOST
    end

    # Piwik site identifier.
    #
    # The Piwik "site" or "project" is the data collection unit associated with
    # this service.  To avoid polluting production usage information, only
    # clients of the "search_production" environment will send with "idsite=1".
    #
    # @return [Fixnum]
    # @return [nil]
    #
    def self.site
      if Virgo.deployed_production?
        PIWIK_PROD_SITE
      elsif Virgo.deployed_development? || Virgo.desktop_production?
        PIWIK_DEV_SITE
      end
    end

    # Piwik JavaScript asset.
    #
    # If present, this should be included in <head> before any other JavaScript
    # files.
    #
    # @return [String]
    # @return [nil]                   If `Piwik.enabled?` is *false*.
    #
    def self.script
      "//#{host}/piwik.js" if enabled?
    end

    # Piwik host tracker URL.
    #
    # @return [String]
    # @return [nil]                   If `Piwik.enabled?` is *false*.
    #
    def self.tracker_url
      "//#{host}/piwik.php" if enabled?
    end

  end

end
