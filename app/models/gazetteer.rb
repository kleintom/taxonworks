# Gazetteer allows a project to add its own named shapes to participate in
# filtering, georeferencing, etc.
#
# @!attribute geography
#   @return [RGeo::Geographic::Geography]
#   Can hold any of the RGeo geometry types point, line string, polygon,
#   multipoint, multilinestring, multipolygon.
#
# @!attribute name
#   @return [String]
#   The name of the gazetteer item
#
# @!attribute parent_id
#   @return [Integer]
#   ???
#
# @!attribute iso_3166_a2
#   @return [String]
#   Two alpha-character identification of country.
#
# @!attribute iso_3166_a3
#   @return [String]
#   Three alpha-character identification of country.
#
# @!attribute project_id
#   @return [Integer]
#   the project ID

class Gazetteer < ApplicationRecord
  include Housekeeping
  include Shared::Citations
  include Shared::Notes
  include Shared::DataAttributes
  include Shared::AlternateValues
  include Shared::IsData

  ALTERNATE_VALUES_FOR = [:name].freeze

  has_closure_tree

  belongs_to :geographic_item, inverse_of: :gazetteers

  validates :name, presence: true, length: {minimum: 1}

  accepts_nested_attributes_for :geographic_item

  # @return [Hash] of the pieces of a GeoJSON 'Feature'
  def to_geo_json_feature
    to_simple_json_feature.merge(
      properties: {
        gazetteer: {
          id:,
          tag: name
        }
      }
    )
  end

  def to_simple_json_feature
    {
      type: 'Feature',
      properties: {},
      geometry: geographic_item.to_geo_json
    }
  end

  # Assumes @gazetteer is set
  # @param [Hash] TODO describe shape of hash
  # @return A single rgeo shape containing all of the input shapes
  # Raises on error
  def self.combine_shapes_to_rgeo(shapes)
    if shapes['geojson'].blank? && shapes['wkt'].blank?
      raise TaxonWorks::Error, 'No shapes provided'
    end

    geojson_rgeo = convert_geojson_to_rgeo(shapes['geojson'])
    wkt_rgeo = convert_wkt_to_rgeo(shapes['wkt'])

    shapes = geojson_rgeo + wkt_rgeo

    combine_rgeo_shapes(shapes)
  end

  # @return [Array] of RGeo::Geographic::Projected*Impl
  # Raises RGeo::Error::InvalidGeometry on error
  def self.convert_geojson_to_rgeo(shapes)
    return [] if shapes.blank?

    rgeo_shapes = shapes.map { |shape|
      # Raises RGeo::Error::InvalidGeometry on error
      RGeo::GeoJSON.decode(
        shape, json_parser: :json, geo_factory: Gis::FACTORY
      )
    }

    rgeo_shapes.map(&:geometry)
  end

  # @return [Array] of RGeo::Geographic::Projected*Impl
  # Raises RGeo::Error::RGeoError on error
  def self.convert_wkt_to_rgeo(wkt_shapes)
    return [] if wkt_shapes.blank?

    wkt_shapes.map { |shape|
      begin
        ::Gis::FACTORY.parse_wkt(shape)
      rescue RGeo::Error::RGeoError => e
        raise e.exception("Invalid WKT: #{e.message}")
      end
    }
  end

  # @param [Array] rgeo_shapes of RGeo::Geographic::Projected*Impl
  # @return [RGeo::Geographic::Projected*Impl] A single shape combining all of the
  #   input shapes
  # Raises TaxonWorks::Error on error
  def self.combine_rgeo_shapes(rgeo_shapes)
    if rgeo_shapes.count == 1
      return rgeo_shapes[0]
    end

    # unary_union, which would be preferable here, is apparently unavailable
    # for geographic geometries
    u = rgeo_shapes[0]
    rgeo_shapes[1..].each { |s| u = u.union(s) }

    if u.nil?
      raise TaxonWorks::Error, 'Computing the union of the shapes failed'
    end

    u
  end
end
