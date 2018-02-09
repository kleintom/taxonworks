# require 'support/shared_contexts/geo/area_a'

RSPEC_GEO_FACTORY = Gis::FACTORY
shared_context 'stuff for complex geo tests' do

  let(:geo_user) {
    u = @user.nil? ? User.find(1) : @user
    # $user    = u
    $user_id = u.id
    u
  }
  let(:geo_project) {
    p = @project.nil? ? Project.find(1) : @project
    # $project    = p
    $project_id = p.id
    p
  }
  let(:joe) { geo_user }

  let(:country_gat) { GeographicAreaType.create!(name: 'Country', creator: geo_user, updater: geo_user) }
  let(:state_gat) { GeographicAreaType.create!(name: 'State', creator: geo_user, updater: geo_user) }
  let(:county_gat) { GeographicAreaType.create!(name: 'County', creator: geo_user, updater: geo_user) }
  let(:parish_gat) { GeographicAreaType.create!(name: 'Parish', creator: geo_user, updater: geo_user) }
  let(:planet_gat) { GeographicAreaType.create!(name: 'Planet', creator: geo_user, updater: geo_user) }
  let(:land_mass_gat) { GeographicAreaType.create!(name: 'Land Mass', creator: geo_user, updater: geo_user) }

# include_context 'stuff for area_a'

  let(:list_shape_a) {
    RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(0, 0, 0.0),
                                   RSPEC_GEO_FACTORY.point(0, 10, 0.0),
                                   RSPEC_GEO_FACTORY.point(10, 10, 0.0),
                                   RSPEC_GEO_FACTORY.point(10, 0, 0.0),
                                   RSPEC_GEO_FACTORY.point(0, 0, 0.0)])
  }

  let(:list_shape_b) {
    RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(0, 0, 0.0),
                                   RSPEC_GEO_FACTORY.point(10, 0, 0.0),
                                   RSPEC_GEO_FACTORY.point(10, -10, 0.0),
                                   RSPEC_GEO_FACTORY.point(0, -10, 0.0),
                                   RSPEC_GEO_FACTORY.point(0, 0, 0.0)])
  }

  let(:list_shape_e) {
    RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(0, 10, 0.0),
                                   RSPEC_GEO_FACTORY.point(10, 10, 0.0),
                                   RSPEC_GEO_FACTORY.point(10, -10, 0.0),
                                   RSPEC_GEO_FACTORY.point(0, -10, 0.0),
                                   RSPEC_GEO_FACTORY.point(0, 10, 0.0)])
  }


  let(:shape_a) { RSPEC_GEO_FACTORY.polygon(list_shape_a) }
  let(:shape_b) { RSPEC_GEO_FACTORY.polygon(list_shape_b) }
  let(:shape_e) { RSPEC_GEO_FACTORY.polygon(list_shape_e) }

  let(:new_box_a) { FactoryBot.create(:geographic_item_multi_polygon,
                                      multi_polygon: RSPEC_GEO_FACTORY.multi_polygon([shape_a]),
                                      creator:       geo_user,
                                      updater:       geo_user) }
  let(:new_box_b) { FactoryBot.create(:geographic_item_multi_polygon,
                                      multi_polygon: RSPEC_GEO_FACTORY.multi_polygon([shape_b]),
                                      creator:       geo_user,
                                      updater:       geo_user) }
  let(:new_box_e) { FactoryBot.create(:geographic_item_multi_polygon,
                                      multi_polygon: RSPEC_GEO_FACTORY.multi_polygon([shape_e]),
                                      creator:       geo_user,
                                      updater:       geo_user) }

  let(:earth) { FactoryBot.create(:earth_geographic_area,
                                  geographic_area_type: planet_gat,
                                  creator:              geo_user,
                                  updater:              geo_user) }

