<!-- lib/firehose/README.md -->

# Firehose: Sirsi catalog interface

These modules interface to the Firehose web API to get information about the
availability status of catalog items, to get information about patron account
status of the logged-in user, and to submit circulation requests on behalf of
the logged-in user.

| File                                | Description                           |
| ----------------------------------- | ------------------------------------- |
| [common.rb](common.rb)              | Common definitions.                   |
| [availability.rb](availability.rb)  | Catalog item status information.      |
| [checkouts.rb](checkouts.rb)        | Request renewal of checked-out items. |
| [holds.rb](holds.rb)                | Request hold/recall of items.         |
| [libraries.rb](libraries.rb)        | List of libraries.                    |
| [patron.rb](patron.rb)              | Patron status information.            |
| [reserves.rb](reserves.rb)          | Course reserve information.           |

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
[bl_img]:      ../doc/images/blacklight_logo.png
[bl_url]:      http://projectblacklight.org
[bl_gem]:      https://rubygems.org/gems/blacklight
[rm_img]:      ../doc/images/icon_RubyMine.png
[rm_url]:      https://www.jetbrains.com/ruby

<!-- vi: set filetype=markdown: set wrap: -->
