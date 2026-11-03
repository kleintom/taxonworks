module Vendor

  # Wraps the biodiversity gem (https://github.com/GlobalNamesArchitecture/biodiversity)
  # Links parsed string results to Protonyms/Combinations in TaxonWorks.
  #   a = Vendor::Biodiversity::Result.new 
  #   a.name = 'Aus bus'
  #   a.parse
  #
  module Biodiversity
    
    RANKS = %i{genus subgenus species subspecies variety form}.freeze

    # gnparser parses whole names, not bare authorships, so an authorship
    # is parsed after this placeholder name. A binomial: after a uninomial
    # gnparser reads a leading "(Author)" as a subgenus.
    AUTHORSHIP_PARSE_PLACEHOLDER = 'Aus bus'.freeze

    # gnparser word types that are a publication year.
    YEAR_WORD_TYPES = %w{YEAR APPROXIMATE_YEAR}.freeze

    # Splits an authorship string into a Protonym's verbatim_author and
    # year_of_publication, using gnparser to find the authors and years.
    #
    # Protonym validates that verbatim_author contains no digits, so the year
    # is returned separately.
    #
    # Author text is sliced verbatim out of authorship at gnparser's word
    # positions, rather than rebuilt from gnparser's author lists, which
    # normalize author abbreviations (e.g. "Hook.f." -> "Hook. fil.").
    # Whatever gnparser leaves unparsed at the end (e.g. "(Approved Lists
    # 1980)" on ICNP names, or "nom. cons.") isn't kept.
    #
    # A Protonym represents the original description, so for a
    # recombination, e.g. "(Chatton, 1925) Whittaker & Margulis, 1978", year
    # is always the basionym's, and is nil when the parenthetical has none
    # (common in ICN citations, e.g. "(Drude) Thorne ex Royen").
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
    # TODO: get gnparser (gnames/gnparser) to parse these authorships, which
    # it currently finds no authorship in (v1.15.0; ~0.4% of a Catalogue of
    # Life sample, 2026-11; see the xspecs):
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
    # without parens, so they read as original combinations. They're cited
    # like ICN, e.g. Escherichia coli "(Migula, 1895) Castellani & Chalmers
    # 1919 (Approved Lists 1980)", but Protonym's closed-parens validation
    # only exempts ICN, so "(Migula) Castellani & Chalmers" isn't storable
    # (see the xspecs). A fix probably needs that validation to exempt ICNP
    # too.
    #
    # @param authorship [String, nil] HTML entities are decoded
    # @param nomenclatural_code [Symbol, nil] the code of the Protonym's rank
    #   (NomenclaturalRank.nomenclatural_code): :iczn, :icn, :icnp, :icvcn
    # @return [Hash, nil] { verbatim_author: String or nil, year: Integer or
    #   nil, recombination: Boolean }; nil when authorship is blank or
    #   gnparser finds no authorship in it - nothing is parsed otherwise
    def self.split_authorship(authorship, nomenclatural_code: nil)
      return nil if authorship.blank?

      # gnparser's word positions are into the entity-decoded string.
      name = "#{AUTHORSHIP_PARSE_PLACEHOLDER} " \
        "#{::CGI.unescapeHTML(authorship).strip}"
      parsed = ::Biodiversity::Parser.parse(name)

      original = parsed.dig(:authorship, :originalAuth)
      return nil if original.nil?

      words = parsed[:words]
      # "Leach in Brewster, 1815": the year is on the in-authors.
      year = (
        original.dig(:year, :year) || original.dig(:inAuthors, :year, :year)
      )&.to_i

      if !parsed.dig(:authorship, :normalized).to_s.start_with?('(')
        return {
          verbatim_author: author_text(name, words, 0, name.length),
          year:,
          recombination: false
        }
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

      { verbatim_author:, year:, recombination: true }
    end

    # The text of the authors in text[from...to], as written: from the first
    # author word to the last one before any year. So "Smith, 1900 emend.
    # Jones, 1950" is "Smith".
    # @param words [Array<Hash>] gnparser's words for text
    # @return [String, nil]
    def self.author_text(text, words, from, to)
      in_range = words.select { |w| w[:start] >= from && w[:end] <= to }
      first_year = in_range.find { |w| YEAR_WORD_TYPES.include?(w[:wordType]) }
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

    class Result
      # query string
      attr_accessor :name

      # how to match
      #   `ranked`: return names at that queried rank only (e.g. only match a subgenus to rank subgenus
      #   `groups`: return names at Group level (species or genus), i.e. a subgenus name in query will match genus OR subgenus in database
      attr_accessor :mode

      # project to query against
      attr_accessor :project_id

      # one of :iczn, :icn, :icnp
      attr_accessor :nomenclature_code

      # the result of a ScientificNameParser parse
      attr_accessor :parse_result

      # a summarized result, used to render JSON
      #   {
      #     protonyms: { genus: [ @protonym1, ...], ... }
      #     parse: { genus:  'Aus', species: 'bus', ...}
      #   }
      # Hash of rank => [Protonyms] like { genus: [<#>, <#>] }
      attr_reader :result

      # @return [String] the bit after ` in `
      attr_reader :citation

      # @return [Boolean] 
      #   whether or not the query string was succesfully parsed
      attr_reader :parseable

      # @return [Hash]
      #   a memoized result of the matching TW protonyms per rank
      attr_reader :protonym_result

      # @return [Combination]
      #   a memoized result of disambiguated_combination
      attr_reader :disambiguated_combination

      # @return [Combination]
      #   a memoized combiantion with only unambiguous elements 
      attr_reader :combination

      # @return [Boolean]
      #   - true, we match on words from verbatim:
      #   - false, we match on words from normalized:
      attr_reader :normalized
       

      def initialize(query_string: nil, project_id: nil, code: :iczn, match_mode: :groups, verbatim: false)
        @project_id = project_id
        @name = query_string
        @nomenclature_code = code
        @mode = match_mode
        @normalized = !verbatim

        parse if !query_string.blank?
      end

      def normalized
        @normalized ? :normalized : :verbatim
      end

      # @return [@parse_result]
      #   a Biodiversity name parser result
      def parse
        @combination = nil
        @disambiguated_combination = nil

        n, @citation = preparse

        begin
          @parse_result ||= ::Biodiversity::Parser.parse(n)
        rescue NoMethodError => e
          case e.message
          when /canonical/
            @parseable = false 
          else
            raise
          end
        end

        @parse_result[:scientificName] = parse_result[normalized]
        @parse_result
      end

      # @return [Boolean]
      def parseable
        @parseable = parse_result[:parsed] && parse_result[:tail].blank? if @parseable.nil?
        @parseable 
      end

      # @return [Array]
      #  TODO: deprecate
      def preparse
        name.split(' in ')
      end

      # @return [Hash]
      def detail
        parse_result[:details] || {}
      end

      # @return [String, nil]
      def genus
        if parse_result[:rank] == 'subgen.'
          parse_result.dig(:details, :uninomial, :parent)
        else
          parse_result[:words]&.detect{ |w| %w{UNINOMIAL GENUS}.include?(w[:wordType]) }&.dig(normalized)
        end
      end

      # @return [String, nil] 
      def subgenus
        if parse_result[:rank] == 'subgen.'
          parse_result.dig(:details, :uninomial, :uninomial)
        else
          (parse_result[:words] || [])[1..]&.detect{ |w| %w{UNINOMIAL INFRA_GENUS}.include?(w[:wordType]) }&.dig(normalized)
        end
      end

      # @return [String, nil]
      def species
        parse_result[:words]&.detect { |w| 'SPECIES' == w[:wordType] }&.dig(normalized)
      end

      # @return [String, nil]
      def subspecies
        infraspecies(nil)
      end

      # @return [String, nil]
      def variety
        infraspecies('var.')
      end

      # @return [String, nil]
      def form
        infraspecies('f.')
      end

      # @return [String, nil]
      def infraspecies(biodiversity_rank)
        detail.dig(:infraspecies, :infraspecies)&.detect { |e| e[:rank] == biodiversity_rank }&.dig(:value)
      end

      # @return [Integer]
      #   the total monominals in the epithet
      def name_count 
        (detail[detail.keys.first].keys - [:authorship]).count
      end

      # @return [Symbol, nil] like `:genus`
      def finest_rank
        RANKS.reverse_each do |k|
          return k if send(k)
        end
        nil
      end

      # @return [Hash, nil]
      #   the Biodiversity authorship hash
      def authorship
        parse_result.dig(:authorship, :originalAuth)
      end

      # @return [String, nil]
      def author
        if a = authorship
          Utilities::Strings.authorship_sentence(a[:authors])
        else
          nil
        end
      end

      def author_year
        [author, year].compact.join(', ')
      end

      # @return [String, nil]
      def year
        if a = authorship
          return a.dig(:year, :year)
        end
      end

      # return only references to ambiguous protonyms
      #
      # Parse 'form' 
      # Parse 'parse 'Var" 

      # @return [Boolean]
      #   true if for each parsed piece of there name there is 1 and only 1 result
      def is_unambiguous?
        RANKS.each do |r|
          if !send(r).nil?
            return false unless !send(r).nil? && !unambiguous_at?(r).nil?
          end
        end
        true
      end

      # @return [Boolean]
      def is_authored?
        author_year.size > 0
      end

      # @return [Protonym, nil]
      #   true if there is a single matching result or nominotypical subs
      # @param rank [Symbol] like `:genus` or `:species`
      def unambiguous_at?(rank)
        return protonym_result[rank].first if protonym_result[rank].size == 1
        if protonym_result[rank].size == 2
          n1 = protonym_result[rank].first
          n2 = protonym_result[rank].last
          return n2 if n2.nominotypical_sub_of?(n1) 
          return n1 if n1.nominotypical_sub_of?(n2) 
        end
        nil 
      end

      # @return [Array]
      #   the ranks, as symbols, at which there are multiple (>1) Protonym matches
      #   !! subtly different than unambiguous_at, probably should use that?!
      def ambiguous_ranks
        a = [ ]
        protonym_result.each do |k, v|
          a.push k if v.count > 1
        end
        a 
      end

      # @return [Combination]
      # @param target_protonym_ids [Hash] like like `{genus: 123, species: 345}`
      #   Given a targeted list of ids checks to see if
      #      a) there is an *ambiguous* result at the rank AND
      #      b) there is a Protonym with the id provided in the ambiguous result
      #   If a and b are both true then the combination once ambiguous result is set to the id provided in targeted_protonym_ids
      def disambiguate_combination(target_protonym_ids = {})
        return nil unless target_protonym_ids.any?
        c = combination
        b = ambiguous_ranks

        target_protonym_ids.each do |rank, id|
          if b.include?(rank)
            c.send("#{rank}_id=", id) if protonym_result[rank].map(&:id).include?(id)
          end
        end
        @disambiguated_combination = c
      end

      # @return [ String, false ]
      #   a wrapper on string returning methods
      # @param rank [Symbol, String] 
      #   rank is one of `genus`, `subgenus`, `species, `subspecies`, `variety`, `form`
      def string(rank = nil)
        send(rank)
      end

      # @return [Scope]
      # @param rank [Symbol] like `:genus` or `:species`
      def basic_scope(rank)
        Protonym.where(
          project_id: project_id,
          name: string(rank)
        )
      end

      # @return [Scope]
      # @param rank [Symbol] like `:genus` or `:species`
      def protonyms(rank)
        case mode
        when :ranked
          ranked_protonyms(rank)
        when :groups
          grouped_protonyms(rank)
        else
          Protonym.none
        end
      end

      # @return [Scope]
      #    Protonyms at a given rank
      def ranked_protonyms(rank)
        basic_scope(rank).where(rank_class: Ranks.lookup(nomenclature_code, rank))
      end

      # @return [Scope]
      # @param rank [Symbol] like `:genus` or `:species`
      #   Protonyms grouped by nomenclatural group, for a rank
      def grouped_protonyms(rank)
        s = case rank
            when :genus, :subgenus
              basic_scope(rank).is_genus_group
            when :species, :subspecies, :variety, :form
              basic_scope(rank).is_species_group
            else
              Protonym.none
            end

        (is_authored? && finest_rank == rank) ? scope_to_author_year(s) : s
      end

      # @return [Scope]
      #  if there is an exact author year match scope it to that match, otherwise
      #     ignore the author year
      def scope_to_author_year(scope)
        t = scope.where('(cached_author_year = ? OR cached_author_year = ?)', author_year, author_year.gsub(' & ', ' and '))
        t.count > 0 ? t : scope
      end

      # @return [Hash]
      #   we inspect this internally, so it has to be decoupled
      def protonym_result
        return @protonym_result if @protonym_result
        h = {}
        RANKS.each do |r|
          h[r] = protonyms(r).to_a
        end
        @protonym_result = h
        @protonym_result
      end

      # @return [Hash]
      def parse_values
        h = {
          author: author,
          year: year
        }
        RANKS.each do |r|
          h[r] = send(r)
        end
        h
      end

      # @return [Hash]
      #   summary for rendering purposes
      def result
        @result ||= build_result
      end

      # @return [Hash]
      def build_result
        @result = {}
        @result[:protonyms] = protonym_result
        @result[:parse] = parse_values
        @result[:unambiguous] = is_unambiguous?
        @result[:existing_combination_id] = combination_exists?.try(:id)
        @result[:other_matches] = other_matches
        @result
      end

      # @return [Combination]
      #   ranks that are unambiguous have their Protonym set
      def combination
        @combination ||= set_combination
      end

      def set_combination
        c = Combination.new
        RANKS.each do |r|
          c.send("#{r}=", unambiguous_at?(r))
        end
        c
      end

      # @return [Combination, false]
      #    the Combination, if it exists
      def combination_exists?
        if is_unambiguous?
          Combination.match_exists?(**combination.protonym_ids_params) # TODO: pass name?
        else
          false
        end
      end

      def author_word_position 
        if a = parse_result[:words]
          b = (a.detect { |v| v[:wordType] == 'AUTHOR_WORD'})&.dig(:start)
          p = [name.length, b].compact.min
        end
      end

      def name_without_author_year
        pos = author_word_position

        # nothing was parsed, there is no author/year to remove
        return name if pos.nil?

        # author_word doesn't point to parens if any
        offset = pos > 0 && '(' == name[pos-1] ? 2 : 1

        name[0..pos - offset].strip
      end

      # @return [Hash]
      #   `:verbatim` - names that have verbatim supplied, these should be the only names NOT parsed that user is interested in
      #   `:subgenus` - names that exactly match a subgenus, these are potential new combinations as Genus alone 
      #   `:original_combination` - names that exactly match the original combination
      def other_matches
        h = { 
          verbatim: [],
          subgenus: [], 
          original: []
        }

        h[:verbatim] = TaxonName.where(project_id: project_id, cached: name_without_author_year).
          where('verbatim_name is not null').order(:cached).all.to_a if parseable
        
        h[:subgenus] = Protonym.where(
          project_id: project_id, 
          name: genus, 
          rank_class: Ranks.lookup(nomenclature_code, :subgenus)
        ).all.to_a

        h[:original_combination] = Protonym.where(project_id: project_id). 
          where( cached_original_combination: name_without_author_year
                ).all.to_a if parseable

        h
      end

    end
  end
end
