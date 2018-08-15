# lib/uva/marc/relator.rb

require 'uva'

# Methods for assembling bibliographic information from MARC records.
#
module UVA::Marc::Relator

  include UVA

  # MARC relator codes associated with an "author" of a work.
  #
  # @see self#RELATOR_MAP
  #
  AUTHOR_RELATORS = [
    :adp, # Adapter
    :arc, # Architect
    :aus, # Author of screenplay
    :aut, # Author
    :cmp, # Composer
    :cre, # Creator
    :dis, # Dissertant
    :drt, # Director
  ].deep_freeze

  # MARC relator codes associated with an "advisor" for a work.
  #
  # @see self#RELATOR_MAP
  #
  ADVISOR_RELATORS = [
    :sad, # Scientific advisor
    :ths, # Thesis advisor
  ].deep_freeze

  # MARC relator codes associated with an "editor" of a work.
  #
  # @see self#RELATOR_MAP
  #
  EDITOR_RELATORS = [
    :edt, # Editor
  ].deep_freeze

  # To simplify string comparisons, most punctuation is removed from the terms.
  #
  # @see self#relator_term
  #
  RELATOR_TERM_APPEND = {
    aft:  '.'
  }.deep_freeze

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Determine whether the given relator term could be considered an author for
  # the purposes of citation.
  #
  # This is heuristic and definitely not comprehensive.  A more complete
  # solution would have to take into account the type of work to provide
  # context for determining whether a particular role would be considered one
  # of the creators of the work in a citation.
  #
  # @param [String, Symbol] term
  #
  # @see self#get_relator
  #
  def author?(term)
    code = get_relator(term)
    AUTHOR_RELATORS.include?(code)
  end

  # Determine whether the given relator term could be considered an advisor for
  # the purposes of citation.
  #
  # @param [String, Symbol] term
  #
  # @see self#get_relator
  #
  def advisor?(term)
    code = get_relator(term)
    ADVISOR_RELATORS.include?(code)
  end

  # Determine whether the given relator term could be considered an editor for
  # the purposes of citation.
  #
  # @param [String, Symbol] term
  #
  # @see self#get_relator
  #
  def editor?(term)
    code = get_relator(term)
    EDITOR_RELATORS.include?(code)
  end

  # Determine whether the given relator term could be considered a creator of
  # the work for the purposes of citation.
  #
  # @param [String, Symbol] term
  #
  # @see self#get_relator
  #
  def creator?(term)
    code = get_relator(term)
    author?(code) || editor?(code)
  end

  # Get a role name based on *term*.
  #
  # @param [String, Symbol] term
  # @param [Boolean]        exact
  #
  # @return [String]
  #
  # @see self#get_relator
  #
  def get_role(term, exact = false)
    string = term.to_s.gsub(/[^A-Za-z0-9\s_-]/, '').downcase
    symbol = string.to_sym
    code =
      if term.is_a?(Symbol)
        get_relator([symbol, string], exact)
      else
        string = string.capitalize
        get_relator([string, symbol], exact)
      end
    relator_term(code) || string
  end

  # Associate a RELATOR_MAP key with *term*.
  #
  # - If *term* is an Array, the result will be the first matching value.
  # - If *term* is a Symbol, it is the result if found in RELATOR_MAP.
  # - If *term* is a Regexp, the key of the first matching RELATOR_MAP
  #     value will be returned.
  # - If *term* is a String, an exact match on value is sought first, then, if
  #     *exact* is not set to *true*, the value that begins with *term*, or
  #     lastly the value that includes *term*.
  #
  # @param [String, Regexp, Symbol, Array] term
  # @param [Boolean] exact            Applies only if *term* is a String.
  #
  # @return [Symbol]                  RELATOR_MAP key.
  # @return [nil]                     No relator code could be determined.
  #
  def get_relator(term, exact = false)
    case term
      when Array  then term.find { |t| get_relator(t, exact) }
      when Symbol then RELATOR_MAP[term] && term
      when Regexp then RELATOR_MAP.find { |k, v| return k if v =~ term }
      else
        term = term.to_s.capitalize
        RELATOR_MAP.find { |k, v| return k if v == term }
        return if exact
        RELATOR_MAP.find { |k, v| return k if v.start_with?(term) }
        RELATOR_MAP.find { |k, v| return k if v.include?(term) }
    end
  end

  # Direct lookup of a relator_code.
  #
  # @param [Symbol] code
  #
  # @return [String]
  # @return [nil]
  #
  def relator_term(code)
    result = RELATOR_MAP[code]
    append = result && RELATOR_TERM_APPEND[code]
    result += append if append
    result
  end

  # Full mapping of relator code to relator description.
  #
  # @return [Hash]
  #
  def relator_mapping
    RELATOR_MAP
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # MARC relator codes mapped to their associated MARC relator terms.
  #
  # @see https://www.loc.gov/marc/relators/relacode.html
  # @see https://www.loc.gov/marc/relators/relaterm.html
  #
  RELATOR_MAP = {
    acp: 'Art copyist',
    act: 'Actor',
    adp: 'Adapter',
    aft: 'Author of afterword, colophon, etc', # NOTE: Ending '.' was removed.
    anl: 'Analyst',
    anm: 'Animator',
    ann: 'Annotator',
    ant: 'Bibliographic antecedent',
    app: 'Applicant',
    aqt: 'Author in quotations or text abstracts',
    arc: 'Architect',
    ard: 'Artistic director',
    arr: 'Arranger',
    art: 'Artist',
    asg: 'Assignee',
    asn: 'Associated name',
    att: 'Attributed name',
    auc: 'Auctioneer',
    aud: 'Author of dialog',
    aui: 'Author of introduction',
    aus: 'Author of screenplay',
    aut: 'Author',
    bdd: 'Binding designer',
    bjd: 'Bookjacket designer',
    bkd: 'Book designer',
    bkp: 'Book producer',
    bnd: 'Binder',
    bpd: 'Bookplate designer',
    bsl: 'Bookseller',
    ccp: 'Conceptor',
    chr: 'Choreographer',
    clb: 'Collaborator',
    cli: 'Client',
    cll: 'Calligrapher',
    clt: 'Collotyper',
    cmm: 'Commentator',
    cmp: 'Composer',
    cmt: 'Compositor',
    cng: 'Cinematographer',
    cnd: 'Conductor',
    cns: 'Censor',
    coe: 'Contestant-appellee',
    col: 'Collector',
    com: 'Compiler',
    cos: 'Contestant',
    cot: 'Contestant-appellant',
    cov: 'Cover designer',
    cpc: 'Copyright claimant',
    cpe: 'Complainant-appellee',
    cph: 'Copyright holder',
    cpl: 'Complainant',
    cpt: 'Complainant-appellant',
    cre: 'Creator',
    crp: 'Correspondent',
    crr: 'Corrector',
    csl: 'Consultant',
    csp: 'Consultant to a project',
    cst: 'Costume designer',
    ctb: 'Contributor',
    cte: 'Contestee-appellee',
    ctg: 'Cartographer',
    ctr: 'Contractor',
    cts: 'Contestee',
    ctt: 'Contestee-appellant',
    cur: 'Curator',
    cwt: 'Commentator for written text',
    dfd: 'Defendant',
    dfe: 'Defendant-appellee',
    dft: 'Defendant-appellant',
    dgg: 'Degree grantor',
    dis: 'Dissertant',
    dln: 'Delineator',
    dnc: 'Dancer',
    dnr: 'Donor',
    dpc: 'Depicted',
    dpt: 'Depositor',
    drm: 'Draftsman',
    drt: 'Director',
    dsr: 'Designer',
    dst: 'Distributor',
    dtc: 'Data contributor',
    dte: 'Dedicatee',
    dtm: 'Data manager',
    dto: 'Dedicator',
    dub: 'Dubious author',
    edt: 'Editor',
    egr: 'Engraver',
    elg: 'Electrician',
    elt: 'Electrotyper',
    eng: 'Engineer',
    etr: 'Etcher',
    exp: 'Expert',
    fac: 'Facsimilist',
    fld: 'Field director',
    flm: 'Film editor',
    fmo: 'Former owner',
    fpy: 'First party',
    fnd: 'Funder',
    frg: 'Forger',
    gis: 'Geographic information specialist',
    grt: 'Graphic technician',
    hnr: 'Honoree',
    hst: 'Host',
    ill: 'Illustrator',
    ilu: 'Illuminator',
    ins: 'Inscriber',
    inv: 'Inventor',
    itr: 'Instrumentalist',
    ive: 'Interviewee',
    ivr: 'Interviewer',
    lbr: 'Laboratory',
    lbt: 'Librettist',
    ldr: 'Laboratory director',
    led: 'Lead',
    lee: 'Libelee-appellee',
    lel: 'Libelee',
    len: 'Lender',
    let: 'Libelee-appellant',
    lgd: 'Lighting designer',
    lie: 'Libelant-appellee',
    lil: 'Libelant',
    lit: 'Libelant-appellant',
    lsa: 'Landscape architect',
    lse: 'Licensee',
    lso: 'Licensor',
    ltg: 'Lithographer',
    lyr: 'Lyricist',
    mcp: 'Music copyist',
    mfr: 'Manufacturer',
    mdc: 'Metadata contact',
    mod: 'Moderator',
    mon: 'Monitor',
    mrk: 'Markup editor',
    msd: 'Musical director',
    mte: 'Metal-engraver',
    mus: 'Musician',
    nrt: 'Narrator',
    opn: 'Opponent',
    org: 'Originator',
    orm: 'Organizer of meeting',
    oth: 'Other',
    own: 'Owner',
    pat: 'Patron',
    pbd: 'Publishing director',
    pbl: 'Publisher',
    pdr: 'Project director',
    pfr: 'Proofreader',
    pht: 'Photographer',
    plt: 'Platemaker',
    pma: 'Permitting agency',
    pmn: 'Production manager',
    pop: 'Printer of plates',
    ppm: 'Papermaker',
    ppt: 'Puppeteer',
    prc: 'Process contact',
    prd: 'Production personnel',
    prf: 'Performer',
    prg: 'Programmer',
    prm: 'Printmaker',
    pro: 'Producer',
    prt: 'Printer',
    pta: 'Patent applicant',
    pte: 'Plaintiff-appellee',
    ptf: 'Plaintiff',
    pth: 'Patent holder',
    ptt: 'Plaintiff-appellant',
    rbr: 'Rubricator',
    rce: 'Recording engineer',
    rcp: 'Recipient',
    red: 'Redactor',
    ren: 'Renderer',
    res: 'Researcher',
    rev: 'Reviewer',
    rps: 'Repository',
    rpt: 'Reporter',
    rpy: 'Responsible party',
    rse: 'Respondent-appellee',
    rsg: 'Restager',
    rsp: 'Respondent',
    rst: 'Respondent-appellant',
    rth: 'Research team head',
    rtm: 'Research team member',
    sad: 'Scientific advisor',
    sce: 'Scenarist',
    scl: 'Sculptor',
    scr: 'Scribe',
    sds: 'Sound designer',
    sec: 'Secretary',
    sgn: 'Signer',
    sht: 'Supporting host',
    sng: 'Singer',
    spk: 'Speaker',
    spn: 'Sponsor',
    spy: 'Second party',
    srv: 'Surveyor',
    std: 'Set designer',
    stl: 'Storyteller',
    stm: 'Stage manager',
    stn: 'Standards body',
    str: 'Stereotyper',
    tcd: 'Technical director',
    tch: 'Teacher',
    ths: 'Thesis advisor',
    trc: 'Transcriber',
    trl: 'Translator',
    tyd: 'Type designer',
    tyg: 'Typographer',
    vdg: 'Videographer',
    voc: 'Vocalist',
    wam: 'Writer of accompanying material',
    wdc: 'Woodcutter',
    wde: 'Wood-engraver',
    wit: 'Witness',
  }.deep_freeze

end
