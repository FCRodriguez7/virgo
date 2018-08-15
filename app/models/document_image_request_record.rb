# app/models/document_image_request_record.rb

require 'uva'

# A record of when a request was made for a document whose image we don't have
# on file.
#
# This class derives from the schema of the *document_image_request_records*
# database table.
#
# @see CreateDocumentImageRequestRecords
#
class DocumentImageRequestRecord < ActiveRecord::Base

  include UVA

  # ===========================================================================
  # :section: Class Methods
  # ===========================================================================

  public

  # DocumentImageRequestRecord.delete_old_requests
  #
  # @param [Numeric] days_old
  #
  # @return [void]
  #
  def self.delete_old_requests(days_old)
    unless days_old.is_a?(Numeric)
      raise ArgumentError, 'days_old is expected to be a number'
    end
    if days_old <= 0
      raise ArgumentError, 'days_old is expected to be greater than 0'
    end
    self.destroy_all(['requested_at < ?', (Time.zone.today - days_old)])
  end

end
