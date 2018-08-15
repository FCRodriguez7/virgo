<!-- lib/uva/article/ebsco.md -->

# EDS API: EBSCO Discovery Service application programming interface

This document aggregates information from the
[EBSCO Discovery Service Wiki][eds_wiki] that discusses some of the specific
things that show up in [ebsco.rb](ebsco.rb) and things for future
consideration.

For overview information, see the links in the [References](#references)
section below.

| Document Section                                | Description
| ----------------------------------------------- | -----------------------------------------------------------------------------
| [Search request](#search-request)               | EBSCO search parameters and reply format.
| [Retrieve request](#retrieve-request)           | Retrieve the full EBSCO record for an item.
| [Info request](#info-request)                   | EBSCO configuration and settings information.
| [CreateSession](#createsession-request)         | Initiate an EBSCO session on behalf of a client.
| [EndSession](#endsession-request)               | Terminate an EBSCO session.
| [Other topics](#other-topics)                   | Additional information assembled from various parts of the EDS documentation.
| [Future investigations](#future-investigations) | Potential areas of investigation/improvement.

#### References

Authoritative information about EBSCO EDS can be found on their web sites.

  - General
    - [EBSCO Discovery Service Wiki][eds_wiki]
    - [YouTube videos][eds_youtube]
  - Search and Retrieval
    - [Searching EDS Content][eds_search]
    - [Performing a Search][eds_perf]
    - [Relevance Ranking][eds_relev]
    - [Retrieving a Detailed Record][eds_detail]
  - Search Fields and Limiters
    - [Field Codes][eds_codes]
    - [Document Types, Publication Types and Source Types][eds_types]
  - Session Management
    - [Authentication][eds_auth]
    - [Error Codes][eds_error]
  - API Details
    - [EBSCO Discovery Service API User Guide][eds_user]
    - [EBSCO Discovery Service API Reference Guide][eds_ref]
    - [EBSCO Discovery Service API User Guide Appendix][eds_appx]
    - [EBSCO Discovery Service API User FAQs][eds_faq]
    - [EBSCO EDS API schema definitions][eds_api]

<style>
  /* === Styling for GET and POST lines === */
  h6      { margin: auto; background: #e0ffff; }
  h2 + h6 { margin-top: -1.5em; }
  h6 + p  { margin-top: 1em; }
</style>

-------------------------------------------------------------------------------

## Search request

###### &nbsp;&nbsp;[GET][eds_get_s] http\://eds-api.ebscohost.com/edsapi/rest/search
###### [POST][eds_post_r] http\://eds-api.ebscohost.com/edsapi/rest/search

The document records returned in a search result contain a subset of the
information for each document.

To obtain full information (in particular, URL links for the full-text download
of an article), a [Retrieve](#retrieve-request) request must be made for each
record individually.

### Parameters
(Click on the parameter name to jump to its description.)

| Parameter                           |            | Format                                             | Default     | Example
| ----------------------------------- | ---------- | -------------------------------------------------- | ----------- | --------------------------------------------------------------------------------------
| [`includefacets`](#includefacets)   | optional   | `y`&#124;`n`                                       | `y`         | `includefacets=y`
| [`facetfilter`](#facetfilter)       | optional   | filterID`,`facetID`:`value\[`,`facetID`:`value\]\* | _none_      | `facetfilter=1,Publisher:wiley-blackwell`
| [`sort`](#sort)                     | optional   | _string_                                           | `relevance` | `sort=date`
| [`query[-n]`](#query)               | *required* | \[BooleanOperator`,`\]\[FieldCode`:`\]Term         | _none_      | `query-1=Rob Hall`<br/>`query-2=OR,AU:Jon Krakauer`<br/>`query-3=OR,SU:Mountaineering`
| [`limiter`](#limiter)               | optional   | limiterID`:`value\[`,`value\]\*                    | _none_      | `limiter=FT:y`
| [`searchmode`](#searchmode)         | optional   | `any`&#124;`bool`&#124;`all`&#124;`smart`          | `all`       | `searchmode=any`
| [`expander`](#expander)             | optional   | _string_                                           | _none_      | `expander=fulltext`
| [`view`](#view)                     | optional   | `title`&#124;`brief`&#124;`detailed`               | `brief`     | `view=detailed`
| [`resultsperpage`](#resultsperpage) | optional   | _integer_                                          | `20`        | `resultsperpage=50`
| [`pagenumber`](#pagenumber)         | optional   | _integer_                                          | `1`         | `pagenumber=3`
| [`highlight`](#highlight)           | optional   | `y`&#124;`n`                                       | `y`         | `highlight=n`
| [`action[-n]`](#action)             | optional   | _(see [Actions documentation][eds_actions])_       | _none_      | `action-1=addfacetfilter(Journal:backpacker)`
| [`relatedcontent`](#relatedcontent) | optional   | type\[`,`type\]\*                                  | _none_      | `relatedcontent=rs`
| [`autosuggest`](#autosuggest)       | optional   | `y`&#124;`n`                                       | `n`         | `autosuggest=y`

#### includefacets

> Specifies whether or not facets should be included in the response.

The date range is included in the response when set to `y`.

|     | Description                                           | Notes
| --- | ----------------------------------------------------- | -------------------------------------------------------
| `y` | Facets and facet hit counts included in the response. | The default behavior if includefacets is not specified.
| `n` | Facets not included in the response.                  |

#### facetfilter

> Refines the results of a previous search.

Filters are defined in terms of a facet types and values.
A facet value group is a collection of one or more pairs of facet types
(identified by an ID) and values that are applied as follows to the search.

Individual facet filters within a group are OR'd together.
If multiple facet filter groups are specified, they are AND'd together.

Facets and their values are obtained by specifying the parameter
`includeFacets=y` in the original search request.
The response to such a request will include facets and their values that are
available for filtering the current results.

|          | Description                          | Notes
| -------- | ------------------------------------ | --------------------------------------------
| filterID | A number that identifies the filter. | The value must be unique within the request.
| facetID  | Unique identifier of the facet type. |
| value    | The facet value to filter on.        |

#### sort

> Specifies how the search results should be sorted.

|             | Description                                      | Notes
| ----------- | ------------------------------------------------ | ----------------------------------------------
| `relevance` | Sort by most relevant search result.             | The default behavior if sort is not specified.
| `date`      | Sort by descending date of publication/issuance. |

Valid sort values are given in the reply to the API Info request in the
[AvailableSorts](#availablesorts) element.

#### [query][eds_query]

> Specifies what to search for.

This parameter may appear multiple times in a request.
When evaluating a search request, the order in which the query expressions are
evaluated may affects results.

This parameter optionally takes an “ordinal” which defines the order when
multiple parameters of the same type are found in a search request.
If the ordinal is omitted, the parameters will be evaluated from left to right
as received.

|                             | Values                                              | Default    | Description                                                                                                                             | Notes
| --------------------------- | --------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------
| [BooleanOperator][eds_bool] | `AND`&#124;`OR`&#124;`NOT`                          | `AND`      | Specifies the how this query expression relates to other query expressions within the same search request.                              |
| [FieldCode][eds_field]      | _([AvailableSearchFields](#availablesearchfields))_ | _none_     | Specifies the search field in which to search for the term.<br/>Valid fields are specified in the metadata supplied by the INFO method. | If not specified the default is to search all authors, all subjects, all keywords, all title info (including source title) and all abstracts.
| [Term][eds_term]            |                                                     | _required_ | The text to search for.                                                                                                                 |

Valid FieldCodes are given in the reply to the API Info request in the
[AvailableSearchFields](#availablesearchfields) element.

#### limiter

> Specifies what to further limit the search by.

|           | Description                                     | Notes
| --------- | ----------------------------------------------- | --------------------------------------------------------------------------
| limiterID | Unique identifier of the limiter.               | The available limiters are specified in the response from the Info Method.
| value     | The value(s) to limit by, separated by a comma. | Only limiters of type "multiselectvalue" will accept more than one value.

Valid limiters are given in the reply to the API Info request in the
[AvailableLimiters](#availablelimiters) element.

#### [searchmode][eds_mode]

> Specifies default boolean operations for search terms with multiple words.

|         | Description                                                                          | Example:<br/>For `query="TI:water desert"` return...
| ------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------
| `all`   | The implied boolean operator is `AND`.                                               | ...titles with "water" AND "desert"
| `any`   | The implied boolean operator is `OR`.                                                | ...titles with "water" OR titles with "desert"
| `bool`  | The words are searched as a phrase (words in order and near each other). \[_**1**_\] | ...titles with "water desert" or "water in the desert"
| `smart` | All of the words are summarized and the most relevant terms are used. \[_**2**_\]    |

> \[_**1**_\] Ignores "stop words"; e.g. the search term "water in the desert"
will be handled the same as the search term "water desert".

> \[_**2**_\] EBSCO SmartText is intended for situations where a large chunk of
text is pasted into the search box.  This mode summarizes the search term text,
extracts the most relevant search terms, and searches for those terms.

Valid search modes are given in the reply to the API Info request in the
[AvailableSearchModes](#availablesearchmodes) element.

#### expander

> Expanders to be applied to this search.

|                   | Description                               | Notes
| ----------------- | ----------------------------------------- | --------------
| `fulltext`        | Include full-text metadata in the search. | On by default.
| `relatedsubjects` | TODO                                      |
| `thesaurus`       | TODO                                      |

Valid expanders are given in the reply to the API Info request in the
[AvailableExpanders](#availableexpanders) element.

#### [view][eds_views]

> Specifies the level of detail in the records returned.

|            | Data elements included in results records
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------
| `title`    | Title, Relevancy score, Custom links, Full text link indicators, AN, Permanent links, Database name and ID, Book jackets, Publication type ID and icons.
| `brief`    | `title` + Authors, Source, Subjects.
| `detailed` | `brief` + Abstract.

The default view (`brief`) is given in the reply to the API Info request in the
[ViewResultSettings](#viewresultsettings) element.

#### resultsperpage

> The number of records to be returned for a search request.

The default number (`20`) is given in the reply to the API Info request in the
[ViewResultSettings](#viewresultsettings) element.

#### pagenumber

> Specifies the page number of records to return.

This is used to determine which records to return for the search.
For example, if the results per page is specified as 20 and the page number is
set to 2, records 21-40 are returned.

#### highlight

> Specifies whether or not to highlight the search term in the results.

|     | Description                                                                   | Notes
| --- | ----------------------------------------------------------------------------- | ---------------------------------------------------
| `y` | Wrap occurrences of search term matches in `<highlight>...</highlight>` tags. | The default behavior if highlight is not specified.
| `n` | Do not modify the results to highlight search term matches.                   |

#### action

> Specifies an action used to operate on the current search request.

Actions are applied after all query string parameters have been resolved.

Actions can optionally specify an ordinal.
Like the query parameter, if the ordinal is omitted, the parameters will be
evaluated from left to right as received.

| Action Name    | Description                                 | Format                     | Examples
| -------------- | ------------------------------------------- | -------------------------- | --------------------------
| `GoToPage`     | Sets the page number on the search request. | `GoToPage(`*int*`)`        | `action-1=GoToPage(2)`
| `SetHighlight` | Sets whether highlighting is on or off.     | `SetHighlight(y`&#124;`n)` | `action-1=SetHighlight(y)`
| ...            | See the [API Reference Guide][eds_actions] for the full listing.

#### relatedcontent

> Comma separated list of related content types to return with the search
results.

#### autosuggest

> Specifies whether auto suggestions should be included in the response.

The default setting (`y`) is given in the reply to the API Info request in the
[AvailableDidYouMeanOptions](#availabledidyoumeanoptions) element.

### Message response format

(Annotations reference the associated item in the `UVA::Article::Ebsco`
namespace.)

- **SearchResponseMessageGet**                  \[**`SearchResponseMessage`**\]
  - SearchRequestGet
    - QueryString
    - SearchCriteriaWithActions
      - QueriesWithAction
        - QueryWithAction _(zero or more)_
          - Query
            - BooleanOperator
            - FieldCode
            - Term
          - RemoveAction
      - FacetFiltersWithAction
        - FacetFilterWithAction _(zero or more)_
          - FilterId
          - FacetValuesWithAction
            - FacetValueWithAction _(zero or more)_
              - FacetValue
                - Id
                - Value
              - RemoveAction
          - RemoveAction
      - LimitersWithAction
        - LimiterWithAction _(zero or more)_
          - Id
          - LimiterValuesWithAction
            - LimiterValueWithAction _(zero or more)_
              - Value
              - RemoveAction
          - RemoveAction
      - ExpandersWithAction
        - ExpanderWithAction _(zero or more)_
          - Id
          - ExpanderValuesWithAction
            - ExpanderValueWithAction _(zero or more)_
              - Value
              - RemoveAction
          - RemoveAction
      - PublicationWithAction
        - Id
        - RemoveAction
  - **SearchResult**                                     \[**`SearchResult`**\]
    - **Statistics**                                       \[**`Statistics`**\]
      - TotalHits                                   \[`Statistics#total_hits`\]
      - TotalSearchTime
      - Databases
        - Database _(zero or more)_
          - Id
          - Label
          - Status
          - Hits
    - **Data**                      \[`SearchResult#data`\] \[**`EbscoData`**\]
      - RecordFormat
      - Records                                            \[`EbscoData#docs`\]
        - **[Record](#record)** _(zero or more) (see [Retrieve response message](#retrieveresponsemessage))_
    - **AvailableFacets**                             \[`SearchResult#facets`\]
      - AvailableFacet _(zero or more)_                         \[**`Facet`**\]
        - Id                                                   \[`Facet#name`\]
        - Label
        - AvailableFacetValues                                \[`Facet#items`\]
          - AvailableFacetValue _(zero or more)_                 \[**`Item`**\]
            - Value                                            \[`Item#value`\]
            - Count                                             \[`Item#hits`\]
            - AddAction
    - RelatedContent
      - RelatedPublications
        - RelatedPublication _(zero or more)_
          - Type
          - Label
          - PublicationRecords
            - Record _(zero or more)_
              - ResultId
              - PLink
              - Header
                - PublicationId
                - IsSearchable
                - RelevancyScore
                - AccessLevel
                - ResourceType
              - [ImageInfo](#ImageInfo)     _(see [Retrieve response message](#RetrieveResponseMessage))_
              - [CustomLinks](#CustomLinks) _(see [Retrieve response message](#RetrieveResponseMessage))_
              - [Items](#Items)             _(see [Retrieve response message](#RetrieveResponseMessage))_
              - [RecordInfo](#RecordInfo)   _(see [Retrieve response message](#RetrieveResponseMessage))_
              - FullTextHoldings
                - FullTextHolding _(zero or more)_
                  - URL
                  - Name
                  - CoverageDates
                    - CoverageDate _(zero or more)_
                      - StartDate
                      - EndDate
                  - CoverageStatement
                  - Databases
                    - DatabaseId _(zero or more)_
                  - Embargo
                  - EmbargoUnit
                  - EmbargoDescription
                  - Facts
                    - Fact _(zero or more)_
                      - Key
                      - Value
                  - Notes
                    - Note _(zero or more)_
                      - NoteId
                      - Rank
                      - NoteName
                      - NoteText
                      - IconUrl
                      - IconText
                      - IconLibRef
                      - HoverText
                      - LinkUrl
                      - DisplaySettings
                        - DisplaySetting _(zero or more)_
      - RelatedRecords
        - RelatedRecord _(zero or more)_
          - Type
          - Label
          - Records
            - **[Record](#record)** _(zero or more) (see [Retrieve response message](#retrieveresponsemessage))_
    - AvailableCriteria
      - DateRange
        - MinDate
        - MaxDate
    - AutoSuggestedTerms
      - AutoSuggestedTerm _(zero or more)_

-------------------------------------------------------------------------------

## Retrieve request

###### &nbsp;&nbsp;[GET][eds_get_r] http\://eds-api.ebscohost.com/edsapi/rest/retrieve
###### [POST][eds_post_r] http\://eds-api.ebscohost.com/edsapi/rest/retrieve

Get full information for a specific EBSCO index record.

### Parameters

| Parameter   | Description         | Required?  | Format   | Default | Example
| ----------- | ------------------- | ---------- | -------- | ------- | -------------
| `dbid`      | Database identifier | *required* | _string_ | _none_  | `dbid=a9h`
| `an`        | Accession number    | *required* | _string_ | _none_  | `an=36108341`

### Message response format <a id="RetrieveResponseMessage"></a>

(Annotations reference the associated item in the `UVA::Article::Ebsco`
namespace.)

- **RetrieveResponseMessage**                 \[**`RetrieveResponseMessage`**\]
  - **Record** <a id="Record"></a>                           \[**`Document`**\]
    - ResultId
    - PLink                                                \[`Document#plink`\]
    - **Header**                                               \[**`Header`**\]
      - DbId                                                  \[`Header#dbid`\]
      - DbLabel
      - An                                                      \[`Header#an`\]
      - RelevancyScore
      - AccessLevel
      - PubType
      - PubTypeId
    - ImageInfo <a id="ImageInfo"></a>
      - CoverArt _(zero or more)_
        - Size
        - Target
    - **CustomLinks** <a id="CustomLinks"></a>      \[`Document#custom_links`\]
      - CustomLink _(zero or more)_                        \[**`CustomLink`**\]
        - Url                                              \[`CustomLink#url`\]
        - Name                                            \[`CustomLink#name`\]
        - Category
        - Text                                            \[`CustomLink#text`\]
        - Icon                                        \[`CustomLink#icon_url`\]
        - MouseOverText
    - **FullText**                                           \[**`FullText`**\]
      - Text
        - Availability
        - Value
      - Links
        - Link _(zero or more)_
          - Type
          - Url
      - CustomLinks                                 \[`FullText#custom_links`\]
        - CustomLink _(zero or more)_                      \[**`CustomLink`**\]
          - Url                                            \[`CustomLink#url`\]
          - Name                                          \[`CustomLink#name`\]
          - Category
          - Text                                          \[`CustomLink#text`\]
          - Icon                                      \[`CustomLink#icon_url`\]
          - MouseOverText
    - **Items** <a id="Items"></a>              \[`Document#display_elements`\]
      - Item _(zero or more)_                          \[**`DisplayElement`**\]
        - Name                                         \[`DisplayElement#key`\]
        - Label
        - Group
        - Data                                       \[`DisplayElement#value`\]
    - **RecordInfo** <a id="RecordInfo"></a>               \[**`RecordInfo`**\]
      - AccessInfo
        - Permissions
          - Permit _(zero or more)_
            - Flag
            - Type
      - **BibRecord**                                       \[**`BibRecord`**\]
        - **BibEntity**                  \[**`BibEntity1`**, **`BibEntity2`**\]
          - Id
          - Type
          - Classifications
            - Classification _(zero or more)_
              - Type
              - Code
              - Scheme
          - **Dates**                                    \[`BibEntity2#dates`\]
            - Date _(zero or more)_                           \[**`DateDMY`**\]
              - Type                                    \[`DateDMY#date_type`\]
              - Text                                         \[`DateDMY#text`\]
              - D                                             \[`DateDMY#day`\]
              - M                                           \[`DateDMY#month`\]
              - Y                                            \[`DateDMY#year`\]
          - **Identifiers** \[`BibEntity1#identifiers`,`BibEntity2#identifiers`\]
            - Identifier _(zero or more)_                  \[**`Identifier`**\]
              - Type                           \[`Identifier#identifier_type`\]
              - Value                                    \[`Identifier#value`\]
              - Scope
          - **Languages**                            \[`BibEntity1#languages`\]
            - Language _(zero or more)_                      \[**`Language`**\]
              - Code
              - Text                                    \[`Language#language`\]
          - **Numbering**                            \[`BibEntity2#numbering`\]
            - Number _(zero or more)_                          \[**`Number`**\]
              - Type                                   \[`Number#number_type`\]
              - Value                                        \[`Number#value`\]
          - **PhysicalDescription**               \[**`PhysicalDescription`**\]
            - Pagination                                   \[**`Pagination`**\]
              - PageCount                           \[`Pagination#page_count`\]
              - StartPage                           \[`Pagination#start_page`\]
          - **Subjects**                              \[`BibEntity1#subjects`\]
            - Subject _(zero or more)_                        \[**`Subject`**\]
              - Type
              - SubjectFull                          \[`Subject#subject_full`\]
              - Authority
          - **Titles**                                  \[`BibEntity2#titles`\]
            - Title _(zero or more)_                            \[**`Title`**\]
              - Type                                           \[`Title#type`\]
              - TitleFull                                     \[`Title#value`\]
          - ItemTypes
            - ItemType _(zero or more)_
              - Type
              - Text
          - ContentDescriptions
            - ContentDescription _(zero or more)_
              - Type
              - Text
        - **BibRelationships**                       \[**`BibRelationships`**\]
          - HasContributorRelationships     \[`BibRelationships#contributors`\]
            - **HasContributor** _(zero or more)_      \[**`HasContributor`**\]
              - PersonEntity                             \[**`PersonEntity`**\]
                - Name                                           \[**`Name`**\]
                  - NameFull                               \[`Name#name_full`\]
          - HasPubAgentRelationships
            - HasPubAgent _(zero or more)_
              - OrganizationEntity _(**one** or more)_
                - Name
                  - NameFull
              - Roles
                - Role _(zero or more)_
          - IsPartOfRelationships \[`BibRelationships#is_part_of_relationships`\]
            - **IsPartOf** _(zero or more)_                  \[**`IsPartOf`**\]
              - **BibEntity** _(recursive definition)_     \[**`BibEntity2`**\]
          - HasPartRelationships
            - HasPart _(zero or more)_
              - **BibEntity** _(recursive definition)_
      - FileInfo
        - File
          - Id
          - IsDownloadable
          - FileName
          - FileLocation
            - Type
            - Location
            - Path
          - ImgCategory
        - FileList
          - File _(zero or more)_
            - Id
            - IsDownloadable
            - FileName
            - FileLocation
              - Type
              - Location
              - Path
            - ImgCategory
        - FilePosLinks
          - FilePosLink _(zero or more)_
            - Id
            - FragId
            - FileId
            - Labels
              - Label _(zero or more)_
                - Type
                - Text
        - FilePosLinkRefLists
          - FilePosLinkRefList _(zero or more)_
            - Use
            - FilePosLinkRefs
              - FilePosLinkRef _(zero or more)_
                - FilePosLinkId
      - PersonRecord
        - Entity
          - Name
            - NameFull
      - RightsInfo
        - RightsStatements
          - RightsStatement _(zero or more)_
            - Type
            - Text

-------------------------------------------------------------------------------

## Info request

###### &nbsp;&nbsp;[GET][eds_get_i] http\://eds-api.ebscohost.com/edsapi/rest/info
###### [POST][eds_post_i] http\://eds-api.ebscohost.com/edsapi/rest/info

The Info request reports on configured defaults and the sets of valid values
for sorting and searching.
Some of these values are tuneable by changing the Library's EBSCO profile
through the [EBSCOadmin][ebsco_admin] interface.
(At the UVa Library, this requires coordination with the librarian responsible
for maintaining electronic journals.)

This request will always send the same information until the EBSCO profile is
changed.

Virgo does not currently send this request, nor is it set up to handle the
possibility that any of the values might change.
It's not likely that we would find much value in processing this information
dynamically in the production service.  But there would be some benefit to
checking this within automated testing to verify that the values have not
changed.

### Message response format

- **InfoResponseMessage**
  - AvailableSearchCriteria
    - [AvailableSorts](#availablesorts)
    - [AvailableSearchFields](#availablesearchfields)
    - [AvailableExpanders](#availableexpanders)
    - [AvailableLimiters](#availablelimiters)
    - [AvailableSearchModes](#availablesearchmodes)
    - AvailableRelatedContent
    - [AvailableDidYouMeanOptions](#availabledidyoumeanoptions)
  - [ViewResultSettings](#viewresultsettings)
  - [ApplicationSettings](#applicationsettings)
  - [ApiSettings](#apisettings)

#### ApiSettings

| Item                           | Value |
| ------------------------------ | ----- |
| [MaxRecordJumpAhead][eds_jump] | `250` |

#### ApplicationSettings

| Item               | Value  | Units   |
| ------------------ | ------ | ------- |
| SessionTimeout     | `1800` | seconds |

#### ViewResultSettings

| Item               | Value   |
| ------------------ | ------- |
| ResultsPerPage     | `20`    |
| ResultListView     | `brief` |

#### AvailableDidYouMeanOptions

| Id                           | Label          | DefaultOn |
| ---------------------------- | -------------- | --------- |
| [`AutoSuggest`][eds_suggest] | "Did You Mean" | **y**     |

#### [AvailableExpanders][eds_expand]

| Id                | Label                                              | DefaultOn | AddAction
| ----------------- | -------------------------------------------------- | --------- | ----------------------------
| `relatedsubjects` | "Apply equivalent subjects"                        | n         | addexpander(relatedsubjects)
| `thesaurus`       | "Apply related words"                              | n         | addexpander(thesaurus)
| `fulltext`        | "Also search within the full text of the articles" | **y**     | addexpander(fulltext)

#### AvailableLimiters

| Id     | Label                                | Type             | DefaultOn | AddAction              | Order
| ------ | ------------------------------------ | ---------------- | --------- | ---------------------- | -----
| `FR`   | "References Available"               | select           | n         | addlimiter(FR:value)   | 1
| `FT`   | "Full Text"                          | select           | n         | addlimiter(FT:value)   | 2
| `RV`   | "Scholarly (Peer Reviewed) Journals" | select           | n         | addlimiter(RV:value)   | 3
| `SO`   | "Journal Name"                       | text             | n         | addlimiter(SO:value)   | 4
| `AU`   | "Author"                             | text             | n         | addlimiter(AU:value)   | 5
| `DT1`  | "Published Date"                     | ymrange          | n         | addlimiter(DT1:value)  | 6
| `TI`   | "Title"                              | text             | n         | addlimiter(TI:value)   | 7
| `FT1`  | "Available in Library Collection"    | select           | n         | addlimiter(FT1:value)  | 8
| `LA99` | "Language"                           | multiselectvalue | n         | addlimiter(LA99:value) | 9

Others mentioned on the EDS Wiki [FieldCodes][eds_codes] page:

| FieldCode | Description      | Example
| --------- | ---------------- | -------------------------------------------------------------
| `DT`      | Date limiter     | `DT 20050101-20150101` limits from Jan 1, 2005 to Jan 1, 2015
| `LA`      | Language         | `LA eng OR LA english` (both needed to get them all)
| `PT`      | Publication Type | `PT Article OR PT Journal Article`
| `PZ`      | Document Type    | `PZ editorials`, `PZ interviews`, `PZ theses`
| `ZT`      | ???              |

#### AvailableSearchFields

| FieldCode | Label           |
| --------- | --------------- |
| `TX`      | "All Text"      |
| `AU`      | "Author"        |
| `TI`      | "Title"         |
| `SU`      | "Subject Terms" |
| `SO`      | "Source"        |
| `AB`      | "Abstract"      |
| `IS`      | "ISSN"          |
| `IB`      | "ISBN"          |

#### AvailableSearchModes

| Id      | Label                         | DefaultOn | AddAction            |
| ------- | ----------------------------- | --------- | -------------------- |
| `bool`  | "Boolean/Phrase"              | n         | setsearchmode(bool)  |
| `all`   | "Find all my search terms"    | **y**     | setsearchmode(all)   |
| `any`   | "Find any of my search terms" | n         | setsearchmode(any)   |
| `smart` | "SmartText Searching"         | n         | setsearchmode(smart) |

#### AvailableSorts

| Id          | Label         | AddAction          |
| ----------- | ------------- | ------------------ |
| `date`      | "Date Newest" | setsort(date)      |
| `relevance` | "Relevance"   | setsort(relevance) |
| `date2`     | "Date Oldest" | setsort(date2)     |

-------------------------------------------------------------------------------

## CreateSession request

###### [POST][eds_post_cs] http\://eds-api.ebscohost.com/edsapi/rest/createsession
###### &nbsp;&nbsp;[GET][eds_get_cs] http\://eds-api.ebscohost.com/edsapi/rest/createsession

Establishes an EBSCO EDS session for the current client.
The retrieved `SessionToken` must be supplied with the header of subsequent
requests.

### Parameters

| Parameter | Description            | Required?  | Format       | Default | Example
| --------- | ---------------------- | ---------- | ------------ | ------- | -----------------
| `Profile` | EBSCO profile ID       | *required* | _string_     | _none_  | `profile=uva_api`
| `Guest`   | Non-privileged session | optional   | `y`&#124;`n` | `n`     | `guest=y`
| `Org`     | Organization name      | optional   | _string_     | _none_  | `org=UVa Library`

### Message response format

- **CreateSessionResponseMessage**
  - SessionToken                       (see `UVA::Article::Ebsco#open_session`)

-------------------------------------------------------------------------------

## EndSession request

###### [POST][eds_post_es] http\://eds-api.ebscohost.com/edsapi/rest/endsession
###### &nbsp;&nbsp;[GET][eds_get_es] http\://eds-api.ebscohost.com/edsapi/rest/endsession

Terminates the EBSCO EDS session for the current client.

This request is not mandatory; the session will automatically terminate within
[SessionTimeout](#applicationsettings) seconds.

### Parameters

| Parameter      | Description                             | Required?  | Format   | Default |
| -------------- | --------------------------------------- | ---------- | -------- | ------- |
| `SessionToken` | Returned from previous `CreateSession`. | *required* | _string_ | _none_  |

### Message response format

- EndSessionResponse
  - IsSuccessful                      (see `UVA::Article::Ebsco#close_session`)

-------------------------------------------------------------------------------

## Other topics

### Source Type

Some of these source types would only be encountered if catalog holdings were
uploaded and searched via EDS (that is, they won't be encountered when
searching for articles).

| Count       | Source Type                | Rolled up from these Publication Types
| -----------:| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------
| 143,221,043 | `Academic Journals`        | Academic Journal, Peer-Reviewed Journal
| 57,043,661  | `Magazines`                | Periodical, Journal Article, Journal
| -           | `Trade Publications`       | Trade Publication
| 43,382,022  | `News`                     | Newspaper, Newswire
| 596,058     | `Books`                    | Book, Almanac, Reference Book, Book Collection, Essay, Audiobook, eBook
| 15,491,461  | `Reviews`                  | Book Review, Film Review, Product Review
| 558,725     | `Reports`                  | Country Report, Market Research Report, Report, Educational Report, SWOT Analysis, Industry Report, Industry Profile, Grey Literature
| 721,397     | `Conference Materials`     | Conference Paper, Conference Proceeding,  Symposium
| 71          | `Dissertations`            | Dissertation, Thesis
| 119,283     | `Biographies`              | Biography
| 54,772      | `Primary Source Documents` | Legal Document, Primary Source Document
| -           | `Government Documents`     | Government Document
| -           | `Music Score`              | Music, Music Score, Multiple Score Format, Voice Score, Printed Music
| -           | `Research Starters`        | Research Starters Content
| 10,863      | `Electronic Resources`     | Computer File, Computer, Electronic Resource, eBook, Website
| 2,832       | `Non-Print Resources`      | CD-ROM, Game, Kit, Mixed Materials, Multimedia, Object, Realia, Visual Material, Technical Drawing
| 13          | `Audio`                    | Audio, Audiobook, Audiocassette, Audiovisual, Sound Recording
| -           | `Videos`                   | DVD, Motion Picture, Video
| -           | `Maps`                     | Map

The Count column shows the response counts for each source type reported by:
```
search?query=TX:*&expander=fulltext&view=title&facetfilter=0,SourceType:NAME
```
Items with a dash (-) returned no results.

Similar (but not identical!) results can be seen from the SourceType facet hits
reported by
```
search?query=TX:*&expander=fulltext&view=title
```

### Publication Type

This list is gathered from EDS documentation sources.
Some of these publication types would only be encountered if catalog holdings
were uploaded and searched via EDS (that is, they won't be encountered when
searching for articles).

| PT Count    | Publication Type            |
| -----------:| --------------------------- |
| 108,218,616 | `Academic Journal`          |
| 15,649      | `Almanac`                   |
| 13          | `Audio`                     |
| -           | `Audiobook`                 |
| -           | `Audiocassette`             |
| -           | `Audiovisual`               |
| 92,812      | `Biography`                 |
| 559,645     | `Book`                      |
| 276         | `Book Collection`           |
| 46,889      | `Book Review`               |
| -           | `CD-ROM`                    |
| -           | `Computer`                  |
| 1           | `Computer File`             |
| 597,166     | `Conference Paper`          |
| 93,120      | `Conference Proceeding`     |
| 157,421     | `Country Report`            |
| 3           | `Dissertation`              |
| -           | `DVD`                       |
| -           | `eBook`                     |
| -           | `Educational Report`        |
| 10,863      | `Electronic Resource`       |
| 143         | `Essay`                     |
| 1,338       | `Film Review`               |
| -           | `Game`                      |
| 2,066       | `Government Document`       |
| -           | `Grey Literature`           |
| 67,382      | `Industry Profile`          |
| -           | `Industry Report`           |
| -           | `Journal`                   |
| 21,404,045  | `Journal Article`           |
| -           | `Kit`                       |
| -           | `Legal Document`            |
| 5           | `Map`                       |
| 100,532     | `Market Research Report`    |
| -           | `Mixed Materials`           |
| -           | `Motion Picture`            |
| 28          | `Multimedia`                |
| -           | `Multiple Score Format`     |
| -           | `Music`                     |
| -           | `Music Score`               |
| 34,793,516  | `Newspaper`                 |
| 290,811     | `Newswire`                  |
| -           | `Object`                    |
| -           | `Peer-Reviewed Journal`     |
| 55,853,564  | `Periodical`                |
| 66,965      | `Primary Source Document`   |
| -           | `Printed Music`             |
| 9,116       | `Product Review`            |
| -           | `Realia`                    |
| -           | `Reference Book`            |
| 81,636      | `Report`                    |
| -           | `Research Starters Content` |
| -           | `Sound Recording`           |
| -           | `SWOT Analysis`             |
| -           | `Symposium`                 |
| -           | `Technical Drawing`         |
| -           | `Thesis`                    |
| 23,421,336  | `Trade Publication`         |
| -           | `Video`                     |
| -           | `Visual Material`           |
| -           | `Voice Score`               |
| 4,566       | `Website`                   |

The Count column shows the response counts for each publication type reported
by:
```
search?expander=fulltext&view=title&query=PT:TYPE
```
Items with a dash (-) returned no results.

> NOTE: The meaningfulness of the result numbers are questionable.
The effectiveness of `query=PT` would have to be investigated before drawing
any conclusions from the results in this table.

-------------------------------------------------------------------------------

## Future investigations

##### Provide a mechanism for the user to select [hit highlighting][eds_hilite]

- Probably the simplest thing would be to unconditionally send Search requests
  with `highlight=y` (and Retrieve requests with `highlightterms`) and then
  simply change how `<highlight>` HTML elements are handled
  depending on the user selection.
  
- This is probably best done in the client by providing a control to toggle the
  styling on these elements:  With hit-highlighting turned on, `<highlight>`
  elements would have one set of style properties; with hit-highlighting turned
  off they would have the same style properties as neighboring text. 
  
- Solr also has the ability to do hit-highlighting, so whatever approach is
  used it should be able to support user-selectable hit-highlighting for Solr
  results as well.

##### Determine whether we can make use of [autosuggest][eds_suggest]

- If a search term appears to be a misspelling of one or more other words, they
  will be provided with the returned search results; these can be used to
  create search links with the same parameters but with the "misspelled" word
  replaced with the suggested word.
  
- For symmetry with catalog search, it would be preferable that the same kind
  of service could be provided for Solr searches as well.

##### Make use of [cover images][eds_covers]

- These will not be available for all (maybe most) items, but if they are
  provided then they should be used.
  
- Most likely these would be treated like images/URLs that are provided by some
  Solr records -- the indicated data would be used in place of a request to the
  cover image server.

##### Optimizations to improve [access speed][eds_speedup]

- Investigate use of `session` or in-memory cookies to save and restore search
results pages rather than re-issuing the same query.
  - Use case: After performing a search, visiting a details page, and returning
  to the search -- rather than re-issuing the search to populate the search
  results page, contents of the page could be taken from a session variable
  created when the search results page was first acquired.
  - This could be applicable to Solr searches as well.
  - Supporting this would require more sophisticated session management in
  general, but once that conceptual model was in place, there are probably a
  lot of situations where pages could be updated much faster by avoiding
  duplication of network requests.

- Investigate use of *actions* to modify defaults for subsequent requests.
  - Use case: Make selection of the "peer reviewed" limiter into a toggle
  rather than making it appear as a kind of facet.  Then the setting of the
  toggle would reflect the state of the limiter without having to add
  `limiter=RV:Y` when "peer-reviewed" was selected because the search that
  included `action=AddLimiter(RV:y)`.
  - This is theoretical; better documentation on the effects of *actions* needs
  to be found and/or experimentation is needed to see whether they really act
  as described here.
  - This would also require more sophisticated session management.

---
---

> [![Blacklight][bl_img]][bl_url]
> Virgo is based on the [Blacklight][bl_url] [gem][bl_gem] for searching Solr indexes in Ruby-on-Rails.

> [![RubyMine][rm_img]][rm_url]
> Virgo developers use [RubyMine][rm_url] for better Ruby-on-Rails development.

<!---------------------------------------------------------------------------->
<!-- Other link references:
REF ---------- LINK ---------------------------- TOOLTIP --------------------->
[ebsco_admin]: http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide_Appendix#EBSCOadmin_Options
[eds_wiki]:    http://edswiki.ebscohost.com/EBSCO_Discovery_Service_Wiki
[eds_actions]: http://edswiki.ebscohost.com/API_Reference_Guide:_Search_and_Retrieve:_Search#Actions
[eds_api]:     https://eds-api.ebscohost.com/edsapi/rest/help
[eds_appx]:    http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide_Appendix
[eds_auth]:    http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide#Authentication
[eds_bool]:    http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide_Appendix#BooleanOperator_Property
[eds_codes]:   http://edswiki.ebscohost.com/Field_Codes
[eds_covers]:  http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_FAQs#Do_I_get_links_to_book_jackets_returned_in_the_Search_response.3F
[eds_detail]:  http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide#Retrieving_a_Detailed_Record
[eds_error]:   http://edswiki.ebscohost.com/API_Reference_Guide:_Error_Codes
[eds_expand]:  http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide_Appendix#Expander_Search_Specification
[eds_faq]:     http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_FAQs
[eds_field]:   http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide_Appendix#FieldCode_Property
[eds_get_cs]:  https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/CreateSession
[eds_get_es]:  https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/EndSessionGet
[eds_get_i]:   https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/Info
[eds_get_r]:   https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/RetrieveFromQueryString
[eds_get_s]:   https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/SearchFromQueryString
[eds_hilite]:  http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_FAQs#How_do_I_highlight_my_query_terms_in_Search_and_Retrieve_responses.3F
[eds_jump]:    http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide_Appendix#Max_Record_Jump_Ahead
[eds_mode]:    https://help.ebsco.com/interfaces/EBSCO_Guides/EBSCO_Interfaces_User_Guide/Applying_Search_Modes
[eds_perf]:    http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide#Performing_a_Search
[eds_post_cs]: https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/CreateSessionFromPost
[eds_post_es]: https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/EndSessionPost
[eds_post_i]:  https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/InfoPost
[eds_post_r]:  https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/RetrieveFromPostedData
[eds_post_s]:  https://eds-api.ebscohost.com/EDSAPI/rest/help/operations/SearchFromPostedData
[eds_query]:   http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide_Appendix#EDS_API_-_Search.27s_Query_Parameter
[eds_ref]:     http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_Reference_Guide
[eds_relev]:   http://edswiki.ebscohost.com/Relevance_Ranking:_How_it_Works
[eds_search]:  http://edswiki.ebscohost.com/Searching_EDS_Content
[eds_speedup]: http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide#Improving_Application_Speed_-_Not_Required
[eds_suggest]: http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_FAQs#How_do_I_get_and_use_autosuggested_terms.3F
[eds_term]:    http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide_Appendix#Understanding_How_the_Term_is_Effected_by_the_SearchMode_Parameter
[eds_text]:    http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_FAQs#How_is_full_text_retrieved_in_EDS_API.3F
[eds_types]:   http://support.epnet.com/knowledge_base/detail.php?id=6674
[eds_user]:    http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_Guide
[eds_views]:   http://edswiki.ebscohost.com/EBSCO_Discovery_Service_API_User_FAQs#Why_are_there_3_views_.28Title_Only.2C_Brief.2C_Detailed.29.3F
[eds_youtube]: https://www.youtube.com/results?search_query=%22EDS+API%22
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
