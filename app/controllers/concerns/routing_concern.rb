# app/controllers/concerns/routing_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving routes.
#
# @see UVA::Scope
#
module RoutingConcern

  extend ActiveSupport::Concern

  include UVA
  include UVA::Scope
  include UVA::Helper::Links

end
