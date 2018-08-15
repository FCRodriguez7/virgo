# app/helpers/about_helper.rb

require 'uva'

# Definitions to support */app/views/about/**.erb* view templates.
#
# @see AboutController
#
module AboutHelper

  include ActionView::Helpers::TagHelper

  include UVA
  include UVA::Administration

  ENV_VARIABLES = %w(
    rvm_version
    rvm_path
    rvm_ruby_string
    rvm_bin_path
    gemset
    BUNDLE_GEMFILE
    BUNDLE_BIN_PATH
    GEM_HOME
    GEM_PATH
    _ORIGINAL_GEM_PATH
    MY_RUBY_HOME
    RUBYLIB
    LANG
    LANGUAGE
    PATH
  ).deep_freeze

  LIBRARY_DESCRIPTION  = 'Libraries configured in the Sirsi ILS as reported ' \
                         'by the Firehose service.'.html_safe.freeze
  LOCATION_DESCRIPTION = 'Locations configured in the Sirsi ILS as reported ' \
                         'by the Firehose service.'.html_safe.freeze

  LIBRARY_HEADINGS  = %w(ID Code Name Deliverable? LEOable?).deep_freeze
  LOCATION_HEADINGS = %w(ID Code Name).deep_freeze

  # ===========================================================================
  # :section: Main page
  # ===========================================================================

  public

  # run_values
  #
  # @return [Hash{String=>String}]
  #
  def run_values
    {
      'Host server' => host_server,
      'RACK_ENV'    => ENV['RACK_ENV'],
      'RAILS_ENV'   => ENV['RAILS_ENV'],
      'Rails.env'   => Rails.env,
    }
  end

  # url_values
  #
  # @return [Hash{String=>String}]
  #
  def url_values
    {
      'Solr URL'               => Blacklight.solr.options[:url],
      'FIREHOSE_URL'           => FIREHOSE_URL,
      'FEDORA_REST_URL'        => FEDORA_REST_URL,
      'PDA_WEB_SERVICE'        => PDA_WEB_SERVICE,
      'ARTICLE_ENGINE_DEFAULT' => UVA::Article::DEFAULT_PROVIDER,
      'COVER_IMAGE_URL'        => ENV['COVER_IMAGE_URL'],
    }
  end

  # db_values
  #
  # @return [Hash{String=>String}]
  #
  def db_values
    db_config = Rails.application.config.database_configuration[Rails.env]
    {
      'Database host'    => (db_config['host'] || 'localhost'),
      'Database name'    => db_config['database'],
      'Database adapter' => db_config['adapter'],
    }
  end

  # get_env_values
  #
  # @return [Hash{String=>String}]
  #
  def env_values
    ENV.keys.sort.map { |name|
      value = ENV[name]
      value = content_tag(:strong, value) if ENV_VARIABLES.include?(name)
      [name, value]
    }.to_h
  end

  # ===========================================================================
  # :section: About page
  # ===========================================================================

  public

  # show_entries
  #
  # @param [Hash] table
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def show_entries(table)
    table.map { |name, value|
      content_tag(:p) do
        show_entry(name, value)
      end
    }.join(NL).html_safe
  end

  # show_entry
  #
  # @param [String] name
  # @param [String] value
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def show_entry(name, value)
    name  = content_tag(:div, name,  class: 'about-item')
    value = content_tag(:div, value, class: 'about-value')
    name << ': ' << value
  end

  # ===========================================================================
  # :section: List library page
  # ===========================================================================

  public

  # library_description
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def library_description
    LIBRARY_DESCRIPTION
  end

  # library_heading_row
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def library_heading_row
    content_tag(:tr) do
      content_tags(:th, *LIBRARY_HEADINGS, class: 'heading')
    end
  end

  # library_rows
  #
  # @param [Firehose::LibraryList] list
  # @param [Hash]                  opt
  #
  # @return [Array<ActiveSupport::SafeBuffer>]
  #
  def library_rows(list, opt = nil)
    html_opt = { class: 'data' }
    html_opt.merge!(opt) if opt.present?
    list.libraries
      .sort { |a, b| a.id.to_i <=> b.id.to_i }
      .map do |library|
        entry = [
          library.id,
          library.code,
          library.name,
          library.deliverable?,
          library.leoable?
        ]
        content_tag(:tr) do
          content_tags(:td, *entry, html_opt)
        end
      end
  end

  # ===========================================================================
  # :section: List location page
  # ===========================================================================

  public

  # location_description
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def location_description
    LOCATION_DESCRIPTION
  end

  # location_heading_row
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def location_heading_row
    content_tag(:tr) do
      content_tags(:th, *LOCATION_HEADINGS, class: 'heading')
    end
  end

  # location_rows
  #
  # @param [Firehose::LocationList] list
  # @param [Hash]                   opt
  #
  # @return [Array<ActiveSupport::SafeBuffer>]
  #
  def location_rows(list, opt = nil)
    html_opt = { class: 'data' }
    html_opt.merge!(opt) if opt.present?
    list.locations
      .sort { |a, b| a.id.to_i <=> b.id.to_i }
      .map do |location|
        entry = [
          location.id,
          location.code,
          location.name,
        ]
        content_tag(:tr) do
          content_tags(:td, *entry, html_opt)
        end
      end
  end

  # ===========================================================================
  # :section: List page
  # ===========================================================================

  protected

  # content_tags
  #
  # @param [Symbol, String] tag
  # @param [Array<String>]  args
  #
  # @return [ActiveSupport::SafeBuffer]
  #
  def content_tags(tag, *args)
    html_opt = args.last.is_a?(Hash) ? args.pop : {}
    args.map { |arg| content_tag(tag, arg, html_opt) }.join.html_safe
  end

end
