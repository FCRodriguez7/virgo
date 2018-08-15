# app/views/about/index.xml.builder

user = current_user && current_user.login
user += ' (admin)' if user_is_admin?(user)

ip_addr   = get_current_ip
true_addr = get_current_ip(true)
fake_addr = (ip_addr unless ip_addr == true_addr)
true_addr = nil unless fake_addr.present?

missing = '-'

# =============================================================================
# XML template
# =============================================================================

xml.instruct! :xml
xml.About {
  xml.Site {
    xml.ShortName   application_name
    xml.Description 'UVA Library search-and-discovery interface'
  }
  xml.Release {
    xml.Version     APP_VERSION
  }
  xml.Session {
    xml.User        user || missing
    xml.IpAddress   ip_addr
    xml.TrueAddr    true_addr if true_addr
    xml.ForgedAddr  fake_addr if fake_addr
    xml.SessionId   session[:session_id] || missing
  }
  if @can_view_about
    xml.RunValues   { xml_builder(xml, run_values) }
    xml.UrlValues   { xml_builder(xml, url_values) }
    xml.DbValues    { xml_builder(xml, db_values) }
    xml.RailsInfo   { xml_builder(xml, Rails::Info.properties.to_a.to_h) }
    xml.Environment { xml_builder(xml, env_values) }
  end
}
