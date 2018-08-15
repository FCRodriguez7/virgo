# lib/uva/administration.rb

require 'uva'

module UVA

  # UVA::Administration
  #
  module Administration

    include UVA

    ADMIN_TABLE_PATH = 'config/admins.yml'.freeze

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Indicate whether the user is included in the list of administrators.
    #
    # @param [String] user_id         Default: `current_user.login`.
    #
    # @see AboutController#index
    # @see UserSessionsController#test_user?
    #
    def user_is_admin?(user_id = nil)
      admin_lookup('all', user_id).present?
    end

    # Get the value of *user_id* in *section*.
    #
    # @param [String, Symbol] section
    # @param [String] user_id         Default: `current_user.login`.
    #
    # @return [String]
    # @return [nil]                   Entry not found.
    #
    def admin_lookup(section, user_id = nil)
      return unless admin_table.present?
      user_id ||= current_user && current_user.login
      group = admin_table[section.to_s]
      group[user_id.to_s] unless group.blank?
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Load information from the YAML configuration file.
    #
    # @param [String] path            Relative or absolute path to the file.
    #
    # @return [Hash]                  Contents of the YAML file.
    # @return [nil]                   If there was a problem.
    #
    def self.load_table(path = nil)
      path ||= ADMIN_TABLE_PATH
      config = (path if path.start_with?('/')) || Rails.root.join(path)
      YAML.load_file(config)
    rescue => e
      Rails.logger.error { "Error reading #{config.inspect} - #{e.message}" }
      nil
    end

    # =========================================================================
    # :section:
    # =========================================================================

    protected

    # Eager-loaded configuration information.
    ADMIN_TABLE = (load_table || {}).deep_freeze

    # admin_table
    #
    # @return [Hash]
    #
    def admin_table
      @admin_table ||= ADMIN_TABLE
    end

  end

end
