# config/initializers/activerecord_mysqladapter.rb
#
# This fixes an issue that later versions of MySQL have with the ActiveRecord
# 3.x definitions for the database types that leads to the error message:
#
#   Mysql::Error: All parts of a PRIMARY KEY must be NOT NULL;
#   if you need NULL in a key, use UNIQUE instead
#
# === References
# https://github.com/rails/rails/pull/13247

require 'active_record/connection_adapters/mysql_adapter'

class ActiveRecord::ConnectionAdapters::MysqlAdapter
  NATIVE_DATABASE_TYPES[:primary_key] = 'int(11) auto_increment PRIMARY KEY'
end
