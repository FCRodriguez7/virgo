<!-- app/helpers/README.md -->

# View Helpers

These modules are mixed in to view classes automatically by Rails to provide
them with definitions that can be used within *.erb files.

## Usage

These modules are handled by Rails; they are mixed in to the appropriate view
class based on the base name of the controller.  E.g.  `CatalogController`
views with templates in */app/views/catalog/\*\*.erb* automatically use
the definitions from */app/helpers/catalog_helper.rb*.

## Implementation Notes

These files are mostly composed of `include` statements for modules in the
`UVA::Helper` namespace, where the actual task- or feature-oriented methods
are defined.

(These modules are also included in */app/controllers/concerns/*.rb* to provide
definitions that are needed by both controllers and their associated views.)

---
---

> [![Blacklight][bl_img]][bl_url]
> Virgo is based on the [Blacklight][bl_url] [gem][bl_gem] for searching Solr indexes in Ruby-on-Rails.

> [![RubyMine][rm_img]][rm_url]
> Virgo developers use [RubyMine][rm_url] for better Ruby-on-Rails development.

<!---------------------------------------------------------------------------->
<!-- Other link references:
REF ---------- LINK -------------------------- TOOLTIP ----------------------->
[version_url]: https://github.com/uvalib/virgo
[version_img]: https://badge.fury.io/gh/uvalib%2virgo.png
[status_url]:  https://travis-ci.org/uvalib/virgo
[status_img]:  https://api.travis-ci.org/uvalib/virgo.svg?branch=develop
[bl_img]:      ../../lib/doc/images/blacklight_logo.png
[bl_url]:      http://projectblacklight.org
[bl_gem]:      https://rubygems.org/gems/blacklight
[rm_img]:      ../../lib/doc/images/icon_RubyMine.png
[rm_url]:      https://www.jetbrains.com/ruby

<!-- vi: set filetype=markdown: set wrap: -->