# need some areas
  begin
    let(:linestring) {
      RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(0, 0, 0.0),
                                     RSPEC_GEO_FACTORY.point(0, 10, 0.0),
                                     RSPEC_GEO_FACTORY.point(10, 10, 0.0),
                                     RSPEC_GEO_FACTORY.point(10, 0, 0.0),
                                     RSPEC_GEO_FACTORY.point(0, 0, 0.0)])
    }
    let(:line_string_a) { FactoryBot.create(:geographic_item_line_string, line_string: linestring.as_binary) }
    let(:area_linestring) {
      area = FactoryBot.create(:level0_geographic_area,
                               name:                 'linestring',
                               geographic_area_type: land_mass_gat,
                               iso_3166_a3:          nil,
                               iso_3166_a2:          nil,
                               parent:               earth)
      area.geographic_items << line_string_a
      area.save!
      area
    }
  end

  begin
    let(:polygon_outer) {
      RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(1, -1, 0.0),
                                     RSPEC_GEO_FACTORY.point(9, -1, 0.0),
                                     RSPEC_GEO_FACTORY.point(9, -9, 0.0),
                                     RSPEC_GEO_FACTORY.point(9, -1, 0.0),
                                     RSPEC_GEO_FACTORY.point(1, -1, 0.0)])
    }
    let(:polygon_inner) {
      RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(2.5, -2.5, 0.0),
                                     RSPEC_GEO_FACTORY.point(7.5, -2.5, 0.0),
                                     RSPEC_GEO_FACTORY.point(7.5, -7.5, 0.0),
                                     RSPEC_GEO_FACTORY.point(2.5, -7.5, 0.0),
                                     RSPEC_GEO_FACTORY.point(2.5, -2.5, 0.0)])
    }
    let(:polygon) { RSPEC_GEO_FACTORY.polygon(polygon_outer, [polygon_inner]) }
    let(:polygon_b) { FactoryBot.create(:geographic_item_polygon, polygon: polygon.as_binary) }

    let(:area_polygon) {
      area = FactoryBot.create(:level0_geographic_area,
                               name:                 'polygon',
                               geographic_area_type: land_mass_gat,
                               iso_3166_a3:          nil,
                               iso_3166_a2:          nil,
                               parent:               earth)
      area.geographic_items << polygon_b
      area.save!
      area
    }
  end

  begin
    let(:multipoint) {
      RSPEC_GEO_FACTORY.multi_point([polygon_inner.points[0],
                                     polygon_inner.points[1],
                                     polygon_inner.points[2],
                                     polygon_inner.points[3]])
    }
    let(:multipoint_b) { FactoryBot.create(:geographic_item_multi_point, multi_point: multipoint.as_binary) }

    let(:area_multipoint) {
      area = FactoryBot.create(:level0_geographic_area,
                               name:                 'multipoint',
                               geographic_area_type: land_mass_gat,
                               iso_3166_a3:          nil,
                               iso_3166_a2:          nil,
                               parent:               earth)
      area.geographic_items << multipoint_b
      area.save!
      area
    }
  end

  begin
    let(:multilinestring) { RSPEC_GEO_FACTORY.multi_line_string([list_shape_a, list_shape_b]) }
    let(:multilinestring_b) { FactoryBot.create(:geographic_item_multi_line_string,
                                                multi_line_string: multilinestring.as_binary) }

    let(:area_multilinestring) {
      area = FactoryBot.create(:level0_geographic_area,
                               name:                 'multilinestring',
                               geographic_area_type: land_mass_gat,
                               iso_3166_a3:          nil,
                               iso_3166_a2:          nil,
                               parent:               earth)
      area.geographic_items << multilinestring_b
      area.save!
      area
    }
  end

  begin
    let(:multipolygon) { RSPEC_GEO_FACTORY.multi_polygon([RSPEC_GEO_FACTORY.polygon(polygon_outer),
                                                          RSPEC_GEO_FACTORY.polygon(polygon_inner)]) }
    let(:multipolygon_b) { FactoryBot.create(:geographic_item_multi_polygon,
                                             multi_polygon: multipolygon.as_binary,
                                             creator:       geo_user,
                                             updater:       geo_user) }

    let(:area_multipolygon) {
      area = FactoryBot.create(:level0_geographic_area,
                               name:                 'multipolygon',
                               geographic_area_type: land_mass_gat,
                               iso_3166_a3:          nil,
                               iso_3166_a2:          nil,
                               parent:               earth,
                               creator:              geo_user,
                               updater:              geo_user)
      area.geographic_items << multipolygon_b
      area.save!
      area
    }
  end

  let(:area_e) {
    area = FactoryBot.create(:level0_geographic_area,
                             name:                 'E',
                             geographic_area_type: land_mass_gat,
                             iso_3166_a3:          nil,
                             iso_3166_a2:          nil,
                             parent:               earth,
                             creator:              geo_user,
                             updater:              geo_user)
    area.geographic_items << new_box_e
    area.save!
    area
  }

  let(:area_a) {
    area = FactoryBot.create(:level1_geographic_area,
                             name:                 'A',
                             geographic_area_type: parish_gat,
                             iso_3166_a3:          nil,
                             iso_3166_a2:          nil,
                             parent:               area_e,
                             creator:              geo_user,
                             updater:              geo_user)
    area.geographic_items << new_box_a
    area.save!
    area
  }

  let(:area_b) {
    area = FactoryBot.create(:level1_geographic_area,
                             name:                 'B',
                             geographic_area_type: parish_gat,
                             iso_3166_a3:          nil,
                             iso_3166_a2:          nil,
                             parent:               area_e,
                             creator:              geo_user,
                             updater:              geo_user)
    area.geographic_items << new_box_b
    area.save!
    area
  }

  let(:json_string) { '{"type":"Feature", "properties":{}, "geometry":{"type":"MultiPolygon", ' \
                            '"coordinates":[[[[0, 10, 0], [10, 10, 0], [10, -10, 0], [0, -10, 0], [0, 10, 0]]]]}}' }

# need some collecting events
  let(:ce_area_v) { FactoryBot.create(:collecting_event, verbatim_label: 'ce_area_v collecting event test') }

  let(:ce_a) {
    ce = FactoryBot.create(:collecting_event,
                           start_date_year:   1971,
                           start_date_month:  1,
                           start_date_day:    1,
                           verbatim_locality: 'environs of A',
                           verbatim_label:    'Eh?',
                           geographic_area:   area_a,
                           project:           geo_project,
                           updater:           geo_user,
                           creator:           geo_user)
    ce.reload
    ce
  }

  let(:ce_b) {
    ce = FactoryBot.create(:collecting_event,
                           start_date_year:   1982,
                           start_date_month:  2,
                           start_date_day:    2,
                           verbatim_locality: 'environs of B',
                           verbatim_label:    'Bah',
                           geographic_area:   area_b,
                           project:           geo_project,
                           updater:           geo_user,
                           creator:           joe)
    # ce.save!
    # ce.reload
    ce
  }

