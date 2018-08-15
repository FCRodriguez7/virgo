<!-- lib/uva/view/README.md -->

# View support modules

Classes and modules used to encapsulate common view tasks.

## Item Tooltip

A class used to manage a CSS-based popup "tooltip" for displaying information
about an item (an instance of a class based on UVA::IndexDoc).

## Display Fields

The most common task in this application is the sequential display of item
metadata in several distinct contexts (search results entries, item details
show pages, tabular columns [e.g., in "Starred Items"], etc.).

The `UVA::View::FieldSet` class maintains a set of metadata field values, each
of which is encapsulated in a `UVA::View::Field` instance.  Fields are
comprised of two `UVA::View::Part` instances -- one for the label associated
with the metadata field and one with the value of the metadata field.  These
elements are associated with the metadata fields of a particular IndexDoc item
regardless of the context.  However, each of these elements has a `render`
method whose result changes depending on the context of the rendering.

## Usage
The `include UVA` statement automatically includes `UVA::View`, which sets up
the modules here for autoload.
  
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
