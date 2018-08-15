# app/models/reserve_request.rb

require 'active_model'
require 'uva'

# ReserveRequest
#
# @see ReserveItem
#
class ReserveRequest

  include ActiveModel::Validations

  include UVA

  # ===========================================================================
  # :section: Validations
  # ===========================================================================

  validates :name, presence: {
    message: 'You must enter your name'
  }
  validates :email, presence: {
    message: 'You must enter your email address'
  }
  validates :course_id, presence: {
    message: 'You must enter the Course ID'
  }
  validates :semester, presence: {
    message: 'You must enter the semester'
  }
  validates :email, format: {
    with:    /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/,
    message: 'You must enter a valid email address'
  }

  validate :reserve_items_valid
  validate :instructor_valid

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # @return [String]
  attr_accessor :name

  # @return [String]
  attr_accessor :email

  # @return [String]
  attr_accessor :university_id

  # @return [String]
  attr_accessor :instructor_cid

  # @return [String]
  attr_accessor :instructor_name

  # @return [String]
  attr_accessor :course_id

  # @return [String]
  attr_accessor :semester

  # @return [Array<ReserveItem>]
  attr_accessor :reserve_items

  # @return [String]
  attr_accessor :is_instructor

  # Create a new self instance.
  #
  # @param [String] name
  # @param [String] email
  # @param [String] course_id
  # @param [String] semester
  # @param [String] instructor_cid    Instructor computing ID.
  # @param [String] instructor_name
  # @param [String] is_instructor
  #
  #--
  # rubocop:disable Metrics/ParameterLists
  #++
  def initialize(name, email, course_id, semester,
    instructor_cid, instructor_name, is_instructor)
    @name            = name
    @email           = email
    @course_id       = course_id
    @semester        = semester
    @instructor_cid  = instructor_cid
    @instructor_name = instructor_name
    @is_instructor   = is_instructor
    @reserve_items   = []
    # rubocop:enable Metrics/ParameterLists
  end

  # reserve_item
  #
  # @param [String] id
  #
  # @return [ReserveItem]
  # @return [nil]
  #
  def reserve_item(id)
    @reserve_items.find do |item|
      item && item.document && (item.document.doc_id == id)
    end
  end

  # custom_errors
  #
  # @return [Array<String>]
  #
  def custom_errors
    messages = []
    self.errors.each do |_attr, msg|
      messages << msg unless messages.include?(msg)
    end
    messages
  end

  # reserve_items_by_coordinators
  #
  # @return [Hash]
  #
  def reserve_items_by_coordinators
    items = {}
    @reserve_items.each do |item|
      addr = item && item.coordinator_address
      next if addr.blank?
      items[addr] ||= []
      items[addr] << item
    end
    items
  end

  # ===========================================================================
  # :section: Validations
  # ===========================================================================

  protected

  # reserve_items_valid
  #
  # @return [void]
  #
  def reserve_items_valid
    @reserve_items.each do |item|
      # Run validations on this item.
      next if item.valid?
      # Add validation errors for this item to errors for the whole request.
      item.errors.each { |field, msg| errors.add(field, msg) }
    end
  end

  # instructor_valid
  #
  # @return [Boolean]
  #
  def instructor_valid
    if is_instructor == 'on'
      validates_presence_of(
        :instructor_cid,
        message: 'You must enter the instructor computing ID'
      )
      validates_presence_of(
        :instructor_name,
        message: 'You must enter the instructor name')
    else
      # name and email is validated separately
      true
    end
  end

end