# need some collection objects
  let(:co_a) {
    co = FactoryBot.create(:valid_collection_object,
                           created_at:       '2000/01/01',
                           updated_at:       '2000/07/01',
                           collecting_event: ce_a,
                           project:          geo_project,
                           creator:          geo_user,
                           updater:          geo_user)
    # co.reload
    o = FactoryBot.create(:valid_otu_with_taxon_name,
                          name:    'Otu_A',
                          project: geo_project,
                          creator: geo_user,
                          updater: geo_user)
    o.taxon_name.update_column(:name, 'antivitis')
    # o            = Otu.create!(name: 'Otu_A', creator: geo_user, updater: geo_user, project: geo_project)
    # tn           = Protonym.create!(name: 'antivitis', creator: geo_user, updater: geo_user, project: geo_project)
    # o.taxon_name = tn
    co.otus << o

    o = top_dog # this is o1
    o.taxon_name.taxon_name_authors << ted
    co.otus << o

    o            = by_bill
    o.taxon_name = top_dog.taxon_name
    co.otus << o

    o            = FactoryBot.create(:valid_otu, name: 'Abra',
                                     project:          geo_project,
                                     creator:          geo_user,
                                     updater:          geo_user)
    o.taxon_name = tn_abra
    o.taxon_name.taxon_name_authors << ted
    co.otus << o

    o            = FactoryBot.create(:valid_otu, name: 'Abra cadabra',
                                     project:          geo_project,
                                     creator:          geo_user,
                                     updater:          geo_user)
    t_n          = tn_cadabra
    o.taxon_name = t_n
    o.save!
    o.taxon_name.taxon_name_authors << bill
    co.otus << o
    o = FactoryBot.create(:valid_otu, name: 'Abra cadabra alakazam',
                          project:          geo_project,
                          creator:          geo_user,
                          updater:          geo_user)
    co.collecting_event.collectors << bill
    o.taxon_name = tn_alakazam

    o.taxon_name.taxon_name_authors << ted
    co.otus << o
    co
  }

  let(:co_b) {
    co = FactoryBot.create(:valid_collection_object,
                           created_at:       '2001/01/01',
                           updated_at:       '2001/07/01',
                           collecting_event: ce_b,
                           project:          geo_project,
                           creator:          geo_user,
                           updater:          geo_user)
    o  = FactoryBot.create(:valid_otu_with_taxon_name, name: 'P4',
                           project:                          geo_project,
                           creator:                          geo_user,
                           updater:                          geo_user)
    co.collecting_event.collectors << sargon
    co.collecting_event.collectors << daryl
    o.taxon_name.update_column(:name, 'beevitis')
    co.otus << o
    o            = FactoryBot.create(:valid_otu, name: 'Sargon\'s spooler',
                                     project:          geo_project,
                                     creator:          geo_user,
                                     updater:          geo_user)
    o.taxon_name = tn_spooler
    o.taxon_name.taxon_name_authors << sargon
    o.taxon_name.taxon_name_authors << daryl
    co.otus << o
    o = nuther_dog
    o.taxon_name.taxon_name_authors << bill
    o.taxon_name.taxon_name_authors << ted
    o.taxon_name.taxon_name_authors << sargon
    co.otus << o
    co
  }

  let(:co_a_otus) { co_a.otus }

  let(:abra) { co_a_otus.where(name: 'Abra').first }
  let(:otu_a) { co_a_otus.where(name: 'Otu_A').first }
  let(:cadabra) { co_a_otus.where(name: 'Abra cadabra').first }
  let(:alakazam) { co_a_otus.where('name like ?', '%alakazam%').first }

  let(:co_b_otus) { co_b.otus }

  let(:spooler) { co_b_otus.where('name like ?', '%spooler%').first }
  let(:otu_p4) { co_b_otus.where(name: 'P4').first }

  let(:p_a) { GeographicItem::Point.create(point: new_box_a.st_centroid) }
  let(:p_b) { GeographicItem::Point.create(point: new_box_b.st_centroid) }

  let(:gr_a) { FactoryBot.create(:georeference_verbatim_data,
                                 api_request:           'area_a',
                                 collecting_event:      ce_a,
                                 error_geographic_item: new_box_a,
                                 geographic_item:       p_a,
                                 creator:               geo_user,
                                 updater:               geo_user)
  }

  let(:err_b) { GeographicItem::Polygon.create(polygon: RSPEC_GEO_FACTORY.polygon(polygon_inner)) }

  let(:gr_b) { FactoryBot.create(:georeference_verbatim_data,
                                 api_request:           'area_b',
                                 collecting_event:      ce_b,
                                 error_geographic_item: err_b,
                                 geographic_item:       p_b,
                                 creator:               geo_user,
                                 updater:               geo_user)
  }

# need some people
  let(:sargon) { Person.create!(first_name: 'of Akkad', last_name: 'Sargon',
                                creator:    geo_user,
                                updater:    geo_user) }
  let(:andy) { Person.create!(first_name: 'Andy', last_name: 'Worehall', prefix: 'Non-author',
                              creator:    geo_user,
                              updater:    geo_user) }
  let(:daryl) { Person.create!(first_name: 'Daryl', last_name: 'Penfold', prefix: 'with Sargon',
                               creator:    geo_user,
                               updater:    geo_user) }
  let(:ted) { FactoryBot.create(:valid_person, last_name: 'Pomaroy', first_name: 'Ted', prefix: 'HEWIC',
                                creator:                  geo_user,
                                updater:                  geo_user) }
  let(:bill) { Person.create!(first_name: 'Bill', last_name: 'Ardson',
                              creator:    geo_user,
                              updater:    geo_user) }

