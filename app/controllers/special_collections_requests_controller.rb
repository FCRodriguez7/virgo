# app/controllers/special_collections_requests_controller.rb

require 'uva'

# This controller implements the Special Collections request queue, both the
# patron-facing portion for submitting requests and the librarian-facing
# portion for updating and removing requests.
#
# Special Collections requests are for patrons to obtain items for viewing in
# the Special Collections reading room.  Also used by Special Collections
# administrators to view and process the request queue.
#
# @see SpecialCollectionsConcern
#
class SpecialCollectionsRequestsController < ApplicationController

  include SpecialCollectionsConcern

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  before_filter :verify_admin,  except: [:start, :new, :create, :non_uva]
  before_filter :verify_ip,     only:   [:start, :new]
  before_filter :bypass_login,  only:   [:start]
  before_filter :new_request,   only:   [:start, :new, :non_uva]
  before_filter :build_request, only:   [:create]
  before_filter :validate_user, only:   [:new, :create]

  # ===========================================================================
  # :section: Exception Handlers
  # ===========================================================================

  rescue_from Blacklight::Exceptions::InvalidSolrID do |error|
    flash[:notice] = MESSAGE[:bad_item] % error
    Rails.logger.info { "REDIRECT due to #{error}" }
    redirect portal_index_path(path_opt)
  end

  rescue_from UVA::Exceptions::HiddenSolrID do |error|
    flash[:notice] = MESSAGE[:bad_item] % error
    Rails.logger.info { "REDIRECT due to #{error}" }
    redirect portal_index_path(path_opt)
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /special_collections_requests
  # Used by special collections staff to view the request queue.
  #
  def index
    get_requests
    respond_to do |format|
      format.html { render layout: layout_name }
    end
  end

  # == GET /special_collections_requests/CATKEY/new
  # Pulls up the items and allows a person to construct a request.
  #
  def new
    initialize_request(params[:id])
    respond_to do |format|
      format.html { render layout: layout_name }
    end
  end

  # == POST /special_collections_requests
  # Submits the request.
  #
  def create
    status = create_request
    respond_to do |format|
      format.html do
        if status == :created
          flash[:notice] = MESSAGE[status]
        else
          flash[:error]  = MESSAGE[status]
        end
        doc_id = @sc_request.document_id
        case status
          when :no_items
            redirect new_special_collections_request_path(doc_id, path_opt)
          when :not_created
            if no_redirects?
              render_flash_only
            else
              render action: 'start', layout: layout_name
            end
          else
            if in_popup?
              render_flash_only
            else
              redirect catalog_path(doc_id, path_opt)
            end
        end
      end
    end
  end

  # == GET /special_collections_requests/REQUEST_ID/edit
  # Used by Special Collections staff to review an individual request.
  #
  # @return [SolrDocument]
  #
  def edit
    req_id = params[:id]
    load_request(req_id)
    initialize_request(@sc_request.document_id)
    respond_to do |format|
      format.html { render layout: layout_name }
    end
  end

  # == PUT /special_collections_requests/REQUEST_ID
  # Used by Special Collections staff to process the request.
  #
  def update

    # Get the database record and update it with the new information.
    status = update_request(params[:id], params[:special_collections_request])

    # Generate a new PDF if successful; go back to the edit page if not.
    if status == :updated
      redirect_to action: 'show', format: 'pdf'
    else
      respond_to do |format|
        format.html do
          flash[:error] = MESSAGE[status]
          render action: 'edit', layout: layout_name
        end
      end
    end

  end

  # == GET /special_collections_requests/REQUEST_ID.pdf
  # Generates a PDF copy of the request.
  #
  def show

    # Get the database record for the request.
    req_id = params[:id]
    load_request(
      req_id,
      joins: :special_collections_request_items,
      order:   'special_collections_request_items.location, ' \
               'special_collections_request_items.barcode'
    )
    initialize_request(@sc_request.document_id)

    # Prepare for the PDF to be rendered.
    respond_to do |format|
      format.pdf do
        prawnto filename: "Request #{req_id}"
        prawnto inline:   false
        prawnto prawn:    { page_layout: :landscape }
      end
    end

  end

  # == GET /special_collections_requests/ID/start
  # Prompts for login (NetBadge or non-UVa).
  #
  def start
    respond_to do |format|
      format.html do
        if in_popup?
          flash[:error] = MESSAGE[:no_user] if flash[:error].blank?
          render_flash_only
        else
          render layout: layout_name
        end
      end
    end
  end

  # == GET /special_collections_requests/non_uva
  # Allows a non-UVa person to enter his or her library account id.
  #
  def non_uva
    respond_to do |format|
      format.html { render layout: layout_name }
    end
  end

end
