<!-- lib/uva/util/README.md -->

# Utility modules

Various mixin modules mostly related to string handling in one way or another.

| File                                   | Description                                                   |
| -------------------------------------- | ------------------------------------------------------------- |
| [date_methods.rb](date_methods.rb)     | Methods for extract date values from strings.                 |
| [html_methods.rb](html_methods.rb)     | Methods for string processing for HTML output.                |
| [route_methods.rb](route_methods.rb)   | A mixin to support route shortcuts outside the MVC framework. |
| [string_methods.rb](string_methods.rb) | Methods for string processing and searching.                  |
| [text_constants.rb](text_constants.rb) | Constants for common strings and regular expressions.         |
| [dev.rb](dev.rb)                       | Fine-grained debugging support disabled in production.        |
| [log.rb](log.rb)                       | Logging enhancements including developer console output.      |
  
## Usage

The `include UVA` statement automatically includes `UVA::Util`, which sets up
the modules here for autoload.  The most critical of these modules are
automatically included in the class/module with the `include UVA` statement.
Other modules must be included directly, e.g.:
```ruby
include UVA
include UVA::Util::HtmlMethods
```
  
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
