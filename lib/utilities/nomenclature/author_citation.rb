# Author citations (the author and year after a name) as each
# nomenclatural code writes them, in particular for a name that is no
# longer in its original combination (or, for the ICN and ICNP, rank):
# reading one written elsewhere (.from_parts, .recombination_form?),
# writing one (.citation, .recombination, .ex, .misapplication), reading
# one back (.original_author_year), and checking a stored author
# (.well_formed?).
module Utilities::Nomenclature::AuthorCitation

  # Codes whose recombinations are cited as the original author in
  # parentheses followed by the author of the change, e.g. "(Drude) Thorne
  # ex Royen". The ICVCN (March 2025, ictv.global/about/code) has no rules
  # on citing authors; it's cited as the ICN is, as TaxonWorks always has.
  CITES_COMBINATION_AUTHOR = %i{icn icnp icvcn}.freeze

  # Whether a citation, as written, is of a name no longer in its original
  # combination: it leads with a parenthetical, the original name's author,
  # e.g. "(Linnaeus, 1758)", "(Moench) Voss", or "(Sahlberg, 1871) non
  # Boheman, 1852".
  #
  # A practical rule, not a code's: a citation from elsewhere was built who
  # knows how, and the parenthetical is the only sign of an earlier
  # combination it can carry. The codes cite recombinations that way, but
  # not everything cited that way is one.
  #
  # TODO: ICNP revived names (Rule 33c Note 2) credit the original author
  # with "ex" in a leading parenthetical, e.g. Pseudomonas cepacia "(ex
  # Burkholder 1950) Palleroni and Holmes 1981". That's an original
  # combination by the reviver, whose year it takes (ICNP Rule 28a): author
  # "Palleroni and Holmes", year 1981, not a recombination of Burkholder's
  # 1950 name. For :icnp a parenthetical starting "ex" should be read that
  # way here and in .from_parts. gnparser can't parse these yet, so
  # today they fall back to the raw string (with its years), which
  # Protonym's verbatim_author validation rejects (see the xspec 'an ICNP
  # revived name is an original combination by the reviver' on
  # Protonym.verbatim_author_and_year). A later recombination keeps the
  # credit inside the parentheses and is read correctly:
  # "(Palleroni and Holmes 1981 ex Burkholder 1950) Yabuuchi et al. 1993".
  #
  # One exception, PRE_STARTING_POINT_FORM: the ICN (Art. 46.7) lets a
  # pre-starting-point author be cited in a leading parenthetical followed by
  # "ex", e.g. Hydrocoleum glutinosum "(C. Agardh) ex Gomont". That's an
  # original combination by Gomont, not a recombination (a pre-starting-point
  # name isn't validly published). Only the ICN writes that form, so it's
  # read that way whatever the code.
  # @param citation [String]
  # @return [Boolean]
  def self.recombination_form?(citation)
    citation.start_with?('(') && !citation.match?(PRE_STARTING_POINT_FORM)
  end

  # See .recombination_form?; also Protonym.is_original_name, in SQL.
  PRE_STARTING_POINT_FORM = /\A\([^()]+\)\s+ex\s/

  # The author and year of a citation written elsewhere, given as its parts
  # (e.g. by Vendor::Biodiversity.authorship_parts), as the code cites the
  # name. By the rule in recombination_form?, a parenthetical author is the
  # original name's author, and what follows it the current combination's;
  # the year is always the original name's.
  #
  # Something after the citation, the tail, is read only for ICN Art. 46.7,
  # a pre-starting-point author in parentheses followed by "ex" and the
  # name's author: "(C. Agardh) ex Gomont 1892" is an original combination
  # by Gomont, "(C. Agardh) ex Gomont", 1892. Any other says the citation
  # isn't just a name's author, e.g. a misapplication's "Melichar, 1905 non
  # Walker, 1858" (ICZN Art. 51.2.1) or a later homonym's "Thomas non
  # Borkh. 1800" (ICN Rec. 50C.1), and isn't read.
  # @param nomenclatural_code [Symbol, nil] :iczn, :icn, :icnp, :icvcn
  # @param parenthetical_author [String, nil] the citation's leading
  #   parenthetical
  # @param parenthetical_year [Integer, nil] its year
  # @param author [String, nil] the rest of the citation, or the whole
  #   citation when it has no parenthetical
  # @param year [Integer, nil] its year
  # @param tail [Hash, nil] what follows the citation, { connective:
  #   String or nil, authorship: parts like these, or nil }, e.g. for "ex
  #   Gomont 1892" { connective: 'ex', authorship: { ..., author: 'Gomont',
  #   year: 1892 } }
  # @param current_combination_year [Integer, nil] the year of the name as
  #   currently combined, given apart from the citation. Only used when the
  #   name is in its original combination and the citation has no year.
  #   Never used for a recombination: that's not the original name's year.
  # @return [Array(String, Integer), Array(nil, nil), nil] nil when the
  #   citation isn't read
  def self.from_parts(
    nomenclatural_code, parenthetical_author:, parenthetical_year:, author:,
    year:, tail: nil, current_combination_year: nil
  )
    if !tail.nil?
      return pre_starting_point(
        nomenclatural_code, parenthetical_author, author, tail,
        current_combination_year
      )
    end

    if parenthetical_author.nil? || parenthetical_author.empty?
      return [author, year || current_combination_year]
    end

    [
      recombination(nomenclatural_code, parenthetical_author, author),
      parenthetical_year
    ]
  end

  # Only written for the ICZN, the one code whose names TaxonWorks cites
  # with a year (see TaxonName#icn_author_and_year). The codes differ on
  # years: the ICNP cites them (Rule 34b, Note 1), the ICN doesn't make them
  # part of the author citation (Art. 46.1 Ex. 1: "Rosa L. (Sp. Pl.: 491.
  # 1753)", the year is in the bibliographic reference).
  # @param nomenclatural_code [Symbol] :iczn
  # @param author [String, nil] e.g. a Protonym's author_string, not in its
  #   recombination form: one stored that way, e.g. "(Linnaeus)", goes
  #   through .original_author_year first
  # @param year [Integer, nil]
  # @param recombination [Boolean] whether the name is a species-group
  #   name combined with a genus other than its original one. Nomenclaturally
  #   only a species-group name can be (ICZN Art. 51.3), so pass true only in
  #   that case.
  # @param priority_year [Integer, nil] for a family-group name maintained
  #   under ICZN Art. 40.2.1, the date of priority it takes from the name it
  #   replaced; cited after the name's own year when it differs. ICZN Rec.
  #   40A encloses it in parentheses, "THAUMALEIDAE Bezzi, 1913 (1847)";
  #   TaxonWorks uses square brackets, "Bezzi, 1913 [1847]".
  # @return [String] empty when there's neither author nor year
  def self.citation(
    nomenclatural_code, author, year, recombination:, priority_year: nil
  )
    if nomenclatural_code != :iczn
      raise ArgumentError, 'citation is only written for :iczn, not ' \
        "#{nomenclatural_code.inspect}"
    end

    citation = [author, year].compact.join(', ')
    citation = self.recombination(:iczn, citation) if recombination

    if !priority_year.nil? && priority_year != year
      citation += " [#{priority_year}]"
    end

    citation
  end

  # The author of a name ascribed by its publishing author to someone else,
  # e.g. "Nutt. ex Seem.": the author it was ascribed to, " ex ", then the
  # publishing author.
  #
  # ICN Art. 46.5: when the validating description isn't ascribed to or
  # associated with the author the name was ascribed to, the name is the
  # publishing author's, "However ... authorship as ascribed, followed by
  # 'ex', may be inserted before the name(s) of the publishing author(s)",
  # e.g. "G. tomentosum Nutt. ex Seem. or G. tomentosum Seem." Art. 46.10
  # lets the publishing author adopt the "ex" form in the protologue, Art.
  # 46.7 allows it for a pre-starting-point author. But Art. 46.4: a name
  # taken up from a different "name" that wasn't validly published is
  # cited with only its publishing author, "A. drummondii Steud., not A.
  # drummondii 'Nees ex Steud.'". Which applies is the caller's to decide.
  #
  # A recombination keeps the "ex" inside the parentheses, e.g. "(Douglas
  # ex D. Don) Lindl.": pass the result to recombination.
  # @param nomenclatural_code [Symbol] :icn
  # @param ascribed_author [String, nil] who the name was ascribed to
  # @param author [String, nil] the publishing author
  # @return [String, nil] author as-is when there's no ascribed_author
  def self.ex(nomenclatural_code, ascribed_author, author)
    if nomenclatural_code != :icn
      raise ArgumentError, 'ex is only written for :icn, not ' \
        "#{nomenclatural_code.inspect}"
    end
    return author if ascribed_author.nil? || ascribed_author.strip.empty?

    "#{ascribed_author} ex #{author}"
  end

  # The citation of a misapplied name, the use of a name by a later author
  # for a taxon other than the one it was established for: citation, the
  # later author's (as built by .citation or .recombination), followed by
  # " non " and the author (and year) of the name as established, e.g.
  # "Melichar, 1905 non Walker, 1858".
  #
  # ICZN Art. 51.2.1: a subsequent user is separated from the name "in some
  # distinctive and explicit manner, but not by parentheses", e.g. "Cancer
  # pagurus Linnaeus sensu Latreille". " non " is TaxonWorks' manner.
  #
  # ICN Rec. 50D.1: a misapplied name is indicated by "auct. non" followed by
  # the original author, e.g. "F. exasperata auct. non Vahl", the
  # misidentification's author going in its bibliographic reference. A bare
  # "non" marks a later homonym (Rec. 50C.1, "Ulmus racemosa Thomas ... non
  # Borkh. 1800"), so TaxonWorks' "Thomas non Borkh." doesn't follow the
  # recommendation.
  # @param nomenclatural_code [Symbol] :iczn, :icn
  # @param citation [String, nil] the misapplied name's
  # @param author [String, nil] the author of the name as established
  # @param year [Integer, nil] its year, cited only for the ICZN. ICN Rec.
  #   50D.1 cites the original author without one, "auct. non Vahl", and
  #   TaxonWorks cites the ICN's names without one (see .citation).
  # @return [String, nil] citation as-is when there's no author
  def self.misapplication(nomenclatural_code, citation, author, year)
    if !%i{iczn icn}.include?(nomenclatural_code)
      raise ArgumentError, 'misapplication is only written for :iczn and ' \
        ":icn, not #{nomenclatural_code.inspect}"
    end
    return citation if author.nil? || author.strip.empty?

    year = nil if nomenclatural_code != :iczn

    "#{citation} non #{[author, year].compact.join(', ')}"
  end

  # The author part of the citation of a name no longer in its original
  # combination (or, for the ICN and ICNP, rank).
  # @param nomenclatural_code [Symbol, nil] :iczn, :icn, :icnp, :icvcn
  # @param original_author [String, nil] the author(s) of the original
  #   name, e.g. "Chatton", optionally with its year, e.g. "Chatton, 1925"
  # @param combination_author [String, nil] the author(s) of the current
  #   combination or rank, e.g. "Whittaker & Margulis"; none when blank
  # @return [String, nil] original_author as-is when it's nil or empty
  def self.recombination(
    nomenclatural_code, original_author, combination_author = nil
  )
    return original_author if original_author.nil? || original_author.empty?

    case nomenclatural_code
    when :iczn
      iczn(original_author)
    when *CITES_COMBINATION_AUTHOR
      basionym_and_combination_author(original_author, combination_author)
    else
      # With no code there's no rule to apply.
      original_author
    end
  end

  # The original name's author (and year, if cited) from a citation: for
  # one in the code's recombination form, what's inside the parentheses
  # (the inverse of recombination); for any other, e.g. an original
  # combination's, the whole citation. A citation that adds to the form,
  # e.g. a misapplication's, is also returned whole.
  # @param nomenclatural_code [Symbol, nil] :iczn, :icn, :icnp, :icvcn
  # @param citation [String] e.g. a TaxonName's cached_author_year
  # @return [String]
  def self.original_author_year(nomenclatural_code, citation)
    original =
      case nomenclatural_code
      when :iczn
        # The whole citation in parentheses, like this:
        # (Baker, 1899) -> Baker, 1899
        # Not with anything after them, like this:
        # (Baker, 1899) non Gillette, 1898
        # (Baker, 1899) non (Gillette)
        citation[1...-1] if wholly_parenthesized?(citation)
      when *CITES_COMBINATION_AUTHOR
        # A leading parenthetical, like this:
        # (Seub.) Lowden -> Seub.
        # (Migula) Castellani & Chalmers -> Migula
        # Not a parenthetical elsewhere, like this:
        # auct. non (L.) Benth.
        # Retz. (fruit)
        # (C. Agardh) ex Gomont, an original combination
        citation[/\A\(([^()]+)\)/, 1] if recombination_form?(citation)
      end

    original || citation
  end

  # Whether verbatim_author has a form that `recombination` could have written
  # for the code: for the ICZN (and no code) either wholly in parentheses
  # or with none at all, "(Chatton)" or "Chatton"; for the ICNP and ICVCN
  # an optional leading parenthetical and then no parentheses, "(Migula)
  # Castellani & Chalmers". The ICN allows anything: until TaxonWorks
  # records a basionym's author apart from the name's, ICN verbatim_author
  # carries other parentheticals, e.g. "Retz. (fruit)", "auct. non (L.)
  # Benth.".
  # @param verbatim_author [String]
  # @param nomenclatural_code [Symbol, nil]
  # @return [Boolean]
  def self.well_formed?(verbatim_author, nomenclatural_code:)
    case nomenclatural_code
    when :icn
      true
    when *CITES_COMBINATION_AUTHOR
      verbatim_author.match?(/\A(\([^()]+\)\s*)?[^()]*\z/)
    else
      verbatim_author.match?(/\A\([^()]+\)\z|\A[^()]+\z/)
    end
  end

  # Whether citation's leading parenthesis closes at its last character.
  def self.wholly_parenthesized?(citation)
    citation.start_with?('(') &&
      ::Utilities::Strings.closing_paren_index(citation) ==
        citation.length - 1
  end
  private_class_method :wholly_parenthesized?

  # ICN Art. 46.7: "(C. Agardh) ex Gomont", a pre-starting-point author in
  # parentheses followed by "ex" and the author of the name, nothing between
  # them, as the author and year of an original combination by that author.
  # nil for any other tail.
  def self.pre_starting_point(
    nomenclatural_code, parenthetical_author, author, tail,
    current_combination_year
  )
    ex_authorship = tail[:authorship]
    if nomenclatural_code != :icn || tail[:connective] != 'ex' ||
        parenthetical_author.nil? || parenthetical_author.empty? ||
        !(author.nil? || author.empty?) || ex_authorship.nil? ||
        ex_authorship[:author].nil? ||
        !ex_authorship[:parenthetical_author].nil? ||
        !ex_authorship[:tail].nil?
      return nil
    end

    [
      ex(:icn, "(#{parenthetical_author})", ex_authorship[:author]),
      ex_authorship[:year] || current_combination_year
    ]
  end
  private_class_method :pre_starting_point

  # A species-group name combined with a genus other than its original one
  # has its author (and year, if given) in parentheses (ICZN Art. 51.3),
  # e.g. "(Chatton)". The author of the new combination isn't part of the
  # citation; if cited at all it follows the parentheses (Rec. 51G), and
  # isn't here.
  def self.iczn(original_author)
    "(#{original_author})"
  end
  private_class_method :iczn

  # A name transferred to another genus or species, or changed in rank, is
  # cited with the original name's author in parentheses followed by the
  # author who made the change (ICN Art. 49.1; ICNP Rules 34b, 34c), e.g.
  # "(Drude) Thorne ex Royen". A blank combination_author is none.
  def self.basionym_and_combination_author(original_author, combination_author)
    combination_author = nil if combination_author.to_s.strip.empty?
    ["(#{original_author})", combination_author].compact.join(' ')
  end
  private_class_method :basionym_and_combination_author

end
