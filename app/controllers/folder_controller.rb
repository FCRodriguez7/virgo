# app/controllers/folder_controller.rb

require 'uva'

# This controller implements the "Starred Items" functionality which allows
# the user to accumulate a list of catalog and/or article entries that will be
# subject to the same operation (e.g., citation, e-mail, course reserve. etc.).
#
# === Implementation Notes
# This definition extends/overrides Blacklight's FolderController; however,
# because *config/routes.rb* does not include :folder in the argument to
# `Blacklight.add_routes`, route methods defined there are not necessarily
# supported by this controller definition.
#
# @see "#{Blacklight.controllers_dir}/folder_controller.rb"
#
# @see StarredItemsConcern
#
class FolderController < ApplicationController

  include AccessArticlesConcern
  include AccessIndexConcern
  include StarredItemsConcern

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  before_filter :set_max_per_page,  only: [:index, :refworks_texts, :csv, :ris]
  before_filter :get_items,         only: [:refworks_texts, :csv, :ris]
  before_filter :get_starred_items, only: [:index]

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /folder
  # Replaces the Blacklight FolderController method.
  #
  # @see StarredItemsConcern#get_starred_items
  #
  def index
    respond_to do |format|
      format.html { render }
      format.json { redirect_to list_folders_path }
      format.text { redirect_to list_folders_path }
    end
  end

  # == POST /folder
  # == POST /folder?add_only=true
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
  # This action will return a JSON response in the form of an array of exactly
  # 2 items:
  #
  # The item at location 0 will always be a status string.  Its value will be
  # 'OK' if all requested items were added to the folder.  If all items to be
  # added were not added to the folder, the max number of items permitted in
  # the folder will be returned as the string.
  #
  # The item at location 1 of the JSON response is an array.  The array will
  # either be empty or contain a list of the ids which were actually added to
  # the folder.  The item at location 1 of the json response will NEVER be nil.
  #
  # @see app/assets/javascripts/feature/starred-items
  #
  def create
    status, added_ids =
      update_starred_items(params[:id], params[:article_id], params[:add_only])
    respond_to do |format|

      # Do not refresh or display anything to the web client.  Refresh of the
      # starred/unstarred items takes place on the client side to keep the page
      # from scrolling back to top.
      format.html { render nothing: true }

      # Package the status and the combined list of actually added ids to the
      # JSON response.  (This list may be smaller than the list of ids to add
      # if the maximum number of starred items has been reached.)
      format.js { render json: [status, added_ids] }

    end
  end

  # == GET /folder/destroy?id=ID
  # Remove a starred catalog item from the starred folder page or from a
  # catalog item's detail page.
  #
  # Replaces the Blacklight FolderController method.
  #
  def destroy
    unstar_item
    respond_to do |format|
      format.html { redirect_back } # The page refreshes after the deletion.
      format.js   { render nothing: true }
    end
  end

  # == POST /folder/clear
  # Get rid of the items in the folder.
  #
  # Replaces the Blacklight FolderController method.
  #
  # @see app/assets/javascripts/feature/starred-items
  #
  def clear
    if folder_empty?
      message = MESSAGE[:no_clear_items]
    else
      unstar_all_items
      message = MESSAGE[:all_clear]
    end
    redirect_back(message)
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /folder/refworks_texts
  #
  # @see StarredItemsConcern#get_items
  #
  def refworks_texts
    if @documents.blank? && @articles.blank?
      redirect_back(MESSAGE[:no_refworks_items])
    end
  end

  # == GET /folder/csv
  #
  # @see StarredItemsConcern#get_items
  #
  def csv
    if @documents.blank? && @articles.blank?
      redirect_back(MESSAGE[:no_csv_items])
    else
      respond_to do |format|
        format.csv
      end
    end
  end

  # == GET /folder/citation
  #
  def citation
    if folder_empty?
      redirect_back(MESSAGE[:no_cite_items])
    else
      redirect_to_catalog(path_opt.merge(action: __method__))
    end
  end

  # == GET /folder/email
  #
  def email
    if folder_empty?
      redirect_back(MESSAGE[:no_email_items])
    else
      redirect_to_catalog(path_opt.merge(action: __method__))
    end
  end

  # == GET /folder/print
  #
  def print
    if folder_empty?
      redirect_back(MESSAGE[:no_print_items])
    else
      redirect_to folders_path(view: 'print')
    end
  end

  # == GET /folder/endnote
  #
  def endnote
    if folder_empty?
      redirect_back(MESSAGE[:no_endnote_items])
    else
      redirect_to_catalog(action: __method__, format: 'endnote')
    end
  end

  # == GET /folder/ris
  #
  def ris
    if @documents.blank? && @articles.blank?
      redirect_back(MESSAGE[:no_zotero_items])
    else
      respond_to do |format|
        format.ris
      end
    end
  end

  # == GET /folder/course_reserve
  #
  def course_reserve
    redirect_to(
      controller:        'reserves',
      action:            'email',
      id:                starred_document_ids,
      show_max_per_page: 'true'
    )
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /folder/list
  # Get the current list of starred item IDs (for use with scripting).
  #
  # This is preferred over `/folder?format=json` because it does not trigger
  # filters which perform Solr and/or EBSCO lookups.
  #
  # @see UVA::StarredItem#starred_items_json
  # @see getStarredItems() in app/assets/javascripts/feature/starred-items
  #
  def list
    expires_now
    respond_to do |format|
      format.any(:json, :js)   { render json: starred_items_json }
      format.any(:html, :text) { render text: starred_items_text }
    end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # redirect_to_catalog
  #
  # @param [Hash] opt
  #
  # @return [void]
  #
  def redirect_to_catalog(opt = nil)
    url_params = {
      controller:        'catalog',
      id:                starred_document_ids,
      article_id:        starred_article_ids,
      show_max_per_page: 'true'
    }
    url_params.merge!(opt) if opt.present?
    redirect_to(url_params)
  end

end
