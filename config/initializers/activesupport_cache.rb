# config/initializers/activesupport_cache.rb
#
# Maybe this is different in later versions of Rails, but for Rails 3 and
# earlier ActiveSupport::Cache::Entry#value explicitly freezes the returned
# cached value.
#
# It's not clear what the justification for this is -- perhaps it's a "CYA"
# type of thing, but for the current use of file caching (storing and
# retrieving SolrDocument instances) it's very problematic since there's no
# guarantee that the stored SolrDocument will have had all of its "lazy-loaded"
# member variables filled it at the time that it is cached.  The result coming
# out of the cache needs to be writable to be usable.

require 'active_support/cache'

module ActiveSupport::Cache

  class Entry

    def value
      if raw_value && compressed?
        Marshal.load(Zlib::Inflate.inflate(raw_value))
      else
        raw_value
      end
    end

  end

end
