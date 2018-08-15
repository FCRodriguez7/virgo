class SpecialCollectionInstructionalQueue < ActiveRecord::Migration
  def up
    add_column :special_collections_requests, :is_instructional, :boolean, default: false
  end

  def down
    remove_column :special_collections_requests, :is_instructional
  end
end
