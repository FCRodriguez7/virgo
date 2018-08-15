# app/helpers/record_mailer_helper.rb

require 'uva'

# ::RecordMailerHelper
#
# Definitions to support */app/views/record_mailer/**.erb* view templates.
#
# @see RecordMailer
#
module RecordMailerHelper

  include UVA
  include UVA::Helper::Copyright
  include UVA::Helper::CourseReserve
  include UVA::Helper::TextMessages

end
