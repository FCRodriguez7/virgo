# lib/ext.rb

# Require all modules from the "lib/ext" directory.
LIB_EXT_LOADS ||=
  begin
    dir = File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'))
    Dir["#{dir}/*.rb"].each { |path| require(path) }
  end
