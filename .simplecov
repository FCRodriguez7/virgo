SimpleCov.start 'rails' do
  # any custom configs like groups and filters can be here at a central place
  add_filter "/config/"
  add_filter "/spec/"
  add_filter "/features/"
  add_filter "/lib/uva/uva_summon.rb"
  add_filter "/lib/uva/primo.rb"
  add_filter "/lib/tasks/"
  add_filter "/lib/cover_image/"
  
  # Only merge rspec and cuke results if they are both less than 2 days old (172800 seconds).
  merge_timeout 172800
end
