# db/migrate/*_add_internal_to_special_collections_requests.rb

class AddInternalToSpecialCollectionsRequests < ActiveRecord::Migration

  def self.up
    add_column :special_collections_requests, :internal, :boolean, default: false
  end

  def self.down
    remove_column :special_collections_requests, :internal
  end

end
