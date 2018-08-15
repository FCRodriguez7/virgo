<!-- lib/uva/illiad/README.md -->

# Atlas Systems ILLiad requests

Support for making requests through U.Va.'s ILLiad systems for LEO delivery,
Ivy Stacks retrievals, and potentially other Interlibrary Loan requests.

The primary mechanism is through ILLiad's own URL query syntax; the code can
also make use of ILLiad's OpenURL support.  In either case, though, the result
is a new browser tab to the Atlas Systems web site with a pre-populated form
where the actual request is submitted.

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
