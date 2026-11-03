# Builds a Protonym's verbatim_author from the parts of an authorship
# citation (e.g. as found by Vendor::Biodiversity.authorship_parts), the way
# TaxonWorks writes it for each nomenclatural code.
#
# A recombination is signalled with parens on verbatim_author, but what goes
# inside and around them differs by code - see each code's method.
module Utilities::Nomenclature::VerbatimAuthor

  # @param original_author [String, nil] the author(s) of the original
  #   name, e.g. "Chatton"; for a name that isn't a recombination, the whole
  #   author citation, e.g. "Dejean ex Boisduval"
  # @param combination_author [String, nil] the author(s) of the current
  #   combination, e.g. "Whittaker & Margulis"
  # @param recombination [Boolean] whether the name is no longer in its
  #   original combination
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
    when :icn
      icn(original_author, combination_author)
    when :icnp
      icnp(original_author, combination_author)
    else
      # ICVCN names don't carry authorship this way; unknown codes get the
      # original author unadorned.
      original_author
    end
  end

  # Just the original author, wrapped, e.g. "(Chatton)":
  # TaxonName#iczn_author_and_year strips and re-wraps parens found on
  # verbatim_author, and the combination author isn't part of an ICZN
  # citation.
  def self.iczn(original_author)
    "(#{original_author})"
  end
  private_class_method :iczn

  # The whole citation, e.g. "(Drude) Thorne ex Royen": Protonym's
  # closed-parens validation exempts ICN for exactly this, and
  # TaxonName#icn_author_and_year renders verbatim_author as-is.
  def self.icn(original_author, combination_author)
    ["(#{original_author})", combination_author].compact.join(' ')
  end
  private_class_method :icn

  # TODO: investigate/fix ICNP recombinations. They get the original author
  # without parens, so they read as original combinations. They're cited
  # like ICN, e.g. Escherichia coli "(Migula, 1895) Castellani & Chalmers
  # 1919 (Approved Lists 1980)", but Protonym's closed-parens validation
  # only exempts ICN, so "(Migula) Castellani & Chalmers" isn't storable
  # (see the xspecs). A fix probably needs that validation to exempt ICNP
  # too.
  def self.icnp(original_author, _combination_author)
    original_author
  end
  private_class_method :icnp

end
