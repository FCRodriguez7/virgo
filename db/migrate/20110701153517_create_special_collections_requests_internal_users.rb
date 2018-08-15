# db/migrate/*_create_special_collections_requests_to_internal_users.rb

class CreateSpecialCollectionsRequestsInternalUsers < ActiveRecord::Migration

  def self.up
    create_table :special_collections_requests_internal_users do |t|
      t.column :computing_id, :string
    end
  end

  def self.down
    drop_table :special_collections_requests_internal_users
  end

end
