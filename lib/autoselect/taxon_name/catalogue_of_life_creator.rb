module Autoselect
  module TaxonName
    # Creates TaxonName records (and CoL URI identifiers) from a Catalog of
    # Life selection.
    #
    # Receives an ordered list of rows (distal → proximal, i.e. kingdom
    # first, ending with the target — the row for the name the user
    # actually selected).
    # Rows with a taxonworks_id are already in the project and serve only as
    # parent anchors.
    class CatalogueOfLifeCreator

      # Raised when any name in the creation loop fails validation.
      # Carries the row that triggered the failure for frontend highlighting.
      class CreationError < StandardError
        attr_reader :col_name, :col_id

        def initialize(message, col_name: nil, col_id: nil)
          super(message)
          @col_name = col_name
          @col_id = col_id
        end
      end

      # @param rows [Array<Hash>] ordered distal→proximal; each hash has:
      #   col_name [String] — scientific name string from CoL
      #   col_rank [String] — human-readable rank (e.g. 'genus', 'species')
      #   col_id [String] — CoL taxon ID used to build the identifier URI
      #   taxonworks_id [Integer, nil] — existing TaxonName ID; if present,
      #     no creation occurs for this row
      #   col_authorship [String, nil] — combined author+year string from
      #     CoL (e.g. 'Linnaeus, 1758')
      #   col_year [String, nil] — year string extracted from CoL
      #     combinationAuthorship (target row only)
      #   col_status [String, nil] — CoL nomenclatural status (e.g.
      #     'accepted', 'synonym'); present on the target row only. A
      #     non-'accepted' status tags the created name with the nearest
      #     synonym TaxonNameClassification for its code (see
      #     NOMENCLATURE_CODE_TO_SYNONYM_CLASSIFICATION).
      # @param col_code [String, nil] CoL nomenclatural code string:
      #   'zoological', 'botanical', 'bacterial', 'viral'. When present,
      #   rank resolution uses the corresponding lookup first. Falls back
      #   to trying all codes when nil or unrecognised.
      # @param project_id [Integer]
      # @param user_id [Integer]
      def initialize(rows:, project_id:, user_id:, col_code: nil)
        @rows = rows
        @project_id = project_id.to_i
        @user_id = user_id.to_i
        @col_code = col_code.to_s.downcase.presence
      end

      # @return [Hash] { taxon_name_id: Integer, created_ids: Array<Integer> }
      # @raise [CreationError] if any record fails validation; the transaction
      # is fully rolled back in that case.
      def call
        parent_id = project_root_id
        created_ids = []

        ::ActiveRecord::Base.transaction do
          @rows.each do |row|
            if row[:taxonworks_id].present?
              parent_id = row[:taxonworks_id].to_i
              next
            end

            rank_class = resolve_rank_class(row[:col_rank])

            # Skip rows whose rank is entirely unknown to TaxonWorks — we
            # cannot create a valid Protonym without a rank_class (e.g.
            # CoL-only ranks like 'domain').
            next if rank_class.nil?

            author, year =
              split_authorship(row[:col_authorship], row[:col_year])

            begin
              tn = ::TaxonName.create!(
                type: 'Protonym',
                name: row[:col_name],
                parent_id:,
                rank_class:,
                verbatim_author: author,
                year_of_publication: year,
                project_id: @project_id,
                by: @user_id,
              )
            rescue ::ActiveRecord::RecordInvalid => e
              raise CreationError.new(
                e.record.errors.full_messages.join(', '),
                col_name: row[:col_name],
                col_id: row[:col_id]
              )
            end

            # Tag non-accepted names (synonym, misapplied, …) with a status
            # classification.
            assign_synonym_classification(tn, row)

            if row[:col_id].present?
              begin
                ::Identifier::Global::Uri::ChecklistBank.create!(
                  taxon_id: row[:col_id],
                  dataset_id: row[:dataset_id],
                  identifier_object: tn,
                  project_id: @project_id,
                  by: @user_id
                )
              rescue ::ActiveRecord::RecordInvalid => e
                raise CreationError.new(
                  "CoL identifier for #{row[:col_name]}:
                    #{e.record.errors.full_messages.join(', ')}",
                  col_name: row[:col_name],
                  col_id: row[:col_id]
                )
              end
            end

            created_ids << tn.id
            parent_id = tn.id
          end
        end

        { taxon_name_id: parent_id, created_ids: }
      end

      private

      # Returns the TaxonName id of the project's Root node.
      def project_root_id
        ::Project.find(@project_id).root_taxon_name.id
      end

      # Assigns a "not the accepted name" TaxonNameClassification to a
      # freshly-created name when CoL reports a non-'accepted' status. The
      # class is chosen by the created name's own nomenclatural code (see
      # NOMENCLATURE_CODE_TO_SYNONYM_CLASSIFICATION), which is guaranteed to
      # satisfy TaxonNameClassification's code-match validation.
      #
      # Only the target row carries a col_status; accepted names and ancestor
      # rows are left untagged.
      def assign_synonym_classification(taxon_name, row)
        status = row[:col_status].to_s
        return if status.blank? || status.casecmp?('accepted')

        code = taxon_name.rank_class.nomenclatural_code
        classification_type =
          ::NOMENCLATURE_CODE_TO_SYNONYM_CLASSIFICATION[code]
        return if classification_type.nil?

        ::TaxonNameClassification.create!(
          taxon_name: taxon_name,
          type: classification_type,
          project_id: @project_id,
          by: @user_id
        )
      rescue ::ActiveRecord::RecordInvalid => e
        raise CreationError.new(
          "Status for #{row[:col_name]}:
            #{e.record.errors.full_messages.join(', ')}",
          col_name: row[:col_name],
          col_id: row[:col_id]
        )
      end

      # Maps a human-readable CoL rank string to a TaxonWorks rank_class
      # string, using @col_code as the primary code and falling back
      # through the rest so that any rank resolves if possible. Returns nil
      # for unknown ranks; callers should skip creation for those rows.
      def resolve_rank_class(rank_string)
        ::Vendor::Colrapi.rank_class_for(rank_string, @col_code)
      end

      # Splits a CoL authorship string into
      # [verbatim_author, year_of_publication].
      def split_authorship(col_authorship, col_year)
        ::Vendor::Colrapi.split_authorship(col_authorship, col_year, col_code: @col_code)
      end

    end
  end
end
