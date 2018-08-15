<!-- lib/uva/helper/README.md -->

# Task-oriented modules

These modules are used by both concerns (*/app/controllers/concerns/\*.rb*) and
view helpers (*/app/helpers/\*.rb*), providing definitions to support handling
routes and creating the responses for a particular feature.

Modules in this directory expect to be used directly from a controller, a
controller concern, a view, or a view helper.  The module methods contain
references to `params`, `session`, and other information from the HTTP request
that is supplied through the Rails MVC framework.

## Usage

The `include UVA` statement automatically includes `UVA::Helper`, which sets up
all of the modules here for autoload.  None of the modules are automatically
included in the class/module with the `include UVA` statement; specific modules
must be included explicitly, e.g.:

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
