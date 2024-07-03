require 'rails_helper'
require 'support/shared_contexts/shared_geo'

describe GeographicItem::Geography, type: :model, group: [:geo, :shared_geo] do
  include_context 'stuff for geography tests' # spec/support/shared_contexts/shared_geo_for_geography.rb

  # the pattern `before { [s1, s2, ...].each }` is to instantiate variables
  # that have been `let` (not `let!`) by referencing them using [...].each.

  # TODO add some geometry_collection specs

  let(:geographic_item) { GeographicItem.new }

  context 'can hold any' do
    specify 'point' do
      expect(simple_point.geo_object_type).to eq(:point)
    end

    specify 'line_string' do
      expect(simple_line_string.geo_object_type).to eq(:line_string)
    end

    specify 'polygon' do
      expect(simple_polygon.geo_object_type).to eq(:polygon)
    end

    specify 'multi_point' do
      expect(simple_multi_point.geo_object_type).to eq(:multi_point)
    end

    specify 'multi_line_string' do
      expect(simple_multi_line_string.geo_object_type).to eq(:multi_line_string)
    end

    specify 'multi_polygon' do
      expect(simple_multi_polygon.geo_object_type).to eq(:multi_polygon)
    end

    specify 'geometry_collection' do
      expect(simple_geometry_collection.geo_object_type)
        .to eq(:geometry_collection)
    end
  end

  # Note these all use geography as the shape column via
  # "data_type":"geography" in the properties hash
  context 'construction via #shape=' do
    let(:geo_json) {
      '{
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [10, 10]
        },
        "properties": {
          "data_type":"geography",
          "name": "Sample Point",
          "description": "This is a sample point feature."
        }
      }'
    }

    let(:geo_json2) {
      '{
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [20, 20]
        },
        "properties": {
          "data_type":"geography",
          "name": "Sample Point",
          "description": "This is a sample point feature."
        }
      }'
    }
    specify 'geojson with properties: data_type: geography assigns to ' \
      'geography column' do
      geographic_item.shape = '{"type":"Feature","geometry":{"type":"Point",' \
      '"coordinates":[-88.09681320155505,40.461195702960666]},' \
      '"properties":{"data_type":"geography", "name":"Paxton City Hall"}}'
      expect(geographic_item.geography).to be_truthy
    end

    specify '#shape=' do
      g = GeographicItem.new(shape: geo_json)
      expect(g.save).to be_truthy
    end

    specify '#shape= 2' do
      g = GeographicItem.create!(shape: geo_json)
      g.update!(shape: geo_json2)
      expect(g.reload.geo_object.to_s).to match(/20/)
    end

    specify '#shape= bad linear ring' do
      bad = '{
        "type": "Feature",
        "geometry": {
          "type": "Polygon",
          "coordinates": [
            [
              [-80.498221, 25.761437],
              [-80.498221, 25.761959],
              [-80.498221, 25.761959],
              [-80.498221, 25.761437]
            ]
          ]
        },
        "properties": {"data_type":"geography"}
      }'

      g = GeographicItem.new(shape: bad)
      g.valid?
      expect(g.errors[:base]).to be_present
    end

    specify 'for polygon' do
      geographic_item.shape = '{"type":"Feature","geometry":{"type":"Polygon",' \
        '"coordinates":[[[-90.25122106075287,38.619731572825145],[-86.12036168575287,39.77758382625017],' \
        '[-87.62384042143822,41.89478088863241],[-90.25122106075287,38.619731572825145]]]},"properties":{"data_type":"geography"}}'
      expect(geographic_item.valid?).to be_truthy
    end

    specify 'for linestring' do
      geographic_item.shape =
        '{"type":"Feature","geometry":{"type":"LineString","coordinates":[' \
        '[-90.25122106075287,38.619731572825145],' \
        '[-86.12036168575287,39.77758382625017],' \
        '[-87.62384042143822,41.89478088863241]]},' \
        '"properties":{"data_type":"geography"}}'
      expect(geographic_item.valid?).to be_truthy
    end

    specify 'for "circle"' do
      geographic_item.shape = '{"type":"Feature","geometry":{"type":"Point",' \
        '"coordinates":[-88.09681320155505,40.461195702960666]},' \
        '"properties":{"data_type":"geography","radius":1468.749413840412,' \
        '"name":"Paxton City Hall"}}'
      expect(geographic_item.valid?).to be_truthy
    end
  end

  context '#geo_object_type gives underlying shape' do
    specify '#geo_object_type' do
      expect(geographic_item).to respond_to(:geo_object_type)
    end

    specify '#geo_object_type when item not saved' do
      geographic_item.point = simple_shapes[:point]
      expect(geographic_item.geo_object_type).to eq(:point)
    end
  end

  context 'validation' do
    specify 'some data must be provided' do
      geographic_item.valid?
      expect(geographic_item.errors[:base]).to be_present
    end

    specify 'invalid data for point is invalid' do
      geographic_item.point = 'Some string'
      expect(geographic_item.valid?).to be_falsey
    end

    specify 'a valid point is valid' do
      expect(simple_point.valid?).to be_truthy
    end

    specify "a good point didn't change on creation" do
      expect(simple_point.geography.x).to eq 10
    end

    specify 'a point, when provided, has a legal geography' do
      geographic_item.geography = simple_rgeo_point
      expect(geographic_item.valid?).to be_truthy
    end

    specify 'geography can change shape' do
      simple_point.geography = simple_polygon.geography
      expect(simple_point.valid?).to be_truthy
      expect(simple_point.geo_object_type).to eq(:polygon)
    end
  end

  context '#geo_object' do
    before {
      geographic_item.geography = simple_rgeo_point
    }

    specify '#geo_object returns stored data' do
      geographic_item.save!
      expect(geographic_item.geo_object).to eq(simple_rgeo_point)
    end

    specify '#geo_object returns stored db data' do
      geographic_item.save!
      geo_id = geographic_item.id
      expect(GeographicItem.find(geo_id).geo_object).to eq geographic_item.geo_object
    end
  end

  context 'instance methods' do
    specify '#geo_object' do
      expect(geographic_item).to respond_to(:geo_object)
    end

    specify '#contains? - to see if one object is contained by another.' do
      expect(geographic_item).to respond_to(:contains?)
    end

    specify '#within? -  to see if one object is within another.' do
      expect(geographic_item).to respond_to(:within?)
    end

    specify '#contains? if one object is inside the area defined by the other' do
      expect(donut.contains?(donut_interior_point.geo_object)).to be_truthy
    end

    specify '#contains? if one object is outside the area defined by the other' do
      expect(donut.contains?(distant_point.geo_object)).to be_falsey
    end

    specify '#st_centroid returns a lat/lng of the centroid of the GeoObject' do
      simple_polygon.save!
      expect(simple_polygon.st_centroid).to eq('POINT(5 5)')
    end
  end

  context 'class methods' do

    specify '::within_radius_of_item' do
        expect(GeographicItem).to respond_to(:within_radius_of_item)
      end

    specify '::intersecting method' do
      expect(GeographicItem).to respond_to(:intersecting)
    end

    context '::superset_of_union_of - return objects containing the union of the
             given objects' do
      before(:each) {
        [donut, donut_hole_point, donut_interior_point,
         donut_left_interior_edge_point].each
      }

      specify 'find the polygon containing the point' do
        expect(GeographicItem.superset_of_union_of(
          donut_interior_point.id
        ).to_a).to contain_exactly(donut)
      end

      specify 'find the polygon containing two points' do
        expect(GeographicItem.superset_of_union_of(
          donut_interior_point.id, donut_left_interior_edge_point.id
        ).to_a).to contain_exactly(donut)
      end

      specify 'a polygon covers its edge' do
        expect(GeographicItem.superset_of_union_of(
          donut_bottom_and_left_interior_edges.id
        ).to_a).to contain_exactly(donut)
      end

      specify "donut doesn't contain point in donut hole" do
        expect(
          GeographicItem.superset_of_union_of(
            donut_hole_point.id
        ).to_a).to eq([])
      end

      specify 'find that shapes contain their vertices' do
        vertex = FactoryBot.create(:geographic_item_geography,
          geography: donut_left_interior_edge.geo_object.start_point)

        expect(GeographicItem.superset_of_union_of(
          vertex.id
        ).to_a).to contain_exactly(donut_left_interior_edge, donut)
      end
    end

    context '::within_union_of' do
      before { [donut_bottom_and_left_interior_edges,
        donut_interior_point, donut_hole_point,
        donut_left_interior_edge].each
      }

      specify 'a shape is within_union_of itself' do
        expect(
          GeographicItem.where(
            GeographicItem.subset_of_union_of_sql(donut.id)
          ).to_a
        ).to include(donut)
      end

      specify 'finds the shapes covered by a polygon' do
        expect(
          GeographicItem.where(
            GeographicItem.subset_of_union_of_sql(donut.id)
          ).to_a
        ).to contain_exactly(donut, donut_bottom_and_left_interior_edges,
          donut_interior_point, donut_left_interior_edge)
      end

      specify 'returns duplicates' do
        duplicate_point = FactoryBot.create(:geographic_item_geography,
          geography: box_centroid.geo_object)

        expect(
          GeographicItem.where(
            GeographicItem.subset_of_union_of_sql(box.id)
          ).to_a
        ).to contain_exactly(box_centroid, duplicate_point, box)
      end
    end

    context '::st_covers - returns objects of a given shape which contain one
             or more given objects' do
      before { [donut, donut_left_interior_edge,
                donut_bottom_and_left_interior_edges,
                donut_rectangle_multi_polygon,
                box, box_rectangle_union
              ].each }

      specify 'includes self when self is of the right shape' do
        expect(GeographicItem.st_covers('multi_line_string',
          [donut_bottom_and_left_interior_edges]).to_a)
        .to include(donut_bottom_and_left_interior_edges)
      end

      specify 'a shape that covers two input shapes is only returned once' do
        expect(GeographicItem.st_covers('polygon',
          [box_centroid, box_horizontal_bisect_line]).to_a)
        # box and box_rectangle_union contain both inputs
        .to contain_exactly(
          box, rectangle_intersecting_box, box_rectangle_union
        )
      end

      specify 'includes shapes that cover part of their boundary' do
        expect(GeographicItem.st_covers('any',
          [donut_left_interior_edge]).to_a)
        .to contain_exactly(donut_left_interior_edge,
          donut_bottom_and_left_interior_edges, donut,
          donut_rectangle_multi_polygon
        )
      end

      specify 'point covered by nothing is only covered by itself' do
        expect(GeographicItem.st_covers('any',
          distant_point).to_a)
        .to contain_exactly(distant_point)
      end

      # OR!
      specify 'disjoint polygons each containing an input' do
        expect(GeographicItem.st_covers('polygon',
          [donut_left_interior_edge, box_centroid]).to_a)
        .to contain_exactly(
          donut, box, rectangle_intersecting_box, box_rectangle_union
        )
      end

      specify 'works with any_line' do
        expect(GeographicItem.st_covers('any_line',
          donut_left_interior_edge_point, distant_point).to_a)
        .to contain_exactly(
          donut_left_interior_edge,
          donut_bottom_and_left_interior_edges
        )
      end

      specify 'works with any_poly' do
        expect(GeographicItem.st_covers('any_poly',
          box_centroid).to_a)
        .to contain_exactly(
          box, rectangle_intersecting_box, box_rectangle_union,
          donut_rectangle_multi_polygon
        )
      end

      specify 'works with any' do
        expect(GeographicItem.st_covers('any',
          donut_left_interior_edge_point).to_a)
        .to contain_exactly(donut_left_interior_edge_point,
          donut_left_interior_edge,
          donut_bottom_and_left_interior_edges,
          donut,
          donut_rectangle_multi_polygon
        )
      end
    end

    context '::st_covered_by - returns objects which are contained by given
             objects.' do
      before { [donut, donut_interior_point, donut_left_interior_edge_point,
                donut_left_interior_edge_point, donut_left_interior_edge,
                donut_bottom_and_left_interior_edges,
                box, box_centroid, box_horizontal_bisect_line,
                rectangle_intersecting_box, box_rectangle_intersection_point,
                donut_rectangle_multi_polygon].each }

      specify 'object of the right shape is st_covered_by itself' do
        expect(GeographicItem.st_covered_by('multi_line_string',
            [donut_bottom_and_left_interior_edges]).to_a)
          .to include(donut_bottom_and_left_interior_edges)
      end

      specify 'includes shapes which are a boundary component of an input' do
        expect(GeographicItem.st_covered_by('line_string',
          donut).to_a)
        .to contain_exactly(donut_left_interior_edge)
      end

      specify 'a point only covers itself' do
        expect(GeographicItem.st_covered_by('any',
          donut_left_interior_edge_point).to_a)
        .to eq([donut_left_interior_edge_point])
      end

      specify 'shapes contained by two shapes are only returned once' do
        expect(GeographicItem.st_covered_by('point',
          box, rectangle_intersecting_box).to_a)
        .to eq([box_centroid, box_rectangle_intersection_point])
      end

      specify 'points in separate polygons' do
        expect(GeographicItem.st_covered_by('point',
          donut, box).to_a)
        .to contain_exactly(donut_interior_point,
          donut_left_interior_edge_point, box_centroid, box_rectangle_intersection_point)
      end

      specify 'works with any_line' do
        expect(GeographicItem.st_covered_by('any_line',
          donut).to_a)
        .to contain_exactly(
          donut_left_interior_edge, donut_bottom_and_left_interior_edges
        )
      end

      specify 'works with any_poly' do
        expect(GeographicItem.st_covered_by('any_poly',
          donut_and_rectangle_geometry_collection).to_a)
        .to contain_exactly(
           donut, rectangle_intersecting_box, donut_rectangle_multi_polygon
        )
      end

      specify 'DOES NOT WORK with arbitrary geometry collection' do
        pending 'ST_Covers fails when input GeometryCollection has a line intersecting a polygon\'s interior'
        # The same test as the previous only the collection in the first
        # argument also contains a line intersecting the interior of rectangle
        expect(GeographicItem.st_covered_by('any_poly',
          fail_multi_dimen_geometry_collection).to_a)
        .to contain_exactly(
          donut, rectangle_intersecting_box, donut_rectangle_multi_polygon
        )
      end

      specify 'works with any' do
        expect(GeographicItem.st_covered_by('any',
          box_rectangle_union).to_a)
        .to contain_exactly(box_rectangle_union,
          box, rectangle_intersecting_box, box_horizontal_bisect_line,
          box_centroid, box_rectangle_intersection_point
        )
      end
    end

    context '::within_radius_of_item' do
      before { [box, box_horizontal_bisect_line, box_centroid].each }

      specify 'returns objects within a specific distance of an object' do
        # box is 20 from donut at the "equator", box_centroid is 30 from donut
        r = 25 * Utilities::Geo::ONE_WEST
        expect(
          GeographicItem.within_radius_of_item(donut.id, r)
        ).to contain_exactly(donut,
          box, box_horizontal_bisect_line
        )
      end

      # Intended?
      specify 'shape is within_radius_of itself' do
        expect(
          GeographicItem.within_radius_of_item(box_centroid.id, 100)
        ).to include(box_centroid)
      end
    end

    context '::intersecting' do
      before { [
        donut, donut_left_interior_edge,
        box, box_centroid, box_horizontal_bisect_line,
        rectangle_intersecting_box, box_rectangle_union
      ].each }

      # Intended?
      specify 'a geometry of the right shape intersects itself' do
        expect(GeographicItem.intersecting('any', distant_point.id).to_a)
          .to eq([distant_point])
      end

      specify 'works with a specific shape' do
        expect(GeographicItem.intersecting('polygon',
          box_rectangle_intersection_point.id).to_a)
          .to contain_exactly(
            box, rectangle_intersecting_box, box_rectangle_union
          )
      end

      specify 'works with multiple input shapes' do
        expect(GeographicItem.intersecting('line_string',
          [donut_left_interior_edge_point.id, box_centroid.id]).to_a)
        .to contain_exactly(
          donut_left_interior_edge, box_horizontal_bisect_line
        )
      end

      specify 'works with any' do
        expect(GeographicItem.intersecting('any',
          box_horizontal_bisect_line.id).to_a)
        .to contain_exactly(box_horizontal_bisect_line,
          box, box_centroid, rectangle_intersecting_box, box_rectangle_union
        )
      end
    end
  end
end
