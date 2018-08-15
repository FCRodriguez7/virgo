# app/controllers/concerns/action_responses_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving display of messages on web clients.
#
# @see UVA::Helper::ActionResponses
#
module ActionResponsesConcern

  extend ActiveSupport::Concern

  include UVA
  include UVA::Helper::ActionResponses

end
