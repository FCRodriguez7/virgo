# lib/uva/illiad/definitions.rb

require 'uva'

# Support for web access to ILLiad.
#
# === References
# For information on the web API functionality see the following:
# @see https://prometheus.atlas-sys.com/display/illiad/ILLiad+Web+DLL+Tags
# @see https://prometheus.atlas-sys.com/display/illiad/Customizing+the+Web+Interface
# @see https://www.oclc.org/developer/develop/web-services/worldcat-knowledge-base-api/openurl-resource.en.html
#
module UVA::Illiad

  # ===========================================================================
  # :section: Constants - ILLiad Request Types
  # ===========================================================================

  # These are the standard ILLiad request types; each is annotated with the URL
  # parameters used to get to the form associated with the type. While LEO
  # requests (and OpenURL format requests) use Action=10 Form=30, this list
  # indicates the distinct types of requests that can be made from the menu on
  # the right hand side of the page when you log in to ILLiad, although our two
  # ILLiads only have explicit links for the following:
  #
  # Request Type              UVA ILLiad            HSL ILLiad
  # ------------------------- --------------------- -------------------------
  # ILL_REQ_GENERIC           "Borrow an Item"      n/a
  # ILL_REQ_AUDIO_VIDEO       "Audio/Video Request" n/a
  # ILL_REQ_LOAN              n/a                   "Book Request"
  # ILL_REQ_ARTICLE           "Scan (PDF) Request"  "Article/Photocopy Request"
  # ILL_REQ_BOOK_CHAPTER      n/a                   "Book Chapter Request"
  # ILL_REQ_CONFERENCE_PAPER  n/a                   "Book Chapter Request"
  # ILL_REQ_THESIS            n/a                   "Thesis Request"
  #
  #--
  # rubocop:disable Style/MutableConstant
  #++
  ILL_REQ = [

    ILL_REQ_GENERIC          = 'Generic Loan',       # Action=10 Form=20 (1)
    ILL_REQ_AUDIO_VIDEO      = 'Audio/Video Loan',   # Action=10 Form=20 (2)
    ILL_REQ_LOAN             = 'Loan',               # Action=10 Form=21
    ILL_REQ_ARTICLE          = 'Article',            # Action=10 Form=22
    ILL_REQ_BOOK_CHAPTER     = 'Book Chapter',       # Action=10 Form=23
    ILL_REQ_CONFERENCE_PAPER = 'Conference Paper',   # Action=10 Form=24
    ILL_REQ_PATENT           = 'Patent',             # Action=10 Form=25
    ILL_REQ_REPORT           = 'Report',             # Action=10 Form=26
    ILL_REQ_THESIS           = 'Thesis',             # Action=10 Form=27
    ILL_REQ_DOCUMENT         = 'Standards Document', # Action=10 Form=28

    # NOTE (1) Value=GenericRequestLoan
    # NOTE (2) Value=GenericRequestAudioVideo

  ].deep_freeze
  #--
  # rubocop:enable Style/MutableConstant
  #++

  # ===========================================================================
  # :section: Constants - ILLiad Formats
  # ===========================================================================

  # These appear to be specific to the UVA ILLiad (HSL ILLiad pages, which do
  # not appear to be locally customized, do not reference them).
  #
  #--
  # rubocop:disable Style/MutableConstant
  #++
  ILL_FMT = [

    # From the "DocumentType" menu on the UVA ILLiad "Borrow an Item" page
    # (/illiad/illiad.dll?Action=10&Form=20&Value=GenericRequestLoan).
    #
    # All but two items are associated with value="Book" on that page and there
    # does not appear to be a way to initialize the selection through URL query
    # arguments.

    ILL_FMT_BOOK          = 'Book',
    ILL_FMT_BOUND_VOLUME  = 'Bound Journal Volume',
    ILL_FMT_DISSERTATION  = 'Thesis or Dissertation',
    ILL_FMT_NEWSPAPER     = 'Newspapers',              # value="Newspaper"
    ILL_FMT_MICROFORM     = 'Microform',
    ILL_FMT_GOVDOC        = 'Government Document',     # value="GovDoc"
    ILL_FMT_SCORE         = 'Music Score',

    # From the "LoanEdition" menu on UVA ILLiad "Audio / Video Request" page
    # (/illiad/illiad.dll?Action=10&Form=20&Value=GenericRequestAudioVideo).
    #
    # None of these were associated with a value and there does not appear to
    # be a way to initialize the selection through URL query arguments.

    ILL_FMT_ANY           = 'Any',
    ILL_FMT_CD            = 'CD',
    ILL_FMT_LP            = 'LP',
    ILL_FMT_DVD           = 'DVD',
    ILL_FMT_BLURAY        = 'Blu-Ray',
    ILL_FMT_VHS           = 'VHS',
    ILL_FMT_LASERDISC     = 'LD',

    # From the "DocumentType" menu on the UVA ILLiad "Scan (PDF) Request" page
    # (/illiad/illiad.dll?Action=10&Form=22).

    ILL_FMT_ARTICLE       = 'Article',
    ILL_FMT_BOOK_CHAPTER  = 'Book Chapter',
    ILL_FMT_LAW_CITE      = 'Law Cite Check',

  ].deep_freeze
  #--
  # rubocop:enable Style/MutableConstant
  #++

  # ===========================================================================
  # :section: Constants - ILLiad Commands
  # ===========================================================================

  # Each ILLiad command is indicated in the URL query an Action, a Form (for
  # most commands), and a Value (for some commands).  The following constants
  # express each command as an array with the Action/Form/Value combination
  # which identifies that command.
  #
  #--
  # rubocop:disable Style/MutableConstant
  #++
  ILL_CMD = [

    # NAME                    [ ACTION, FORM, VALUE ]                 NOTES
    # ---------------------   --------------------------------------- -----
    CMD_ABOUT               = [10,  1],
    CMD_FAQ                 = [10,  2, 'FAQ'], # .................... X o
    CMD_MAIN_MENU           = [10, 10],

    CMD_SCAN_COLLAB         = [10, 20, 'GenericRequestToolkit'],
    CMD_SCAN_PDF            = [10, 22],
    CMD_SCAN_ARCHIVAL       = [10, 29, 'Other'], # .................. X U

    CMD_REQUEST_ITEM        = [10, 20, 'GenericRequestLoan'],
    CMD_REQUEST_AV          = [10, 20, 'GenericRequestAudioVideo'],
    CMD_REQUEST_LOAN        = [10, 21], # ........................... X U *
    CMD_REQUEST_CHAPTER     = [10, 23], # ........................... X U
    CMD_REQUEST_CONF_PAPER  = [10, 24], # ........................... X U
    CMD_REQUEST_PATENT      = [10, 25], # ........................... X U
    CMD_REQUEST_REPORT      = [10, 26], # ........................... X U
    CMD_REQUEST_THESIS      = [10, 27], # ........................... X U
    CMD_REQUEST_STD_DOC     = [10, 28], # ........................... X U
    CMD_REQUEST_OPENURL     = [10, 30], # ........................... X U
    CMD_REQUEST_LEO         = CMD_REQUEST_OPENURL, # ................ X U

    CMD_VIEW_ALL            = [10, 60],
    CMD_VIEW_OUTSTANDING    = [10, 62],
    CMD_VIEW_DOWNLOADS      = [10, 64],
    CMD_REQUEST_UNDELETE    = [10, 65], # ........................... X o
    CMD_VIEW_CHECKED_OUT    = [10, 66],
    CMD_VIEW_HISTORY        = [10, 68], # ........................... X U
    CMD_VIEW_CANCELLED      = [10, 70],
    CMD_VIEW_NOTIFICATIONS  = [10, 73],

    CMD_USER_REGISTRATION   = [10, 80], # ...........................     ?
    CMD_USER_INFORMATION    = [10, 81],
    CMD_USER_ACCOUNTS       = [10, 82], # ........................... X o
    CMD_USER_PWD_CHANGE     = [10, 83],
    CMD_USER_PWD_FORGET     = [10, 84], # ........................... X   ?
    CMD_USER_PWD_NEW        = [10, 85, 'PasswordResetID'], # ........ X   ?

    CMD_LOGOFF              = [99],

    # NOTE X - Does not have a link on the UVA ILLiad menu
    # NOTE o - Can be accessed but does not have a UVA-styled page
    # NOTE U - Can be accessed and has a UVA-styled page
    # NOTE * - Appears in ILLiad pages as commented-out link "Virgo request"
    # NOTE ? - Not tested

    # Undocumented/custom commands
    #
    # These are combinations that can be found on the UVA ILLiad web site but
    # do not seem to be "official" commands.  Documented for future reference.

    # NAME                    [ ACTION, TYPE, VALUE ]                 NOTES
    # ---------------------   --------------------------------------- -----
    CMD_SUBSCRIBE           = [2, 41, '1141191084635319'], # ........ 1

    # NOTE 1 - "Subscribe to Notifications Feed" on CMD_VIEW_NOTIFICATIONS page

  ].deep_freeze
  #--
  # rubocop:enable Style/MutableConstant
  #++

  # ===========================================================================
  # :section: Constants
  # ===========================================================================

  QUERY_SEPARATOR = '&'.freeze
  STANDARD_PATH   = '/illiad/illiad.dll'.freeze
  OPENURL_PATH    = "#{STANDARD_PATH}/OpenURL".freeze

end
