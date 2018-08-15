# app/controllers/concerns/starred_items_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving the "starred item" folder.
#
# @see UVA::Helper::StarredItems
#
module StarredItemsConcern

  extend ActiveSupport::Concern

  include AccessIndexConcern
  include AccessArticlesConcern

  include UVA::StarredItems

  # Messages displayed to the user by this feature.
  MESSAGE = {
    all_clear:         'Cleared all starred items.',
    no_cite_items:     'Please star some items to cite.',
    no_clear_items:    'There are no starred items to clear.',
    no_csv_items:      'Please star some items to export.',
    no_email_items:    'Please star some items to email.',
    no_endnote_items:  'Please star some items to export to EndNote.',
    no_print_items:    'Please star some items to print.',
    no_refworks_items: 'Please star some items to export to RefWorks.',
    no_zotero_items:   'Please star some items to export to Zotero.',
  }.deep_freeze

  OK_STATUS = 'OK'.freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # redirect_back
  #
  # @param [String] message
  #
  # @return [String]
  #
  def redirect_back(message = nil)
    flash[:notice] = message if message.present?
    redirect_to referring_page
  end

  # referring_page
  #
  # @return [String]
  #
  def referring_page
    request.env['HTTP_REFERER'] || root_url
  end

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  public

  # set_max_per_page
  #
  # @return ['true']
  #
  def set_max_per_page
    params[:show_max_per_page] = 'true'
  end

  # Get items either from URL parameters or from starred items.
  #
  # @return [void]
  #
  def get_items
    if params[:id] || params[:article_id]
      set_documents
      set_articles
    else
      get_starred_items
    end
  end

  # Get starred items, which results in updating @documents and @articles
  # with the currently selected items.
  #
  # @return [void]
  #
  def get_starred_items
    get_starred_documents
    get_starred_articles
  end

  # Get documents from the index.
  #
  # @param [String, Array<String>] ids
  #
  # @return [Array<UVA::IndexDoc>]
  #
  def get_starred_documents(ids = nil)
    ids ||= starred_document_ids
    set_documents(ids)
  end

  # Get articles from the article provider.
  #
  # @param [String, Array<String>] ids
  #
  # @return [Array<UVA::ArticleDoc>]
  #
  def get_starred_articles(ids = nil)
    ids ||= starred_article_ids
    set_articles(ids)
  end

  # This action receives a list of params[:id] and params[:article_id] which
  # are to be added or removed from the session variables holding
  # :folder_document_ids and :folder_article_ids.
  #
  # If a param id or article_id is already on the respective session variable
  # list, then that id is removed from the respective session variable list.
  #
  # If a param id or article_id is not already on the respective session
  # variable list, then it is added to the respective session variable list.
  #
  # @param [String, Array<String>] document_ids
  # @param [String, Array<String>] article_ids
  # @param [Boolean]               add_only     If *true* then do not delete
  #                                               items that are already in the
  #                                               folder.
  #
  #
  # @return [Array<(String, Array<String>)>]
  #
  def update_starred_items(
    document_ids = nil,
    article_ids  = nil,
    add_only     = false
  )
    # Get arguments, defaulting to `params` values, as arrays of ids whose
    # "starred" state will be toggled.
    document_ids ||= params[:id]
    article_ids  ||= params[:article_id]
    document_ids = Array(document_ids).compact
    article_ids  = Array(article_ids).compact

    # "Unstar" any items that were already present in the folder by deleting
    # them now unless *add_only* is true.  In either case, the items are
    # removed from the list of items to be added to the folder.
    if add_only
      document_ids.delete_if { |id| starred_document_ids.include?(id) }
      article_ids.delete_if  { |id| starred_article_ids.include?(id)  }
    else
      document_ids.delete_if { |id| starred_document_ids.delete(id) }
      article_ids.delete_if  { |id| starred_article_ids.delete(id)  }
    end

    # "Star" any remaining ids by adding them to the folder, limited by the
    # number of slots still open.
    documents_added = document_ids.first(remaining_item_count)
    articles_added  = article_ids.first(remaining_item_count)
    starred_document_ids.concat(documents_added)
    starred_article_ids.concat(articles_added)

    # Return with "OK" if all ids were added as expected or return with the
    # limit if it was exceeded.
    expected  = document_ids.size + article_ids.size
    added_ids = documents_added + articles_added
    status = (added_ids.size < expected) ? max_folder_items.to_s : OK_STATUS
    return status, added_ids
  end

end
