# lib/tasks/release.rake
#
# rubocop:disable Rails/Date

namespace :release do

  def valid_url?(url, user, pass)
    require 'net/http'
    require 'net/https'
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.port == 443
    success = false
    http.start do |h|
      req = Net::HTTP::Get.new(uri.path)
      req.basic_auth(user, pass)
      response = h.request(req)
      success  = ('200' == response.code)
    end
    success
  end

  base = 'https://xxx.virginia.edu/xxx'

  desc 'Creates a new tag from trunk; requires USER/PASS; set SOURCE to ' \
       'name of path if other than trunk.'
  task :tag do
    # d = Time.current
    user   = ENV['USER']
    pass   = ENV['PASS']
    source = ENV['SOURCE'] || 'trunk'
    source_url = "#{base}/#{source}"
    # dest_url = "#{base}/tags/#{d.month}#{d.day}#{d.year}"
    puts valid_url?("#{source_url}/", user, pass)
  end

end
