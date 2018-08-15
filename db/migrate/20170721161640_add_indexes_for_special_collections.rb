class AddIndexesForSpecialCollections < ActiveRecord::Migration
  def up
    add_index :special_collections_requests, :created_at
    add_index :special_collections_requests, :user_id
    add_index :special_collections_requests, :document_id
    add_index :special_collections_requests, :is_instructional
  end

  def down
    remove_index :special_collections_requests, :created_at
    remove_index :special_collections_requests, :user_id
    remove_index :special_collections_requests, :document_id
    remove_index :special_collections_requests, :is_instructional
  end
end
