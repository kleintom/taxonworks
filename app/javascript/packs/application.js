/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb

/* import 'core-js/stable'
import 'regenerator-runtime/runtime' */
// Styles
import 'leaflet/dist/leaflet.css'
import 'tippy.js/dist/tippy.css'

import '../vanilla/initializers/copyTable.js'
import '../vue/initializers/IssueTracker/main.js'

import '../vue/tasks/citations/otus/main.js'
import '../vue/tasks/content/editor/main.js'
import '../vue/tasks/nomenclature/new_taxon_name/main.js'
import '../vue/tasks/loans/new/main.js'
import '../vue/tasks/observation_matrices/matrix_row_coder/main.js'
import '../vue/initializers/RadialAnnotator/main.js'
import '../vue/initializers/RadialOtu/main.js'
import '../vue/initializers/ButtonOtu/main.js'
import '../vue/initializers/RadialNavigation/main.js'
import '../vue/initializers/RadialQuickForms/main.js'
import '../vue/initializers/PdfViewer/main.js'
import '../vue/initializers/ButtonConfidence/main.js'
import '../vue/initializers/ButtonTag/main.js'
import '../vue/initializers/QuickCitation/main.js'
import '../vue/initializers/BrowseNomenclature/main.js'
import '../vue/initializers/PinboardNavigator/main.js'
import '../vue/initializers/SmartSelector/main.js'
import '../vue/initializers/SoftValidations/main.js'
import '../vue/initializers/SimpleMap/main.js'
import '../vue/initializers/MapShape/main.js'
import '../vue/initializers/GraphViz/main.js'
import '../vue/initializers/WeekInReviewGraph/main.js'
import '../vue/tasks/type_specimens/main.js'
import '../vue/tasks/nomenclature/new_combination/main.js'
import '../vue/tasks/browse_annotations/main.js'
import '../vue/tasks/descriptors/new/main.js'
import '../vue/tasks/observation_matrices/new/main.js'
import '../vue/tasks/clipboard/main.js'
import '../vue/tasks/uniquify/people/main.js'
import '../vue/tasks/single_bibtex_source/main.js'
import '../vue/tasks/nomenclature/by_source/main.js'
import '../vue/tasks/people/author_by_letter/main.js'
import '../vue/tasks/collecting_events/filter/main.js'
import '../vue/tasks/digitize/main.js'
import '../vue/tasks/labels/print_labels/main.js'
import '../vue/tasks/projects/preferences/main.js'
import '../vue/tasks/asserted_distributions/new_asserted_distribution/main.js'
import '../vue/tasks/images/new_image/main.js'
import '../vue/tasks/images/filter/main.js'
import '../vue/tasks/sources/hub/main.js'
import '../vue/tasks/nomenclature/filter/main.js'
import '../vue/tasks/observation_matrices/image/main.js'
import '../vue/tasks/observation_matrices/dashboard/main.js'
import '../vue/tasks/nomenclature/stats/main.js'
import '../vue/tasks/otu/browse_asserted_distributions/main.js'
import '../vue/tasks/collection_objects/filter/main.js'
import '../vue/tasks/sources/new_source/main.js'
import '../vue/tasks/otu/browse/main.js'
import '../vue/tasks/collection_objects/slide_breakdown/main.js'
import '../vue/tasks/biological_relationships/composer/main.js'
import '../vue/tasks/nomenclature/match/main.js'
import '../vue/tasks/controlled_vocabularies/manage/main.js'
import '../vue/tasks/collection_objects/match/main.js'
import '../vue/tasks/collection_objects/browse/main.js'
import '../vue/tasks/sources/filter/main.js'
import '../vue/tasks/collecting_events/new_collecting_event/main.js'
import '../vue/tasks/interactive_keys/main.js'
import '../vue/tasks/extracts/new_extract/main.js'
import '../vue/tasks/namespaces/new_namespace/main.js'
import '../vue/data/downloads/index.js'
import '../vue/tasks/dwca_import/main.js'
import '../vue/tasks/observation_matrices/matrix_column_coder/main.js'
import '../vue/tasks/dwc/dashboard/index.js'
import '../vue/tasks/administration/data/index.js'
import '../vue/tasks/graph/object_graph/main.js'
import '../vue/tasks/controlled_vocabularies/biocurations/main.js'
import '../vue/tasks/extracts/filter/main.js'
import '../vue/tasks/otu/filter/main.js'
import '../vue/tasks/people/filter/main.js'
import '../vue/tasks/collection_objects/stepwise/determinations/main.js'
import '../vue/tasks/content/publisher/main.js'
import '../vue/tasks/collection_objects/freeform_digitize/main.js'
import '../vue/tasks/biological_associations/filter/main.js'
import '../vue/tasks/collection_objects/simple_new_specimen/index'
import '../vue/tasks/accessions/breakdown/filter/main'
import '../vue/tasks/asserted_distributions/filter/main.js'
import '../vue/tasks/descriptors/filter/main.js'
import '../vue/tasks/loans/filter/main.js'
import '../vue/tasks/observations/filter/main.js'
import '../vue/tasks/contents/filter/main.js'
import '../vue/tasks/biological_associations/biological_associations_graph/main.js'
import '../vue/tasks/biological_associations/network/main.js'
import '../vue/tasks/collecting_events/stepwise/collectors/main.js'
import '../vue/tasks/leads/new_lead/main.js'
import '../vue/tasks/leads/show/main.js'
import '../vue/tasks/field_occurrences/new_field_occurrences/main.js'
import '../vue/tasks/metadata/vocabulary/project_vocabulary/main.js'
import '../vue/tasks/otus/new_otu/main.js'
import '../vue/tasks/leads/hub/main.js'
import '../vue/tasks/data_attributes/field_synchronize/main.js'
import '../vue/tasks/containers/new_container/main.js'
import '../vue/tasks/observation_matrices/import_nexus/main.js'
import '../vue/tasks/dwc_occurrences/filter/main.js'
import '../vue/tasks/images/new_filename_depicting_image/main.js'
