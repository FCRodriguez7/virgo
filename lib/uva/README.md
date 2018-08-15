<!-- lib/uva/README.md -->

# UVa classes and extensions for Virgo

This directory holds implementations for UVa-specific features.

| Directory                             | Description                           |
|---------------------------------------|---------------------------------------|
| [lib/uva/advanced_search][adv_search] | Blacklight Advanced Search extensions |
| [lib/uva/article][article]            | Article 'Engines'                     |
| [lib/uva/helper][uva_helper]          | Concern/helper support                |
| [lib/uva/illiad][illiad]              | Interlibrary Loan requests            |
| [lib/uva/index_doc][index_doc]        | IndexDoc extensions                   |
| [lib/uva/marc][marc]                  | MARC metadata processing              |
| [lib/uva/util][util]                  | Utility methods                       |
| [lib/uva/view][view]                  | Domain-specific display support       |
| [lib/uva/xsl][xsl]                    | XSLT templates                        |

---
---

> [![Blacklight][bl_img]][bl_url]
> Virgo is based on the [Blacklight][bl_url] [gem][bl_gem] for searching Solr indexes in Ruby-on-Rails.

> [![RubyMine][rm_img]][rm_url]
> Virgo developers use [RubyMine][rm_url] for better Ruby-on-Rails development.

<!---------------------------------------------------------------------------->
<!-- Directory link references used above:
REF --------- LINK -------------------- TOOLTIP ------------------------------>
[adv_search]: advanced_search/README.md "Blacklight Advanced Search extensions"
[article]:    article/README.md         "Article 'Engines'"
[uva_helper]: helper/README.md          "Concern/helper support"
[illiad]:     illiad/README.md          "Interlibrary Loan requests"
[index_doc]:  index_doc/README.md       "IndexDoc extensions"
[marc]:       marc/README.md            "MARC metadata processing"
[util]:       util/README.md            "Utility methods"
[view]:       view/README.md            "Domain-specific display support"
[xsl]:        xsl/README.md             "XSLT templates"

<!---------------------------------------------------------------------------->
<!-- Other link references:
REF ---------- LINK ------------------- TOOLTIP ------------------------------>
[version_url]: https://github.com/uvalib/virgo
[version_img]: https://badge.fury.io/gh/uvalib%2virgo.png
[status_url]:  https://travis-ci.org/uvalib/virgo
[status_img]:  https://api.travis-ci.org/uvalib/virgo.svg?branch=develop
[bl_img]:      ../doc/images/blacklight_logo.png
[bl_url]:      http://projectblacklight.org
[bl_gem]:      https://rubygems.org/gems/blacklight
[rm_img]:      ../doc/images/icon_RubyMine.png
[rm_url]:      https://www.jetbrains.com/ruby

<!-- vi: set filetype=markdown: set wrap: -->
