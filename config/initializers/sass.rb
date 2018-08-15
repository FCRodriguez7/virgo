# config/initializers/sass.rb

require 'sass'

module Sass::Script::Functions

  # Test for a deployed environment from within .scss and .sass files.
  #
  # @return [Boolean]
  #
  # === Usage Notes
  # Use to specify definitions for a deployed setting (where Rails is running
  # on a library server).
  #
  # @example
  #   @if deployed_server() {
  #       color: red;
  #   }
  #   @else {
  #       color: black;
  #   }
  #
  def deployed_server
    Sass::Script::Bool.new(Virgo.deployed?)
  end

  # Test for development environment from within .scss and .sass files.
  #
  # @return [Boolean]
  #
  # === Usage Notes
  # Use to specify definitions for any non-deployed setting (e.g. desktop
  # development) regardless of the value of `Rails.env`.
  #
  # @example
  #   @if non_deployed_server() {
  #       color: black;
  #   }
  #   @else {
  #       color: red;
  #   }
  #
  def non_deployed_server
    Sass::Script::Bool.new(Virgo.desktop?)
  end

end