# need some otus
  let(:top_dog) {
    FactoryBot.create(:valid_otu, name: 'Top Dog', taxon_name:
                                        FactoryBot.create(:valid_taxon_name,
                                                          rank_class: Ranks.lookup(:iczn, 'Family'),
                                                          name:       'Topdogidae',
                                                          project:    geo_project,
                                                          creator:    geo_user,
                                                          updater:    geo_user),
                      creator:          geo_user,
                      updater:          geo_user
    )
  }

  let(:nuther_dog) {
    FactoryBot.create(:valid_otu, name: 'Another Dog', taxon_name:
                                        FactoryBot.create(:valid_taxon_name,
                                                          rank_class: Ranks.lookup(:iczn, 'Family'),
                                                          name:       'Nutherdogidae',
                                                          project:    geo_project,
                                                          creator:    geo_user,
                                                          updater:    geo_user),
                      creator:          geo_user,
                      updater:          geo_user
    )
  }

  let(:tn_abra) { Protonym.create!(name:       'Abra',
                                   rank_class: Ranks.lookup(:iczn, 'Genus'),
                                   parent:     top_dog.taxon_name,
                                   creator:    geo_user,
                                   updater:    geo_user)
  }
  let(:tn_spooler) { Protonym.create!(name:       'spooler',
                                      rank_class: Ranks.lookup(:iczn, 'Species'),
                                      parent:     tn_abra,
                                      creator:    geo_user,
                                      updater:    geo_user)
  }
  let(:tn_cadabra) { Protonym.create!(name:                'cadabra',
                                      year_of_publication: 2017,
                                      verbatim_author:     'Bill Ardson',
                                      rank_class:          Ranks.lookup(:iczn, 'Species'),
                                      parent:              tn_abra,
                                      creator:             geo_user,
                                      updater:             geo_user)
  }
  let(:tn_alakazam) { Protonym.create!(name:       'alakazam',
                                       rank_class: Ranks.lookup(:iczn, 'Subspecies'),
                                       parent:     tn_cadabra,
                                       creator:    geo_user,
                                       updater:    geo_user)
  }

  let(:by_bill) { FactoryBot.create(:valid_otu, name: 'Top Dog (by Bill)', taxon_name: top_dog.taxon_name,
                                    creator:          geo_user,
                                    updater:          geo_user) }

  begin # for GeographicItem interaction
    let(:all_items) { FactoryBot.create(:geographic_item_geometry_collection,
                                        geometry_collection: GeoBuild::ALL_SHAPES.as_binary) } # 54
    let(:outer_limits) { FactoryBot.create(:geographic_item_line_string,
                                           line_string: GeoBuild::CONVEX_HULL.exterior_ring.as_binary) } # 55

    let(:p0) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT0.as_binary) } # 0
    let(:p1) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT1.as_binary) }
    let(:p2) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT2.as_binary) } # 2
    let(:p3) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT3.as_binary) } # 3
    let(:p4) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT4.as_binary) } # 3
    let(:p10) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT10.as_binary) } # 10 } #
    let(:p11) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT11.as_binary) } # 11 } #
    let(:p12) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT12.as_binary) } # 10 } #
    let(:p13) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT13.as_binary) } # 10 } #
    let(:p14) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT14.as_binary) } # 14 } #
    let(:p16) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT16.as_binary) } # 16 } #
    let(:p17) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT17.as_binary) } # 17
    let(:p18) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT18.as_binary) } # 17
    let(:p19) { FactoryBot.create(:geographic_item_point, point: GeoBuild::POINT19.as_binary) } # 17

    let(:a) { FactoryBot.create(:geographic_item_line_string, line_string: GeoBuild::SHAPE_A.as_binary) } # 24 } #
    let(:b) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::SHAPE_B.as_binary) } # 27
    let(:c1) { FactoryBot.create(:geographic_item_line_string, line_string: GeoBuild::SHAPE_C1) } # 28
    let(:c2) { FactoryBot.create(:geographic_item_line_string, line_string: GeoBuild::SHAPE_C2) } # 28
    let(:c3) { FactoryBot.create(:geographic_item_line_string, line_string: GeoBuild::SHAPE_C3) } # 29
    let(:c) { FactoryBot.create(:geographic_item_multi_line_string,
                                multi_line_string: GeoBuild::SHAPE_C.as_binary) } # 30
    let(:d) { FactoryBot.create(:geographic_item_line_string, line_string: GeoBuild::SHAPE_D.as_binary) }
    let(:b1) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::SHAPE_B_OUTER.as_binary) } # 25
    let(:b2) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::SHAPE_B_INNER.as_binary) } # 26
    let(:e0) { e.geo_object } # a collection of polygons
    let(:e1) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::POLY_E1.as_binary) } # 35
    let(:e2) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::POLY_E2.as_binary) } # 33
    let(:e3) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::POLY_E3.as_binary) } # 34
    let(:e4) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::POLY_E4.as_binary) } # 35
    let(:e5) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::POLY_E5.as_binary) } # 35
    let(:e) { FactoryBot.create(:geographic_item_geometry_collection,
                                geometry_collection: GeoBuild::SHAPE_E.as_binary) } # 37
    let(:f1) { FactoryBot.create(:geographic_item_line_string, line_string: GeoBuild::SHAPE_F1.as_binary) } # 38
    let(:f2) { FactoryBot.create(:geographic_item_line_string, line_string: GeoBuild::SHAPE_F2.as_binary) } # 39
    # let(:f1) { f.geo_object.geometry_n(0) } #
    # let(:f2) { f.geo_object.geometry_n(1) } #
    let(:f) { FactoryBot.create(:geographic_item_multi_line_string,
                                multi_line_string: GeoBuild::SHAPE_F.as_binary) } # 40
    let(:g1) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::SHAPE_G1.as_binary) } # 41
    let(:g2) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::SHAPE_G2.as_binary) } # 42
    let(:g3) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::SHAPE_G3.as_binary) } # 43
    let(:g) { FactoryBot.create(:geographic_item_multi_polygon,
                                multi_polygon: GeoBuild::SHAPE_G.as_binary) } # 44
    let(:h) { FactoryBot.create(:geographic_item_multi_point, multi_point: GeoBuild::SHAPE_H.as_binary) } # 45
    let(:j) { FactoryBot.create(:geographic_item_geometry_collection, geometry_collection: GeoBuild::SHAPE_J) } # 47
    let(:k) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::SHAPE_K.as_binary) }
    let(:l) { FactoryBot.create(:geographic_item_line_string, line_string: GeoBuild::SHAPE_L.as_binary) } # 49 } #

    let(:r2020) { FactoryBot.create(:geographic_item_point, point: GeoBuild::ROOM2020.as_binary) } # 50
    let(:r2022) { FactoryBot.create(:geographic_item_point, point: GeoBuild::ROOM2022.as_binary) } # 51
    let(:r2024) { FactoryBot.create(:geographic_item_point, point: GeoBuild::ROOM2024.as_binary) } # 52
    let(:rooms) { FactoryBot.create(:geographic_item_multi_point, multi_point: GeoBuild::ROOMS20NN.as_binary) } # 53

    let(:shapeE1) { e0.geometry_n(0) } #
    let(:shapeE2) { e0.geometry_n(1) } #
    let(:shapeE3) { e0.geometry_n(2) } #
    let(:shapeE4) { e0.geometry_n(3) } #
    let(:shapeE5) { e0.geometry_n(4) } #

    let(:r) { a.geo_object.intersection(p16.geo_object) } #
    let(:p16_on_a) { GeoBuild::P16_ON_A } #

    let(:item_a) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::BOX_1) } # 57
    let(:item_b) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::BOX_2) } # 58
    let(:item_c) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::BOX_3) } # 59
    let(:item_d) { FactoryBot.create(:geographic_item_polygon, polygon: GeoBuild::BOX_4) } # 60

    b = FactoryBot.build(:geographic_item_polygon, polygon: GeoBuild::SHAPE_B.as_binary) # 27

    let(:ce_p1) { FactoryBot.create(:collecting_event, verbatim_label: '@ce_p1 collect_event test') }

    let(:gr01) { FactoryBot.create(:georeference_verbatim_data,
                                   api_request:           'gr01',
                                   collecting_event:      ce_p1,
                                   error_geographic_item: k,
                                   geographic_item:       p1) } #  3

    let(:gr11) { FactoryBot.create(:georeference_verbatim_data,
                                   api_request:           'gr11',
                                   error_geographic_item: e1,
                                   collecting_event:      ce_p1,
                                   geographic_item:       p11) } #  4

    let(:ce_p2) { FactoryBot.create(:collecting_event, verbatim_label: '@ce_p2 collect_event test') }
    let(:gr02) { FactoryBot.create(:georeference_verbatim_data,
                                   api_request:           'gr02',
                                   collecting_event:      ce_p2,
                                   error_geographic_item: k,
                                   geographic_item:       p2) }
    let(:gr121) { FactoryBot.create(:georeference_verbatim_data,
                                    api_request:           'gr121',
                                    collecting_event:      ce_p2,
                                    error_geographic_item: e1,
                                    geographic_item:       p12) }

    let(:ce_p3) { FactoryBot.create(:collecting_event, verbatim_label: '@ce_p3 collect_event test') }
    let(:gr03) { FactoryBot.create(:georeference_verbatim_data,
                                   api_request:           'gr03',
                                   collecting_event:      ce_p3,
                                   error_geographic_item: k,
                                   geographic_item:       p3) }
    let(:gr13) { FactoryBot.create(:georeference_verbatim_data,
                                   api_request:           'gr13',
                                   collecting_event:      ce_p3,
                                   error_geographic_item: e2,
                                   geographic_item:       p13) }

    let(:ce_n3) { FactoryBot.create(:collecting_event,
                                    start_date_year:   1982,
                                    start_date_month:  2,
                                    start_date_day:    2,
                                    end_date_year:     1984,
                                    end_date_month:    9,
                                    end_date_day:      15,
                                    verbatim_locality: 'Greater Boxia Lake',
                                    verbatim_label:    '@ce_n3',
                                    geographic_area:   area_n3) }
    let(:gr_n3) { FactoryBot.create(:georeference_verbatim_data,
                                    api_request:           'gr_n3',
                                    collecting_event:      ce_n3,
                                    error_geographic_item: item_n3,
                                    geographic_item:       GeographicItem.new(point: item_n3.st_centroid)) }
    let(:co_n3) { FactoryBot.create(:valid_collection_object, {collecting_event: ce_n3}) }

  end
