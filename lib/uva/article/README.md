<!-- lib/uva/article/README.md -->

# Article Engine implementations

Each implements and extension to UVA::Article::Engine which defines the access
mechanisms to an article search provider, as well as a Document class which
implements the UVA::ArticleDoc interface.

| File                   | Description                                    |
| ---------------------- | ---------------------------------------------- |
| [ebsco.md](ebsco.md)   | EBSCO Discovery Service API details.           |
| [ebsco.rb](ebsco.rb)   | Articles via EBSCO Discovery Service.          |
| [primo.rb](primo.rb)   | Articles via Ex Libris Primo. _(see **NOTE**)_ |
| [summon.rb](summon.rb) | Articles via ProQuest Summon. _(see **NOTE**)_ |

> _**NOTE:**_ EBSCO is our current article search provider so the related code
has been thoroughly tested.  The legacy support for Primo, and the code added
to support testing Summon, have been refactored along with the rest of the code
base, but these engines have only been tested to ensure that they could be
selectable as article search choices -- any portions of code formulate requests
or process results have not been tested.

---
---

> [![Blacklight][bl_img]][bl_url]
> Virgo is based on the [Blacklight][bl_url] [gem][bl_gem] for searching Solr indexes in Ruby-on-Rails.

> [![RubyMine][rm_img]][rm_url]
> Virgo developers use [RubyMine][rm_url] for better Ruby-on-Rails development.

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
