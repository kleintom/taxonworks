# Writes the author part of a name's author citation from its parts, as each
# nomenclatural code says to cite a name that is no longer in its original
# combination (or, for the ICN and ICNP, rank).
module Utilities::Nomenclature::VerbatimAuthor

  # @param original_author [String, nil] the author(s) of the original
  #   name, e.g. "Chatton"; for a name in its original combination, the
  #   whole author citation, e.g. "Dejean ex Boisduval"
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
    return original_author if original_author.nil? || !recombination

    case nomenclatural_code
    when :iczn
      iczn(original_author)
    when :icn, :icnp
      icn_icnp(original_author, combination_author)
    else
      # The ICVCN (March 2025, ictv.global/about/code) has no rules on
      # citing authors; with no code there's no rule to apply.
      original_author
    end
  end

  # A species-group name combined with a genus other than its original one
  # has its author in parentheses (ICZN Art. 51.3), e.g. "(Chatton)". The
  # author of the new combination isn't part of the citation; if cited at
  # all it follows the parentheses (Rec. 51G), and isn't here.
  def self.iczn(original_author)
    "(#{original_author})"
  end
  private_class_method :iczn

  # A name transferred to another genus or species, or changed in rank, is
  # cited with the original name's author in parentheses followed by the
  # author who made the change (ICN Art. 49.1; ICNP Rules 34b, 34c), e.g.
  # "(Drude) Thorne ex Royen".
  def self.icn_icnp(original_author, combination_author)
    ["(#{original_author})", combination_author].compact.join(' ')
  end
  private_class_method :icn_icnp

end
