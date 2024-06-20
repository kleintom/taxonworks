# require 'rgeo'

# A GeographicItem is one and only one of [point, line_string, polygon, multi_point, multi_line_string,
# multi_polygon, geometry_collection, geography] which describes a position, path, or area on the globe, generally associated
# with a geographic_area (through a geographic_area_geographic_item entry), a gazetteer, or a georeference.
#
# @!attribute point
#   @return [RGeo::Geographic::ProjectedPointImpl]
#
# @!attribute line_string
#   @return [RGeo::Geographic::ProjectedLineStringImpl]
#
# @!attribute polygon
#   @return [RGeo::Geographic::ProjectedPolygonImpl]
#   CCW orientation is applied
#
# @!attribute multi_point
#   @return [RGeo::Geographic::ProjectedMultiPointImpl]
#
# @!attribute multi_line_string
#   @return [RGeo::Geographic::ProjectedMultiLineStringImpl]
#
# @!attribute multi_polygon
#   @return [RGeo::Geographic::ProjectedMultiPolygonImpl]
#   CCW orientation is applied
#
# @!attribute geometry_collection
#   @return [RGeo::Geographic::ProjectedGeometryCollectionImpl]
#
# @!attribute geography
#   @return [RGeo::Geographic::Geography]
#   Holds a shape of any geographic type. Currently only used by Gazetteer,
#   eventually all of the above shapes will be folded into here.
#
# @!attribute type
#   @return [String]
#     Rails STI
#
# @!attribute cached_total_area
#   @return [Numeric]
#     if polygon-based the value of the enclosed area in square meters
#
# Key methods in this giant library
#
# `#geo_object` - return a RGEO object representation
#
#
class GeographicItem < ApplicationRecord
  include Housekeeping::Users
  include Housekeeping::Timestamps
  include Shared::HasPapertrail
  include Shared::IsData
  include Shared::SharedAcrossProjects

  # Methods that are deprecated or used only in specs
  # TODO move spec-only methods somewhere else?
  include GeographicItem::Deprecated

  # @return [Hash, nil]
  #   An internal variable for use in super calls, holds a Hash in GeoJSON format (temporarily)
  attr_accessor :geometry

  # @return [Boolean, RGeo object]
  # @params value [Hash in GeoJSON format] ?!
  # TODO: WHY! boolean not nil, or object
  # Used to build geographic items from a shape [ of what class ] !?
  attr_accessor :shape

  # @return [Boolean]
  #   When true cached values are not built
  attr_accessor :no_cached

  SHAPE_TYPES = [
    :point,
    :line_string,
    :polygon,
    :multi_point,
    :multi_line_string,
    :multi_polygon,
    :geometry_collection
  ].freeze

  DATA_TYPES = (SHAPE_TYPES + [:geography]).freeze

  GEOMETRY_SQL = Arel::Nodes::Case.new(arel_table[:type])
    .when('GeographicItem::MultiPolygon').then(Arel::Nodes::NamedFunction.new('CAST', [arel_table[:multi_polygon].as('geometry')]))
    .when('GeographicItem::Point').then(Arel::Nodes::NamedFunction.new('CAST', [arel_table[:point].as('geometry')]))
    .when('GeographicItem::LineString').then(Arel::Nodes::NamedFunction.new('CAST', [arel_table[:line_string].as('geometry')]))
    .when('GeographicItem::Polygon').then(Arel::Nodes::NamedFunction.new('CAST', [arel_table[:polygon].as('geometry')]))
    .when('GeographicItem::MultiLineString').then(Arel::Nodes::NamedFunction.new('CAST', [arel_table[:multi_line_string].as('geometry')]))
    .when('GeographicItem::MultiPoint').then(Arel::Nodes::NamedFunction.new('CAST', [arel_table[:multi_point].as('geometry')]))
    .when('GeographicItem::GeometryCollection').then(Arel::Nodes::NamedFunction.new('CAST', [arel_table[:geometry_collection].as('geometry')]))
    .when('GeographicItem::Geography').then(Arel::Nodes::NamedFunction.new('CAST', [arel_table[:geography].as('geometry')]))
    .freeze

  GEOGRAPHY_SQL = "CASE geographic_items.type
    WHEN 'GeographicItem::MultiPolygon' THEN multi_polygon
    WHEN 'GeographicItem::Point' THEN point
    WHEN 'GeographicItem::LineString' THEN line_string
    WHEN 'GeographicItem::Polygon' THEN polygon
    WHEN 'GeographicItem::MultiLineString' THEN multi_line_string
    WHEN 'GeographicItem::MultiPoint' THEN multi_point
    WHEN 'GeographicItem::GeometryCollection' THEN geometry_collection
    WHEN 'GeographicItem::Geography' THEN geography
    END".freeze

    # ANTI_MERIDIAN = '0X0102000020E61000000200000000000000008066400000000000405640000000000080664000000000004056C0'
    ANTI_MERIDIAN = 'LINESTRING (180 89.0, 180 -89)'.freeze

    has_many :cached_map_items, inverse_of: :geographic_item

    has_many :geographic_areas_geographic_items, dependent: :destroy, inverse_of: :geographic_item
    has_many :geographic_areas, through: :geographic_areas_geographic_items
    has_many :asserted_distributions, through: :geographic_areas
    has_many :geographic_area_types, through: :geographic_areas
    has_many :parent_geographic_areas, through: :geographic_areas, source: :parent

    has_many :gazetteers, inverse_of: :geographic_item
    has_many :georeferences, inverse_of: :geographic_item
    has_many :georeferences_through_error_geographic_item,
      class_name: 'Georeference', foreign_key: :error_geographic_item_id, inverse_of: :error_geographic_item
    has_many :collecting_events_through_georeferences, through: :georeferences, source: :collecting_event
    has_many :collecting_events_through_georeference_error_geographic_item,
      through: :georeferences_through_error_geographic_item, source: :collecting_event

    # TODO: THIS IS NOT GOOD
    before_validation :set_type_if_shape_column_present

    validate :some_data_is_provided
    validates :type, presence: true # not needed

    scope :include_collecting_event, -> { includes(:collecting_events_through_georeferences) }
    scope :geo_with_collecting_event, -> { joins(:collecting_events_through_georeferences) }
    scope :err_with_collecting_event, -> { joins(:georeferences_through_error_geographic_item) }

    after_save :set_cached, unless: Proc.new {|n| n.no_cached || errors.any? }
    after_save :align_winding

    class << self

      def st_union(geographic_item_scope)
        GeographicItem.select("ST_Union(#{GeographicItem::GEOMETRY_SQL.to_sql}) as collection")
          .where(id: geographic_item_scope.pluck(:id))
      end

      # @param [String] wkt
      # @return [Boolean]
      #   whether or not the wkt intersects with the anti-meridian
      #   !! StrongParams security considerations
      def crosses_anti_meridian?(wkt)
        GeographicItem.find_by_sql(
          ['SELECT ST_Intersects(ST_GeogFromText(?), ST_GeogFromText(?)) as r;', wkt, ANTI_MERIDIAN]
        ).first.r
      end

      #
      # SQL fragments
      #

      # @param [Integer, String]
      # @return [String]
      #   a SQL select statement that returns the *geometry* for the
      #   geographic_item with the specified id
      def select_geometry_sql(geographic_item_id)
        "SELECT #{GeographicItem::GEOMETRY_SQL.to_sql} from geographic_items where geographic_items.id = #{geographic_item_id}"
      end

      # @param [Integer, String]
      # @return [String]
      #   a SQL select statement that returns the geography for the
      #   geographic_item with the specified id
      def select_geography_sql(geographic_item_id)
        ActiveRecord::Base.send(:sanitize_sql_for_conditions, [
          "SELECT #{GeographicItem::GEOGRAPHY_SQL} from geographic_items where geographic_items.id = ?",
          geographic_item_id])
      end

      # @param [Symbol] choice, either :latitude or :longitude
      # @return [String]
      #   a fragment returning either latitude or longitude columns
      def lat_long_sql(choice)
        return nil unless [:latitude, :longitude].include?(choice)
        f = "'D.DDDDDD'" # TODO: probably a constant somewhere
        v = (choice == :latitude ? 1 : 2)

      'CASE geographic_items.type ' \
      "WHEN 'GeographicItem::GeometryCollection' THEN split_part(ST_AsLatLonText(ST_Centroid" \
      "(geometry_collection::geometry), #{f}), ' ', #{v})
      WHEN 'GeographicItem::LineString' THEN split_part(ST_AsLatLonText(ST_Centroid(line_string::geometry), " \
      "#{f}), ' ', #{v})
      WHEN 'GeographicItem::MultiPolygon' THEN split_part(ST_AsLatLonText(" \
      "ST_Centroid(multi_polygon::geometry), #{f}), ' ', #{v})
      WHEN 'GeographicItem::Point' THEN split_part(ST_AsLatLonText(" \
      "ST_Centroid(point::geometry), #{f}), ' ', #{v})
      WHEN 'GeographicItem::Polygon' THEN split_part(ST_AsLatLonText(" \
      "ST_Centroid(polygon::geometry), #{f}), ' ', #{v})
      WHEN 'GeographicItem::MultiLineString' THEN split_part(ST_AsLatLonText(" \
      "ST_Centroid(multi_line_string::geometry), #{f} ), ' ', #{v})
      WHEN 'GeographicItem::MultiPoint' THEN split_part(ST_AsLatLonText(" \
      "ST_Centroid(multi_point::geometry), #{f}), ' ', #{v})
      WHEN 'GeographicItem::GeometryCollection' THEN split_part(ST_AsLatLonText(" \
      "ST_Centroid(geometry_collection::geometry), #{f}), ' ', #{v})
      WHEN 'GeographicItem::Geography' THEN split_part(ST_AsLatLonText(" \
      "ST_Centroid(geography::geometry), #{f}), ' ', #{v})
    END as #{choice}"
      end

      # @param [Integer] geographic_item_id
      # @param [Integer] distance
      # @return [String]
      def within_radius_of_item_sql(geographic_item_id, distance)
        'ST_DWithin(' \
          "(#{GeographicItem::GEOGRAPHY_SQL}), " \
          "(#{select_geography_sql(geographic_item_id)}), " \
          "#{distance}" \
        ')'
      end


      # @param [Integer] geographic_item_id
      # @param [Number] distance (in meters) (positive only?!)
      # @param [Number] buffer: distance in meters to grow/shrink the shapes checked against (negative allowed)
      # @return [String]
      def st_buffer_st_within(geographic_item_id, distance, buffer = 0)
        'ST_DWithin(' \
          "ST_Buffer(#{GeographicItem::GEOGRAPHY_SQL}, #{buffer}), " \
          "(#{select_geography_sql(geographic_item_id)}), " \
          "#{distance}" \
        ')'
      end

      # TODO: 3D is overkill here
      # @param [String] wkt
      # @param [Integer] distance (meters)
      # @return [String]
      # !! This is intersecting
      def intersecting_radius_of_wkt_sql(wkt, distance)
        'ST_DWithin(' \
          "(#{GeographicItem::GEOGRAPHY_SQL}), " \
          "ST_GeographyFromText('#{wkt}'), " \
          "#{distance}" \
        ')'
      end

      # @param [String] wkt
      # @param [Integer] distance (meters)
      # @return [String]
      # !! This is fully covering
      def within_radius_of_wkt_sql(wkt, distance)
        'ST_Covers(' \
          "ST_Buffer(ST_GeographyFromText('#{wkt}'), #{distance}), " \
          "(#{GeographicItem::GEOGRAPHY_SQL})" \
        ')'
      end

      # @param [String, Integer, String]
      # @return [String]
      #   a SQL fragment for ST_Contains() function, returns
      #   all geographic items whose target_shape contains the item supplied's
      #   source_shape
      def containing_sql(target_shape = nil, geographic_item_id = nil,
                         source_shape = nil)
        return 'false' if geographic_item_id.nil? || source_shape.nil? || target_shape.nil?

        target_shape_sql = GeographicItem.shape_column_sql(target_shape)
        'ST_Contains(' \
          "#{target_shape_sql}::geometry, " \
          "(#{geometry_sql(geographic_item_id, source_shape)})" \
        ')'
      end

      # @param [String, Integer, String]
      # @return [String]
      #   a SQL fragment for ST_Contains() function, returns
      #   all geographic items whose target_shape is contained in the item
      #   supplied's source_shape
      def reverse_containing_sql(target_shape = nil, geographic_item_id = nil, source_shape = nil)
        return 'false' if geographic_item_id.nil? || source_shape.nil? || target_shape.nil?

        target_shape_sql = GeographicItem.shape_column_sql(target_shape)
        'ST_Contains(' \
          "(#{geometry_sql(geographic_item_id, source_shape)}), " \
          "#{target_shape_sql}::geometry" \
        ')'
      end

      # @param [Integer, String]
      # @return [String]
      #   a SQL fragment that returns the column containing data of the given
      #   shape for the specified geographic item
      def geometry_sql(geographic_item_id = nil, shape = nil)
        return 'false' if geographic_item_id.nil? || shape.nil?

        "SELECT #{GeographicItem.shape_column_sql(shape)}::geometry FROM " \
          "geographic_items WHERE id = #{geographic_item_id}"
      end

      # @param [Integer, Array of Integer] geographic_item_ids
      # @return [String]
      #    returns one or more geographic items combined as a single geometry
      #    in a paren wrapped column 'single_geometry'
      def single_geometry_sql(*geographic_item_ids)
        geographic_item_ids.flatten!
        q = ActiveRecord::Base.send(:sanitize_sql_for_conditions, [
          "SELECT ST_Collect(f.the_geom) AS single_geometry
     FROM (
        SELECT (ST_DUMP(#{GeographicItem::GEOMETRY_SQL.to_sql})).geom as the_geom
        FROM geographic_items
        WHERE id in (?))
      AS f", geographic_item_ids])

      '(' + q + ')'
      end

      # @param [Integer, Array of Integer] geographic_item_ids
      # @return [String]
      #   returns a single geometry "column" (paren wrapped) as
      #   "single_geometry" for multiple geographic item ids, or the geometry
      #   as 'geometry' for a single id
      def geometry_sql2(*geographic_item_ids)
        geographic_item_ids.flatten! # *ALWAYS* reduce the pile to a single level of ids
        if geographic_item_ids.count == 1
          "(#{GeographicItem.geometry_for_sql(geographic_item_ids.first)})"
        else
          GeographicItem.single_geometry_sql(geographic_item_ids)
        end
      end

      # @param [Integer, Array of Integer] geographic_item_ids
      # @return [String] Those geographic items containing the union of
      # geographic_item_ids.
      def containing_where_sql(*geographic_item_ids)
        "ST_CoveredBy(
          #{GeographicItem.geometry_sql2(*geographic_item_ids)},
          #{GeographicItem::GEOMETRY_SQL.to_sql})"
      end

      # @params [String] well known text
      # @return [String] the SQL fragment for the specific geometry type,
      # shifted by longitude
      # Note: this routine is called when it is already known that the A
      # argument crosses anti-meridian
      # TODO If wkt coords are in the range 0..360 and GI coords are in the range -180..180 (or vice versa), doesn't this fail? Don't you want all coords in the range 0..360 in this geometry case? Is there any assumption about range of inputs for georefs, e.g.? are they always normalized? See anti-meridian spec?
      def contained_by_wkt_shifted_sql(wkt)
        "ST_Contains(ST_ShiftLongitude(ST_GeomFromText('#{wkt}', 4326)), (
        CASE geographic_items.type
           WHEN 'GeographicItem::MultiPolygon' THEN ST_ShiftLongitude(multi_polygon::geometry)
           WHEN 'GeographicItem::Point' THEN ST_ShiftLongitude(point::geometry)
           WHEN 'GeographicItem::LineString' THEN ST_ShiftLongitude(line_string::geometry)
           WHEN 'GeographicItem::Polygon' THEN ST_ShiftLongitude(polygon::geometry)
           WHEN 'GeographicItem::MultiLineString' THEN ST_ShiftLongitude(multi_line_string::geometry)
           WHEN 'GeographicItem::MultiPoint' THEN ST_ShiftLongitude(multi_point::geometry)
           WHEN 'GeographicItem::GeometryCollection' THEN ST_ShiftLongitude(geometry_collection::geometry)
           WHEN 'GeographicItem::Geography' THEN ST_ShiftLongitude(geography::geometry)
        END
        )
      )"
      end

      # TODO: Remove the hard coded 4326 reference
      # @params [String] wkt
      # @return [String] SQL fragment limiting geographic items to those
      # contained by this WKT
      def contained_by_wkt_sql(wkt)
        if crosses_anti_meridian?(wkt)
          contained_by_wkt_shifted_sql(wkt)
        else
          'ST_Contains(' \
            "ST_GeomFromText('#{wkt}', 4326), " \
            "#{GEOMETRY_SQL.to_sql}" \
          ')'
        end
      end

      # @param [Integer, Array of Integer] geographic_item_ids
      # @return [String] sql for contained_by via ST_Contains
      # Note: !! If the target GeographicItem#id crosses the anti-meridian then you may/will get unexpected results.
      def contained_by_where_sql(*geographic_item_ids)
        'ST_Contains(' \
          "#{GeographicItem.geometry_sql2(*geographic_item_ids)}, " \
          "#{GEOMETRY_SQL.to_sql}" \
        ')'
      end

      # @param [RGeo:Point] rgeo_point
      # @return [String] sql for containing via ST_CoveredBy
      # TODO: Remove the hard coded 4326 reference
      # TODO: should this be wkt_point instead of rgeo_point?
      def containing_where_for_point_sql(rgeo_point)
        'ST_CoveredBy(' \
          "ST_GeomFromText('#{rgeo_point}', 4326), " \
          "#{GeographicItem::GEOMETRY_SQL.to_sql}" \
        ')'
      end

      # @param [Integer] geographic_item_id
      # @return [String] SQL for geometries
      def geometry_for_sql(geographic_item_id)
        'SELECT ' + GeographicItem::GEOMETRY_SQL.to_sql + ' AS geometry FROM geographic_items WHERE id = ' \
          "#{geographic_item_id} LIMIT 1"
      end

      #
      # Scopes
      #

      # @param [Integer, Array of Integer] geographic_item_ids
      # @return [Scope]
      #    the geographic items containing all of the geographic_item ids;
      #    return value never includes geographic_item_ids
      def containing(*geographic_item_ids)
        where(GeographicItem.containing_where_sql(geographic_item_ids)).not_ids(*geographic_item_ids)
      end

      # @param [RGeo::Point] rgeo_point
      # @return [Scope]
      #    the geographic items containing this point
      # TODO: should be containing_wkt ?
      def containing_point(rgeo_point)
        where(GeographicItem.containing_where_for_point_sql(rgeo_point))
      end

      # return [Scope]
      #   A scope that limits the result to those GeographicItems that have a collecting event
      #   through either the geographic_item or the error_geographic_item
      #
      # A raw SQL join approach for comparison
      #
      # GeographicItem.joins('LEFT JOIN georeferences g1 ON geographic_items.id = g1.geographic_item_id').
      #   joins('LEFT JOIN georeferences g2 ON geographic_items.id = g2.error_geographic_item_id').
      #   where("(g1.geographic_item_id IS NOT NULL OR g2.error_geographic_item_id IS NOT NULL)").uniq

      # @return [Scope] GeographicItem
      # This uses an Arel table approach, this is ultimately more decomposable if we need. Of use:
      #  http://danshultz.github.io/talks/mastering_activerecord_arel  <- best
      #  https://github.com/rails/arel
      #  http://stackoverflow.com/questions/4500629/use-arel-for-a-nested-set-join-query-and-convert-to-activerecordrelation
      #  http://rdoc.info/github/rails/arel/Arel/SelectManager
      #  http://stackoverflow.com/questions/7976358/activerecord-arel-or-condition
      #
      def with_collecting_event_through_georeferences
        geographic_items = GeographicItem.arel_table
        georeferences = Georeference.arel_table
        g1 = georeferences.alias('a')
        g2 = georeferences.alias('b')

        c = geographic_items.join(g1, Arel::Nodes::OuterJoin).on(geographic_items[:id].eq(g1[:geographic_item_id]))
          .join(g2, Arel::Nodes::OuterJoin).on(geographic_items[:id].eq(g2[:error_geographic_item_id]))

        GeographicItem.joins(# turn the Arel back into scope
                             c.join_sources # translate the Arel join to a join hash(?)
                            ).where(
                              g1[:id].not_eq(nil).or(g2[:id].not_eq(nil)) # returns a Arel::Nodes::Grouping
                            ).distinct
      end

      # @param [String, GeographicItems]
      # @return [Scope]
      def intersecting(shape, *geographic_items)
        shape = shape.to_s.downcase
        if shape == 'any'
          pieces = []
          SHAPE_TYPES.each { |shape|
            pieces.push(GeographicItem.intersecting(shape, geographic_items).to_a)
          }

          # @TODO change 'id in (?)' to some other sql construct
          GeographicItem.where(id: pieces.flatten.map(&:id))
        else
          shape_column = GeographicItem.shape_column_sql(shape)
          q = geographic_items.flatten.collect { |geographic_item|
            # seems like we want this: http://danshultz.github.io/talks/mastering_activerecord_arel/#/15/2
            # TODO would geometry intersect be equivalent and faster?
            "ST_Intersects(#{shape_column}, '#{geographic_item.geo_object}')"
          }.join(' or ')

          where(q)
        end
      end

      # @param [GeographicItem#id] geographic_item_id
      # @param [Float] distance in meters ?!?!
      # @return [ActiveRecord::Relation]
      # !! should be distance, not radius?!
      def within_radius_of_item(geographic_item_id, distance)
        where(within_radius_of_item_sql(geographic_item_id, distance))
      end

      # rubocop:disable Metrics/MethodLength
      # @param [String] shape to search
      # @param [GeographicItem] geographic_items or array of geographic_items
      #                         to be tested.
      # @return [Scope] of GeographicItems that contain at least one of
      #                 geographic_items
      #
      # If this scope is given an Array of GeographicItems as a second parameter,
      # it will return the 'OR' of each of the objects against the table.
      # SELECT COUNT(*) FROM "geographic_items"
      #        WHERE (ST_Contains(polygon::geometry, GeomFromEWKT('srid=4326;POINT (0.0 0.0 0.0)'))
      #               OR ST_Contains(polygon::geometry, GeomFromEWKT('srid=4326;POINT (-9.8 5.0 0.0)')))
      #
      def are_contained_in_item(shape, *geographic_items) # = containing
        geographic_items.flatten! # in case there is a array of arrays, or multiple objects
        shape = shape.to_s.downcase
        case shape
        when 'any'
          part = []
          SHAPE_TYPES.each { |shape|
            part.push(GeographicItem.are_contained_in_item(shape, geographic_items).to_a)
          }
          # TODO: change 'id in (?)' to some other sql construct
          GeographicItem.where(id: part.flatten.map(&:id))

        when 'any_poly', 'any_line'
          part = []
          SHAPE_TYPES.each { |shape|
            if column.to_s.index(shape.gsub('any_', ''))
              part.push(GeographicItem.are_contained_in_item(shape, geographic_items).to_a)
            end
          }
          # TODO: change 'id in (?)' to some other sql construct
          GeographicItem.where(id: part.flatten.map(&:id))

        else
          q = geographic_items.flatten.collect { |geographic_item|
            GeographicItem.containing_sql(shape, geographic_item.id,
                                          geographic_item.geo_object_type)
          }.join(' or ')

          # This will prevent the invocation of *ALL* of the GeographicItems
          # if there are no GeographicItems in the request (see
          # CollectingEvent.name_hash(types)).
          q = 'FALSE' if q.blank?
          where(q) # .not_including(geographic_items)
        end
      end

      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      # @param shape [String] can be any of SHAPE_TYPES, or 'any' to check
      # against all types, 'any_poly' to check against 'polygon' or
      # 'multi_polygon', or 'any_line' to check against 'line_string' or
      #'multi_line_string'.
      # @param geographic_items [GeographicItem] Can be a single
      # GeographicItem, or an array of GeographicItem.
      # @return [Scope] of all GeographicItems of the given shape contained
      # in one or more of geographic_items
      def is_contained_by(shape, *geographic_items)
        shape = shape.to_s.downcase
        case shape
        when 'any'
          part = []
          SHAPE_TYPES.each { |shape|
            part.push(GeographicItem.is_contained_by(shape, geographic_items).to_a)
          }
          # @TODO change 'id in (?)' to some other sql construct
          GeographicItem.where(id: part.flatten.map(&:id))

        when 'any_poly', 'any_line'
          part = []
          SHAPE_TYPES.each { |shape|
            if shape.to_s.index(shape.gsub('any_', ''))
              part.push(GeographicItem.is_contained_by(shape, geographic_items).to_a)
            end
          }
          # @TODO change 'id in (?)' to some other sql construct
          GeographicItem.where(id: part.flatten.map(&:id))

        else
          q = geographic_items.flatten.collect { |geographic_item|
            GeographicItem.reverse_containing_sql(shape, geographic_item.to_param,
                                                  geographic_item.geo_object_type)
          }.join(' or ')
          where(q) # .not_including(geographic_items)
        end
      end

      # rubocop:enable Metrics/MethodLength

      # @param [String, GeographicItem]
      # @return [Scope]
      def ordered_by_shortest_distance_from(shape, geographic_item)
        select_distance_with_geo_object(shape, geographic_item)
          .where_distance_greater_than_zero(shape, geographic_item)
          .order('distance')
      end

      # @param [String, GeographicItem]
      # @return [Scope]
      def ordered_by_longest_distance_from(shape, geographic_item)
        select_distance_with_geo_object(shape, geographic_item)
          .where_distance_greater_than_zero(shape, geographic_item)
          .order('distance desc')
      end

      # @param [String] shape
      # @param [GeographicItem] geographic_item
      # @return [String]
      def select_distance_with_geo_object(shape, geographic_item)
        shape_column = GeographicItem.shape_column_sql(shape)
        select("*, ST_Distance(#{shape_column}, GeomFromEWKT('srid=4326;#{geographic_item.geo_object}')) as distance")
      end

      # @param [String, GeographicItem]
      # @return [Scope]
      def where_distance_greater_than_zero(shape, geographic_item)
        shape_column = GeographicItem.shape_column_sql(shape)
        where("#{shape_column} is not null and ST_Distance(#{shape_column}, " \
              "GeomFromEWKT('srid=4326;#{geographic_item.geo_object}')) > 0")
      end

      # @param [GeographicItem]
      # @return [Scope]
      def not_including(geographic_items)
        where.not(id: geographic_items)
      end

      #
      # Other
      #

      # @param [Integer] geographic_item_id1
      # @param [Integer] geographic_item_id2
      # @return [Float]
      def distance_between(geographic_item_id1, geographic_item_id2)
        q = 'ST_Distance(' \
               "#{GeographicItem::GEOGRAPHY_SQL}, " \
               "(#{select_geography_sql(geographic_item_id2)}) " \
             ') as distance'

        GeographicItem.where(id: geographic_item_id1).pick(Arel.sql(q))
      end

      # @param [RGeo::Point] point
      # @return [Hash]
      #   as per #inferred_geographic_name_hierarchy but for Rgeo point
      def point_inferred_geographic_name_hierarchy(point)
        GeographicItem.containing_point(point).order(cached_total_area: :ASC).first&.inferred_geographic_name_hierarchy
      end

      # @param [String] type_name ('polygon', 'point', 'line', etc)
      # @return [String] if type
      def eval_for_type(type_name)
        retval = 'GeographicItem'
        case type_name.upcase
        when 'POLYGON'
          retval += '::Polygon'
        when 'MULTIPOLYGON'
          retval += '::MultiPolygon'
        when 'LINESTRING'
          retval += '::LineString'
        when 'MULTILINESTRING'
          retval += '::MultiLineString'
        when 'POINT'
          retval += '::Point'
        when 'MULTIPOINT'
          retval += '::MultiPoint'
        when 'GEOMETRYCOLLECTION'
          retval += '::GeometryCollection'
        when 'GEOGRAPHY'
          retval += '::Geography'
        else
          retval = nil
        end
        retval
      end

      # example, not used
      # @param [Integer] geographic_item_id
      # @return [RGeo::Geographic object]
      def geometry_for(geographic_item_id)
        GeographicItem.select(GeographicItem::GEOMETRY_SQL.to_sql + ' AS geometry').find(geographic_item_id)['geometry']
      end

      # example, not used
      # @param [Integer, Array] geographic_item_ids
      # @return [Scope]
      def st_multi(*geographic_item_ids)
        GeographicItem.find_by_sql(
          "SELECT ST_Multi(ST_Collect(g.the_geom)) AS singlegeom
     FROM (
        SELECT (ST_DUMP(#{GeographicItem::GEOMETRY_SQL.to_sql})).geom AS the_geom
        FROM geographic_items
        WHERE id IN (?))
      AS g;", geographic_item_ids.flatten
        )
      end
    end # class << self

    # @return [Hash]
    #    a geographic_name_classification or empty Hash
    # This is a quick approach that works only when
    # the geographic_item is linked explicitly to a GeographicArea.
    #
    # !! Note that it is not impossible for a GeographicItem to be linked
    # to > 1 GeographicArea, in that case we are assuming that all are
    # equally refined, this might not be the case in the future because
    # of how the GeographicArea gazetteer is indexed.
    def quick_geographic_name_hierarchy
      geographic_areas.order(:id).each do |ga|
        h = ga.geographic_name_classification # not quick enough !!
        return h if h.present?
      end
      return {}
    end

    # @return [Hash]
    #   a geographic_name_classification (see GeographicArea) inferred by
    # finding the smallest area containing this GeographicItem, in the most accurate gazetteer
    # and using it to return country/state/county. See also the logic in
    # filling in missing levels in GeographicArea.
    def inferred_geographic_name_hierarchy
      if small_area = containing_geographic_areas
        .joins(:geographic_areas_geographic_items)
        .merge(GeographicAreasGeographicItem.ordered_by_data_origin)
        .ordered_by_area
        .first

        small_area.geographic_name_classification
      else
        {}
      end
    end

    # @param [RGeo::Point] point
    # @return [Hash]
    #   as per #inferred_geographic_name_hierarchy but for Rgeo point
    def point_inferred_geographic_name_hierarchy(point)
      GeographicItem.containing_point(point).order(cached_total_area: :ASC).first&.inferred_geographic_name_hierarchy
    end

    def geographic_name_hierarchy
      a = quick_geographic_name_hierarchy # quick; almost never the case, UI not setup to do this
      return a if a.present?
      inferred_geographic_name_hierarchy # slow
    end

    # @return [Scope]
    #   the Geographic Areas that contain (gis) this geographic item
    def containing_geographic_areas
      GeographicArea.joins(:geographic_items).includes(:geographic_area_type)
        .joins("JOIN (#{GeographicItem.containing(id).to_sql}) j on geographic_items.id = j.id")
    end

    # @return [Boolean]
    #   whether stored shape is ST_IsValid
    def valid_geometry?
      GeographicItem.where(id:).select("ST_IsValid(ST_AsBinary(#{data_column})) is_valid").first['is_valid']
    end

    # @return [Array of latitude, longitude]
    #    the lat, lon of the first point in the GeoItem, see subclass for
    #    st_start_point
    def start_point
      o = st_start_point
      [o.y, o.x]
    end

    # @return [Array]
    #   the lat, long, as STRINGs for the centroid of this geographic item
    #   Meh- this: https://postgis.net/docs/en/ST_MinimumBoundingRadius.html
    def center_coords
      r = GeographicItem.find_by_sql(
        "Select split_part(ST_AsLatLonText(ST_Centroid(#{GeographicItem::GEOMETRY_SQL.to_sql}), " \
        "'D.DDDDDD'), ' ', 1) latitude, split_part(ST_AsLatLonText(ST_Centroid" \
        "(#{GeographicItem::GEOMETRY_SQL.to_sql}), 'D.DDDDDD'), ' ', 2) " \
        "longitude from geographic_items where id = #{id};")[0]

      [r.latitude, r.longitude]
    end

    # @return [RGeo::Geographic::ProjectedPointImpl]
    #    representing the centroid of this geographic item
    def centroid
      # Gis::FACTORY.point(*center_coords.reverse)
      return geo_object if geo_object_type == :point
      return Gis::FACTORY.parse_wkt(self.st_centroid)
    end

    # @param [GeographicItem] geographic_item
    # @return [Double] distance in meters
    # Like st_distance but works with changed and non persisted objects
    def st_distance_to_geographic_item(geographic_item)
      unless !persisted? || changed?
        a = "(#{GeographicItem.select_geography_sql(id)})"
      else
        a = "ST_GeographyFromText('#{geo_object}')"
      end

      unless !geographic_item.persisted? || geographic_item.changed?
        b = "(#{GeographicItem.select_geography_sql(geographic_item.id)})"
      else
        b = "ST_GeographyFromText('#{geographic_item.geo_object}')"
      end

      ActiveRecord::Base.connection.select_value("SELECT ST_Distance(#{a}, #{b})")
    end

    # @param [Integer] geographic_item_id
    # @return [Double] distance in meters
    def st_distance_spheroid(geographic_item_id)
      q = 'ST_DistanceSpheroid(' \
            "(#{GeographicItem.select_geometry_sql(id)}), " \
            "(#{GeographicItem.select_geometry_sql(geographic_item_id)}) ," \
            "'#{Gis::SPHEROID}'" \
          ') as distance'
      GeographicItem.where(id:).pick(Arel.sql(q))
    end

    # @return [String]
    #   a WKT POINT representing the centroid of the geographic item
    def st_centroid
      GeographicItem.where(id:).pick(Arel.sql("ST_AsEWKT(ST_Centroid(#{GeographicItem::GEOMETRY_SQL.to_sql}))")).gsub(/SRID=\d*;/, '')
    end

    # @return [Integer]
    #   the number of points in the geometry
    def st_npoints
      GeographicItem.where(id:).pick(Arel.sql("ST_NPoints(#{GeographicItem::GEOMETRY_SQL.to_sql}) as npoints"))
    end

    # !!TODO: migrate these to use native column calls

    # @param [geo_object]
    # @return [Boolean]
    def contains?(target_geo_object)
      return nil if target_geo_object.nil?
      self.geo_object.contains?(target_geo_object)
    end

    # @param [geo_object]
    # @return [Boolean]
    def within?(target_geo_object)
      self.geo_object.within?(target_geo_object)
    end

    # @param [geo_object]
    # @return [Boolean]
    def intersects?(target_geo_object)
      self.geo_object.intersects?(target_geo_object)
    end

    # @return [GeoJSON hash]
    #    via Rgeo apparently necessary for GeometryCollection
    def rgeo_to_geo_json
      RGeo::GeoJSON.encode(geo_object).to_json
    end

    # @return [Hash]
    #   in GeoJSON format
    #   Computed via "raw" PostGIS (much faster). This
    #   requires the geo_object_type and id.
    def to_geo_json
      JSON.parse(
        GeographicItem.connection.select_one(
          "SELECT ST_AsGeoJSON(#{data_column}::geometry) a " \
          "FROM geographic_items WHERE id=#{id};"
        )['a']
      )
    end

    # @return [Hash]
    #   the shape as a GeoJSON Feature with some item metadata
    def to_geo_json_feature
      @geometry ||= to_geo_json
      {'type' => 'Feature',
       'geometry' => geometry,
       'properties' => {
         'geographic_item' => {
           'id' => id}
       }
      }
    end

    # @param value [String] like:
    #   '{"type":"Feature","geometry":{"type":"Point","coordinates":[2.5,4.0]},"properties":{"color":"red"}}'
    #
    #   '{"type":"Feature","geometry":{"type":"Polygon","coordinates":"[[[-125.29394388198853, 48.584480409793],
    #      [-67.11035013198853, 45.09937589848195],[-80.64550638198853, 25.01924647619111],[-117.55956888198853,
    #      32.5591595028449],[-125.29394388198853, 48.584480409793]]]"},"properties":{}}'
    #
    #  '{"type":"Point","coordinates":[2.5,4.0]},"properties":{"color":"red"}}'
    #
    # @return [RGeo object]
    def shape=(value)
      return if value.blank?

      begin
        geom = RGeo::GeoJSON.decode(value, json_parser: :json, geo_factory: Gis::FACTORY)
      rescue RGeo::Error::InvalidGeometry => e
        errors.add(:base, "invalid geometry: #{e.to_s}")
        return
      end

      this_type = nil

      if geom.respond_to?(:properties) && geom.properties['data_type'].present?
        this_type = geom.properties['data_type']
      elsif geom.respond_to?(:geometry_type)
        this_type = geom.geometry_type.to_s
      elsif geom.respond_to?(:geometry)
        this_type = geom.geometry.geometry_type.to_s
      else
      end

      self.type = GeographicItem.eval_for_type(this_type) unless geom.nil?

      if type.blank?
        errors.add(:base, "unrecognized geometry type '#{this_type}'")
        return
      end

      object = nil

      s = geom.respond_to?(:geometry) ? geom.geometry.to_s : geom.to_s

      begin
        object = Gis::FACTORY.parse_wkt(s)
      rescue RGeo::Error::InvalidGeometry
        errors.add(:self, 'Shape value is an Invalid Geometry')
        return
      end

      write_attribute(this_type.underscore.to_sym, object)
      geom
    end

    # @return [String]
    def to_wkt
      #  10k  #<Benchmark::Tms:0x00007fb0dfd30fd0 @label="", @real=25.237487000005785, @cstime=0.0, @cutime=0.0, @stime=1.1704609999999995, @utime=5.507929999999988, @total=6.678390999999987>
      #  GeographicItem.select("ST_AsText( #{GeographicItem::GEOMETRY_SQL.to_sql}) wkt").where(id: id).first.wkt

      # 10k <Benchmark::Tms:0x00007fb0e02f7540 @label="", @real=21.619827999995323, @cstime=0.0, @cutime=0.0, @stime=0.8850890000000007, @utime=3.2958549999999605, @total=4.180943999999961>
      if (a = ApplicationRecord.connection.execute( "SELECT ST_AsText( #{GeographicItem::GEOMETRY_SQL.to_sql} ) wkt from geographic_items where geographic_items.id = #{id}").first)
        return a['wkt']
      else
        return nil
      end
    end

    # @return  [Float] in meters, calculated
    # TODO: share with world
    #    Geographic item 96862 (Cajamar in Brazil) is the only(?) record to fail using `false` (quicker) method of everything we tested
    def area
      a = GeographicItem.where(id:).select("ST_Area(#{GeographicItem::GEOGRAPHY_SQL}, true) as area_in_meters").first['area_in_meters']
      a = nil if a.nan?
      a
    end

    # TODO: This is bad, while internal use of ONE_WEST_MEAN is consistent it is in-accurate given the vast differences of radius vs. lat/long position.
    # When we strike the error-polygon from radius we should remove this
    #
    # Use case is returning the radius from a circle we calculated via buffer for error-polygon creation.
    def radius
      r = ApplicationRecord.connection.execute( "SELECT ST_MinimumBoundingRadius( ST_Transform(  #{GeographicItem::GEOMETRY_SQL.to_sql}, 4326 )  ) AS radius from geographic_items where geographic_items.id = #{id}").first['radius'].split(',').last.chop.to_f
      r = (r * Utilities::Geo::ONE_WEST_MEAN).to_i
    end

    # Convention is to store in PostGIS in CCW
    # @return Array [Boolean]
    #   false - cw
    #   true - ccw (preferred), except see donuts
    def orientations
      if (column = multi_polygon_column)
        ApplicationRecord.connection.execute(" \
             SELECT ST_IsPolygonCCW(a.geom) as is_ccw
                FROM ( SELECT b.id, (ST_Dump(p_geom)).geom AS geom
                   FROM (SELECT id, #{column}::geometry AS p_geom FROM geographic_items where id = #{id}) AS b \
              ) AS a;").collect{|a| a['is_ccw']}
      elsif (column = polygon_column)
        ApplicationRecord.connection.execute("SELECT ST_IsPolygonCCW(#{column}::geometry) as is_ccw \
          FROM geographic_items where  id = #{id};").collect{|a| a['is_ccw']}
      else
        []
      end
    end

    # @return Boolean
    #   looks at all orientations
    #   if they follow the pattern [true, false, ... <all false>] then `true`, else `false`
    # !! Does not confirm that shapes are nested !!
    def is_basic_donut?
      a = orientations
      b = a.shift
      return false unless b
      a.uniq!
      a == [false]
    end

    def st_isvalid
      ApplicationRecord.connection.execute( "SELECT ST_IsValid(  #{GeographicItem::GEOMETRY_SQL.to_sql }) from  geographic_items where geographic_items.id = #{id}").first['st_isvalid']
    end

    def st_isvalidreason
      r = ApplicationRecord.connection.execute( "SELECT ST_IsValidReason(  #{GeographicItem::GEOMETRY_SQL.to_sql }) from  geographic_items where geographic_items.id = #{id}").first['st_isvalidreason']
    end

    # @return [Symbol, nil]
    #   the specific type of geography: :point, :multipolygon, etc. Returns
    #   the underlying shape of :geography in the :geography case
    def geo_object_type
      column = data_column

      return column == :geography ?
        geography.geometry_type.type_name.underscore.to_sym :
        column
    end

    # @return [RGeo instance, nil]
    #  the Rgeo shape (See http://rubydoc.info/github/dazuma/rgeo/RGeo/Feature)
    def geo_object
      column = data_column

      return column.nil? ? nil : send(column)
    end

    private

    # @return [Symbol]
    #   returns the attribute (column name) containing data
    #   nearly all methods should use #geo_object_type instead
    def data_column
      # This works before and after this item has been saved
      DATA_TYPES.each { |item|
        return item if send(item)
      }
      nil
    end

    def polygon_column
      geo_object_type == :polygon ? data_column : nil
    end

    def multi_polygon_column
      geo_object_type == :multi_polygon ? data_column : nil
    end

    # @param [String] shape, the type of shape you want
    # @return [String]
    #   A paren-wrapped SQL fragment for selecting the geography column
    #   containing shape. Returns the column named :shape if no shape is found.
    #   !! This should probably never be called except to be put directly in a
    #   raw ST_* statement as the parameter that matches some shape.
    def self.shape_column_sql(shape)
      st_shape = 'ST_' + shape.to_s.camelize

      '(CASE ST_GeometryType(geography::geometry) ' \
      "WHEN '#{st_shape}' THEN geography " \
      "ELSE #{shape} END)"
    end

    def align_winding
      if orientations.flatten.include?(false)
        if (column = multi_polygon_column)
          column = column.to_s
          ApplicationRecord.connection.execute(
            "UPDATE geographic_items set #{column} = ST_ForcePolygonCCW(#{column}::geometry)
              WHERE id = #{self.id};"
           )
        elsif (column = polygon_column)
          column = column.to_s
          ApplicationRecord.connection.execute(
            "UPDATE geographic_items set #{column} = ST_ForcePolygonCCW(#{column}::geometry)
              WHERE id = #{self.id};"
           )
        end
      end
      true
    end

    # Crude debuging helper, write the shapes
    # to a png
    def self.debug_draw(geographic_item_ids = [])
      return false if geographic_item_ids.empty?
      # TODO support other shapes
      sql = "SELECT ST_AsPNG(
         ST_AsRaster(
            (SELECT ST_Union(multi_polygon::geometry) from geographic_items where id IN (" + geographic_item_ids.join(',') + ")), 1920, 1080
        )
       ) png;"

      # ST_Buffer( multi_polygon::geometry, 0, 'join=bevel'),
      #     1920,
      #     1080)


      result = ActiveRecord::Base.connection.execute(sql).first['png']
      r = ActiveRecord::Base.connection.unescape_bytea(result)

      prefix = if geographic_item_ids.size > 10
                 'multiple'
               else
                 geographic_item_ids.join('_')
               end

      n = prefix + '_debug.draw.png'

      # Open the file in binary write mode ("wb")
      File.open(n, 'wb') do |file|
        # Write the binary data to the file
        file.write(r)
      end
    end

    # def png

    #   if ids = Otu.joins(:cached_map_items).first.cached_map_items.pluck(:geographic_item_id)

    #     sql = "SELECT ST_AsPNG(
    #    ST_AsRaster(
    #        ST_Buffer( multi_polygon::geometry, 0, 'join=bevel'),
    #            1024,
    #            768)
    #     ) png
    #        from geographic_items where id IN (" + ids.join(',') + ');'

    #     # hack, not the best way to unpack result
    #     result = ActiveRecord::Base.connection.execute(sql).first['png']
    #     r = ActiveRecord::Base.connection.unescape_bytea(result)

    #     send_data r, filename: 'foo.png', type: 'imnage/png'

    #   else
    #     render json: {foo: false}
    #   end
    # end

    def set_cached
      update_column(:cached_total_area, area)
    end

    # @return [Boolean, String] false if already set, or type to which it was set
    def set_type_if_shape_column_present
      if type.blank?
        column = data_column
        self.type = "GeographicItem::#{column.to_s.camelize}" if column
      end
    end

    # @return [Boolean] iff there is one and only one shape column set
    def some_data_is_provided
      data = []

      DATA_TYPES.each do |item|
        data.push(item) if send(item).present?
      end

      case data.count
      when 0
        errors.add(:base, 'No shape provided or provided shape is invalid')
      when 1
        return true
      else
        data.each do |object|
          errors.add(object, 'More than one shape type provided')
        end
      end
      false
    end
end

    #     Dir[Rails.root.to_s + '/app/models/geographic_item/**/*.rb'].each { |file| require_dependency file }
