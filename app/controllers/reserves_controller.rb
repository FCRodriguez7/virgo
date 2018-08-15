# app/controllers/reserves_controller.rb

require 'uva'

# This controller is the user-facing portion of "Course Reserve" which allows
# an instructor to send an email with a list of items to be placed on reserve.
#
# @see CourseReserveConcern
#
class ReservesController < ApplicationController

  include CourseReserveConcern

  # ===========================================================================
  # :section: Filters
  # ===========================================================================

  before_filter :validate_user
  before_filter :set_documents
  before_filter :build_request

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # == GET /reserves
  #
  def index
  end

  # == GET /reserves/course
  #
  def course
  end

  # == GET /reserves/email?id=CATKEY
  #
  def email
  end

  # == POST /reserves/send_email_record
  #
  def send_email_record
    if deliver_email_records(@reserve_request)
      render
    else
      @use_reserves_dropdowns = true
      render :email
    end
  end

end
