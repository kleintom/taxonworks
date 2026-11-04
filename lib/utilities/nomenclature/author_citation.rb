# Author citations (the author and year after a name) as each
# nomenclatural code writes them, in particular for a name that is no
# longer in its original combination (or, for the ICN and ICNP, rank):
# reading one written elsewhere (author_and_year, recombination_form?),
# writing one (recombination), reading one back (original_author_year), and
# checking a stored author (well_formed?).
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
  # combination by the reviver, whose year it takes (Rule 28a): author
  # "Palleroni and Holmes", year 1981, not a recombination of Burkholder's
  # 1950 name. For :icnp a parenthetical starting "ex" should be read that
  # way here and in author_and_year. gnparser can't parse these yet, so
  # today they fall back to the raw string (with its years), which
  # Protonym's verbatim_author validation rejects (see the xspec 'an ICNP
  # revived name is an original combination by the reviver' on
  # Protonym.verbatim_author_and_year). A later recombination keeps the
  # credit inside the parentheses and is read correctly:
  # "(Palleroni and Holmes 1981 ex Burkholder 1950) Yabuuchi et al. 1993".
  # @param citation [String]
  # @return [Boolean]
  def self.recombination_form?(citation)
    citation.start_with?('(')
  end

  # The author and year of a citation written elsewhere, given as its parts
  # (e.g. by Vendor::Biodiversity.authorship_parts), as the code cites the
  # name. By the rule in recombination_form?, a parenthetical author is the
  # original name's author, and what follows it the current combination's;
  # the year is always the original name's.
  # @param nomenclatural_code [Symbol, nil] :iczn, :icn, :icnp, :icvcn
  # @param parenthetical_author [String, nil] the citation's leading
  #   parenthetical
  # @param parenthetical_year [Integer, nil] its year
  # @param author [String, nil] the rest of the citation, or the whole
  #   citation when it has no parenthetical
  # @param year [Integer, nil] its year
  # @param current_combination_year [Integer, nil] the year of the name as
  #   currently combined, given apart from the citation. Only used when the
  #   name is in its original combination and the citation has no year.
  #   Never used for a recombination: that's not the original name's year.
  # @return [Array(String, Integer), Array(nil, nil)]
  def self.author_and_year(
    nomenclatural_code, parenthetical_author:, parenthetical_year:, author:,
    year:, current_combination_year: nil
  )
    if parenthetical_author.nil? || parenthetical_author.empty?
      return [author, year || current_combination_year]
    end

    [
      recombination(nomenclatural_code, parenthetical_author, author),
      parenthetical_year
    ]
  end

  # The author part of the citation of a name no longer in its original
  # combination (or, for the ICN and ICNP, rank).
  # @param nomenclatural_code [Symbol, nil] :iczn, :icn, :icnp, :icvcn
  # @param original_author [String, nil] the author(s) of the original
  #   name, e.g. "Chatton", optionally with its year, e.g. "Chatton, 1925"
  # @param combination_author [String, nil] the author(s) of the current
  #   combination or rank, e.g. "Whittaker & Margulis"
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
        citation[/\A\((.*)\)\z/, 1]
      when *CITES_COMBINATION_AUTHOR
        # A leading parenthetical, like this:
        # (Seub.) Lowden -> Seub.
        # (Migula) Castellani & Chalmers -> Migula
        # Not a parenthetical elsewhere, like this:
        # auct. non (L.) Benth.
        # Retz. (fruit)
        citation[/\A\(([^()]+)\)/, 1]
      end

    original || citation
  end

  # Whether verbatim_author has a form recombination could have written
  # for the code: for the ICZN (and no code) either wholly in parentheses
  # or with none at all, "(Chatton)" or "Chatton"; for codes that cite
  # the combination author after the parentheses, anything.
  # @param verbatim_author [String]
  # @param nomenclatural_code [Symbol, nil]
  # @return [Boolean]
  def self.well_formed?(verbatim_author, nomenclatural_code:)
    return true if CITES_COMBINATION_AUTHOR.include?(nomenclatural_code)

    verbatim_author.match?(/\A\([^()]+\)\z|\A[^()]+\z/)
  end

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
  # "(Drude) Thorne ex Royen".
  def self.basionym_and_combination_author(original_author, combination_author)
    ["(#{original_author})", combination_author].compact.join(' ')
  end
  private_class_method :basionym_and_combination_author

end
