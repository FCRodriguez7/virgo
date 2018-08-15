<!-- lib/uva/marc/README.md -->

# MARC metadata

This directory contains some extensions to `MARC` classes to allow them to be
used when frozen, but the primary focus is support for processing of MARC and
to define methods which extract specific bibliographic concepts from the
metadata with specific combinations of MARC fields/subfields.

| File                     | Description                                      |
| ------------------------ | ------------------------------------------------ |
| [ext.rb](ext.rb)         | MARC extensions.                                 |
| [record.rb](record.rb)   | MARC data extraction.                            |
| [relator.rb](relator.rb) | Handling of MARC relator codes and roles.        |

## Implementation notes

In keeping with the original implementation, `UVA::Marc::Record` is a
standalone class and not a subclass of `MARC::Record`.  This might change in
the future.

### Virgo Solr fields versus MARC metadata

For records from the catalog (and other sources of MARC metadata), the Virgo
Solr instance combines selected subfields of specific MARC fields to create
index fields for the purpose of searching and/or for the purpose of display.

Some of the display fields can (and are used) directly, but, because not all of
the MARC metadata fields are mapped on to index fields, the Solr document also
includes a **marc_display** field which is the entire source metadata record in
MARCXML format.  The `UVA::Marc::Record` initializer receives this though the
*marc_src* parameter.
  
#### Virgo Solr field mappings

The following is a fairly up-to-date description of how fields from Virgo's
Solr instance map on to MARC fields/subfields.  (This isn't exhaustive and
probably needs to be expanded.)

| Solr field                  | MARC                  | UVA::Marc::Record method  | Notes   |
| --------------------------- | --------------------- | ------------------------- | ------- |
| alternate_form_title_facet  | 246$*                 | variant_title             |         |
| author_display              | 100$*, 110$*, 111$*   | get_primary_author        | 1       |
| author_facet                | 100$*, 110$*, 111$*, 700$*, 710$*, 711$*, 800$*, 810$*, 811$*, 773$a | get_primary_author, located_in | |
| call_number_display         | 090, 086$a            | call_number, sudoc_number | 2, 3, 4 |
| date_bulk_coverage_display  | 245$g                 | bulk_dates                |         |
| date_coverage_display       | 245$f                 | inclusive_dates           |         |
| description_note_display    | 520$a                 | plot_summary              |         |
| form_display                | 245$k                 | form                      |         |
| genre_facet                 | 655$a                 | lc_genre_subject_heading  |         |
| isbn_display                | 020$a                 | isbn                      |         |
| issn_display                | 022$a                 | issn                      |         |
| local_notes_display         | 946$a                 | location_notes            |         |
| medium_display              | 245$h                 | medium                    |         |
| oclc_display                | 035$a                 | oclc_number               |         |
| part_display                | 245$n                 | part                      |         |
| ports_of_call_facet         | 650$cz, 651$az, 655$z | subjects, place_names, lc_subject_heading, lc_geo_subject_heading, lc_genre_subject_heading | |
| published_date_display      | 008, 260$c            | publication_date          |         |
| published_display           | 260$abc, 264$abc      | publication_statement     | 5       |
| responsibility_statement_display | 245$c            | responsibility_statement  |         |
| series_title_facet          | 440$a, 490$a, 810$*, 811$*, 830$* | series_subfields, series_statement | |
| subject_era_facet           | 650$dy, 651$y, 655$y  | subjects, place_names, lc_subject_heading, lc_geo_subject_heading, lc_genre_subject_heading | |
| subject_facet               | 600, 610, 611, 630, 648, 650, 651, 655, 690 | personal_name_as_subject, corporate_name_as_subject, conference_as_subject, title_as_subject, subjects, place_names, lc_subject_heading, lc_geo_subject_heading, lc_genre_subject_heading, local_subject_heading | |
| subtitle_display            | 245$b                 | subtitle                  |         |
| title_display               | 245$a                 | title                     |         |
| topic_form_genre_facet      | 650$abx, 655$a        | subjects, place_names, lc_subject_heading | |
| uniform_title_display       | 130$*, 240$*          | uniform_title             |         |
| uniform_title_facet         | 130$*, 240$*          | uniform_title             |         |
| upc_display                 | 024$a                 | upc                       |         |
| video_run_time_display      | 300$a                 | physical_description      |         |

NOTES
<li><small>1</small>
  Linked author names must be acquired separately through the
  linked_author_display Solr field.</li>
<li><small>2</small>
  Does not include MARC 050.</li>
<li><small>3</small>
  086$a is for ProQuest Congressional Hearings.</li>
<li><small>4</small>
  Many of things in the catalog classified as "Government Document" are missing
  this MARC field and should probably not be classified that way.</li>
<li><small>5</small>
  Other related methods are <code>publication_place</code> and
  <code>publisher</code>, although they include MARC 502$c which the Solr field
  does not.</li>
  
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
