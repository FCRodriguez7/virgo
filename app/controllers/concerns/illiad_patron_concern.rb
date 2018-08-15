# app/controllers/concerns/illiad_patron_concern.rb

require 'active_support/concern'
require 'uva'

# Support for controller actions involving requests to ILL (Interlibrary Loan)
# systems.
#
# @see UVA::Illiad
#
module IlliadPatronConcern

  extend ActiveSupport::Concern

  include UVA

  # After a while, sections marked with this constant can be removed.
  TRANSITION_FROM_OLD_ILLIAD_SESSION = true

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Determine if an ILLiad has been selected, either previously in the session
  # or by way of the client through the current request parameters.
  #
  # If no ILLiad has been selected, return *nil* to allow the caller to prompt
  # for a selection.
  #
  # @param [SolrDocument] doc
  # @param [Boolean]      ivy
  #
  # @return [UVA::Illiad::Session]
  # @return [nil]                     If an ILLiad needs to be selected.
  #
  def get_illiad_session(doc = nil, ivy = nil)
    selection = params[:illiad_selection] || session[:illiad_selection]
    if TRANSITION_FROM_OLD_ILLIAD_SESSION
      illiad = session.delete(:illiad)
      selection ||= illiad.selection if illiad.is_a?(UVA::Illiad::Session)
    end
    url = doc && canonical_url(doc)
    ivy = ivy.is_a?(TrueClass) || (ivy == :sid_ivy)
    UVA::Illiad::Session.new(selection, doc, url, ivy).tap do |illiad|
      session[:illiad_selection] = illiad.selection
    end
  end

  # Forget ILLiad selection settings.
  #
  # @return [void]
  #
  def clear_illiad_session
    session.delete(:illiad_selection)
    session.delete(:illiad_referrer) if TRANSITION_FROM_OLD_ILLIAD_SESSION
  end

end
