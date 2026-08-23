module Vendor

  # A middle-layer wrapper between Colrapi and TaxonWorks
  module Colrapi

    DATASETS = {
      col: '3LR', # The Human edited compilation
      col_extended: '3LXR'  # Human plus algorithmic extensions
    }.freeze

    # @params taxonworks_object
    #   any object that responds_to `.taxonomy`
    #
    # @params colrapi_result
    #    a nameusage result
    #
    # @return [Array]
    #   with hashes {
    #    { rank: 'species'
    #      col: 'name',
    #      taxonworks: 'name'
    #      rank_origin: :col, :taxonworks, :both
    #    }
    #
    # 2 row alignment facilitator
    #
    def self.align_classification(taxonworks_object, colrapi_result)
      r = []
    end

    # @params taxonworks_object
    #   currently only an CollectionObject
    #
    # @return hash
    #     { taxonworks_name: name }
    #      col_results: [
    #          { usage: {
    #             name:
    #             status:
    # },
    #          accepted: {}
    #         }
    #        ]
    #      }
    #
    def self.name_status(taxonworks_object, colrapi_result)
      o = taxonworks_object

      r = {
          taxonworks_name: collection_object_scientific_name(o),
          col_usages: [],
          provisional_status: :accepted,
      }

      if colrapi_result.dig('total') == 0
        r[:provisional_status] = :undeterminable
        return r
      end

      colrapi_result['result'].each do |u|
        i = u['usage']

        d = {
          usage: {},
          accepted: {}
        }

        d[:usage][:name] = i.dig *%w{name scientificName}
        d[:usage][:status] = i['status']

        if i['accepted']
          d[:accepted][:name] = i.dig *%w{accepted name scientificName}
          d[:accepted][:status] = i.dig *%w{accepted status}
        end

        if d[:usage][:status] == 'synonym' && (d[:usage][:name] == r[:taxonworks_name])
          r[:provisional_status] = :synonym
        end

        r[:col_usages].push d
      end
      r
    end

    # Searches the Catalogue of Life by name string.
    #
    # The Colrapi gem takes dataset_id as a positional first argument.
    # Response structure: { 'total' => Integer, 'result' => Array }
    # Each result entry is a flat nameusage hash with keys:
    #   'id', 'status', 'name' (hash with 'scientificName', 'rank', 'authorship', …),
    #   'label', 'labelHtml', 'parentId', etc.
    #
    # @param name_string [String]
    # @param dataset_id [String, nil] CoL dataset ID; falls back to the default hardwired ID when nil
    # @return [Hash] raw Colrapi nameusage response (keys 'total', 'result')
    def self.search(name_string, dataset_id: nil)
      target = dataset_id.presence || DATASETS[:col]
      ::Colrapi.nameusage(target, q: name_string, limit: 20)
    rescue => e
      Rails.logger.warn "Vendor::Colrapi.search error: #{e.message}"
      { 'total' => 0, 'result' => [] }
    end

    # Searches CoL datasets by name string.
    #
    # Returns an array of dataset summaries, each containing at least 'id', 'title', and 'alias'.
    # Used by the preferences UI to let users pick a target dataset.
    #
    # @param q [String] dataset name search string
    # @param limit [Integer]
    # @return [Array<Hash>]
    def self.datasets(q:, limit: 20)
      # Text search by title/name.
      text_results = begin
        result = ::Colrapi.dataset(q: q, limit: limit)
        (result['result'] || []).map { |d| { 'id' => d['key'].to_s, 'title' => d['title'], 'alias' => d['alias'] } }
      rescue => e
        Rails.logger.warn "Vendor::Colrapi.datasets text search error: #{e.message}"
        []
      end

      # Direct lookup by dataset ID — `q` may itself be a key like '3LXR'.
      # Colrapi.dataset(dataset_id:) returns a single hash, not a paged result.
      direct_hit = begin
        d = ::Colrapi.dataset(dataset_id: q)
        d.is_a?(Hash) && d['key'].present? ? { 'id' => d['key'].to_s, 'title' => d['title'], 'alias' => d['alias'] } : nil
      rescue
        nil
      end

      seen = {}
      [direct_hit, *text_results].compact.each_with_object([]) do |d, arr|
        next if seen[d['id']]
        seen[d['id']] = true
        arr << d
      end
    end

    # Returns the ancestor classification chain for a CoL taxon.
    #
    # Uses Colrapi.taxon with subresource: 'classification'.
    # Response is an Array of hashes with keys: 'id', 'name' (String, not hash),
    # 'authorship', 'rank', 'label', 'labelHtml'.
    #
    # Only valid for backbone datasets (DATASETS[:col], DATASETS[:col_extended]).
    # For external datasets use ancestors_via_parent_id instead.
    #
    # @param taxon_id [String] CoL taxon ID (e.g. '6MB3T')
    # @return [Array<Hash>]
    def self.ancestors(taxon_id)
      ::Colrapi.taxon(DATASETS[:col], taxon_id: taxon_id, subresource: 'classification')
    rescue => e
      Rails.logger.warn "Vendor::Colrapi.ancestors error: #{e.message}"
      []
    end

    # Returns true when dataset_id refers to one of the CoL backbone datasets that
    # support the classification subresource for ancestor retrieval.
    # External/denormed datasets (e.g. Mammal Diversity Database, dataset 9802) do not
    # have this subresource and require iterative parentId traversal instead.
    #
    # @param dataset_id [String]
    # @return [Boolean]
    def self.col_backbone_dataset?(dataset_id)
      DATASETS.values.include?(dataset_id.to_s)
    end

    # Builds an ancestor chain for external/denormed datasets by following the parentId
    # field of successive taxon records.
    #
    # External datasets (like the Mammal Diversity Database) are ingested into ChecklistBank
    # without a pre-built classification subresource.  Instead, each nameusage record carries
    # a parentId pointing to the immediate parent within the same dataset.
    #
    # Returns entries in the same format as the classification subresource used by ancestors():
    #   { 'id', 'name' (String uninomial), 'rank', 'authorship', 'label', 'labelHtml' }
    # Order is proximal-first (immediate parent first) matching ancestors() behavior.
    # The starting taxon itself is NOT included; only its ancestors are.
    #
    # @param dataset_id [String] the external dataset to query
    # @param taxon_id [String] ID of the starting taxon
    # @param max_depth [Integer] circuit-breaker against malformed/cyclic data
    # @return [Array<Hash>]
    def self.ancestors_via_parent_id(dataset_id, taxon_id, max_depth: 20)
      chain   = []
      visited = Set.new

      initial = ::Colrapi.taxon(dataset_id, taxon_id: taxon_id)
      return chain if initial.blank?

      current_id = initial['parentId']

      max_depth.times do
        break if current_id.blank? || visited.include?(current_id)
        visited << current_id

        taxon = ::Colrapi.taxon(dataset_id, taxon_id: current_id)

        break if taxon.blank?

        chain << {
          'id'         => current_id,
          'name'       => uninomial_name(taxon['name']).to_s,
          'rank'       => taxon.dig('name', 'rank'),
          'authorship' => taxon.dig('name', 'authorship'),
          'label'      => taxon.fetch('label', '').to_s,
          'labelHtml'  => taxon.fetch('labelHtml', '').to_s
        }

        current_id = taxon['parentId']
      end

      # Return distal-first (kingdom before genus) to match the classification subresource
      # order returned by ancestors(), so build_extension can treat both paths uniformly.
      chain.reverse
    rescue => e
      Rails.logger.warn "Vendor::Colrapi.ancestors_via_parent_id error: #{e.message}"
      []
    end

    # Builds an alignment hash comparing a CoL nameusage result against TaxonNames in the project.
    #
    # col_result is a flat nameusage hash as returned by search (no 'usage' wrapper):
    #   { 'id' => '6MB3T', 'status' => 'accepted',
    #     'name' => { 'scientificName' => 'Homo sapiens', 'rank' => 'species',
    #                 'authorship' => 'Linnaeus, 1758',
    #                 'combinationAuthorship' => { 'authors' => [...], 'year' => '1758' } },
    #     'label' => 'Homo sapiens Linnaeus, 1758', … }
    #
    # Classification entries from ancestors() have:
    #   { 'id' => '636X2', 'name' => 'Homo', 'rank' => 'genus', 'label' => 'Homo', … }
    # Note: in classification entries 'name' is a plain String, not a hash.
    #
    # @param col_result [Hash] a single entry from search['result']
    # @param project_id [Integer, nil]
    # @param dataset_id [String, nil] the dataset that was searched; falls back to DATASETS[:col]
    # @return [Hash] extension hash with :col_key, :col_name, :col_status, :col_authorship,
    #   :col_year, :col_rank, :col_dataset_id, and :alignment (Array of ancestor hashes each including :col_id, :dataset_id)
    def self.build_extension(col_result, project_id, dataset_id: nil)
      col_key        = col_result['id']
      col_name       = uninomial_name(col_result['name'])
      col_rank       = col_result.dig('name', 'rank')&.downcase
      col_name       = extract_subgenus_name(col_name) if col_rank == 'subgenus'
      col_status     = col_result['status']
      col_authorship = col_result.dig('name', 'authorship')
      col_year       = col_result.dig('name', 'combinationAuthorship', 'year') ||
                       col_result.dig('name', 'basionymOrCombinationAuthorship', 'year')

      # CoL nomenclatural code: 'zoological', 'botanical', 'bacterial', 'viral'
      col_code       = col_result.dig('name', 'code')

      # Dataset used for the search (target row).
      col_dataset_id = dataset_id.presence || DATASETS[:col]

      # Backbone datasets (main CoL, extended CoL) expose a classification subresource.
      # External/denormed datasets must be traversed via iterative parentId lookups.
      # Ancestor records carry the dataset_id of whichever source they came from.
      #
      # For synonyms with a single accepted target, CoL attaches the synonym under its accepted
      # name in the tree, so fetching classification via the synonym's own ID returns the accepted
      # name in the chain.  Use the accepted name's ID for the lookup instead, then strip it out
      # by ID (CoL's classification endpoint includes the queried taxon itself as the most
      # proximal entry).
      # Ambiguous synonyms have no single accepted target, so we look up via their own ID.
      non_accepted    = col_status.present? && col_status != 'accepted'
      accepted_id     = col_status == 'synonym' ? col_result.dig('accepted', 'id').presence : nil
      ancestor_lookup_key = accepted_id || col_key

      ancestor_chain, ancestor_dataset_id =
        if ancestor_lookup_key.present?
          if col_backbone_dataset?(col_dataset_id)
            [ancestors(ancestor_lookup_key), DATASETS[:col]]
          else
            [ancestors_via_parent_id(col_dataset_id, ancestor_lookup_key), col_dataset_id]
          end
        else
          [[], col_dataset_id]
        end

      ancestor_chain = ancestor_chain.reject { |a| a['id'] == accepted_id } if accepted_id

      # For any non-accepted name, strip ancestors at or below the name's own rank.
      # CoL places non-accepted names under their accepted name, so the accepted name's
      # classification chain can include same- or lower-ranked entries that are not valid
      # parents of the queried name (e.g. a genus synonym whose accepted name is a subgenus).
      if non_accepted && col_rank.present?
        target_sort = col_rank_sort(col_rank, col_code)
        if target_sort
          ancestor_chain = ancestor_chain.reject { |a|
            anc_sort = col_rank_sort(a['rank']&.downcase, col_code)
            anc_sort && anc_sort >= target_sort
          }
        end
      end

      # Drop suprakingdom ranks (e.g. 'domain') that have no equivalent in TaxonWorks
      # nomenclatural codes.  Kingdom is the highest rank we include.
      # CoL classification returns proximal→distal (immediate parent first); reverse to kingdom-first.
      ancestor_chain = ancestor_chain.reject { |a| a['rank']&.downcase == 'domain' }.reverse

      alignment = ancestor_chain.map do |ancestor|
        rank     = ancestor['rank']&.downcase
        # In classification entries 'name' is a plain String (the uninomial name)
        anc_name = ancestor['name'].is_a?(String) ? ancestor['name'] : ancestor.dig('name', 'scientificName')
        anc_name = extract_subgenus_name(anc_name) if rank == 'subgenus'
        col_id   = ancestor['id']

        scope = ::TaxonName.where(cached: anc_name) # !!!
        scope = scope.where(project_id:) if project_id.present?
        tw_record = scope.first

        {
          rank:,
          col_name:        anc_name,
          col_id:,
          dataset_id:      ancestor_dataset_id,
          col_authorship:  ancestor['authorship'].presence,
          taxonworks_id:   tw_record&.id,
          taxonworks_name: tw_record&.cached,
          match:           tw_record ? 'exact' : 'none'
        }
      end

      { col_key:, col_name:, col_status:, col_authorship:, col_year:, col_rank:, col_code:, col_dataset_id:, alignment: }
    end

    # Returns the single-word name component suitable for storing as a TaxonWorks Protonym name.
    # CoL's scientificName is the full combination (e.g. "Homo sapiens"), but TaxonWorks
    # Protonym requires just the uninomial or epithet.
    # Priority: specificEpithet (species) > infraspecificEpithet (infra) > uninomial (higher) > scientificName fallback.
    #
    # @param name_hash [Hash, nil] the 'name' sub-hash from a CoL nameusage result
    # @return [String, nil]
    def self.uninomial_name(name_hash)
      return nil if name_hash.nil?
      name_hash['infraspecificEpithet'].presence ||
        name_hash['specificEpithet'].presence ||
        name_hash['uninomial'].presence ||
        name_hash['scientificName']
    end

    # Subgenus names in CoL classification arrive as "Genus (Subgenus)" combinations.
    # Extract just the subgenus epithet from inside the parentheses when present.
    def self.extract_subgenus_name(name)
      return name if name.nil?
      name[/\(([^)]+)\)/, 1] || name
    end

    # Maps a CoL nomenclatural code string to its corresponding TaxonWorks
    # rank lookup table. CoL also has a 'cultivars' code (ICNCP), which
    # TaxonWorks does not support and which is intentionally absent here.
    #
    # @param col_code [String, nil] 'zoological', 'botanical', 'bacterial', or 'viral'
    # @return [Hash] mapping of recognized col_code to rank lookup table
    def self.code_lookup_map
      {
        'zoological' => ::ICZN_LOOKUP,
        'botanical'  => ::ICN_LOOKUP,
        'bacterial'  => ::ICNP_LOOKUP,
        'viral'      => ::ICVCN_LOOKUP
      }
    end

    # Maps a CoL rank name ('genus', 'family', …) and CoL nomenclatural code
    # to a TaxonWorks rank_class string. Returns nil when unresolvable.
    #
    # @param rank_name [String]
    # @param col_code [String, nil] see code_lookup_map
    # @param fallback_strategy [Symbol] how to resolve when col_code is
    #   unrecognized, or its lookup doesn't have rank_name:
    #   :default_iczn — fall back to ICZN_LOOKUP only
    #   :try_all_codes — fall back through every other code's lookup, in
    #     code_lookup_map order
    # @return [String, nil]
    def self.rank_class_for(rank_name, col_code, fallback_strategy: :try_all_codes)
      return nil if rank_name.blank?
      r = rank_name.to_s.downcase

      map = code_lookup_map
      primary_lookup = map[col_code]

      if primary_lookup
        result = primary_lookup[r]
        return result if result
      end

      fallback_lookups =
        case fallback_strategy
        when :default_iczn
          primary_lookup ? [] : [::ICZN_LOOKUP]
        when :try_all_codes
          map.values - [primary_lookup]
        end

      fallback_lookups.each do |lookup|
        result = lookup[r]
        return result if result
      end

      nil
    end

    # Maps a CoL rank name ('genus', 'family', …) and CoL nomenclatural code
    # to the TaxonWorks RANK_SORT index. Higher index = more specific rank.
    # Returns nil when unresolvable.
    def self.col_rank_sort(rank_name, col_code)
      rank_class = rank_class_for(rank_name, col_code, fallback_strategy: :default_iczn)
      rank_class ? ::RANK_SORT[rank_class] : nil
    end

    # Splits a CoL authorship string into
    # [verbatim_author, year_of_publication, combination_author].
    #
    # TaxonWorks Protonym validates that verbatim_author contains no digits,
    # so the year must be stored separately in year_of_publication.
    #
    # CoL provides authorship in two forms:
    #   "Linnaeus, 1758" → author "Linnaeus", year 1758, no combination_author
    #   "(Chatton, 1925) Whittaker & Margulis, 1978" →
    #     author "Chatton", year 1925, combination_author "Whittaker & Margulis"
    #
    # A Protonym represents the original description, so whenever authorship
    # leads with a basionym parenthetical, that basionym's own author + year
    # always wins — even over an explicit col_year (CoL's
    # combinationAuthorship year), which describes the *current* combination,
    # not the original one. When the parenthetical carries no year of its
    # own (common in ICN citations, e.g. "(Drude) Thorne ex Royen"), col_year
    # is used as a fallback for year_of_publication only.
    #
    # ICZN (col_code: 'zoological') wraps the returned author in parens, e.g.
    # "(Chatton)", and combination_author is always nil — that parenthesization
    # is TaxonWorks' own sanctioned signal that a Protonym is not in its
    # original combination (see Protonym's author-parenthesization validation
    # and TaxonName#iczn_author_and_year, which strips and re-wraps parens
    # found on verbatim_author). Other codes have no such mechanism —
    # TaxonName#icn_author_and_year instead relies on a Combination +
    # TaxonNameRelationship::CurrentCombination — so combination_author is
    # returned unwrapped for CatalogueOfLifeCreator to build that Combination
    # with (ICN only; see the TODO below for ICNP/ICVCN).
    #
    # If no year can be extracted at all the author string is returned as-is
    # with year nil.
    #
    # TODO: ICNP/ICVCN recombinations still can't render parenthesized, since
    # TaxonNameRelationship::CurrentCombination.valid_object_ranks is
    # hardcoded to GENUS_AND_SPECIES_RANK_NAMES_ICN — it doesn't validate
    # against ICNP or ICVCN ranks at all. Supporting those codes needs that
    # TaxonWorks-wide restriction lifted first, which is out of scope here.
    #
    # Strips every ", YYYY" / " YYYY" occurrence out of text (e.g. a year
    # embedded inside a parenthetical group), wherever it appears.
    # @return [String]
    def self.strip_years(text)
      text.gsub(/,?\s*\b\d{4}\b/, '').strip
    end

    # Strips a single ", YYYY" / " YYYY" occurrence, but only when it's the
    # last thing in text — leaves years elsewhere (e.g. inside a nested
    # parenthetical) untouched.
    # @return [String]
    def self.strip_trailing_year(text)
      text.sub(/,?\s*\b\d{4}\b\z/, '').strip
    end

    # The year at the very end of text, e.g. "Chatton, 1925" → 1925. nil
    # when text doesn't end in one (e.g. a year-less ICN citation).
    # @return [Integer, nil]
    def self.extract_year(text)
      m = text.match(/,?\s*\b(\d{4})\b\z/)
      m && m[1].to_i
    end

    # The last standalone 4-digit year found anywhere in text — a looser
    # fallback than extract_year for authorship strings where punctuation
    # around the year is less predictable.
    # @return [Integer, nil]
    def self.extract_last_year(text)
      m = text.scan(/\b(\d{4})\b/).last
      m && m[0].to_i
    end

    # @param col_authorship [String, nil]
    # @param col_year [String, nil]
    # @param col_code [String, nil] see code_lookup_map
    # @return [Array(String, Integer, String), Array(nil, nil, nil)]
    def self.split_authorship(col_authorship, col_year, col_code: nil)
      return [nil, nil, nil] if col_authorship.blank?

      # ICZN always carries a year in its authorship citation.
      if col_code == 'zoological' && (basionym_match = col_authorship.match(/\A\(([^)]+),\s*(\d{4})\)/))
        basionym_author = strip_years(basionym_match[1])
        basionym_author = basionym_author.blank? ? nil : "(#{basionym_author})"
        return [basionym_author, basionym_match[2].to_i, nil]
      end

      # Other codes: the parenthetical's year is optional, and whatever
      # follows the parenthetical is the current combination's author.
      if col_code != 'zoological' && (basionym_match = col_authorship.match(/\A\(([^)]+)\)\s*(.*)\z/))
        inner = basionym_match[1]
        basionym_author = strip_trailing_year(inner)
        basionym_author = nil if basionym_author.blank?
        basionym_year = extract_year(inner) || col_year.presence&.to_i

        combination_author = strip_years(basionym_match[2])
        combination_author = nil if combination_author.blank?

        return [basionym_author, basionym_year, combination_author] if basionym_author
      end

      year = col_year.presence&.to_i

      # Strip any trailing ", YYYY" or " YYYY" from the authorship string.
      # Also strip years embedded inside parenthetical groups, e.g.
      # "(Chatton, 1925)".
      author = strip_years(col_authorship)
        .gsub(/\(\s*\)/, '') # clean up empty parens left behind
        .gsub(/,\s*\z/, '') # strip trailing comma
        .strip
        .then { |a|
          a.match?(/\A\([^)]*\)\z/) ? a : a.gsub(/\([^)]*\)\s*/, '').strip
        }

      # If no explicit year was given, extract the last 4-digit year from the
      # string (the combination year, not the basionym year in parentheses).
      year ||= extract_last_year(col_authorship)

      author = nil if author.blank?
      [author, year, nil]
    end

    # Extend to buffered with GNA in middle layer?
    # Text only, taxon name cached or OTU name for the
    # most recent determination
    def self.collection_object_scientific_name(collection_object)
      return nil if collection_object.nil?
      if a = collection_object.taxon_determinations.order(:position)&.first
        if a.otu.taxon_name
          a.otu.taxon_name.cached
        else
          a.otu.name
        end
      else
        nil
      end
    end
  end

end
