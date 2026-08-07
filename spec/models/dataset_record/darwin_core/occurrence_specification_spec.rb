require 'rails_helper'

# These specs are "specification specs": each context targets one fixture file in
# spec/files/import_datasets/occurrences/specification/, and is written to be read
# alongside its matching example in docs/guide/import.md. Unlike occurrence_spec.rb
# (which pins down bug-driven, real-world scenarios with heavy nomenclatural setup),
# fixtures here are meant to be minimal and to isolate one documented behavior at a
# time. Keep contexts here small enough to quote in the docs almost verbatim.
describe 'DatasetRecord::DarwinCore::Occurrence, specification examples', type: :model do
  include DwcOccurrenceSpecificationHelpers

  context 'minimum required fields (occurrenceID, basisOfRecord, scientificName)' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('minimum_required_fields.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports the row' do
      expect_row_tally(results, imported: 1)
    end

    it 'creates one collection object' do
      expect(CollectionObject.count).to eq(1)
    end

    it 'creates the genus and species protonyms named in scientificName' do
      expect(TaxonName.find_by(name: 'Orotettix')).to be_an_is_protonym
      expect(TaxonName.find_by(name: 'andeanus')).to be_an_is_protonym
    end

    it 'nests the species protonym under the genus protonym' do
      expect(TaxonName.find_by(cached: 'Orotettix andeanus').parent).to eq(TaxonName.find_by(name: 'Orotettix'))
    end

    it 'creates a taxon determination linking the collection object to the species' do
      determination = CollectionObject.first.current_taxon_determination
      expect(determination.otu.taxon_name).to eq(TaxonName.find_by(cached: 'Orotettix andeanus'))
    end
  end

  context 'minimum required fields (occurrenceID, basisOfRecord, TW:TaxonDetermination:otu_id)' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @otu_with_taxon_name = Otu.create!(id: 900001, taxon_name: FactoryBot.create(:iczn_species))
      @otu_without_taxon_name = Otu.create!(id: 900002, name: 'Unidentified sp.')
      @taxon_name_count_before_import = TaxonName.count

      @import_dataset = stage_specification_file('minimum_required_fields_otu_id.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports both rows' do
      expect_row_tally(results, imported: 2)
    end

    it 'creates no new taxon names' do
      expect(TaxonName.count).to eq(@taxon_name_count_before_import)
    end

    it 'creates a taxon determination using the given OTU, with its taxon name' do
      determination = CollectionObject.first.current_taxon_determination
      expect(determination.otu).to eq(@otu_with_taxon_name)
      expect(determination.otu.taxon_name).to eq(@otu_with_taxon_name.taxon_name)
    end

    it 'creates a taxon determination using the given OTU, even without a taxon name' do
      determination = CollectionObject.second.current_taxon_determination
      expect(determination.otu).to eq(@otu_without_taxon_name)
      expect(determination.otu.taxon_name).to be_nil
    end
  end

  context 'duplicate occurrenceID' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('duplicate_occurrence_id.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports the first row and errors the second' do
      expect_row_tally(results, imported: 1, errored: 1)
    end

    it 'reports the duplicate identifier on the second row' do
      expect(row_error_messages(results.second, :identifier)).to include('spec-001 already taken')
    end

    it 'does not create a second collection object for the errored row' do
      expect(CollectionObject.count).to eq(1)
    end

    it 'does not create a second taxon determination for the errored row' do
      expect(TaxonDetermination.count).to eq(1)
    end
  end

  context 'basisOfRecord defaults' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('basis_of_record_defaults.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports blank, PreservedSpecimen, and the GBIF/case variants alike, and errors an unrecognized value' do
      expect_row_tally(results, imported: 4, errored: 1)
    end

    it 'treats a blank basisOfRecord the same as PreservedSpecimen' do
      expect(Specimen.count).to eq(4)
      expect(Lot.count).to eq(0)
    end

    it 'reformats the GBIF SCREAMING_SNAKE_CASE variant' do
      expect(results.third.status).to eq('Imported')
    end

    it 'matches case-insensitively' do
      expect(results.fourth.status).to eq('Imported')
    end

    it 'reports an unrecognized value by name' do
      expect(row_error_messages(results.fifth, :basisOfRecord))
        .to include("Only 'PreservedSpecimen', 'FossilSpecimen' or blank is allowed.")
    end
  end

  context 'FossilSpecimen, without the DwC fossil BiocurationClass present' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('fossil_specimen.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row' do
      expect_row_tally(results, errored: 1)
    end

    it 'names the missing biocuration class by its DwC URI' do
      expect(row_error_messages(results.first, :basisOfRecord))
        .to include('Biocuration class http://rs.tdwg.org/dwc/terms/FossilSpecimen is not present in project')
    end
  end

  context 'FossilSpecimen, with the DwC fossil BiocurationClass present' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      @fossil_biocuration_class = FactoryBot.create(:valid_biocuration_class, uri: DWC_FOSSIL_URI)

      @import_dataset = stage_specification_file('fossil_specimen.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports the row' do
      expect_row_tally(results, imported: 1)
    end

    it 'classifies the collection object with the fossil biocuration class' do
      expect(CollectionObject.first.biocuration_classes).to include(@fossil_biocuration_class)
    end
  end

  context 'type defaults' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('type_defaults.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports a blank type and an exact "PhysicalObject" alike, and errors anything else' do
      expect_row_tally(results, imported: 2, errored: 2)
    end

    it 'treats a blank type the same as PhysicalObject' do
      expect(results.first.status).to eq('Imported')
      expect(results.second.status).to eq('Imported')
    end

    it 'is case-sensitive, unlike basisOfRecord' do
      expect(row_error_messages(results.third, :type)).to include("Only 'PhysicalObject' or empty allowed")
    end

    it 'reports an unrecognized value by name' do
      expect(row_error_messages(results.fourth, :type)).to include("Only 'PhysicalObject' or empty allowed")
    end
  end

  context 'catalogNumber namespace mechanics' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_namespace, short_name: 'ABC', delimiter: 'NONE')

      @import_dataset = stage_specification_file('catalog_number_namespace.tsv')
    end

    after(:all) { DatabaseCleaner.clean }

    it 'stages a blank catalogNumber and an explicitly-namespaced one as Ready, and a namespace-less one as NotReady' do
      expect(@import_dataset.core_records.order(:id).pluck(:status)).to eq(%w[Ready Ready NotReady])
    end

    context 'after import' do
      let!(:results) { @import_dataset.import(5000, 100) }

      it 'only processes the two Ready rows; the NotReady row is left untouched' do
        expect_row_tally(results, imported: 2)
        expect(@import_dataset.core_records.order(:id).pluck(:status)).to eq(%w[Imported Imported NotReady])
      end

      it 'creates a CatalogNumber identifier only for the row with an explicit namespace' do
        expect(Identifier::Local::CatalogNumber.count).to eq(1)
        expect(Identifier::Local::CatalogNumber.first.namespace.short_name).to eq('ABC')
      end

      it 'computes the identifier value from the namespace short name and the catalogNumber value' do
        expect(Identifier::Local::CatalogNumber.first.cached).to eq('ABC123')
      end
    end
  end

  context 'recordNumber namespace mechanics' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_namespace, short_name: 'DEF', delimiter: 'NONE')

      @import_dataset = stage_specification_file('record_number_namespace.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors a recordNumber missing its companion namespace column, and imports one that has it' do
      expect_row_tally(results, imported: 1, errored: 1)
    end

    it "names the missing companion column, not 'recordNumber' itself" do
      expect(row_error_messages(results.first, 'TW:Namespace:recordNumber')).to include('Namespace not found')
    end

    it 'creates the RecordNumber identifier in the named namespace' do
      expect(Identifier::Local::RecordNumber.count).to eq(1)
      expect(Identifier::Local::RecordNumber.first.namespace.short_name).to eq('DEF')
    end

    it 'computes the identifier value from the namespace short name and the recordNumber value' do
      expect(Identifier::Local::RecordNumber.first.cached).to eq('DEF222')
    end
  end

  context 'recordedBy' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('recorded_by.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports both rows' do
      expect_row_tally(results, imported: 2)
    end

    it 'creates one unvetted Person for a single name' do
      expect(CollectingEvent.first.collectors.map { |p| [p.first_name, p.last_name] }).to eq([['Jane', 'Smith']])
    end

    it 'creates one unvetted Person per name in a pipe-delimited list' do
      expect(CollectingEvent.second.collectors.map { |p| [p.first_name, p.last_name] })
        .to eq([['John', 'Doe'], ['Mary', 'Jones']])
    end

    it 'stores the raw value verbatim on the collecting event regardless of how many names it parses into' do
      expect(CollectingEvent.first.verbatim_collectors).to eq('Jane Smith')
      expect(CollectingEvent.second.verbatim_collectors).to eq('John Doe | Mary Jones')
    end

    it 'creates every person as unvetted' do
      expect(Person::Unvetted.count).to eq(3)
    end
  end

  context 'individualCount' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('individual_count.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports blank, 1, and >1, and errors 0 and negative values' do
      expect_row_tally(results, imported: 3, errored: 2)
    end

    it 'treats a blank individualCount the same as 1, creating a Specimen' do
      expect(results.first.status).to eq('Imported')
      expect(CollectionObject.first).to be_a(Specimen)
    end

    it 'creates a Specimen for individualCount 1' do
      expect(CollectionObject.second).to be_a(Specimen)
    end

    it 'creates a Lot for individualCount > 1' do
      expect(CollectionObject.third).to be_a(Lot)
    end

    it 'errors on 0 and negative values' do
      expect(row_error_messages(results.fourth, :total)).to include('Must be positive.')
      expect(row_error_messages(results.fifth, :total)).to include('Must be positive.')
    end
  end

  context 'sex' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('sex.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports single-word values and errors a multi-word one' do
      expect_row_tally(results, imported: 2, errored: 1)
    end

    it 'auto-creates the Sex BiocurationGroup and a BiocurationClass for a new value' do
      group = BiocurationGroup.find_by(uri: 'http://rs.tdwg.org/dwc/terms/sex')
      expect(group).to_not be_nil
      expect(group.name).to eq('Sex')
      expect(BiocurationClass.where(name: 'male').count).to eq(1)
    end

    it 'reuses the same BiocurationClass for a repeated value rather than duplicating it' do
      expect(CollectionObject.first.biocuration_classes).to eq(CollectionObject.second.biocuration_classes)
    end

    it 'errors a multi-word value' do
      expect(row_error_messages(results.third, :sex))
        .to include('Only single-word controlled vocabulary supported at this time.')
    end
  end

  context 'preparations' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_preparation_type, name: 'pinned')

      @import_dataset = stage_specification_file('preparations.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports a matching preparation name and errors an unrecognized one' do
      expect_row_tally(results, imported: 1, errored: 1)
    end

    it 'assigns the matching PreparationType' do
      expect(CollectionObject.first.preparation_type.name).to eq('pinned')
    end

    it 'names the unrecognized value and does not create a new PreparationType for it' do
      expect(row_error_messages(results.second, :preparations))
        .to include('Unknown preparation "spread". If it is correct please add it to preparation types and retry.')
      expect(PreparationType.count).to eq(1)
    end
  end

  context 'occurrenceID reused across separate imports' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_namespace, short_name: 'CATD', delimiter: 'NONE')
      FactoryBot.create(:valid_namespace, short_name: 'RECD', delimiter: 'NONE')

      @import_a = stage_specification_file('occurrence_id_reuse_a.tsv')
      @results_a = @import_a.import(5000, 100)

      @import_b = stage_specification_file('occurrence_id_reuse_b.tsv')
      @results_b = @import_b.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports both, unlike a duplicate occurrenceID within a single import' do
      expect_row_tally(@results_a, imported: 1)
      expect_row_tally(@results_b, imported: 1)
    end

    it 'assigns each import its own occurrenceID namespace' do
      namespace_a = @import_a.get_core_record_identifier_namespace
      namespace_b = @import_b.get_core_record_identifier_namespace
      expect(namespace_a).to_not eq(namespace_b)
    end

    it 'does not confuse the two imports\' catalogNumber or recordNumber values either, since they differ' do
      expect(Identifier::Local::CatalogNumber.pluck(:cached)).to contain_exactly('CATD700', 'CATD800')
      expect(Identifier::Local::RecordNumber.pluck(:cached)).to contain_exactly('RECDRA', 'RECDRB')
    end
  end

  context 'catalogNumber namespace resolution via institutionCode/collectionCode' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      @namespace_for_pairing = FactoryBot.create(:valid_namespace, short_name: 'INHS', delimiter: 'NONE')
      @namespace_for_collection_code_alone = FactoryBot.create(:valid_namespace, short_name: 'GENERIC', delimiter: 'NONE')
      Repository.create!(name: 'Illinois Natural History Survey', acronym: 'INHS')

      @import_dataset = stage_specification_file('catalog_number_namespace_by_institution_collection_code.tsv')
      # Simulates a curator configuring the mapping table via the import task's Settings panel.
      @import_dataset.update_catalog_number_collection_code_namespace('ENT', @namespace_for_collection_code_alone.id)
      @import_dataset.update_catalog_number_namespace('INHS', 'ENT', @namespace_for_pairing.id)
      # institutionCode alone (no collectionCode at all) is its own distinct mapping key, not a third
      # fallback tier — it does not reuse the collectionCode-only mapping above.
      @import_dataset.update_catalog_number_namespace('INHS', nil, @namespace_for_pairing.id)

      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports all three rows' do
      expect_row_tally(results, imported: 3)
    end

    it 'prefers the institutionCode:collectionCode mapping over the collectionCode-only mapping' do
      expect(Identifier::Local::CatalogNumber.first.cached).to eq('INHS100')
    end

    it 'falls back to the collectionCode-only mapping when institutionCode is blank' do
      expect(Identifier::Local::CatalogNumber.second.cached).to eq('GENERIC200')
    end

    it 'resolves institutionCode alone (no collectionCode at all) via its own mapping' do
      expect(Identifier::Local::CatalogNumber.third.cached).to eq('INHS300')
    end
  end

  context 'catalogNumber must match its computed identifier verbatim' do
    context 'setting off (default)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'ABC', delimiter: 'NONE')

        @import_dataset = stage_specification_file(
          'catalog_number_verbatim_match.tsv',
          import_settings: { 'require_catalog_number_match_verbatim' => false }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports a catalogNumber given with or without its namespace prefix alike' do
        expect_row_tally(@results, imported: 2)
        expect(Identifier::Local::CatalogNumber.pluck(:cached)).to eq(%w[ABC100 ABC200])
      end
    end

    context 'setting on' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'ABC', delimiter: 'NONE')

        @import_dataset = stage_specification_file(
          'catalog_number_verbatim_match.tsv',
          import_settings: { 'require_catalog_number_match_verbatim' => true }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'errors a catalogNumber given without its namespace prefix, and imports one given with it' do
        expect_row_tally(results, imported: 1, errored: 1)
      end

      it 'names the mismatch between the computed and verbatim values' do
        expect(row_error_messages(results.first, :catalogNumber))
          .to include('Computed catalog number ABC100 will not match verbatim 100. Verify the mapped namespace and namespace delimiter are correct.')
      end
    end
  end

  context 'duplicate catalogNumber' do
    context 'within the same import' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'CAT', delimiter: 'NONE')

        @import_dataset = stage_specification_file('duplicate_catalog_number_same_import.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the first row and errors the second' do
        expect_row_tally(@results, imported: 1, errored: 1)
      end

      it "reports 'Is already in use'" do
        expect(row_error_messages(@results.second, :catalogNumber)).to include('Is already in use')
      end
    end

    context 'across separate imports' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'CAT', delimiter: 'NONE')

        @results_a = stage_specification_file('duplicate_catalog_number_import_a.tsv').import(5000, 100)
        @results_b = stage_specification_file('duplicate_catalog_number_import_b.tsv').import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'behaves exactly like the same-import case: first import succeeds, second errors' do
        expect_row_tally(@results_a, imported: 1)
        expect_row_tally(@results_b, errored: 1)
        expect(row_error_messages(@results_b.first, :catalogNumber)).to include('Is already in use')
      end
    end
  end

  context 'duplicate recordNumber' do
    context 'within the same import' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'REC', delimiter: 'NONE')

        @import_dataset = stage_specification_file('duplicate_record_number_same_import.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports both rows: a recordNumber is not required to be unique on its own, unlike catalogNumber or occurrenceID' do
        expect_row_tally(@results, imported: 2)
      end

      it 'creates two RecordNumber identifiers carrying the identical value' do
        expect(Identifier::Local::RecordNumber.pluck(:identifier)).to eq(%w[300 300])
      end
    end

    context 'across separate imports' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'REC', delimiter: 'NONE')

        @results_a = stage_specification_file('duplicate_record_number_import_a.tsv').import(5000, 100)
        @results_b = stage_specification_file('duplicate_record_number_import_b.tsv').import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports both, same as the same-import case' do
        expect_row_tally(@results_a, imported: 1)
        expect_row_tally(@results_b, imported: 1)
      end
    end
  end

  context 'containers' do
    context 'same catalogNumber, different recordNumbers' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'CAT', delimiter: 'NONE')
        FactoryBot.create(:valid_namespace, short_name: 'REC', delimiter: 'NONE')

        @import_dataset = stage_specification_file('container_different_record_numbers.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports both rows' do
        expect_row_tally(@results, imported: 2)
      end

      it 'shares one CatalogNumber identifier and creates two distinct RecordNumber identifiers' do
        expect(Identifier::Local::CatalogNumber.count).to eq(1)
        expect(Identifier::Local::RecordNumber.pluck(:identifier)).to contain_exactly('R1', 'R2')
      end

      it 'containerizes both collection objects together' do
        expect(Container.count).to eq(1)
        expect(Container.first.container_items.count).to eq(2)
      end
    end

    context 'same catalogNumber, same recordNumber' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'CAT', delimiter: 'NONE')
        FactoryBot.create(:valid_namespace, short_name: 'REC', delimiter: 'NONE')

        @import_dataset = stage_specification_file('container_duplicate_record_number.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      # recordNumber is allowed to repeat everywhere (see the 'duplicate recordNumber' context
      # above), with no carve-out for items that also share a catalogNumber. Two specimens from the
      # same collecting event (same recordNumber/field number) placed in the same physical lot (same
      # catalogNumber) is a normal scenario, not necessarily a data-entry error.
      it 'imports both rows into the same container, even though their recordNumber values are identical' do
        expect_row_tally(@results, imported: 2)
        expect(Container.count).to eq(1)
        expect(Identifier::Local::RecordNumber.pluck(:identifier)).to eq(%w[R1 R1])
      end
    end

    context 'containerize_dup_cat_no enabled, without a recordNumber' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'CAT', delimiter: 'NONE')

        @import_dataset = stage_specification_file(
          'container_no_record_number_setting_enabled.tsv',
          import_settings: { 'containerize_dup_cat_no' => true }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      # This setting's entire purpose is to allow containerizing a colliding catalogNumber without a
      # recordNumber present — the trade-off the user opts into by enabling it is that the items
      # placed in the container aren't individually identifiable by identifier afterward (they remain
      # separate, real records, just not separately numbered).
      it 'imports both rows and containerizes them, with no recordNumber to tell them apart' do
        expect_row_tally(@results, imported: 2)
        expect(Container.count).to eq(1)
        expect(Container.first.container_items.count).to eq(2)
        expect(Identifier::Local::RecordNumber.count).to eq(0)
      end
    end

    context 'containerize_dup_cat_no enabled, without a recordNumber, across separate imports' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'CAT', delimiter: 'NONE')

        @results_a = stage_specification_file(
          'container_no_record_number_setting_enabled_across_imports_a.tsv',
          import_settings: { 'containerize_dup_cat_no' => true }
        ).import(5000, 100)
        @results_b = stage_specification_file(
          'container_no_record_number_setting_enabled_across_imports_b.tsv',
          import_settings: { 'containerize_dup_cat_no' => true }
        ).import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'behaves exactly like the same-import case: both import and containerize together' do
        expect_row_tally(@results_a, imported: 1)
        expect_row_tally(@results_b, imported: 1)
        expect(Container.count).to eq(1)
        expect(Container.first.container_items.count).to eq(2)
        expect(Identifier::Local::RecordNumber.count).to eq(0)
      end
    end

    context 'spanning separate imports (with recordNumbers)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'CAT', delimiter: 'NONE')
        FactoryBot.create(:valid_namespace, short_name: 'REC', delimiter: 'NONE')

        @results_a = stage_specification_file('container_spans_imports_a.tsv').import(5000, 100)
        @results_b = stage_specification_file('container_spans_imports_b.tsv').import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports both, one row per import' do
        expect_row_tally(@results_a, imported: 1)
        expect_row_tally(@results_b, imported: 1)
      end

      it 'containerizes both collection objects together, even though they came from separate imports' do
        expect(Container.count).to eq(1)
        expect(Container.first.container_items.count).to eq(2)
      end
    end

    context 'same catalogNumber, no recordNumber, across separate imports' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'CAT', delimiter: 'NONE')

        @results_a = stage_specification_file('container_no_record_number_across_imports_a.tsv').import(5000, 100)
        @results_b = stage_specification_file('container_no_record_number_across_imports_b.tsv').import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the first, and safely errors the second rather than silently containerizing it' do
        expect_row_tally(@results_a, imported: 1)
        expect_row_tally(@results_b, errored: 1)
        expect(row_error_messages(@results_b.first, :catalogNumber)).to include('Is already in use')
      end

      it 'does not create a container' do
        expect(Container.count).to eq(0)
      end
    end

    context 'recordNumber reused across unrelated catalogNumbers' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'CAT', delimiter: 'NONE')
        FactoryBot.create(:valid_namespace, short_name: 'REC', delimiter: 'NONE')

        @import_dataset = stage_specification_file('record_number_reused_across_catalog_numbers.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports both rows without containerizing them' do
        expect_row_tally(@results, imported: 2)
        expect(Container.count).to eq(0)
        expect(Identifier::Local::CatalogNumber.count).to eq(2)
      end
    end
  end

  context 'name matching' do
    context 'same scientificName imported twice, within the same import' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        @taxon_name_count_before_import = TaxonName.count

        @import_dataset = stage_specification_file('scientific_name_matched_same_import.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'imports both rows' do
        expect_row_tally(results, imported: 2)
      end

      it 'creates the genus and species TaxonNames once, not twice' do
        expect(TaxonName.count).to eq(@taxon_name_count_before_import + 2)
      end

      it 'matches the second row to the same species TaxonName the first row created' do
        species = TaxonName.find_by(name: 'andeanus')
        expect(CollectionObject.first.taxon_names).to include(species)
        expect(CollectionObject.second.taxon_names).to include(species)
      end
    end

    context 'same scientificName imported twice, across separate imports' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        @taxon_name_count_before_import = TaxonName.count

        @results_a = stage_specification_file('scientific_name_matched_import_a.tsv').import(5000, 100)
        @results_b = stage_specification_file('scientific_name_matched_import_b.tsv').import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports both, one row per import' do
        expect_row_tally(@results_a, imported: 1)
        expect_row_tally(@results_b, imported: 1)
      end

      it 'creates the genus and species TaxonNames once, not twice, same as the same-import case' do
        expect(TaxonName.count).to eq(@taxon_name_count_before_import + 2)
      end

      it 'matches the second import to the same species TaxonName the first import created' do
        species = TaxonName.find_by(name: 'andeanus')
        expect(CollectionObject.first.taxon_names).to include(species)
        expect(CollectionObject.second.taxon_names).to include(species)
      end
    end

    context 'scientificName already exists in the project' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        root = FactoryBot.create(:root_taxon_name)
        genus = Protonym.create!(parent: root, name: 'Orotettix', rank_class: Ranks.lookup(:iczn, :genus))
        @species = Protonym.create!(parent: genus, name: 'andeanus', rank_class: Ranks.lookup(:iczn, :species))
        @taxon_name_count_before_import = TaxonName.count

        @import_dataset = stage_specification_file('minimum_required_fields.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'imports the row' do
        expect_row_tally(results, imported: 1)
      end

      it 'creates no new TaxonNames, matching the pre-existing genus and species instead' do
        expect(TaxonName.count).to eq(@taxon_name_count_before_import)
      end

      it "matches the row's determination to the pre-existing species, not a newly-created one" do
        expect(CollectionObject.first.taxon_names).to include(@species)
      end
    end

    context 'scientificName omits a subgenus present in the project' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        root = FactoryBot.create(:root_taxon_name)
        genus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
        subgenus = Protonym.create!(parent: genus, name: 'Tanaemyrmex', rank_class: Ranks.lookup(:iczn, :subgenus))
        @species = Protonym.create!(parent: subgenus, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species))
        @taxon_name_count_before_import = TaxonName.count

        @import_dataset = stage_specification_file('scientific_name_missing_subgenus.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'imports the row' do
        expect_row_tally(results, imported: 1)
      end

      it 'creates no new TaxonNames, matching through to the species nested under the subgenus' do
        expect(TaxonName.count).to eq(@taxon_name_count_before_import)
      end

      it "matches the row's determination to the existing species despite the omitted subgenus" do
        expect(CollectionObject.first.taxon_names).to include(@species)
      end
    end

    context 'ambiguous subgenus homonym, no disambiguating information' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        root = FactoryBot.create(:root_taxon_name)
        genus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
        subgenus_a = Protonym.create!(parent: genus, name: 'Tanaemyrmex', rank_class: Ranks.lookup(:iczn, :subgenus))
        subgenus_b = Protonym.create!(parent: genus, name: 'Myrmentoma', rank_class: Ranks.lookup(:iczn, :subgenus))
        @species_a = Protonym.create!(parent: subgenus_a, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                                      verbatim_author: 'Mayr', year_of_publication: 1862)
        @species_b = Protonym.create!(parent: subgenus_b, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                                      verbatim_author: 'Emery', year_of_publication: 1893)
        @genus = genus
        @taxon_name_count_before_import = TaxonName.count

        @import_dataset = stage_specification_file('scientific_name_ambiguous_subgenus_homonym.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      # `get_protonym` (app/models/dataset_record/darwin_core/occurrence.rb) has two separate
      # ambiguity checks: a direct-parent query that correctly raises a detailed "Multiple matches
      # found" error, and a separate wildcard/ancestor query (used when the match is only reachable
      # through an intermediate rank, e.g. a subgenus) that instead just returns the parent with no
      # error at all when it also finds more than one candidate. This scenario hits the second path.
      # TaxonWorks does not currently raise an error here (tracked in error_message_todos.md) — this
      # spec records the expected behavior (matching the direct-parent case's real behavior), not the
      # current one.
      xit 'errors the row, naming the ambiguous candidates, instead of silently matching the genus' do
        expect_row_tally(results, errored: 1)
      end
    end

    context 'ambiguous subgenus homonym, disambiguated by scientificNameAuthorship' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        root = FactoryBot.create(:root_taxon_name)
        genus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
        subgenus_a = Protonym.create!(parent: genus, name: 'Tanaemyrmex', rank_class: Ranks.lookup(:iczn, :subgenus))
        subgenus_b = Protonym.create!(parent: genus, name: 'Myrmentoma', rank_class: Ranks.lookup(:iczn, :subgenus))
        @species_a = Protonym.create!(parent: subgenus_a, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                                      verbatim_author: 'Mayr', year_of_publication: 1862)
        @species_b = Protonym.create!(parent: subgenus_b, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                                      verbatim_author: 'Emery', year_of_publication: 1893)
        @taxon_name_count_before_import = TaxonName.count

        @import_dataset = stage_specification_file('scientific_name_disambiguated_by_author_year.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'imports both rows' do
        expect_row_tally(results, imported: 2)
      end

      it 'creates no new TaxonNames' do
        expect(TaxonName.count).to eq(@taxon_name_count_before_import)
      end

      it 'matches row 1 (author and year) to the Mayr, 1862 species' do
        expect(CollectionObject.first.taxon_names).to include(@species_a)
      end

      it 'matches row 2 (author alone, no year) to the Emery species' do
        expect(CollectionObject.second.taxon_names).to include(@species_b)
      end
    end

    context 'scientificNameAuthorship with a typo matches no existing candidate' do
      def build_ambiguous_project
        root = FactoryBot.create(:root_taxon_name)
        genus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
        subgenus_a = Protonym.create!(parent: genus, name: 'Tanaemyrmex', rank_class: Ranks.lookup(:iczn, :subgenus))
        subgenus_b = Protonym.create!(parent: genus, name: 'Myrmentoma', rank_class: Ranks.lookup(:iczn, :subgenus))
        @species_a = Protonym.create!(parent: subgenus_a, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                                      verbatim_author: 'Mayr', year_of_publication: 1862)
        @species_b = Protonym.create!(parent: subgenus_b, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                                      verbatim_author: 'Emery', year_of_publication: 1893)
      end

      context 'setting off (default)' do
        before :all do
          DatabaseCleaner.start

          init_housekeeping
          build_ambiguous_project
          @taxon_name_count_before_import = TaxonName.count

          @import_dataset = stage_specification_file('scientific_name_author_typo.tsv')
          @results = @import_dataset.import(5000, 100)
        end

        after(:all) { DatabaseCleaner.clean }

        let(:results) { @results }

        it 'imports the row' do
          expect_row_tally(results, imported: 1)
        end

        # `Emory` is a single-letter typo of the existing `Emery, 1893` species' author. Matching is
        # exact, not fuzzy: a typo is indistinguishable from a genuinely different author, so this
        # creates a new, unwanted homonym species rather than either matching or erroring.
        it 'creates a new species TaxonName rather than matching or erroring, since the typo does not exactly match either candidate' do
          expect(TaxonName.count).to eq(@taxon_name_count_before_import + 1)
        end

        it 'places the new species directly under the genus, not under either existing subgenus' do
          created = Protonym.where(name: 'americanus').where.not(id: [@species_a.id, @species_b.id]).first
          expect(created.parent.name).to eq('Camponotus')
          expect(created.verbatim_author).to eq('Emory')
        end
      end

      context 'setting on (restrict_to_existing_nomenclature)' do
        before :all do
          DatabaseCleaner.start

          init_housekeeping
          build_ambiguous_project
          @taxon_name_count_before_import = TaxonName.count

          @import_dataset = stage_specification_file(
            'scientific_name_author_typo.tsv',
            import_settings: { 'restrict_to_existing_nomenclature' => true }
          )
          @results = @import_dataset.import(5000, 100)
        end

        after(:all) { DatabaseCleaner.clean }

        let(:results) { @results }

        it 'errors the row instead of creating a new species TaxonName' do
          expect_row_tally(results, errored: 1)
        end

        it 'creates no new TaxonNames' do
          expect(TaxonName.count).to eq(@taxon_name_count_before_import)
        end

        it 'names the unmatched species and states that new-name creation is disabled' do
          expect(row_error_messages(results.first, :scientificName))
            .to include('Protonym americanus not found with that name and/or classification. Importing new names is disabled by import settings.')
        end
      end
    end
  end

  context 'eventID namespace mechanics' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_namespace, short_name: 'EVT', delimiter: 'NONE')

      @import_dataset = stage_specification_file('event_id_namespace.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports both rows' do
      expect_row_tally(results, imported: 2)
    end

    it 'creates an Event identifier for both rows, even the one without an explicit namespace' do
      expect(Identifier::Local::Event.count).to eq(2)
    end

    it 'auto-creates a default namespace for the row with no TW:Namespace:eventID column value, unlike catalogNumber' do
      default_namespace = Identifier::Local::Event.find_by(identifier: '100').namespace
      expect(default_namespace.short_name).not_to eq('EVT')
      expect(default_namespace.verbatim_short_name).to eq('eventID')
    end

    it 'uses the named namespace for the row that provides one' do
      expect(Identifier::Local::Event.find_by(identifier: '200').namespace.short_name).to eq('EVT')
    end

    it 'computes each identifier from its namespace short name and the eventID value' do
      expect(Identifier::Local::Event.pluck(:cached).sort).to eq(%w[EVT200 eventID:100])
    end
  end

  context 'fieldNumber namespace mechanics' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_namespace, short_name: 'FLD', delimiter: 'NONE')

      @import_dataset = stage_specification_file('field_number_namespace.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors a fieldNumber missing its companion namespace column, and imports one that has it' do
      expect_row_tally(results, imported: 1, errored: 1)
    end

    it "names the missing companion column, not 'fieldNumber' itself" do
      expect(row_error_messages(results.first, 'TW:Namespace:fieldNumber')).to include('Namespace not found')
    end

    it 'creates the FieldNumber identifier in the named namespace' do
      expect(Identifier::Local::FieldNumber.count).to eq(1)
      expect(Identifier::Local::FieldNumber.first.namespace.short_name).to eq('FLD')
    end

    it 'computes the identifier value from the namespace short name and the fieldNumber value' do
      expect(Identifier::Local::FieldNumber.first.cached).to eq('FLD200')
    end
  end

  context 'eventDate: single value vs. a range' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('event_date_single_and_range.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports both rows' do
      expect_row_tally(results, imported: 2)
    end

    it 'a single date populates the start date only, leaving the end date unset' do
      ce = CollectingEvent.first
      expect([ce.start_date_year, ce.start_date_month, ce.start_date_day]).to eq([1983, 10, 25])
      expect([ce.end_date_year, ce.end_date_month, ce.end_date_day]).to eq([nil, nil, nil])
    end

    it 'a range (start/end separated by "/") populates both the start and end dates' do
      ce = CollectingEvent.second
      expect([ce.start_date_year, ce.start_date_month, ce.start_date_day]).to eq([2020, 11, 30])
      expect([ce.end_date_year, ce.end_date_month, ce.end_date_day]).to eq([2020, 12, 4])
    end
  end

  context 'year, month, and day columns as an alternative to eventDate' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('event_date_year_month_day.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'populates the start date from year, month, and day alone' do
      ce = CollectingEvent.first
      expect([ce.start_date_year, ce.start_date_month, ce.start_date_day]).to eq([1999, 7, 4])
    end
  end

  context 'eventDate conflicts with year, month, and/or day' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('event_date_conflict.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row' do
      expect_row_tally(results, errored: 1)
    end

    it 'names the conflict' do
      expect(row_error_messages(results.first, :eventDate))
        .to include('Conflicting values. Please check year, month, and day match eventDate')
    end

    it 'creates no CollectingEvent' do
      expect(CollectingEvent.count).to eq(0)
    end
  end

  context 'verbatimEventDate' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('event_date_verbatim.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'stores the raw value verbatim alongside the parsed eventDate, unmodified' do
      ce = CollectingEvent.first
      expect(ce.verbatim_date).to eq("summer of '99")
      expect([ce.start_date_year, ce.start_date_month, ce.start_date_day]).to eq([1999, 7, 4])
    end
  end

  context 'startDayOfYear and endDayOfYear' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('event_start_end_day_of_year.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports the two rows with a year, and errors the row without one' do
      expect_row_tally(results, imported: 2, errored: 1)
    end

    it 'converts startDayOfYear and endDayOfYear (with year) into a calendar start and end date' do
      ce = CollectingEvent.first
      expect([ce.start_date_year, ce.start_date_month, ce.start_date_day]).to eq([2000, 2, 29])
      expect([ce.end_date_year, ce.end_date_month, ce.end_date_day]).to eq([2000, 3, 5])
    end

    it 'converts startDayOfYear alone into a calendar start date, leaving the end date unset' do
      ce = CollectingEvent.second
      expect([ce.start_date_year, ce.start_date_month, ce.start_date_day]).to eq([2000, 2, 29])
      expect([ce.end_date_year, ce.end_date_month, ce.end_date_day]).to eq([nil, nil, nil])
    end

    it 'requires a year for endDayOfYear, the same as it does for startDayOfYear' do
      expect(row_error_messages(results.third, :endDayOfYear)).to include('Missing year value')
    end
  end

  context 'eventID reused across separate imports' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_namespace, short_name: 'EVT', delimiter: 'NONE')

      @results_a = stage_specification_file('event_id_reuse_a.tsv').import(5000, 100)
      @results_b = stage_specification_file('event_id_reuse_b.tsv').import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports all rows' do
      expect_row_tally(@results_a, imported: 2)
      expect_row_tally(@results_b, imported: 2)
    end

    it 'does NOT share a CollectingEvent for the same eventID left to its default per-import namespace' do
      expect(CollectionObject.first.collecting_event_id).not_to eq(CollectionObject.third.collecting_event_id)
    end

    it 'DOES share a CollectingEvent for the same eventID given an explicit, shared namespace' do
      expect(CollectionObject.second.collecting_event_id).to eq(CollectionObject.fourth.collecting_event_id)
    end

    it 'creates 3 CollectingEvents total: 2 distinct default-namespace ones plus 1 shared explicit-namespace one' do
      expect(CollectingEvent.count).to eq(3)
    end
  end

  context 'fieldNumber reused across separate imports' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_namespace, short_name: 'FLD', delimiter: 'NONE')

      @results_a = stage_specification_file('field_number_reuse_a.tsv').import(5000, 100)
      @results_b = stage_specification_file('field_number_reuse_b.tsv').import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports both rows' do
      expect_row_tally(@results_a, imported: 1)
      expect_row_tally(@results_b, imported: 1)
    end

    it 'shares the same CollectingEvent, since fieldNumber always requires an explicit, shared namespace' do
      expect(CollectionObject.first.collecting_event_id).to eq(CollectionObject.second.collecting_event_id)
    end

    it 'creates only 1 CollectingEvent and 1 FieldNumber identifier' do
      expect(CollectingEvent.count).to eq(1)
      expect(Identifier::Local::FieldNumber.count).to eq(1)
    end
  end

  context 'eventID and fieldNumber refer to inconsistent collecting events' do
    context 'fieldNumber does not match a previously established collecting event' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'EVT', delimiter: 'NONE')
        FactoryBot.create(:valid_namespace, short_name: 'FLD', delimiter: 'NONE')

        @import_dataset = stage_specification_file('event_field_number_partial_mismatch.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'imports row 1, and errors row 2' do
        expect_row_tally(results, imported: 1, errored: 1)
      end

      it 'names the conflict rather than silently accepting either value' do
        expect(row_error_messages(results.second, 'eventID/fieldNumber'))
          .to include('does not match previous definition of collecting event')
      end

      it 'creates only 1 CollectingEvent' do
        expect(CollectingEvent.count).to eq(1)
      end
    end

    context 'eventID and fieldNumber each already belong to a different, previously established collecting event' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'EVT', delimiter: 'NONE')
        FactoryBot.create(:valid_namespace, short_name: 'FLD', delimiter: 'NONE')

        @import_dataset = stage_specification_file('event_field_number_conflicting_ce.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'imports rows 1 and 2, and errors row 3' do
        expect_row_tally(results, imported: 2, errored: 1)
      end

      it 'names the conflict between the two previously established collecting events' do
        expect(row_error_messages(results.third, 'eventID/fieldNumber'))
          .to include('eventId and fieldNumber refer to different collecting events')
      end

      it 'creates 2 CollectingEvents, one per identifier, never merging them' do
        expect(CollectingEvent.count).to eq(2)
      end
    end
  end

  context 'no eventID or fieldNumber given' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('no_event_field_number_identical_locality.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports both rows' do
      expect_row_tally(results, imported: 2)
    end

    it 'creates a separate CollectingEvent per row, even though every other attribute is identical' do
      expect(CollectingEvent.count).to eq(2)
      expect(CollectionObject.first.collecting_event_id).not_to eq(CollectionObject.second.collecting_event_id)
    end
  end
end
