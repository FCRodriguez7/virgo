# app/models/user_session.rb

require 'uva'

# UserSession
#
# @see AuthLogic::Session
#
class UserSession < Authlogic::Session::Base

  include UVA

end
