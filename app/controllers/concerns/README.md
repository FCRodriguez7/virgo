<!-- app/controllers/concerns/README.md -->

# Controller Concerns

These modules are mixed in to controllers to provide task-oriented
functionality through by providing:
 
* An interface to data defined in */app/models*.

* An interface to features implemented under the */lib/uva* and */lib/firehose*
  subdirectories.

* Filter definitions to support data acquisition and validation from the
  controller.

* Flash messages relevant to task steps and/or failures.

In short, code in this directory provides implementation details for the
route-handling actions performed by the controllers.

## Usage

To avoid the need to add `require` statements for each concern, the directory
containing concerns should be added to *config/application.rb* with:
```ruby
  config.autoload_paths += %W(#{config.root}/app/controllers/concerns)
```

## Implementation Notes

Because controllers need some of the same definitions as their views, specific
feature-oriented definitions come from modules in the `UVA::Helper` namespace.
(These modules are also included in */app/helpers/\*.rb*.)

The modules here are named "\*Concern" to avoid confusion with similarly-named
modules in the UVA and/or UVA::Helper namespaces.  (In principal there
_shouldn't_ be any confusion since the names are all in different namespaces,
but RubyMine sometimes has a hard time keeping them straight without distinct
names.)

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
[bl_img]:      ../../../lib/doc/images/blacklight_logo.png
[bl_url]:      http://projectblacklight.org
[bl_gem]:      https://rubygems.org/gems/blacklight
[rm_img]:      ../../../lib/doc/images/icon_RubyMine.png
[rm_url]:      https://www.jetbrains.com/ruby

<!-- vi: set filetype=markdown: set wrap: -->
