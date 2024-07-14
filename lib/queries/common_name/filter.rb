module Queries
  module CommonName
    class Filter < Query::Filter

      PARAMS = [
        :common_name_id,
        :gazetteer_ids,
        :geographic_area_id,
        :language_id,
        :name,
        :otu_id,
        otu_id: [],
        common_name_id: [],
      ].freeze

      # Query variables
      attr_accessor :name, :gazetteer_ids, :geographic_area_id, :otu_id,
        :language_id

      def initialize(query_params)
        super
        @gazetteer_ids = params[:gazetteer_ids]
        @geographic_area_id = params[:geographic_area_id]
        @language_id = params[:language_id]
        @name = params[:name]
        @otu_id = params[:otu_id]
      end

      def otu_id
        [@otu_id].flatten.compact
      end

      def language_id
        [@language_id].flatten.compact
      end

      def gazetteer_ids
        [@gazetteer_ids].flatten.compact
      end

      def geographic_area_id
        [@geographic_area_id_id].flatten.compact
      end

      def common_name_id
        [@common_name_id].flatten.compact
      end

      def otu_id_facet
        return nil if otu_id.empty?
        table[:otu_id].in(otu_id)
      end

      def language_id_facet
        return nil if language_id.empty?
        table[:language_id].in(language_id)
      end

      def name_facet
        return nil if name.blank?
        table[:name].eq(name)
      end

      def gazetteer_ids_facet
        return nil if gazetteer_ids.empty?
        table[:gazetteer_ids].in(gazetteer_ids)
      end

      def geographic_area_id_facet
        return nil if geographic_area_id.empty?
        table[:geographic_area_id].in(geographic_area_id)
      end

      def and_clauses
        [
          gazetteer_ids_facet,
          geographic_area_id_facet,
          language_id_facet,
          name_facet,
          otu_id_facet,
        ]
      end

    end
  end
end