# before {
#   # @user exists as a result of `sign_in_and _select_project` (i.e., a feature test), othewise nil
#   if @user
#     simple_world(@user.id, @project.id)
#   else
#     simple_world
#   end
# }

# need user and project
#   let(:user) { User.find(1) }
#   let(:project) { Project.find(1) }

# need some people
#   let(:sargon) { Person.where(first_name: 'of Akkad', last_name: 'Sargon').first }
#   let(:andy) { Person.where(first_name: 'Andy', last_name: 'Worehall', prefix: 'Non-author').first }
#   let(:daryl) { Person.where(first_name: 'Daryl', last_name: 'Penfold', prefix: 'with Sargon').first }
#   let(:ted) { Person.where(last_name: 'Pomaroy', first_name: 'Ted', prefix: 'HEWIC').first }
#   let(:bill) { Person.where(first_name: 'Bill', last_name: 'Ardson').first }

# need some otus
#   let(:top_dog) { Otu.where(name: 'Top Dog').first }
#   let(:nuther_dog) { Otu.where(name: 'Another Dog').first }
#   let(:spooler) { Otu.where('name like ?', '%spooler%').first }
#   let(:otu_p4) { Otu.where(name: 'P4').first }
#   let(:by_bill) { Otu.where('name like ?', '%by Bill%').first }
#   let(:otu_a) { Otu.where(name: 'Otu_A').first }
#   let(:abra) { Otu.where(name: 'Abra').first }
#   let(:cadabra) { Otu.where('name like ?', '%cadabra%').first }
#   let(:alakazam) { Otu.where('name like ?', '%alakazam%').first }

