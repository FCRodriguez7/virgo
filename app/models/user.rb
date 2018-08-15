# app/models/user.rb

require 'uva'

# User
#
# @see AuthLogic::ActsAsAuthentic
#
class User < ActiveRecord::Base

  include Blacklight::User

  include UVA

  # Include AuthLogic modules into this class.
  acts_as_authentic

end
