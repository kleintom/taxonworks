module Vendor
  module Colrapi

    # Translates between how the Catalogue of Life writes a name and how
    # TaxonWorks stores its names.
    #
    # CoL's formatting depends on the source dataset (sector) a name came from,
    # and isn't always consistent within one source. What has been seen so far
    # (live CoL, 3LR, 2026-09):
    #   * subgenus: "Genus (Subgenus)" for zoological names, in search
    #     results and classifications, but "Genus subgen. Subgenus" for
    #     botanical ones (all 183 botanical subgenera in the backbone, every
    #     one a synonym, 2026-10). TaxonWorks stores the bare epithet in #name
    #     and "Genus (Subgenus)" in #cached (ICZN and ICN alike). The
    #     parentheses are ICZN's rule (Art. 6.1). The ICN writes a subgenus
    #     "Genus subg. Epithet" (Art. 21.1) and only recommends parentheses
    #     (Rec. 21A.1) for showing it inside a species name.
    #   * species group: some sources include the subgenus ("Aedes (Stegomyia)
    #     aegypti", mosquitoes), some omit it ("Bombus terrestris", bees), and
    #     one source can do both (Carabus: "Carabus (Megodontus) violaceus" but
    #     "Carabus violaceus violaceus"). TaxonWorks #cached includes the
    #     subgenus whenever the name is placed under one.
    #   * synonyms can differ from their accepted name within one source: WAD
    #     gives accepted "Aphrophora (Aphrophora) stictica" with the subgenus,
    #     its synonym "Aphrophora binomoriensis" without it (2026-10).
    #   * a name's original combination can be listed as a synonym of the
    #     same species, differing only by subgenus ("Aphrophora ambigua" ->
    #     "Aphrophora (Aphrophora) ambigua", WAD). So a CoL synonym whose
    #     accepted name is the same name once the subgenus is ignored (both
    #     have the same comparison key, see below) doesn't mean a TaxonWorks
    #     name matching it is outdated.
    #   * searching, CoL's /nameusage/search (Colrapi.nameusage_search, used
    #     by .search_term's callers): a query including the subgenus doesn't
    #     return a name CoL gives without it ("Aphrophora (Aphrophora)
    #     binomoriensis" misses "Aphrophora binomoriensis"), while a query
    #     without it still returns names CoL gives with it ("Aedes aegypti"
    #     finds "Aedes (Stegomyia) aegypti", "Aphrophora ambigua" finds both
    #     forms) - see .search_term.
    #     !! The single query in .search_term depends on that second half: it's
    #     observed CoL search behavior (2026-10), not documented. If CoL ever
    #     stops matching that way, names CoL gives with a subgenus silently go
    #     missing (e.g. Outdated Names reports them :undeterminable) and specs,
    #     which stub CoL, won't notice - a second query including the subgenus
    #     would then be needed.
    #   * looking up, CoL's /nameusage?q= (Vendor::Colrapi.search, the
    #     autoselect levels): matches only the exact string, so neither form
    #     finds the other ("Aedes aegypti" finds nothing).
    #   * ICN infraspecific names include connecting terms ("Olea europaea
    #     subsp. africana"), same as TaxonWorks #cached.
    #   * [sic] is TaxonWorks-only (#cached), CoL doesn't send it.
    #
    # Names are compared by a "key" computed the same way from both sides:
    #  * col_name_key - for a name as CoL gives it
    #  * taxonworks_name_keys - for each form of a TaxonName (see .forms)
    #  * name_key - for a naked/unassociated name
    # The key is never displayed or used to create anything. (.search_term,
    # what /nameusage/search is queried with, is close to it, but keeps a
    # subgenus's whole name.)
    #
    # [Authorship is compared the same way, by
    # Utilities::AuthorNames.authorship_key.]
    #
    # Asks of CoL - things CoL's API should handle rather than TaxonWorks
    # working around them. What we do in the meantime:
    #   * /nameusage/search should find a name with or without its
    #     subgenus, both ways. A query with the subgenus misses names CoL
    #     gives without one, so we search without it (.search_term) -
    #     except for a subgenus itself. (The exact /nameusage?q= lookup is
    #     exact by design - not an ask.)
    #   * a name should come formatted the same way whatever its source
    #     (subgenus included or not, a synonym like its accepted name). We
    #     compare keys that ignore the subgenus.
    #   * search should accept "Genus (Subgenus)" for a botanical subgenus,
    #     not only "Genus subgen. Subgenus". Not worked around, see
    #     Vendor::Colrapi.search.
    #   * search should find a fossil name without its dagger (†). Not worked
    #     around.
    #   * the formats of ICN section, subsection, series, subseries (and ICZN
    #     supersubgenus/infragenus) names should be documented - no CoL
    #     examples were found. Not handled: TaxonWorks #cached for these is
    #     just the genus, so #name would need to be compared.
    #   * author/year formats should be consistent across sources (they
    #     likely vary as names do).
    #     * Seen so far (2026-10) they match TaxonWorks #cached_author_year;
    #       see Utilities::AuthorNames.authorship_key for how author/year
    #       are currently compared across CoL and TW.
    #
    module NameTranslation

      # The string to search CoL's fuzzy /nameusage/search
      # (::Colrapi.nameusage_search) with for a name (TaxonWorks #cached or
      # free text) so that every form CoL may give it in comes back.
      #
      # !! One query covers both forms only because that search returns names
      # with a subgenus for a query without one - observed, not documented;
      # see the search note above before relying on this elsewhere. It's no
      # use with the exact /nameusage?q= (Vendor::Colrapi.search): there a
      # query without the subgenus misses names CoL gives with one.
      #
      # A subgenus itself keeps its whole name: without the subgenus it would
      # be a search for its genus, whose many subgenera can push the one
      # wanted off the first page of results.
      #
      # @param name [String, nil]
      # @return [String, nil]
      def self.search_term(name)
        return nil if name.nil?

        name = ::Utilities::Nomenclature.unmisspell_name(name)
        return name.strip if name.strip.match?(SUBGENUS_NAME)

        without_subgenus(name)
      end

      # A whole subgenus name: "Genus (Subgenus)" (CoL zoological, and
      # TaxonWorks #cached for any code) or "Genus subgen. Subgenus" (CoL
      # botanical). The epithet is in group 1 or 2.
      SUBGENUS_NAME = /\A\S+ (?:\(([^)]+)\)|subgen\. (\S+))\z/

      # TaxonWorks Protonym#name for a subgenus: just the epithet.
      #
      # @param col_name [String, nil] a subgenus name (see SUBGENUS_NAME) or
      #   a bare epithet, which is returned as is
      # @return [String, nil]
      def self.subgenus_epithet(col_name)
        return nil if col_name.nil?

        match = col_name.strip.match(SUBGENUS_NAME)
        match ? (match[1] || match[2]) : col_name
      end

      # CoL classification entries give species-group names in full ("Olea
      # europaea", "Carabus (Megodontus) violaceus", "Olea europaea subsp.
      # cuspidata"), TaxonWorks Protonym#name takes just the last epithet.
      # Names that are already an epithet or uninomial are returned as is.
      #
      # @param col_name [String, nil]
      # @param rank [String, nil] CoL rank name, e.g. 'species'
      # @return [String, nil] the TaxonWorks Protonym#name for col_name
      def self.protonym_name(col_name, rank)
        return nil if col_name.nil?
        return subgenus_epithet(col_name) if rank == 'subgenus'

        col_name.split(' ').last
      end

      # @param col_name [String, nil] a name as CoL gives it
      # @param rank [String, nil] CoL rank name, e.g. 'subgenus'
      # @return [String, nil] the comparison key for col_name
      def self.col_name_key(col_name, rank)
        return nil if col_name.nil?
        if rank == 'subgenus'
          return subgenus_epithet(
            ::Utilities::Nomenclature.unmisspell_name(col_name)
          )
        end

        comparable(col_name)
      end

      # The comparison key for a name given as text on the TaxonWorks side -
      # use only when there's no TaxonName (else see .taxonworks_name_keys).
      #
      # @param name [String, nil]
      # @return [String, nil]
      def self.name_key(name)
        return nil if name.nil?

        name = ::Utilities::Nomenclature.unmisspell_name(name)
        return subgenus_epithet(name) if name.match?(SUBGENUS_NAME)

        comparable(name)
      end

      # gnparser parses whole names, not bare authorships, so an authorship
      # is parsed after this placeholder name. A binomial: after a uninomial
      # gnparser reads a leading "(Author)" as a subgenus.
      AUTHORSHIP_PARSE_PLACEHOLDER = 'Aus bus'.freeze

      # gnparser word types that are a publication year.
      YEAR_WORD_TYPES = %w{YEAR APPROXIMATE_YEAR}.freeze

      # Splits a CoL authorship string into
      # [verbatim_author, year_of_publication], using gnparser (via the
      # biodiversity gem) to find the authors and years.
      #
      # TaxonWorks Protonym validates that verbatim_author contains no digits,
      # so the year must be stored separately in year_of_publication.
      #
      # Author text is sliced verbatim out of col_authorship at gnparser's
      # word positions, rather than rebuilt from gnparser's author lists,
      # which normalize author abbreviations (e.g. "Hook.f." -> "Hook. fil.").
      # Whatever gnparser leaves unparsed at the end (e.g. CoL's "(Approved
      # Lists 1980)" on ICNP names, or "nom. cons.") isn't kept.
      #
      # CoL provides authorship in two forms:
      #   "Linnaeus, 1758" -> author "Linnaeus", year 1758
      #   "(Chatton, 1925) Whittaker & Margulis, 1978" -> a recombination: the
      #     basionym's author + year in parens, then the current
      #     combination's
      #
      # A Protonym represents the original description, so for a
      # recombination year_of_publication is always the basionym's year, and
      # is nil when the parenthetical has none (common in ICN citations, e.g.
      # "(Drude) Thorne ex Royen"). col_year (CoL's combinationAuthorship
      # year) describes the *current* combination, so it's never used for a
      # recombination; for any other name it's the fallback when the
      # authorship carries no year.
      #
      # The recombination is signalled with parens on verbatim_author, as
      # TaxonWorks' author rendering expects for each code:
      #   * ICZN: just the basionym author, wrapped, e.g. "(Chatton)" -
      #     TaxonName#iczn_author_and_year strips and re-wraps parens found on
      #     verbatim_author, and the combination author isn't part of an ICZN
      #     citation
      #   * ICN: the whole citation, years removed, e.g. "(Drude) Thorne ex
      #     Royen" - Protonym's closed-parens validation exempts ICN for
      #     exactly this, and TaxonName#icn_author_and_year renders
      #     verbatim_author as-is
      #
      # When gnparser finds no authorship at all (e.g. "sensu Smith") the
      # string is returned as-is with col_year; Protonym validation then
      # reports any digits left in it. We don't parse it ourselves instead.
      #
      # TODO: get gnparser (gnames/gnparser) to parse these CoL authorships,
      # which it currently finds no authorship in (v1.15.0; ~0.4% of a 3LR
      # sample, 2026-11; see the xspecs):
      #   * bracketed authors (ICZN Rec. 51D, anonymous works), e.g.
      #     "[Denis & Schiffermüller], 1775" - the grammar only accepts
      #     brackets around a year
      #   * some accented letters, depending on their neighbours: "Strömberg"
      #     and "Błaszk." fail while "Hönig" and "Bł" parse
      #   * ICNP revived names, e.g. "(ex Jahn, 1924) Reichenbach 2007"
      #   * a parenthesized year after "in", e.g. "Bird in Gellert et al.
      #     (2023)"
      #
      # TODO: investigate/fix ICNP recombinations. They get the basionym author
      # without parens, so they read as original combinations. CoL cites them
      # like ICN, e.g. Escherichia coli "(Migula, 1895) Castellani & Chalmers
      # 1919 (Approved Lists 1980)", but Protonym's closed-parens validation
      # only exempts ICN, so "(Migula) Castellani & Chalmers" isn't storable
      # (see the xspecs). A fix probably needs that validation to exempt ICNP
      # too. ICVCN isn't affected: CoL gives virus names no authorship at all
      # (checked 2026-11).
      #
      # @param col_authorship [String, nil]
      # @param col_year [String, nil]
      # @param nomenclatural_code [Symbol, nil] the code of the rank the
      #   Protonym is created at (NomenclaturalRank.nomenclatural_code): :iczn,
      #   :icn, :icnp, :icvcn
      # @return [Array(String, Integer), Array(nil, nil)]
      def self.split_authorship(
        col_authorship, col_year, nomenclatural_code: nil
      )
        return [nil, nil] if col_authorship.blank?

        # gnparser's word positions are into the entity-decoded string.
        authorship = ::CGI.unescapeHTML(col_authorship).strip
        name = "#{AUTHORSHIP_PARSE_PLACEHOLDER} #{authorship}"
        parsed = ::Biodiversity::Parser.parse(name)

        original = parsed.dig(:authorship, :originalAuth)
        return [authorship, col_year.presence&.to_i] if original.nil?

        words = parsed[:words]
        # "Leach in Brewster, 1815": the year is on the in-authors.
        year = (
          original.dig(:year, :year) ||
            original.dig(:inAuthors, :year, :year)
        )&.to_i

        if !parsed.dig(:authorship, :normalized).to_s.start_with?('(')
          return [
            author_text(name, words, 0, name.length),
            year || col_year.presence&.to_i
          ]
        end

        close_paren = closing_paren_index(
          name, AUTHORSHIP_PARSE_PLACEHOLDER.length + 1
        )
        basionym_author = author_text(name, words, 0, close_paren)

        verbatim_author =
          case nomenclatural_code
          when :iczn
            "(#{basionym_author})"
          when :icn
            combination_author =
              author_text(name, words, close_paren, name.length)
            ["(#{basionym_author})", combination_author].compact.join(' ')
          else
            # TODO: ICNP lands here too - see the ICNP TODO above.
            basionym_author
          end

        [verbatim_author, year]
      end

      # The text of the authors in text[from...to], as written: from the first
      # author word to the last one before any year. So "Smith, 1900 emend.
      # Jones, 1950" is "Smith".
      # @param words [Array<Hash>] gnparser's words for text
      # @return [String, nil]
      def self.author_text(text, words, from, to)
        in_range = words.select { |w| w[:start] >= from && w[:end] <= to }
        first_year =
          in_range.find { |w| YEAR_WORD_TYPES.include?(w[:wordType]) }
        authors = in_range.select do |w|
          w[:wordType].start_with?('AUTHOR_WORD') &&
            (first_year.nil? || w[:start] < first_year[:start])
        end
        return nil if authors.empty?

        text[authors.first[:start]...authors.last[:end]]
      end
      private_class_method :author_text

      # The index in text of the paren closing the one at open_index, or
      # text.length when it's never closed (gnparser accepts
      # "(Linnaeus 1758").
      # @return [Integer]
      def self.closing_paren_index(text, open_index)
        depth = 0
        (open_index...text.length).each do |i|
          depth += 1 if text[i] == '('
          depth -= 1 if text[i] == ')'
          return i if depth == 0
        end
        text.length
      end
      private_class_method :closing_paren_index

      # A TaxonName found by .candidates_by_key, and which of its forms (see
      # .forms) matched: :current or :published.
      Candidate = Struct.new(:taxon_name, :form)

      # The two forms a TaxonWorks name can be written in, which CoL also uses:
      #   * current - #cached, the name as TaxonWorks places it now. Compare
      #     it to CoL names in their current placement, e.g. CoL's accepted
      #     classification.
      #   * published - the name as published: a Protonym's original
      #     combination, or a Combination itself (which has no current form
      #     of its own). CoL lists synonyms this way, while TaxonWorks moves a
      #     synonym under its valid name's parent, so a synonym's #cached can
      #     be a combination that was never published.
      # Which to compare is the caller's decision, and depends on what it's
      # comparing against.
      #
      # @param taxon_name [TaxonName]
      # @return [Hash] { current: String or nil, published: String or nil }
      def self.forms(taxon_name)
        if taxon_name.is_a?(::Combination)
          { current: nil, published: taxon_name.cached }
        else
          {
            current: taxon_name.cached,
            published: taxon_name.cached_original_combination.presence
          }
        end
      end

      # The comparison key of each of a TaxonName's .forms (a subgenus by its
      # epithet).
      #
      # @param taxon_name [TaxonName]
      # @return [Hash] { current: String or nil, published: String or nil }
      def self.taxonworks_name_keys(taxon_name)
        forms(taxon_name).transform_values { |name| name_key(name) }
      end

      # Finds the TaxonNames in project_id one of whose .forms has the key of
      # one of col_rows - which form matched is reported (a name whose two
      # forms share a key is listed once, as :current). Callers still need to
      # check rank (and code) themselves, and decide what a :published match
      # means for them.
      #
      # @param col_rows [Array<Hash>] each with :col_name and :rank
      # @param project_id [Integer]
      # @return [Hash{String => Array<Candidate>}] keyed by comparison key,
      #   only keys of col_rows that have candidates
      def self.candidates_by_key(col_rows, project_id:)
        keys = col_rows
          .map { |row| col_name_key(row[:col_name], row[:rank]) }
          .compact
          .uniq
        return {} if keys.empty?

        t = ::TaxonName.arel_table
        single_word, multi_word = keys.partition { |k| !k.include?(' ') }

        # Exact #cached catches most names (Combinations included); #name
        # catches a subgenus by its epithet, and a misspelled uninomial whose
        # #cached carries [sic].
        condition = t[:cached].in(keys)
          .or(t[:cached_original_combination].in(keys))
        condition = condition.or(t[:name].in(single_word)) if single_word.any?

        # A species-group name may carry a subgenus or [sic] the key doesn't:
        # match #cached on the last epithet (#name) within the genus, and
        # either form on "Genus ... epithet" (the plain "Genus epithet" is
        # matched exactly above). This finds a superset: anything can sit
        # between genus and last epithet, so "Aus bus cus" also finds
        # "Aus xus cus", and "Aus bus" finds "Aus xus bus"; the keys slice
        # below restricts back to applicable names to be returned.
        multi_word.each do |k|
          words = k.split(' ')
          genus = ::ActiveRecord::Base.sanitize_sql_like(words.first)
          epithet = ::ActiveRecord::Base.sanitize_sql_like(words.last)
          condition = condition
            .or(t[:name].eq(words.last).and(t[:cached].matches("#{genus} %")))
            .or(t[:cached].matches("#{genus} % #{epithet}"))
            .or(
              t[:cached_original_combination].matches("#{genus} % #{epithet}")
            )
        end

        candidates = Hash.new { |h, k| h[k] = [] }
        ::TaxonName.where(project_id:).where(condition).each do |taxon_name|
          current, published = taxonworks_name_keys(taxon_name)
            .values_at(:current, :published)
          if current
            candidates[current] << Candidate.new(taxon_name, :current)
          end
          if published && published != current
            candidates[published] << Candidate.new(taxon_name, :published)
          end
        end

        candidates.slice(*keys)
      end

      # @param name [String, nil]
      # @return [String, nil]
      def self.comparable(name)
        return nil if name.nil?

        without_subgenus(::Utilities::Nomenclature.unmisspell_name(name))
      end
      private_class_method :comparable

      # Drops every parenthetical, not just a subgenus (an ICZN interpolated
      # species-group name, Art. 6.2, goes too) - fine for a comparison key.
      #
      # @param name [String]
      # @return [String] e.g. "Aedes (Stegomyia) aegypti" => "Aedes aegypti"
      def self.without_subgenus(name)
        name.gsub(/\s*\([^)]*\)/, '').squeeze(' ').strip
      end
      private_class_method :without_subgenus

    end
  end
end
