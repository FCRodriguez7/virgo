# lib/uva/util/route_methods.rb

require 'uva/util'

module UVA::Util

  # Include this module in a non-MVC framework class to be able to use route
  # helpers like `catalog_path` or `articles_article_url`.
  #
  # === References
  # @see https://www.johnhawthorn.com/2011/03/using-rails-url-helpers-outside-of-views-and-controllers/
  #
  # === Implementation Notes
  # If the `catalog_path` helper is currently defined then including this
  # module adds nothing.
  #
  module RouteMethods

    unless method_defined?(:catalog_path)

      include UVA

      def self.included(base) # :nodoc:
        console_output(
          "include Rails.application.routes.url_helpers for #{base}"
        ) if DEBUG_INCLUDE
      end

      include Rails.application.routes.url_helpers

      def controller
        _routes
      end

      def default_url_options
        {}
      end

    end

  end

end
