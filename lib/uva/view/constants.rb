# lib/uva/view/constants.rb

require 'uva'

module UVA::View

  module Constants

    include UVA

    RETURN_TO_SEARCH = '&larr; Return to search results'.html_safe.freeze

    DEBUG_OPT         = { label: { class: 'debug'               } }.deep_freeze
    AUTHOR_OPT        = { value: { class: 'author-field'        } }.deep_freeze
    DATE_OPT          = { value: { class: 'date-field'          } }.deep_freeze
    CALL_NUMBER_OPT   = { value: { class: 'call-number-field'   } }.deep_freeze
    ONLINE_OPT        = { value: { class: 'online-access-field' } }.deep_freeze

    FOLDER_AUTHOR_OPT = {
      class: 'author',
      value: { join: false, html_tag: 'span', class: 'starred-author' }
    }.deep_freeze
    FOLDER_TITLE_OPT  = { class: 'title' }.deep_freeze
    FOLDER_FORMAT_OPT = { class: 'format', value: { join: true } }.deep_freeze
    FOLDER_DATE_OPT   = { class: 'year',   value: { join: true } }.deep_freeze
    FOLDER_TYPE_OPT   = { class: 'type',   value: { join: true } }.deep_freeze
    FOLDER_ACCESS_OPT = { class: 'access', value: { join: true } }.deep_freeze

    FORMAT_OPT        = { value: { class: 'format'} }.deep_freeze
    YEAR_OPT          = { value: { class: 'year'  } }.deep_freeze

    VIDEO_LENS_OPT    = { value: { html_tag: 'div' } }.deep_freeze
    VIDEO_FORMAT_OPT  = VIDEO_LENS_OPT.deep_merge(FORMAT_OPT).deep_freeze
    VIDEO_YEAR_OPT    = VIDEO_LENS_OPT.deep_merge(YEAR_OPT).deep_freeze
    VIDEO_CALL_NUMBER_OPT =
      VIDEO_LENS_OPT.deep_merge(CALL_NUMBER_OPT).deep_freeze

    # Settings and attributes common to all contexts.
    #
    COMMON_CONTEXT = { label: { no_eval: true } }.deep_freeze

    # Settings and attributes for rendering display fields on an index search
    # results page.
    #
    # Field values displays have a maximum length so that article abstracts
    # take up roughly no more than four lines.
    #
    INDEX_CONTEXT =
      COMMON_CONTEXT.deep_merge(
        html:     true,
        join:     true,
        max_len:  260, # characters
        label:    { html_tag: 'dt' },
        value:    { html_tag: 'dd' },
      ).deep_freeze

    # Settings and attributes for rendering display fields on an item details
    # show page.
    #
    SHOW_CONTEXT =
      COMMON_CONTEXT.deep_merge(
        html:     true,
        join:     false,
        label:    { html_tag: 'dt' },
        value:    { html_tag: 'dd' },
      ).deep_freeze

    # Settings and attributes for rendering display fields on an email (or
    # similar text-only situation).
    #
    EMAIL_CONTEXT =
      COMMON_CONTEXT.deep_merge(
        html:     false,
        join:     true,
        label:    { after: ': ' },
        value:    { sanitize: true }, # TODO: Column alignment
      ).deep_freeze

    # Settings and attributes for rendering display fields for export (through
    # citations, etc.).
    #
    EXPORT_CONTEXT =
      COMMON_CONTEXT.deep_merge(
        html:     false,
        join:     true,
        label:    { visible: false },
        value:    {},
      ).deep_freeze

    # Settings and attributes for rendering display fields as folder rows in
    # the "Starred Items" context.
    #
    FOLDER_CONTEXT =
      COMMON_CONTEXT.deep_merge(
        html:     true,
        join:     false,
        field:    { html_tag: 'td' }, # TODO: Sub-tree for the whole display field.
        label:    { visible: false },
        value:    {},
      ).deep_freeze

    # Settings and attributes for rendering display fields in an RSS feed.
    #
    RSS_CONTEXT =
      COMMON_CONTEXT.deep_merge(
        html:     false,
        join:     true,
        max_len:  250, # characters
        label:    { after: ': ' },
        value:    { after: '<br/>' },
      ).deep_freeze

    # A mapping of context id to context settings/attributes.
    #
    CONTEXT = {
      index:  INDEX_CONTEXT,
      show:   SHOW_CONTEXT,
      email:  EMAIL_CONTEXT,
      export: EXPORT_CONTEXT,
      folder: FOLDER_CONTEXT,
      rss:    RSS_CONTEXT,
    }.freeze

  end

end
