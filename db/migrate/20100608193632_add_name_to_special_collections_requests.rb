# db/migrate/*_add_name_to_special_collections_requests.rb

class AddNameToSpecialCollectionsRequests < ActiveRecord::Migration

  def self.up
    add_column :special_collections_requests, :name, :string
  end

  def self.down
    remove_column :special_collections_requests, :name
  end

end
