<!-- lib/uva/xsl/README.md -->

# XSLT stylesheets

XSLT stylesheets used by [`UVA::Xsl#transform`][xsl].
  
## Directory contents

| File                         | Description                                   |
| ---------------------------- | --------------------------------------------- |
| [descmeta.xsl](descmeta.xsl) | For [`SolrDocument#show_descmeta`][solr_doc]. |
| [ead.xsl](ead.xsl)           | For [`UVA::Ead::Xml`][ead].                   |
| [tei.xsl](tei.xsl)           | For [`UVA::Tei::Xml`][tei].                   |
  
---
---

> [![Blacklight][bl_img]][bl_url]
> Virgo is based on the [Blacklight][bl_url] [gem][bl_gem] for searching Solr indexes in Ruby-on-Rails.

> [![RubyMine][rm_img]][rm_url]
> Virgo developers use [RubyMine][rm_url] for better Ruby-on-Rails development.

<!---------------------------------------------------------------------------->
<!-- Directory link references used above:
REF ---------- LINK ---------------------------- TOOLTIP --------------------->
[xsl]:         ../xsl.rb
[solr_doc]:    ../../../app/models/solr_document.rb
[ead]:         ../index_doc/ead.rb
[tei]:         ../index_doc/tei.rb

<!---------------------------------------------------------------------------->
<!-- Other link references:
REF ---------- LINK ---------------------------- TOOLTIP --------------------->
[version_url]: https://github.com/uvalib/virgo
[version_img]: https://badge.fury.io/gh/uvalib%2virgo.png
[status_url]:  https://travis-ci.org/uvalib/virgo
[status_img]:  https://api.travis-ci.org/uvalib/virgo.svg?branch=develop
[bl_img]:      ../../doc/images/blacklight_logo.png
[bl_url]:      http://projectblacklight.org
[bl_gem]:      https://rubygems.org/gems/blacklight
[rm_img]:      ../../doc/images/icon_RubyMine.png
[rm_url]:      https://www.jetbrains.com/ruby

<!-- vi: set filetype=markdown: set wrap: -->
