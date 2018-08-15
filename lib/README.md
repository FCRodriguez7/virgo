<!-- lib/README.md -->

# UVa classes and extensions for Virgo

This directory holds implementations for UVa-specific features.

| Directory                | Description                     |
|--------------------------|---------------------------------|
| [lib/doc][lib_doc]       | Development documentation       |
| [lib/ext][lib_ext]       | Ruby and gem extensions         |
| [lib/firehose][firehose] | Firehose (Sirsi OPAC interface) |
| [lib/tasks][lib_tasks]   | Local rake tasks                |
| [lib/uva][lib_uva]       | UVa feature implementations     |

---
---

> [![Blacklight][bl_img]][bl_url]
> Virgo is based on the [Blacklight][bl_url] [gem][bl_gem] for searching Solr indexes in Ruby-on-Rails.

> [![RubyMine][rm_img]][rm_url]
> Virgo developers use [RubyMine][rm_url] for better Ruby-on-Rails development.

<!---------------------------------------------------------------------------->
<!-- Directory link references used above:
REF ---------- LINK ---------------------------- TOOLTIP --------------------->
[lib_doc]:     /lib/doc/README.md                "Development documentation"
[lib_ext]:     /lib/ext/README.md                "Ruby and gem extensions"
[firehose]:    /lib/firehose/README.md           "Firehose (Sirsi interface)"
[lib_tasks]:   /lib/tasks/README.md              "Local rake tasks"
[lib_uva]:     /lib/uva/README.md                "UVa feature implementations"
[adv_search]:  lib/uva/advanced_search/README.md "Advanced Search"
[article]:     lib/uva/article/README.md         "Article 'Engines'"
[uva_helper]:  lib/uva/helpers/README.md         "Concern/helper support"
[illiad]:      lib/uva/illiad/README.md          "Interlibrary Loan requests"
[marc]:        lib/uva/marc/README.md            "MARC metadata processing"
[util]:        lib/uva/util/README.md            "Utility methods"
[xsl]:         lib/uva/xsl/README.md             "XSLT templates"

<!---------------------------------------------------------------------------->
<!-- Other link references:
REF ---------- LINK ---------------------------- TOOLTIP --------------------->
[version_url]: https://github.com/uvalib/virgo
[version_img]: https://badge.fury.io/gh/uvalib%2virgo.png
[status_url]:  https://travis-ci.org/uvalib/virgo
[status_img]:  https://api.travis-ci.org/uvalib/virgo.svg?branch=develop
[bl_img]:      doc/images/blacklight_logo.png
[bl_url]:      http://projectblacklight.org
[bl_gem]:      https://rubygems.org/gems/blacklight
[rm_img]:      doc/images/icon_RubyMine.png
[rm_url]:      https://www.jetbrains.com/ruby

<!-- vi: set filetype=markdown: set wrap: -->
