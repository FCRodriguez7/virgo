# lib/uva/starred_items.rb

require 'uva'

module UVA

  # UVA::StarredItems
  #
  module StarredItems

    include UVA

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The limit on the number of starred items that can be maintained in the
    # current session.
    MAX_STARS          = 100

    STAR_LIT_CLASS     = 'remove-star'.freeze
    STAR_LIT_LABEL     = 'Remove Star'.freeze
    STAR_LIT_TOOLTIP   = 'Remove this from Starred Items'.freeze

    STAR_UNLIT_CLASS   = 'add-star'.freeze
    STAR_UNLIT_LABEL   = 'Add Star'.freeze
    STAR_UNLIT_TOOLTIP = 'Add this to Starred Items'.freeze

    STAR_SAVING_CLASS  = 'saving-star'.freeze

    # =========================================================================
    # :section: BlacklightHelperBehavior overrides
    # =========================================================================

    public

    # Indicate whether the document is in the "starred items" folder.
    #
    # @param [String] id
    #
    # @see Blacklight::BlacklightHelperBehavior#item_in_folder?
    #
    def item_in_folder?(id)
      starred_document_ids.include?(id) || starred_article_ids.include?(id)
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # All folder items.
    #
    # @return [Array<String>]
    #
    def starred_item_ids
      starred_document_ids + starred_article_ids
    end

    # Folder documents are maintained in `session[:folder_document_ids]`.
    #
    # @return [Array<String>]
    #
    def starred_document_ids
      session[:folder_document_ids] ||= []
    end

    # Folder articles are maintained in `session[:folder_article_ids]`.
    #
    # @return [Array<String>]
    #
    def starred_article_ids
      session[:folder_article_ids] ||= []
    end

    # The limit on the number of starred items that can be maintained in the
    # current session.
    #
    # @return [Fixnum]
    #
    def max_folder_items
      MAX_STARS
    end

    # starred_id_count
    #
    # @return [Fixnum]
    #
    def starred_item_count
      starred_document_ids.size + starred_article_ids.size
    end

    # remaining_item_count
    #
    # @return [Fixnum]
    #
    def remaining_item_count
      max_folder_items - starred_item_count
    end

    # Indicates whether there are no "starred items" (documents or articles) in
    # the folder.
    #
    def folder_empty?
      starred_document_ids.blank? && starred_article_ids.blank?
    end

    # Remove all "starred items" from the folder.
    #
    # @return [void]
    #
    def unstar_all_items
      starred_document_ids.clear
      starred_article_ids.clear
    end

    # Remove the current "starred item" from the folder -- identified either by
    # `params[:id]` or `params[:article_id]`.
    #
    # @return [String]                The item removed from the folder.
    # @return [nil]                   If the item was not in the folder.
    #
    def unstar_item
      return unless params.present?
      if (id = params[:id])
        unstar_document(id)
      elsif (id = params[:article_id])
        unstar_article(id)
      end
    end

    # Remove the indicated "starred item" document from the folder.
    #
    # @param [String] id              Document to remove from the folder
    #                                   (default `params[:id]`).
    #
    # @return [String]                The item removed from the folder.
    # @return [nil]                   If *id* was not in the folder.
    #
    def unstar_document(id = nil)
      id ||= params[:id]
      starred_document_ids.delete(id)
    end

    # Remove the indicated "starred item" article from the folder.
    #
    # @param [String] id              Article to remove from the folder
    #                                   (default `params[:article_id]`).
    #
    # @return [String]                The item removed from the folder.
    # @return [nil]                   If *id* was not in the folder.
    #
    def unstar_article(id = nil)
      id ||= params[:article_id]
      starred_article_ids.delete(id)
    end

    # The current starred items in JSON format.
    #
    # @return [String]
    #
    def starred_items_json
      {
        documents: starred_document_ids,
        articles:  starred_article_ids
      }.to_json
    end

    # The current starred items in text format.
    #
    # @return [String]
    #
    def starred_items_text
      starred_item_ids.join(NEWLINE)
    end

  end

end