# need some areas
#   let(:area_linestring) { GeographicArea.where(name: 'linestring').first }
#   let(:area_polygon) { GeographicArea.where(name: 'polygon').first }
#   let(:area_multipoint) { GeographicArea.where(name: 'multipoint').first }
#   let(:area_multilinestring) { GeographicArea.where(name: 'multilinestring').first }
#   let(:area_multipolygon) { GeographicArea.where(name: 'multipolygon').first }
# let(:area_a) { GeographicArea.where(name: 'A').first }
# let(:area_b) { GeographicArea.where(name: 'B').first }
# let(:area_e) { GeographicArea.where(name: 'E').first }
# let(:json_string) { '{"type":"Feature", "properties":{}, "geometry":{"type":"MultiPolygon", ' \
#                             '"coordinates":[[[[0, 10, 0], [10, 10, 0], [10, -10, 0], [0, -10, 0], [0, 10, 0]]]]}}' }

# need some collection objects
#   let(:ce_a) { CollectingEvent.where(verbatim_label: 'Eh?').first }
#   let(:co_a) {
#     object = ce_a
#     object.collection_objects.first
#   }
#
#   let(:ce_b) { CollectingEvent.where(verbatim_label: 'Bah').first }
#   let(:co_b) {
#     object = ce_b
#     object.collection_objects.first
#   }

