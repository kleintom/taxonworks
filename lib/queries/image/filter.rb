module Queries
  module Image
    class Filter < Query::Filter
      include Queries::Concerns::Tags

      PARAMS = [
        :ancestor_id_target,
        :biocuration_class_id,
        :collecting_event_id,
        :collection_object_id,
        :collection_object_scope,
        :content_id,
        :depiction,
        :image_id,
        :observation_id,
        :otu_id,
        :sled_image_id,
        :source_id,
        :taxon_name_id,

        biocuration_class_id: [],
        collecting_event_id: [],
        collection_object_id: [],
        content_id: [],
        image_id: [],
        keyword_id_and: [],
        keyword_id_or: [],
        observation_id: [],
        otu_id: [],
        otu_scope: [],
        sled_image_id: [],
        source_id: [],
        taxon_name_id: [],
      ].freeze

      # @return [Array]
      #   images depicting content
      attr_accessor :content_id

      # @return [Array]
      #   images depicting collecting_event
      attr_accessor :collecting_event_id

      # @return [Array]
      #   images depicting collecting_object
      attr_accessor :collection_object_id

      # @return [Array]
      #   images depicting otus
      attr_accessor :otu_id

      # @return [Array]
      #   images depicting observations
      attr_accessor :observation_id

      # @return [Protonym.id, nil]
      #   return all images depicting an Otu that is self or descendant linked
      #   to this TaxonName
      attr_accessor :taxon_name_id

      # @return [Array]
      # A sub scope of sorts. Purpose is to gather all images
      # possible under an OTU that are of an OTU, CollectionObject or Observation.
      #
      # !! Must be used with an otu_id !!
      # @param otu_scope
      #   options
      #     :all (default, includes all below)
      #
      #     :otu (those on the OTU)
      #     :otu_observations (those on just the OTU)
      #     :collection_object_observations (those on just those determined as the OTU)
      #     :collection_objects (those on just those on the collection objects)
      #     :type_material (those on CollectionObjects that have TaxonName used in OTU)
      #     :type_material_observations (those on CollectionObjects that have TaxonName used in OTU)
      #
      #     :coordinate_otus  If present adds both.  Use downstream substraction to to diffs of with/out?
      #
      attr_accessor :otu_scope

      # @param collection_object_scope
      #   options
      #     :all (default, includes all below)
      #
      #     :collection_objects (those on the collection_object)
      #     :observations (those on just the CollectionObject observations)
      #      collecting_events (those on the associated collecting event)
      #     # maybe those on the CE
      attr_accessor :collection_object_scope

      # @return [Array]
      attr_accessor :image_id

      # @return [Array]
      #   of biocuration_class ids
      attr_accessor :biocuration_class_id

      # @return [Array]
      attr_accessor :sled_image_id

      # @return [Array]
      attr_accessor :sqed_depiction_id

      # @return [Boolean, nil]
      #   true - image is used (in a depiction)
      #   false - image is not used
      #   nil - either
      attr_accessor :depiction

      # TODO: taxon_name_id_target?
      # @return [Array]
      #   one or both of 'Otu', 'CollectionObject', defaults to both if nothing provided
      # Only used when `taxon_name_id` provided
      attr_accessor :ancestor_id_target

      # @return [Array]
      #   depicts some collection objec that is a type specimen
      # attr_accessor :is_type

      # @return [Boolean, nil]
      #   nil = TaxonDeterminations match regardless of current or historical
      #   true = TaxonDetermination must be .current
      #   false = TaxonDetermination must be .historical
      # attr_accessor :current_determinations

      # @param params [Hash]
      def initialize(query_params)
        super
        
        @ancestor_id_target = params[:ancestor_id_target]
        @biocuration_class_id = params[:biocuration_class_id]
        @collecting_event_id = params[:collecting_event_id]
        @collection_object_id = params[:collection_object_id]
        @collection_object_scope = params[:collection_object_scope]
        @content_id = params[:content_id]
        @depiction = boolean_param(params, :depiction)
        @image_id = params[:image_id]
        @observation_id = params[:observation_id]
        @otu_id = params[:otu_id]
        @otu_scope = params[:otu_scope]&.map(&:to_sym)
        @sled_image_id = params[:sled_image_id]
        @sqed_depiction_id = params[:sqed_depiction_id]
        @taxon_name_id = params[:taxon_name_id]
       
        set_tags_params(params)
      end

      def observation_id 
        [ @observation_id ].flatten.compact
      end

      def content_id
        [ @content_id ].flatten.compact
      end

      def taxon_name_id
        [ @taxon_name_id ].flatten.compact
      end

      def collection_object_id
        [ @collection_object_id ].flatten.compact
      end

      def collecting_event_id
        [ @collecting_event_id ].flatten.compact
      end

      def image_id
        [ @image_id ].flatten.compact
      end

      def otu_id
        [ @otu_id ].flatten.compact
      end

      def ancestor_id_target
        a = [ @ancestor_id_target ].flatten.compact
        a = ['Otu', 'CollectionObject'] if a.empty?
        a
      end

      def biocuration_class_id
        [ @biocuration_class_id ].flatten.compact
      end

      def otu_scope
        [ @otu_scope ].flatten.compact.map(&:to_sym)
      end

      def collection_object_scope
        [ @collection_object_scope ].flatten.compact.map(&:to_sym)
      end

      def sled_image_id
        [ @sled_image_id ].flatten.compact
      end

      def sqed_depiction_id
        [ @sqed_depiction_id ].flatten.compact
      end

      # @return [Arel::Table]
      def taxon_determination_table
        ::TaxonDetermination.arel_table
      end

      # @return [Arel::Table]
      def otu_table
        ::Otu.arel_table
      end

      # @return [Arel::Table]
      def collection_object_table
        ::CollectionObject.arel_table
      end

      # @return [Arel::Table]
      def type_materials_table
        ::TypeMaterial.arel_table
      end

      # @return [Arel::Table]
      def depiction_table
        ::Depiction.arel_table
      end

      def biocuration_facet
        return nil if biocuration_class_id.empty?
        ::Image.joins(collection_objects: [:depictions]).merge(
          ::CollectionObject::BiologicalCollectionObject.joins(:biocuration_classifications)
          .where(biocuration_classifications: {biocuration_class_id: biocuration_class_id})
        )
      end

      def depiction_facet
        return nil if depiction.nil?
        if depiction
          ::Image.joins(:depictions)
        else
          ::Image.where.missing(:depictions)
        end
      end

      def type_facet
        return nil if is_type.nil?
        table[:type].eq(collection_object_type)
      end

      def sled_image_facet
        return nil if sled_image_id.empty?
        ::Image.joins(:sled_image).where(sled_images: {id: sled_image_id})
      end

      def sqed_depiction_facet
        return nil if sqed_depiction_id.empty?
        ::Image.joins(depictions: [:sqed_depiction]).where(sqed_depictions: {id: sqed_depiction_id})
      end

      def coordinate_otu_ids
        ids = []
        otu_id.each do |id|
          ids += ::Otu.coordinate_otus(id).pluck(:id)
        end
        ids.uniq
      end

      def otu_scope_facet
        return nil if otu_id.empty? || otu_scope.empty?

        otu_ids = otu_id
        otu_ids += coordinate_otu_ids if otu_scope.include?(:coordinate_otus)

        otu_ids.uniq!

        selected = []

        if otu_scope.include?(:all)
          selected = [
            :otu_facet_otus,
            :otu_facet_collection_objects,
            :otu_facet_otu_observations,
            :otu_facet_collection_object_observations,
            :otu_facet_type_material,
            :otu_facet_type_material_observations
          ]
        else
          selected.push :otu_facet_otus if otu_scope.include?(:otus)
          selected.push :otu_facet_collection_objects if otu_scope.include?(:collection_objects)
          selected.push :otu_facet_collection_object_observations if otu_scope.include?(:collection_object_observations)
          selected.push :otu_facet_otu_observations if otu_scope.include?(:otu_observations)
          selected.push :otu_facet_type_material if otu_scope.include?(:type_material)
          selected.push :otu_facet_type_material_observations if otu_scope.include?(:type_material_observations)
        end

        q = selected.collect{|a| '(' + send(a, otu_ids).to_sql + ')'}.join(' UNION ')

        d = ::Image.from('(' + q + ')' + ' as images')
        d
      end

      def collection_object_scope_facet
        return nil if collection_object_id.empty? || collection_object_scope.empty?

        selected = []

        if collection_object_scope.include?(:all)
          selected = [
            :collection_object_facet_collection_objects,
            :collection_object_facet_observations,
            :collection_object_facet_collecting_events,
          ]
        elsif collection_object_scope.present? 
          selected.push :collection_object_facet_collection_objects if collection_object_scope.include?(:collection_objects)
          selected.push :collection_object_facet_observations if collection_object_scope.include?(:observations)
          selected.push :collection_object_facet_collecting_events if collection_object_scope.include?(:collecting_events)
        else
          selected.push collection_object_facet_collection_objects 
        end

        q = selected.collect{|a| '(' + send(a).to_sql + ')'}.join(' UNION ')

        d = ::Image.from('(' + q + ')' + ' as images')
        d
      end

      def collection_object_facet_collection_objects
        ::Image.joins(:collection_objects).where(collection_objects: {id: collection_object_id})
      end

      def collection_object_facet_observations
        ::Image.joins(:observations).where(observations: {observation_object_type: 'CollectionObject', observation_object_id: collection_object_id })
      end

      def collection_object_facet_collecting_events
        ::Image.joins(:observations)
          .joins("INNER JOIN collecting_events on collecting_events.id = observations.observation_object_id AND observations.observation_object_type = 'CollectingEvent'")
          .joins('INNER JOIN collection_objects on collection_objects.collecting_event_id = collecting_events.id')
          .where(collection_objects: {id: collection_object_id})
      end

      def otu_facet_type_material_observations(otu_ids)
        ::Image.joins(:observations)
          .joins("INNER JOIN type_materials on type_materials.collection_object_id = observations.observation_object_id AND observations.observation_object_type = 'CollectionObject'")
          .joins('INNER JOIN otus on otus.taxon_name_id = type_materials.protonym_id')
          .where(otus: {id: otu_ids})
      end

      def otu_facet_type_material(otu_ids)
        ::Image.joins(collection_objects: [type_materials: [protonym: [:otus]]])
          .where(otus: {id: otu_ids})
      end

      def otu_facet_otus(otu_ids)
        ::Image.joins(:depictions).where(depictions: {depiction_object_type: 'Otu', depiction_object_id: otu_ids})
      end

      def otu_facet_collection_objects(otu_ids)
        ::Image.joins(collection_objects: [:taxon_determinations])
          .where(taxon_determinations: {otu_id: otu_ids})
      end

      def otu_facet_collection_object_observations(otu_ids)
        ::Image.joins(:observations)
          .joins('INNER JOIN taxon_determinations on taxon_determinations.biological_collection_object_id = observations.observation_object_id')
          .where(taxon_determinations: {otu_id: otu_ids}, observations: {observation_object_type: 'CollectionObject'})
      end

      def otu_facet_otu_observations(otu_ids)
        ::Image.joins(:observations)
          .where(observations: {observation_object_id: otu_ids, observation_object_type: 'Otu'})
      end

      # @return [Scope]
      def type_material_facet
        return nil if type_specimen_taxon_name_id.nil?

        w = type_materials_table[:collection_object_id].eq(table[:id])
          .and( type_materials_table[:protonym_id].eq(type_specimen_taxon_name_id) )

        ::Image.where(
          ::TypeMaterial.where(w).arel.exists
        )
      end

      # @return [Scope]
      def type_material_type_facet
        return nil if is_type.empty?

        w = type_materials_table[:collection_object_id].eq(table[:id])
          .and( type_materials_table[:type_type].eq_any(is_type) )

        ::Image.where(
          ::TypeMaterial.where(w).arel.exists
        )
      end

      def image_facet
        return nil if image_id.empty?
        table[:id].eq_any(image_id)
      end

      def build_depiction_facet(kind, ids)
        return nil if ids.empty?
        ::Image.joins(:depictions).where(depictions: {depiction_object_id: ids, depiction_object_type: kind})
      end

      def ancestors_facet
        #  Image -> Depictions -> Otu -> TaxonName -> Ancestors
        return nil if taxon_name_id.empty?

        h = Arel::Table.new(:taxon_name_hierarchies)
        t = ::TaxonName.arel_table

        j1, j2, q1, q2 = nil, nil, nil, nil

        if ancestor_id_target.include?('Otu')
          a = otu_table.alias('oj1')
          b = t.alias('tj1')
          h_alias = h.alias('th1')

          j1 = table
            .join(depiction_table, Arel::Nodes::InnerJoin).on(table[:id].eq(depiction_table[:image_id]))
            .join(a, Arel::Nodes::InnerJoin).on( depiction_table[:depiction_object_id].eq(a[:id]).and( depiction_table[:depiction_object_type].eq('Otu') ))
            .join(b, Arel::Nodes::InnerJoin).on( a[:taxon_name_id].eq(b[:id]))
            .join(h_alias, Arel::Nodes::InnerJoin).on(b[:id].eq(h_alias[:descendant_id]))

          z = h_alias[:ancestor_id].eq_any(taxon_name_id)
          q1 = ::Image.joins(j1.join_sources).where(z)
        end

        if ancestor_id_target.include?('CollectionObject')
          a = otu_table.alias('oj2')
          b = t.alias('tj2')
          h_alias = h.alias('th2')

          j2 = table
            .join(depiction_table, Arel::Nodes::InnerJoin).on(table[:id].eq(depiction_table[:image_id]))
            .join(collection_object_table, Arel::Nodes::InnerJoin).on( depiction_table[:depiction_object_id].eq(collection_object_table[:id]).and( depiction_table[:depiction_object_type].eq('CollectionObject') ))
            .join(taxon_determination_table, Arel::Nodes::InnerJoin).on( collection_object_table[:id].eq(taxon_determination_table[:biological_collection_object_id]) )
            .join(a, Arel::Nodes::InnerJoin).on(  taxon_determination_table[:otu_id].eq(a[:id]) )
            .join(b, Arel::Nodes::InnerJoin).on( a[:taxon_name_id].eq(b[:id]))
            .join(h_alias, Arel::Nodes::InnerJoin).on(b[:id].eq(h_alias[:descendant_id]))

          z = h_alias[:ancestor_id].eq_any(taxon_name_id)
          q2 = ::Image.joins(j2.join_sources).where(z)
        end

        if q1 && q2
          ::Image.from("((#{q1.to_sql}) UNION (#{q2.to_sql})) as images")
        elsif q1
          q1
        else
          q2
        end

        #  if validity == true
        #    z = z.and(t[:cached_valid_taxon_name_id].eq(t[:id]))
        #  elsif validity == false
        #    z = z.and(t[:cached_valid_taxon_name_id].not_eq(t[:id]))
        #  end

        # if current_determinations == true
        #   z = z.and(taxon_determination_table[:position].eq(1))
        # elsif current_determinations == false
        #   z = z.and(taxon_determination_table[:position].gt(1))
        # end

      end
     
      def query_facets_facet(name = nil)
        return nil if name.nil?

        q = send((name + '_query').to_sym)

        return nil if q.nil?
       
        n = "query_#{name}_img"

        s = "WITH #{n} AS (" + q.all.to_sql + ') ' +
          ::Image
          .joins(:depictions)
          .joins("JOIN #{n} as #{n}1 on depictions.depiction_object_id = #{n}1.id AND depictions.depiction_object_type = '#{name.treetop_camelize}'")
          .to_sql

        ::Image.from('(' + s + ') as images')
      end

      def and_clauses
        [ image_facet ]
      end

      def merge_clauses
        s = ::Queries::Query::Filter::SUBQUERIES.select{|k,v| v.include?(:image)}.keys.map(&:to_s)
        [
          # type_material_facet,
          # type_material_type_facet,
          *s.collect{|m| query_facets_facet(m)}, # Reference all the Image referencing SUBQUERIES
          ancestors_facet,  # currently covers taxon_name_id
          biocuration_facet,
          build_depiction_facet('CollectingEvent', collecting_event_id),
          build_depiction_facet('Observation', observation_id),
          build_depiction_facet('Content', content_id),

          # build_depiction_facet('CollectionObject', collection_object_id),
          collection_object_scope_facet, # handles ^

          depiction_facet,
          otu_scope_facet,
          sled_image_facet,
          sqed_depiction_facet,
        ]
      end

    end
  end
end
