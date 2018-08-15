# db/migrate/*_acts_as_taggable_migration.rb

class ActsAsTaggableMigration < ActiveRecord::Migration

  def self.up

    create_table :tags do |t|
      t.column :name, :string
    end

    # NOTE: taggable_type should be big enough to store required class names.
    create_table :taggings do |t|
      t.column :tag_id,        :integer
      t.column :taggable_id,   :integer
      t.column :taggable_type, :string
      t.column :created_at,    :datetime
    end

    add_index :taggings, :tag_id
    add_index :taggings, [:taggable_id, :taggable_type]

  end

  def self.down
    drop_table :taggings
    drop_table :tags
  end

end
