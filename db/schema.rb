# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20170721161640) do

  create_table "bookmarks", :force => true do |t|
    t.integer  "user_id",     :null => false
    t.text     "url"
    t.string   "document_id"
    t.string   "title"
    t.text     "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "call_number_ranges", :force => true do |t|
    t.integer "map_id"
    t.string  "call_number_range"
    t.string  "location"
  end

  create_table "document_image_request_records", :force => true do |t|
    t.string   "document_id",  :null => false
    t.datetime "requested_at", :null => false
  end

  add_index "document_image_request_records", ["document_id"], :name => "index_document_image_request_records_on_document_id"
  add_index "document_image_request_records", ["requested_at"], :name => "index_document_image_request_records_on_requested_at"

  create_table "libraries", :force => true do |t|
    t.string "name"
  end

  create_table "locations", :force => true do |t|
    t.string "code"
    t.string "value"
  end

  create_table "map_guides", :force => true do |t|
    t.integer "location_id"
    t.integer "map_id"
    t.string  "call_number_range"
  end

  create_table "maps", :force => true do |t|
    t.string  "url"
    t.string  "description"
    t.integer "library_id"
  end

  create_table "maps_users", :force => true do |t|
    t.string "computing_id"
  end

  create_table "searches", :force => true do |t|
    t.text     "query_params"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "searches", ["user_id"], :name => "index_searches_on_user_id"

  create_table "special_collections_request_items", :force => true do |t|
    t.string "special_collections_request_id"
    t.string "location"
    t.string "call_number"
    t.string "barcode"
  end

  create_table "special_collections_requests", :force => true do |t|
    t.string   "user_id"
    t.string   "document_id"
    t.text     "user_note"
    t.text     "staff_note"
    t.datetime "created_at"
    t.datetime "processed_at"
    t.string   "name"
    t.boolean  "internal",         :default => false
    t.boolean  "is_instructional", :default => false
  end

  add_index "special_collections_requests", ["created_at"], :name => "index_special_collections_requests_on_created_at"
  add_index "special_collections_requests", ["document_id"], :name => "index_special_collections_requests_on_document_id"
  add_index "special_collections_requests", ["is_instructional"], :name => "index_special_collections_requests_on_is_instructional"
  add_index "special_collections_requests", ["user_id"], :name => "index_special_collections_requests_on_user_id"

  create_table "special_collections_users", :force => true do |t|
    t.string  "computing_id"
    t.boolean "is_admin",     :default => true
  end

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type"], :name => "index_taggings_on_taggable_id_and_taggable_type"

  create_table "tags", :force => true do |t|
    t.string "name"
  end

  create_table "users", :force => true do |t|
    t.string   "login",             :null => false
    t.string   "email"
    t.string   "crypted_password"
    t.text     "last_search_url"
    t.datetime "last_login_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "password_salt"
    t.string   "persistence_token"
    t.datetime "current_login_at"
  end

end