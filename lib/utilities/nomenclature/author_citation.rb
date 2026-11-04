# Writes the author part of a name's author citation from its parts, as each
# nomenclatural code says to cite a name that is no longer in its original
# combination (or, for the ICN and ICNP, rank).
#
# Shared by the two places that cite a recombination: storing a citation
# that arrives already written (Protonym.verbatim_author_and_year), and
# deriving one from a name's relationships for display
# (TaxonName#iczn_author_and_year, TaxonName#icn_author_and_year).
module Utilities::Nomenclature::AuthorCitation

  # Codes whose recombinations are cited as the original author in
  # parentheses followed by the author of the change, e.g. "(Drude) Thorne
  # ex Royen". The ICVCN (March 2025, ictv.global/about/code) has no rules
  # on citing authors; it's cited as the ICN is, as TaxonWorks always has.
  CITES_COMBINATION_AUTHOR = %i{icn icnp icvcn}.freeze

  # @param original_author [String, nil] the author(s) of the original
  #   name, e.g. "Chatton", optionally with its year, e.g. "Chatton, 1925";
  #   for a name in its original combination, the whole author citation,
  #   e.g. "Dejean ex Boisduval"
  # @param combination_author [String, nil] the author(s) of the current
  #   combination or rank, e.g. "Whittaker & Margulis"
  # @param recombination [Boolean] whether the name is no longer in its
  #   original combination (or rank)
  # @param nomenclatural_code [Symbol, nil] :iczn, :icn, :icnp, :icvcn
  # @return [String, nil]
  def self.build(
    original_author:, combination_author: nil, recombination: false,
    nomenclatural_code: nil
  )
    return original_author if !recombination

    self.recombination(nomenclatural_code, original_author, combination_author)
  end

  # build for a name known to be a recombination, e.g. one whose original
  # combination is known from its relationships.
  # @param nomenclatural_code [Symbol, nil] :iczn, :icn, :icnp, :icvcn
  # @param original_author [String, nil] as for build
  # @param combination_author [String, nil] as for build
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

  # The inverse of recombination: the original author (and year, if it's
  # inside the parentheses) from a citation in the code's recombination
  # form, or nil when the citation isn't in that form.
  # @param nomenclatural_code [Symbol, nil] :iczn, :icn, :icnp, :icvcn
  # @param citation [String] e.g. a TaxonName's cached_author_year
  # @return [String, nil]
  def self.original_author(nomenclatural_code, citation)
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
  end

  # Whether verbatim_author has a form build could have written for the
  # code: for the ICZN (and no code) either wholly in parentheses or with
  # none at all, "(Chatton)" or "Chatton"; for codes that cite the
  # combination author after the parentheses, anything.
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
