<!-- lib/doc/virgo_classic.md -->

# "Virgo Classic" lens

The "Virgo Classic" lens attempts to provide facilities that approximate those
of Sirsi iLink ("Virgo Classic") in terms of presentation and search.

Presentation largely involves a more space-efficient style that presents more
search results on the screen at a time.

There are broadly two categories of search: *basic search* (and its variation
*browse-by* search) and *advanced search* (with variations targeted to various
sets of content types).  Besides these there is a search on course reserve
entries, and a "search" of bestsellers/award winners which are probably
semi-static lists of catalog items.

The search form presented on the main page is "basic search"; all other types
of search are accessed via links on the right-hand side of the display.

## Basic Search

There are different expected behaviors depending on what type of metadata is
being searched.

| Modes            |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Keyword          | radio button   | _see below_
| Begins with...   | radio button   | Identical to "browse by" search -- _see below_
| Exact            | radio button   | _see below_
| Google Scholar   | radio button   | _see below_

| Fields           |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Search for       | text input box |

| Limiters         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Library          | dropdown menu  |

| Searches         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Search all       | submit button  |
| Author           | submit button  |
| Title            | submit button  |
| Subject          | submit button  |
| Journal title    | submit button  |

### Keyword Search

For a successful search, if there was a single matching catalog item then the
response is the item details page of that single item.  If there were two or
more results then the response is a catalog item listing of the first 20 items.

If the search was not successful, an appropriate "browse by" search is
performed on the term and the first 13 "near" matches are displayed with an
Only "Keyword" searches will actually indicate that there was a failure to
match the search terms.

### Begins with... Search

This always results in a "Browse by" search yielding 13 results on the first
page.  There will be no indication of whether there was an actual match or not.

For "Author" and "Subject" searches the expected results for personal names
will only be obtained if the surname is the first word of the search term.
_E.g._ `conrad joseph` will yield the expected matches;
`joseph conrad` will not.

### Exact Match Search

If there matches on the exact phrase, a listing of the matching items is shown.
(The word/phrase may be anywhere in the target metadata field, unlike a
"Begins with" search.)

However, if there were no exact matches, this falls back to a "Browse by"
search (but with 20 entries on the first page).

The results aren't always what you would expect.

For example "Search all" for `joseph conrad` goes directly to a single item
which has `Joseph, Conrad` as a subject (the same behavior is produced if
"Subject" is the search button). However "Search all" for `conrad joseph` or
`conrad, joseph` goes directly to a *different* record -- one with subject
`Conrad, Joseph` (same behavior for "Subject" exact search).

On the other hand an "Author" exact search for `conrad` (alone) might leave you
frustrated because there are, in fact, matches where the entire author name is
"Conrad" -- so a handful of catalog item results are returned instead of a
"browse-by" listing.  In this case, if you were looking for "Joseph Conrad",
your search term had to have been `conrad joseph`.

### Google Scholar Search

Opens a new browser tab with the results; the same search is performed
regardless of which search button was used to perform the search.

### NOTES and OBSERVATIONS
###### Sirsi iLink Behavior
- "Begins with..." search is identical to "Browse by" search.
- "Search All" (regardless of the search mode) is effectively identical to
"Subject" search -- it does not seem to also find matches on author or title.
- No search ever "fails" in the sense that you don't get some kind of results
back because failed searches always trigger "Browse by" search results.

## Advanced Search

Advanced search allows search of specific sets of metadata fields combined with
logical connectors.

| Fields           |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Words or phrase  | text input box | a.k.a. Keyword
| Author           | text input box |
| Title            | text input box |
| Subject          | text input box |
| Medical subject  | text input box |
| Series           | text input box |
| Periodical title | text input box |
| Author           | text input box |

| Connectors       | dropdown menu  |                                         |
| ---------------- | -------------- | --------------------------------------- |
| And              | menu option    | (_default_)
| Or               | menu option    |
| XOR              | menu option    | "exclusive-or"
| Not              | menu option    |

| Limiters         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Library          | dropdown menu  |
| Language         | dropdown menu  |
| Format           | dropdown menu  |
| Item type        | dropdown menu  |
| Location         | dropdown menu  |
| pPDA/ePDA        | dropdown menu  |
| Pub year         | text input box |

| Sort             | dropdown menu  |                                         |
| ---------------- | -------------- | --------------------------------------- |
| None             | menu option    | (_default_)
| Author           | menu option    |
| Subject          | menu option    |
| Title            | menu option    |
| Relevance        | menu option    |
| Old to New       | menu option    |
| New to Old       | menu option    |

### "DVDs & videos" Search
This is the same form as an advanced search but has a different set of fields
that can potentially be queried.

| Fields           |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| GMD              | text input box |
| Title            | text input box |
| Name(s)          | text input box |
| Production info  | text input box |
| Subject          | text input box |
| Keyword          | text input box |

| Limiters         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                |

| Connectors       |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                |

| Sort             |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                | (_default_: **Title**)

### "E-books, E-Journals, etc." Search
This is the same form as an advanced search but has a more limited set of
fields that can potentially be queried, and is limited to internet materials by
default.

| Fields           |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Author           | text input box |
| Title            | text input box |
| Journal title    | text input box |
| Subject          | text input box |
| Keyword          | text input box |

| Limiters         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                | (_default_ Location: **Internet materials**)

