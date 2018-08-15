# db/migrate/*_add_requested_at_index_to_document_image_request_records.rb

class AddRequestedAtIndexToDocumentImageRequestRecords < ActiveRecord::Migration

  def self.up
    add_index :document_image_request_records, :requested_at
  end

  def self.down
    remove_index :document_image_request_records, :requested_at
  end

end
