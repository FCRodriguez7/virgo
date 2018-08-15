# app/helpers/sitemap_helper.rb

# Helper for the sitemap generator.
module SitemapHelper

  SOLR_URL = 'http://xxx.virginia.edu/xxx'.freeze

  CHUNK_SIZE = 100000

  def solr_params_start_at(start_at)
    @solr_params ||= {
      q:   'shadowed_location_facet:"VISIBLE"',
      fl:  'id,timestamp',
      wt:  'csv',
      rows: CHUNK_SIZE
    }
    @solr_params.merge(start: start_at)
  end

end