| Connectors       |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                |

| Sort             |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                | (_default_: **Title**)

### "CDs, tapes & LPs" Search
This is the same form as an advanced search but has a different set of fields
that can potentially be queried.

| Fields           |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Name(s)          | text input box |
| Title            | text input box |
| Production info  | text input box |
| Subject          | text input box |
| Keyword          | text input box |

| Limiters         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                |

| Connectors       |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                |

| Sort             |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                |

### "Manuscripts" Search
This is the same form as an advanced search but has a different set of fields
that can potentially be queried, and is limited to manuscript format by
default.

| Fields           |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Personal name    | text input box |
| Corporate name   | text input box |
| All authors      | text input box |
| Title            | text input box |
| Geographic name  | text input box |
| Genre Index Term | text input box |
| Subject          | text input box |
| Keyword          | text input box |

| Limiters         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                | (_default_ Format: **MANUSCRIPT**)

| Connectors       |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                |

| Sort             |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| [same]           |                |

## Browse-by Search
This is sort of a cross between basic and advanced search, but where the
results are not catalog entries but links to matching sets of entries.  While
it has the appearance of being a separate "feature", it's actually very

Each page of results is 13 entries.  The first page has a single entry that
collates before the search term, then zero or more "begins with" matches on the
search term, followed by entries that collate after the search term.


For a successful search, the first 20 results [-10] are returned on a new
page. If the search was not successful, an appropriate "browse by" search
is performed on the term and 13 "near" matches are displayed.

Because this is the "fallback" search when a regular search comes up empty,
these search modes don't

### Browse by author, title, subject, etc.

| Fields           |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Browse on        | text input box |

| Limiters         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Library          | dropdown menu  |

| Searches         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Author           | submit button  |
| Title            | submit button  |
| Subject          | submit button  |
| Series           | submit button  |
| Journal title    | submit button  |

### Browse by call number
This is one variation on "browse-by" search that stands alone because no other
search method allow for searching by call number, so this "browse-by" never
appears as a fall-back search.

| Fields           |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Call number      | text input box |

| Limiters         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Library          | dropdown menu  |
| Shelving scheme  | dropdown menu  | _see below_

### NOTES
- Virgo Classic fans seem to value not having to scroll to see their search
results, but each page of "browse-by" results is bigger than my screen -- to
improve upon this the `per_page` size of browse-by results in Virgo should be
around 10 so that you can actually browse them by just repeatedly clicking the
"Next>>" button without scrolling.
- For Virgo, "browse by title" is just a reformatting of normal search results,
but "browse by author", "browse by series", etc. will require something
different in order to list out the matches and also to make the matches links
to full searches.

## Other Searches

### Best Sellers and Award Winners

These results lists must be "canned" sets of items.

### Search Course Reserves

| Fields           |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Search for       | text input box |

| Limiters         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Library          | dropdown menu  | Libraries with reserve desks only.

| Searches         |                |                                         |
| ---------------- | -------------- | --------------------------------------- |
| Instructor       | submit button  |
| Author           | submit button  |
| Title            | submit button  |

## Values

-

| Libraries                        |                                          |
| -------------------------------- | ---------------------------------------- |
| Alderman                         |
| Astronomy                        |
| BLANDY                           |
| Biology & Psychology (Bio-Psych) |
| Brown - Chemistry                |
| Brown Science & Engineering      |
| Clemons                          |
| Darden                           |
| Fine Arts                        |
| Health Sciences                  |
| Ivy                              |
| Law                              |
| Leo Library                      | Cannot proceed with search if this is selected.
| Math                             |
| Mountain Lake                    |
| Music                            |
| Physics                          |
| Robertson Media Center           |
| Room 302, Ruffner Hall           |
| Semester at Sea                  |
| Special Collections              |
| UVA Library                      | Internet materials and other things that aren't associated with a specific library.

-

| Reserve Libraries           |                                               |
| --------------------------- | --------------------------------------------- |
| Astronomy-Reserve           |
| Biology-Psychology-Reserve  |
| Chemistry-Reserve           |
| Clemons-Reserve             |
| Darden-Reserve              |
| Fire-Arts-Reserve           |
| HS-Reserve                  |
| Law-Reserve                 |
| Math-Astronomy-Reserve      |
| Music-Reserve               |
| Physics-Reserve             |
| RMC-Reserve                 |
| Science-Engineering-Reserve |

-

| Shelving schemes                          |                                 |
| ----------------------------------------- | ------------------------------- |
| ALPHANUM                                  |
| ASIS                                      |
| ATDEWEY                                   |
| ATDEWEYLOC                                |
| AUTO                                      |
| Class scheme for web-accessible materials |
| Class scheme for web-accessible serials   |
| DEWEY                                     |
| DEWEY PERIODICALS                         |
| HS ASIS                                   |
| HS LC                                     |
| HS LCper                                  |
| HS alphanuper                             |
| HS serfirst                               |
| HS sername                                |
| LAW LIBRARY ASIS CLASS SCHEME             |
| LC                                        |
| LC class scheme for monographic sets      |
| LCPER                                     |
| NUMERIC                                   |
| SUDOC                                     |
| SUDOC-PER                                 |
| SUDOC-SER                                 |
| VA-INTL                                   |
| VA-INTL-S                                 |
