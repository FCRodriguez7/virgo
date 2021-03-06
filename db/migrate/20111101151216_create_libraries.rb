# db/migrate/*_create_libraries.rb

require 'active_record/fixtures'

class CreateLibraries < ActiveRecord::Migration

  def self.up
    create_table :libraries do |t|
      t.string :name
    end
    ActiveRecord::Fixtures.create_fixtures('test/fixtures', 'libraries')
  end

  def self.down
    drop_table :libraries
  end

end
