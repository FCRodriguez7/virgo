# app/models/reserve_item.rb

require 'active_model'
require 'uva'

# One of the items associated with a course reserve request.
#
# @see ReserveRequest
#
class ReserveItem

  include ActiveModel::Validations

  include UVA

  # Codes for the libraries at which course reserves may be held.  Each code is
  # associated with an array containing the name of the library and the email
  # alias associated with course reserves at that location.
  #
  # @see self#libraries
  #
  RESERVE_LIBRARIES = {
    astr:    ['Astronomy',                   RESERVE_COORDINATOR_SCI],
    brown:   ['Brown Science & Engineering', RESERVE_COORDINATOR_SCI],
    math:    ['Math',                        RESERVE_COORDINATOR_SCI],
    clem:    ['Clemons',                     RESERVE_COORDINATOR_CLEMONS],
    arts:    ['Fine Arts',                   RESERVE_COORDINATOR_FA],
    law:     ['Law',                         RESERVE_COORDINATOR_LAW],
    music:   ['Music',                       RESERVE_COORDINATOR_MUSIC],
    physics: ['Physics',                     RESERVE_COORDINATOR_PHYS],
  }.deep_freeze

  # All valid loan periods.
  #
  # @see self#loan_periods
  #
  LOAN_PERIODS = {
    '3h' => '3 hours',
    '2d' => '2 days'
  }.deep_freeze

  # ===========================================================================
  # :section: Validations
  # ===========================================================================

  public

  validates :library, presence: {
    message: 'You must enter the Reserve Library'
  }
  validates :loan_period, presence: {
    message: 'You must enter the Loan Period'
  }
  validates :document, presence: true

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # @return [SolrDocument]
  attr_accessor :document

  # @return [ReserveItem::Library]
  attr_accessor :library

  # @return [ReserveItem::LoanPeriod]
  attr_accessor :loan_period

  # @return [String]
  attr_accessor :notes

  # Create a new self instance.
  #
  # @param [SolrDocument]   doc
  # @param [String, Symbol] library_code
  # @param [String, Symbol] loan_period_code
  # @param [String]         notes
  #
  def initialize(doc, library_code, loan_period_code, notes)
    @document    = doc
    @library     = ReserveItem.library(library_code)
    @loan_period = ReserveItem.loan_period(loan_period_code)
    @notes       = notes
  end

  # ===========================================================================
  # :section: Class Methods
  # ===========================================================================

  public

  # loan_periods
  #
  # @param [SolrDocument] doc
  #
  # @return [Array<ReserveItem::LoanPeriod>]
  #
  # @see self#LOAN_PERIODS
  #
  def self.loan_periods(doc = nil)
    LOAN_PERIODS.map { |code, name|
      LoanPeriod.new(code, name) unless (code.to_s == '2d') && video?(doc)
    }.compact
  end

  # loan_period
  #
  # @param [String, Symbol] code
  #
  # @return [ReserveItem::LoanPeriod]
  # @return [nil]                     If no matching loan_period was found.
  #
  # @see self#loan_periods
  #
  def self.loan_period(code)
    loan_periods.find { |loan_period| loan_period.match?(code) }
  end

  # ReserveItem.libraries
  #
  # @return [Array<ReserveItem::Library>]
  #
  # @see self#RESERVE_LIBRARIES
  #
  def self.libraries
    @libraries ||=
      RESERVE_LIBRARIES.map do |code, name_and_email|
        Library.new(code, *name_and_email)
      end
  end

  # ReserveItem.library
  #
  # @param [String, Symbol] code
  #
  # @return [ReserveItem::Library]
  # @return [nil]                     If no matching library was found.
  #
  def self.library(code)
    libraries.find { |library| library.match?(code) }
  end

  # ===========================================================================
  # :section: Class Methods
  # ===========================================================================

  public

  # Is the item a DVD or other video?
  #
  # @param [SolrDocument] doc
  #
  def self.video?(doc)
    [:lib_video, :lib_video_full].include?(doc.doc_type) if doc
  end

  # Is the item a compact disc or other audio recording?
  #
  # @param [SolrDocument] doc
  #
  def self.audio?(doc)
    doc.export_format.include?('CD') if doc
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # coordinator_address
  #
  # @return [String]
  #
  def coordinator_address
    if @library.match?(:clem) && (audio? || video?)
      RESERVE_COORDINATOR_RMC
    else
      @library.email
    end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # law_library?
  #
  def law_library?
    @library.match?(:law)
  end

  # Is the item a DVD or other video?
  #
  def video?
    self.class.video?(@document)
  end

  # Is the item a compact disc or other audio recording?
  #
  def audio?
    self.class.audio?(@document)
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # ReserveItem::Library
  #
  class Library

    # @return [String]
    attr_accessor :code

    # @return [String]
    attr_accessor :name

    # @return [String]
    attr_accessor :email

    # Create a new self instance.
    #
    # @param [String, Symbol] code
    # @param [String]         name
    # @param [String]         email
    #
    def initialize(code, name, email)
      @code  = code.to_s
      @name  = name
      @email = email
    end

    # match?
    #
    # @param [String, Symbol] code
    #
    def match?(code)
      @code == code.to_s
    end

  end

  # ReserveItem::LoanPeriod
  #
  class LoanPeriod

    # @return [String]
    attr_accessor :code

    # @return [String]
    attr_accessor :name

    # Create a new self instance.
    #
    # @param [String, Symbol] code
    # @param [String]         name
    #
    def initialize(code, name)
      @code = code.to_s
      @name = name
    end

    # match?
    #
    # @param [String, Symbol] code
    #
    def match?(code)
      @code == code.to_s
    end

  end

end