# rubocop:disable Metrics/MethodLength
  def simple_world(user_id = 1, project_id = 1)
    # temp_user    = $user_id
    # temp_project = $project_id
    #
    # $user_id    = user_id
    # $project_id = project_id
    #
    # user    = User.find($user_id)
    # joe     = user
    # project = Project.find($project_id)

    # planet_gat = GeographicAreaType.create!(name: 'Planet')
    # gat_parish    = GeographicAreaType.create!(name: 'Parish')
    # gat_land_mass = GeographicAreaType.create!(name: 'Land Mass')
    # list_shape_a  = RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(0, 0, 0.0),
    #                                                RSPEC_GEO_FACTORY.point(0, 10, 0.0),
    #                                                RSPEC_GEO_FACTORY.point(10, 10, 0.0),
    #                                                RSPEC_GEO_FACTORY.point(10, 0, 0.0),
    #                                                RSPEC_GEO_FACTORY.point(0, 0, 0.0)])

    # list_shape_b = RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(0, 0, 0.0),
    #                                               RSPEC_GEO_FACTORY.point(10, 0, 0.0),
    #                                               RSPEC_GEO_FACTORY.point(10, -10, 0.0),
    #                                               RSPEC_GEO_FACTORY.point(0, -10, 0.0),
    #                                               RSPEC_GEO_FACTORY.point(0, 0, 0.0)])
    #
    # list_shape_e = RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(0, 10, 0.0),
    #                                               RSPEC_GEO_FACTORY.point(10, 10, 0.0),
    #                                               RSPEC_GEO_FACTORY.point(10, -10, 0.0),
    #                                               RSPEC_GEO_FACTORY.point(0, -10, 0.0),
    #                                               RSPEC_GEO_FACTORY.point(0, 10, 0.0)])
    #
    # shape_a = RSPEC_GEO_FACTORY.polygon(list_shape_a)
    # shape_b = RSPEC_GEO_FACTORY.polygon(list_shape_b)
    # shape_e = RSPEC_GEO_FACTORY.polygon(list_shape_e)

    # new_box_a = FactoryBot.create(:geographic_item, multi_polygon: RSPEC_GEO_FACTORY.multi_polygon([shape_a]))
    # new_box_b = FactoryBot.create(:geographic_item, multi_polygon: RSPEC_GEO_FACTORY.multi_polygon([shape_b]))
    # new_box_e = FactoryBot.create(:geographic_item, multi_polygon: RSPEC_GEO_FACTORY.multi_polygon([shape_e]))

    # earth = FactoryBot.create(:earth_geographic_area,
    #                           geographic_area_type: planet_gat)

    # begin
    #   linestring    = RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(0, 0, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(0, 10, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(10, 10, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(10, 0, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(0, 0, 0.0)])
    #   line_string_a = FactoryBot.build(:geographic_item_line_string, line_string: linestring.as_binary)
    #
    #   area_linestring = FactoryBot.create(:level0_geographic_area,
    #                                       name:                 'linestring',
    #                                       geographic_area_type: gat_land_mass,
    #                                       iso_3166_a3:          nil,
    #                                       iso_3166_a2:          nil,
    #                                       parent:               earth)
    #   area_linestring.geographic_items << line_string_a
    #   area_linestring.save!
    # end
    #
    # begin
    #   polygon_outer = RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(1, -1, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(9, -1, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(9, -9, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(9, -1, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(1, -1, 0.0)])
    #
    #   polygon_inner = RSPEC_GEO_FACTORY.line_string([RSPEC_GEO_FACTORY.point(2.5, -2.5, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(7.5, -2.5, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(7.5, -7.5, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(2.5, -7.5, 0.0),
    #                                                  RSPEC_GEO_FACTORY.point(2.5, -2.5, 0.0)])
    #   polygon       = RSPEC_GEO_FACTORY.polygon(polygon_outer, [polygon_inner])
    #   polygon_b     = FactoryBot.build(:geographic_item_polygon, polygon: polygon.as_binary)
    #
    #   area_polygon = FactoryBot.create(:level0_geographic_area,
    #                                    name:                 'polygon',
    #                                    geographic_area_type: gat_land_mass,
    #                                    iso_3166_a3:          nil,
    #                                    iso_3166_a2:          nil,
    #                                    parent:               earth)
    #   area_polygon.geographic_items << polygon_b
    #   area_polygon.save!
    # end
    #
    # begin
    #   multipoint   = RSPEC_GEO_FACTORY.multi_point([polygon_inner.points[0],
    #                                                 polygon_inner.points[1],
    #                                                 polygon_inner.points[2],
    #                                                 polygon_inner.points[3]])
    #   multipoint_b = FactoryBot.build(:geographic_item_multi_point, multi_point: multipoint.as_binary)
    #
    #   area_multipoint = FactoryBot.create(:level0_geographic_area,
    #                                       name:                 'multipoint',
    #                                       geographic_area_type: gat_land_mass,
    #                                       iso_3166_a3:          nil,
    #                                       iso_3166_a2:          nil,
    #                                       parent:               earth)
    #   area_multipoint.geographic_items << multipoint_b
    #   area_multipoint.save!
    # end
    #
    # begin
    #   multilinestring   = RSPEC_GEO_FACTORY.multi_line_string([list_shape_a, list_shape_b])
    #   multilinestring_b = FactoryBot.build(:geographic_item_multi_line_string,
    #                                        multi_line_string: multilinestring.as_binary)
    #
    #   area_multilinestring = FactoryBot.create(:level0_geographic_area,
    #                                            name:                 'multilinestring',
    #                                            geographic_area_type: gat_land_mass,
    #                                            iso_3166_a3:          nil,
    #                                            iso_3166_a2:          nil,
    #                                            parent:               earth)
    #   area_multilinestring.geographic_items << multilinestring_b
    #   area_multilinestring.save!
    # end
    #
    # begin
    #   multipolygon   = RSPEC_GEO_FACTORY.multi_polygon([RSPEC_GEO_FACTORY.polygon(polygon_outer),
    #                                                     RSPEC_GEO_FACTORY.polygon(polygon_inner)])
    #   multipolygon_b = FactoryBot.create(:geographic_item_multi_polygon, multi_polygon: multipolygon.as_binary)
    #
    #   area_multipolygon = FactoryBot.create(:level0_geographic_area,
    #                                         name:                 'multipolygon',
    #                                         geographic_area_type: gat_land_mass,
    #                                         iso_3166_a3:          nil,
    #                                         iso_3166_a2:          nil,
    #                                         parent:               earth)
    #   area_multipolygon.geographic_items << multipolygon_b
    #   area_multipolygon.save!
    # end
    #
    # area_e = FactoryBot.create(:level0_geographic_area,
    #                            name:                 'E',
    #                            geographic_area_type: gat_land_mass,
    #                            iso_3166_a3:          nil,
    #                            iso_3166_a2:          nil,
    #                            parent:               earth)
    # area_e.geographic_items << new_box_e
    # area_e.save!
    #
    # area_a = FactoryBot.create(:level1_geographic_area,
    #                            name:                 'A',
    #                            geographic_area_type: gat_parish,
    #                            iso_3166_a3:          nil,
    #                            iso_3166_a2:          nil,
    #                            parent:               area_e)
    # area_a.geographic_items << new_box_a
    # area_a.save!

    # area_b = FactoryBot.create(:level1_geographic_area,
    #                            name:                 'B',
    #                            geographic_area_type: gat_parish,
    #                            iso_3166_a3:          nil,
    #                            iso_3166_a2:          nil,
    #                            parent:               area_e)
    # area_b.geographic_items << new_box_b
    # area_b.save!

    # ce_a = FactoryBot.create(:collecting_event,
    #                          start_date_year:   1971,
    #                          start_date_month:  1,
    #                          start_date_day:    1,
    #                          verbatim_locality: 'environs of A',
    #                          verbatim_label:    'Eh?',
    #                          geographic_area:   area_a)

    # co_a = FactoryBot.create(:valid_collection_object,
    #                          created_at:       '2000/01/01',
    #                          updated_at:       '2000/07/01',
    #                          collecting_event: ce_a)

    # gr_a = FactoryBot.create(:georeference_verbatim_data,
    #                          api_request:           'area_a',
    #                          collecting_event:      ce_a,
    #                          error_geographic_item: new_box_a,
    #                          geographic_item:       GeographicItem.new(point: new_box_a.st_centroid))

    # ce_b = FactoryBot.create(:collecting_event,
    #                          start_date_year:   1982,
    #                          start_date_month:  2,
    #                          start_date_day:    2,
    #                          verbatim_locality: 'environs of B',
    #                          verbatim_label:    'Bah',
    #                          geographic_area:   area_b,
    #                          creator:           joe,
    #                          updater:           user,
    #                          project:           project)

    # co_b = FactoryBot.create(:valid_collection_object,
    #                          created_at:       '2001/01/01',
    #                          updated_at:       '2001/07/01',
    #                          collecting_event: ce_b)

    # gr_b = FactoryBot.create(:georeference_verbatim_data,
    #                          api_request:           'area_b',
    #                          collecting_event:      ce_b,
    #                          error_geographic_item: new_box_b,
    #                          geographic_item:       GeographicItem.new(point: new_box_b.st_centroid))

    # sargon = Person.create!(first_name: 'of Akkad', last_name: 'Sargon')
    # andy   = Person.create!(first_name: 'Andy', last_name: 'Worehall', prefix: 'Non-author')
    # daryl  = Person.create!(first_name: 'Daryl', last_name: 'Penfold', prefix: 'with Sargon')
    # ted    = FactoryBot.create(:valid_person, last_name: 'Pomaroy', first_name: 'Ted', prefix: 'HEWIC')
    # bill   = Person.create!(first_name: 'Bill', last_name: 'Ardson')

    # top_dog = FactoryBot.create(:valid_otu, name: 'Top Dog', taxon_name:
    #                                               FactoryBot.create(:valid_taxon_name,
    #                                                                 rank_class: Ranks.lookup(:iczn, 'Family'),
    #                                                                 name:       'Topdogidae')
    # )

    # nuther_dog = FactoryBot.create(:valid_otu, name: 'Another Dog', taxon_name:
    #                                                  FactoryBot.create(:valid_taxon_name,
    #                                                                    rank_class: Ranks.lookup(:iczn, 'Family'),
    #                                                                    name:       'Nutherdogidae')
    # )
    #
    # tn_abra = Protonym.create!(name:       'Abra',
    #                            rank_class: Ranks.lookup(:iczn, 'Genus'),
    #                            parent:     top_dog.taxon_name)
    #
    # tn_spooler = Protonym.create!(name:       'spooler',
    #                               rank_class: Ranks.lookup(:iczn, 'Species'),
    #                               parent:     tn_abra)
    #
    # tn_cadabra  = Protonym.create!(name:                'cadabra',
    #                                year_of_publication: 2017,
    #                                verbatim_author:     'Bill Ardson',
    #                                rank_class:          Ranks.lookup(:iczn, 'Species'),
    #                                parent:              tn_abra)
    # tn_alakazam = Protonym.create!(name:       'alakazam',
    #                                rank_class: Ranks.lookup(:iczn, 'Subspecies'),
    #                                parent:     tn_cadabra)

    # by_bill = FactoryBot.create(:valid_otu, name: 'Top Dog (by Bill)', taxon_name: top_dog.taxon_name)

    # o = FactoryBot.create(:valid_otu_with_taxon_name, name: 'Otu_A')
    # o.taxon_name.update_column(:name, 'antivitis')
    # co_a.otus << o
    #
    # o = top_dog # this is o1
    # o.taxon_name.taxon_name_authors << ted
    # co_a.otus << o
    #
    # o            = by_bill
    # o.taxon_name = top_dog.taxon_name
    # co_a.otus << o
    #
    # o            = FactoryBot.create(:valid_otu, name: 'Abra')
    # o.taxon_name = tn_abra
    # o.taxon_name.taxon_name_authors << ted
    # co_a.otus << o
    #
    # o            = FactoryBot.create(:valid_otu, name: 'Abra cadabra')
    # t_n          = tn_cadabra
    # o.taxon_name = t_n
    # o.save!
    # o.taxon_name.taxon_name_authors << bill
    # co_a.otus << o
    # o = FactoryBot.create(:valid_otu, name: 'Abra cadabra alakazam')
    # co_a.collecting_event.collectors << bill
    # o.taxon_name = tn_alakazam
    #
    # o.taxon_name.taxon_name_authors << ted
    # co_a.otus << o
    # o.taxon_name
    #
    # o = FactoryBot.create(:valid_otu_with_taxon_name, name: 'P4')
    # co_b.collecting_event.collectors << sargon
    # co_b.collecting_event.collectors << daryl
    # o.taxon_name.update_column(:name, 'beevitis')
    # co_b.otus << o
    # o            = FactoryBot.create(:valid_otu, name: 'Sargon\'s spooler')
    # o.taxon_name = tn_spooler
    # o.taxon_name.taxon_name_authors << sargon
    # o.taxon_name.taxon_name_authors << daryl
    # co_b.otus << o
    # o = nuther_dog
    # o.taxon_name.taxon_name_authors << bill
    # o.taxon_name.taxon_name_authors << ted
    # o.taxon_name.taxon_name_authors << sargon
    # co_b.otus << o

    # $user_id    = temp_user
    # $project_id = temp_project
  end
  # rubocop:enable Metrics/MethodLength
end
