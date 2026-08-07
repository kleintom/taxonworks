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

  context 'recordNumber given with its namespace prefix already included' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_namespace, short_name: 'DEF', delimiter: 'NONE')

      @import_dataset = stage_specification_file('record_number_prefix_included.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    # Unlike `catalogNumber` (occurrence.rb ~line 351-353, `delete_namespace_prefix!` strips a given
    # prefix before creating the identifier) and `eventID` (~line 430, same), `recordNumber`'s
    # identifier creation (~line 337-349) never calls `delete_namespace_prefix!` at all. A value
    # already including the namespace prefix is stored as-is, and the computed `cached` value
    # duplicates the prefix rather than matching what was given. Confirmed empirically: `recordNumber:
    # "DEF222"` in namespace `DEF` produces `cached: "DEFDEF222"`, with no error. Recorded as the
    # expected behavior (either strip the prefix tolerantly, matching catalogNumber/eventID's
    # default, or reject the mismatch the way their opt-in verbatim-match settings do), not the
    # current one.
    xit 'errors the row, naming the mismatch, instead of silently doubling the namespace prefix' do
      expect_row_tally(results, errored: 1)
    end

    it 'currently imports instead, computing a doubled-prefix identifier with no indication anything is wrong' do
      expect_row_tally(results, imported: 1)
      expect(Identifier::Local::RecordNumber.first.cached).to eq('DEFDEF222')
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

  context 'fieldNumber given with its namespace prefix already included' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_namespace, short_name: 'FLD', delimiter: 'NONE')

      @import_dataset = stage_specification_file('field_number_prefix_included.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    # Same underlying issue as recordNumber (see 'recordNumber given with its namespace prefix
    # already included'): fieldNumber's identifier creation (occurrence.rb ~line 446-462) never
    # calls `delete_namespace_prefix!` either.
    xit 'errors the row, naming the mismatch, instead of silently doubling the namespace prefix' do
      expect_row_tally(results, errored: 1)
    end

    it 'currently imports instead, computing a doubled-prefix identifier with no indication anything is wrong' do
      expect_row_tally(results, imported: 1)
      expect(Identifier::Local::FieldNumber.first.cached).to eq('FLDFLD200')
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

  context 'eventTime: single value vs. a range' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('event_time_single_and_range.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports both rows' do
      expect_row_tally(results, imported: 2)
    end

    it 'a single time populates the start time only, leaving the end time unset' do
      ce = CollectingEvent.first
      expect([ce.time_start_hour, ce.time_start_minute, ce.time_start_second]).to eq([10, 15, 30])
      expect([ce.time_end_hour, ce.time_end_minute, ce.time_end_second]).to eq([nil, nil, nil])
    end

    it 'a range (start/end separated by "/") populates both the start and end times' do
      ce = CollectingEvent.second
      expect([ce.time_start_hour, ce.time_start_minute, ce.time_start_second]).to eq([10, 15, 30])
      expect([ce.time_end_hour, ce.time_end_minute, ce.time_end_second]).to eq([14, 45, 0])
    end
  end

  context 'malformed eventTime' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('event_time_malformed.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    # `parse_event_class` (app/models/dataset_record/darwin_core/occurrence.rb) matches `eventTime`
    # against a regex and, unlike `eventDate` (parse_iso_date, which raises a clear "Invalid date"
    # error on unparseable input), raises nothing when the regex fails to match at all: every named
    # capture is simply nil, and Utilities::Hashes::set_unless_nil silently sets nothing. The row
    # reports success with the time fields silently absent. Recorded as the expected behavior
    # (matching eventDate's sibling handling of the identical situation), not the current one.
    xit 'errors the row, naming the unparseable value, instead of silently discarding it' do
      expect_row_tally(results, errored: 1)
    end
  end

  context 'eventTime with an out-of-range component' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('event_time_out_of_range.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row' do
      expect_row_tally(results, errored: 1)
    end

    it 'creates no CollectingEvent' do
      expect(CollectingEvent.count).to eq(0)
    end

    it 'names the field and the valid range, alongside a redundant second message' do
      messages = row_error_messages(results.first, :time_start_minute)
      expect(messages).to include('not in range')
      expect(messages).to include('must be an integer between 0 and 59')
    end
  end

  context 'country, stateProvince, county resolve to a GeographicArea' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      @county = FactoryBot.create(:level2_geographic_area) # Champaign, IL, US

      @import_dataset = stage_specification_file('geographic_area_country_state_county.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'matches the most specific (county-level) GeographicArea' do
      expect(CollectingEvent.first.geographic_area_id).to eq(@county.id)
    end
  end

  context 'require geographical area data origin' do
    context 'set to the data_origin actually used' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        @county = FactoryBot.create(:level2_geographic_area) # data_origin: 'Test Data'

        @import_dataset = stage_specification_file(
          'geographic_area_data_origin.tsv',
          import_settings: { 'geographic_area_data_origin' => 'Test Data' }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row and matches the GeographicArea' do
        expect_row_tally(@results, imported: 1)
        expect(CollectingEvent.first.geographic_area_id).to eq(@county.id)
      end
    end

    context 'set to a data_origin other than the one actually used' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:level2_geographic_area) # data_origin: 'Test Data'

        @import_dataset = stage_specification_file(
          'geographic_area_data_origin.tsv',
          import_settings: { 'geographic_area_data_origin' => 'Some Other Source' }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row, matching no GeographicArea, without error' do
        expect_row_tally(@results, imported: 1)
        expect(CollectingEvent.first.geographic_area_id).to be_nil
      end
    end
  end

  context 'country, stateProvince, county: recursive fallback vs. exact match only' do
    context 'setting off (default)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        @state = FactoryBot.create(:level2_geographic_area).parent # Illinois; also creates Champaign, US

        @import_dataset = stage_specification_file('geographic_area_recursive_fallback.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row' do
        expect_row_tally(@results, imported: 1)
      end

      it 'falls back to the state-level GeographicArea when the county does not match' do
        expect(CollectingEvent.first.geographic_area_id).to eq(@state.id)
      end
    end

    context 'setting on (require_geographic_area_exact_match)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:level2_geographic_area)

        @import_dataset = stage_specification_file(
          'geographic_area_recursive_fallback.tsv',
          import_settings: { 'require_geographic_area_exact_match' => true }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row' do
        expect_row_tally(@results, imported: 1)
      end

      it 'does not fall back, and does not error either: no GeographicArea is matched at all' do
        expect(CollectingEvent.first.geographic_area_id).to be_nil
      end
    end
  end

  context 'country, stateProvince, county: error if no geographic area exists' do
    context 'setting off (default)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)

        @import_dataset = stage_specification_file('geographic_area_no_match.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row, matching no GeographicArea, without error' do
        expect_row_tally(@results, imported: 1)
        expect(CollectingEvent.first.geographic_area_id).to be_nil
      end
    end

    context 'setting on (require_geographic_area_exists)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)

        @import_dataset = stage_specification_file(
          'geographic_area_no_match.tsv',
          import_settings: { 'require_geographic_area_exists' => true }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'errors the row instead' do
        expect_row_tally(results, errored: 1)
      end

      it 'names the location levels that were searched for' do
        expect(row_error_messages(results.first, 'country, stateProvince, county'))
          .to include('GeographicArea with location levels county:Nowhere County, state_province:Nowhere State, country:Nowhereland not found.')
      end
    end
  end

  context 'countryCode as a fallback for country' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      earth = FactoryBot.create(:earth_geographic_area)
      @country = FactoryBot.create(
        :geographic_area, :country_gat,
        name: 'United States', iso_3166_a2: 'US', iso_3166_a3: 'USA',
        data_origin: 'country_names_and_code_elements', parent: earth
      ).tap { |c| c.update!(level0_id: c.id) }

      @import_dataset = stage_specification_file('geographic_area_country_code.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports both rows' do
      expect_row_tally(@results, imported: 2)
    end

    it 'resolves a 2-letter countryCode to the matching country' do
      expect(CollectionObject.first.collecting_event.geographic_area_id).to eq(@country.id)
    end

    it 'resolves a 3-letter countryCode to the matching country' do
      expect(CollectionObject.second.collecting_event.geographic_area_id).to eq(@country.id)
    end
  end

  context 'unrecognized countryCode' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('geographic_area_country_code_unrecognized.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    # `countryCode` resolution (app/models/dataset_record/darwin_core/occurrence.rb, ~line 522-527) does
    # `GeographicArea.find_by(iso_3166_a2: country_code, data_origin: 'country_names_and_code_elements').name`
    # with no nil check — an unrecognized code raises a raw `NoMethodError` ("undefined method 'name' for
    # nil"), caught only by the generic `rescue StandardError`, which sets status `Failed` and stores the
    # exception message and full Ruby backtrace, not a normal `DarwinCore::InvalidData` row error. Recorded
    # as the expected behavior (a clean, named error, the same as every other unmatched-value case in this
    # importer), not the current one.
    xit 'errors the row, naming the unrecognized countryCode, instead of failing with an internal exception' do
      expect_row_tally(results, errored: 1)
    end
  end

  context 'decimalLatitude / decimalLongitude' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('geographic_area_lat_long.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'stores decimalLatitude, decimalLongitude, and geodeticDatum verbatim on the CollectingEvent' do
      ce = CollectingEvent.first
      expect(ce.verbatim_latitude).to eq('40.11')
      expect(ce.verbatim_longitude).to eq('-88.20')
      expect(ce.verbatim_datum).to eq('WGS84')
    end

    it 'appends a unit suffix to coordinateUncertaintyInMeters for the CollectingEvent, but not for the Georeference' do
      expect(CollectingEvent.first.verbatim_geolocation_uncertainty).to eq('50m')
      expect(Georeference::VerbatimData.first.error_radius).to eq(50)
    end

    it 'creates a Georeference::VerbatimData record, since both latitude and longitude are present' do
      expect(Georeference::VerbatimData.count).to eq(1)
      expect(Georeference::VerbatimData.first.collecting_event).to eq(CollectingEvent.first)
    end
  end

  context 'eventRemarks, verbatimLocality, and elevation terms' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('location_and_event_pass_through_terms.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'stores eventRemarks as a note on the CollectingEvent' do
      expect(CollectingEvent.first.notes.map(&:text)).to eq(['trail was muddy'])
    end

    it 'stores verbatimLocality, minimumElevationInMeters, maximumElevationInMeters, and verbatimElevation verbatim' do
      ce = CollectingEvent.first
      expect(ce.verbatim_locality).to eq('2 km N of Springfield')
      expect(ce.minimum_elevation).to eq(100)
      expect(ce.maximum_elevation).to eq(150)
      expect(ce.verbatim_elevation).to eq('100-150m')
    end
  end

  context 'georeferencedBy' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('georeferenced_by.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'attaches georeferencedBy as a data attribute on the Georeference, using a predicate matching the DwC term URI' do
      gr = Georeference::VerbatimData.first
      predicate, value = gr.data_attributes.first.then { |da| [da.predicate, da.value] }
      expect(predicate.name).to eq('georeferencedBy')
      expect(predicate.uri).to eq('http://rs.tdwg.org/dwc/terms/georeferencedBy')
      expect(value).to eq('Jane Smith')
    end
  end

  context 'georeferencedBy without decimalLatitude/decimalLongitude' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('georeferenced_by_without_coordinates.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'has no effect: no Georeference exists to attach the value to, since latitude/longitude are required for one to be created' do
      expect(Georeference::VerbatimData.count).to eq(0)
      expect(DataAttribute.count).to eq(0)
    end

    it 'still creates the georeferencedBy Predicate, even though nothing ends up using it' do
      expect(Predicate.where(name: 'georeferencedBy').count).to eq(1)
    end
  end

  context 'decimalLatitude without decimalLongitude' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('geographic_area_lat_without_long.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row rather than storing a partial coordinate' do
      expect_row_tally(results, errored: 1)
    end

    it 'creates no Georeference' do
      expect(Georeference::VerbatimData.count).to eq(0)
    end
  end

  context 'coordinateUncertaintyInMeters must be an integer' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('geographic_area_coordinate_uncertainty_non_integer.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row' do
      expect_row_tally(results, errored: 1)
    end

    it 'names the field' do
      expect(row_error_messages(results.first, :coordinateUncertaintyInMeters)).to include('Non-integer value')
    end

    it 'creates no CollectingEvent' do
      expect(CollectingEvent.count).to eq(0)
    end
  end

  context 'GeographicArea with a shape' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      @country = FactoryBot.create(:level0_geographic_area) # United States, no shape
      geo_item = FactoryBot.create(:valid_geographic_item)
      FactoryBot.create(:geographic_areas_geographic_item, geographic_area: @country, geographic_item: geo_item)

      @import_dataset = stage_specification_file('geographic_area_has_shape.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    # `GeographicArea.has_shape` (app/models/geographic_area.rb) is `scope :has_shape, ->
    # (has_shape = true) { if has_shape ... else <areas WITHOUT a shape> ... end }`. The call site
    # (occurrence.rb) always calls it explicitly — `.has_shape(self.import_dataset.metadata.dig(...,
    # 'require_geographic_area_has_shape'))` — and when that setting was never configured, `.dig`
    # returns `nil`, which is passed explicitly, bypassing the `= true` default entirely. `if nil` is
    # false, so the *else* branch runs: matching is silently restricted to GeographicAreas that do NOT
    # have a shape. A GeographicArea that does have one (the normal case for real, imported gazetteer
    # data) is never matched by default, at any level, unless a shapeless coarser ancestor happens to
    # exist to fall back to. Confirmed empirically: enabling the setting explicitly (`true`) fixes
    # matching for a shaped GeographicArea; leaving it unset does not. Recorded as the expected
    # behavior (the setting's own documented purpose is an opt-in extra restriction, not a
    # prerequisite for ordinary matching), not the current one.
    xit 'matches a GeographicArea regardless of whether it has a shape, when the setting is not configured' do
      expect_row_tally(results, imported: 1)
      expect(CollectingEvent.first.geographic_area_id).to eq(@country.id)
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

  context 'eventID must match its computed identifier verbatim' do
    context 'setting off (default)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'EVT', delimiter: 'NONE')

        @import_dataset = stage_specification_file(
          'event_id_verbatim_match.tsv',
          import_settings: { 'require_tripcode_match_verbatim' => false }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports an eventID given with or without its namespace prefix alike' do
        expect_row_tally(@results, imported: 3)
        expect(Identifier::Local::Event.pluck(:cached)).to contain_exactly('EVT100', 'EVT200', 'eventID:100')
      end
    end

    context 'setting on' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:valid_namespace, short_name: 'EVT', delimiter: 'NONE')

        @import_dataset = stage_specification_file(
          'event_id_verbatim_match.tsv',
          import_settings: { 'require_tripcode_match_verbatim' => true }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'errors an eventID given without its namespace prefix, under an explicit namespace' do
        expect_row_tally(results, imported: 2, errored: 1)
      end

      it 'names the mismatch between the computed and verbatim values' do
        expect(row_error_messages(results.first, :eventID))
          .to include('Computed Event EVT100 will not match verbatim 100. Verify the namespace delimiter is correct.')
      end

      it 'imports one given with its prefix already, matching verbatim' do
        expect(Identifier::Local::Event.find_by(cached: 'EVT200')).to be_present
      end

      it 'does not apply to a row left to the default per-import namespace, since there is no explicit namespace to check against' do
        expect(Identifier::Local::Event.find_by(cached: 'eventID:100')).to be_present
      end
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

  context 'typeStatus: minimum, matching the current name' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      genus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
      @species = Protonym.create!(parent: genus, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species))

      @import_dataset = stage_specification_file('type_status_minimum.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'creates a TypeMaterial for the matched species, since a single-word typeStatus is taken to mean the specimen itself' do
      expect(TypeMaterial.count).to eq(1)
      expect(TypeMaterial.first.type_type).to eq('holotype')
      expect(TypeMaterial.first.protonym).to eq(@species)
    end
  end

  context 'typeStatus illegal for the nomenclatural code' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      genus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
      Protonym.create!(parent: genus, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species))

      @import_dataset = stage_specification_file('type_status_illegal_for_code.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row' do
      expect_row_tally(results, errored: 1)
    end

    it "names the problem: isotype is not a legal type under this row's (default) nomenclatural code" do
      expect(row_error_messages(results.first, :typeStatus)).to include('could not extract legal type from typeStatus')
    end

    it 'creates no TypeMaterial' do
      expect(TypeMaterial.count).to eq(0)
    end
  end

  context 'unparseable typeStatus' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      genus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
      Protonym.create!(parent: genus, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species))

      @import_dataset = stage_specification_file('type_status_unparseable.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row' do
      expect_row_tally(results, errored: 1)
    end

    it "names the problem, since the value doesn't fit either the bare-word or the 'word of name' shape" do
      expect(row_error_messages(results.first, :typeStatus)).to include('Unprocessable typeStatus information')
    end
  end

  context 'typeStatus is ignored when TW:TaxonDetermination:otu_id is used' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      Otu.create!(id: 900001, taxon_name: FactoryBot.create(:iczn_species))

      @import_dataset = stage_specification_file('type_status_ignored_with_otu_id.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'creates no TypeMaterial, even though typeStatus is present' do
      expect(TypeMaterial.count).to eq(0)
    end
  end

  context 'habitat, samplingProtocol, fieldNotes, identifiedBy, dateIdentified, and identificationRemarks' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('identification_and_event_pass_through_terms.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'stores habitat, samplingProtocol, and fieldNotes verbatim on the CollectingEvent' do
      ce = CollectingEvent.first
      expect(ce.verbatim_habitat).to eq('rainforest canopy')
      expect(ce.verbatim_method).to eq('hand collecting')
      expect(ce.field_notes).to eq('saw many nests')
    end

    it 'matches identifiedBy to a person and assigns them as a determiner of the TaxonDetermination' do
      td = TaxonDetermination.first
      expect(td.determiners.map { |p| [p.first_name, p.last_name] }).to eq([['Jane', 'Smith']])
    end

    it 'parses dateIdentified into the TaxonDetermination made-date fields' do
      td = TaxonDetermination.first
      expect([td.year_made, td.month_made, td.day_made]).to eq([1999, 7, 4])
    end

    it 'stores identificationRemarks as a note on the TaxonDetermination' do
      expect(TaxonDetermination.first.notes.map(&:text)).to eq(['looks typical'])
    end
  end

  context 'dateIdentified as a range' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('date_identified_range.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row, unlike eventDate, which does support a range' do
      expect_row_tally(results, errored: 1)
    end

    it 'names the reason' do
      expect(row_error_messages(results.first, :dateIdentified))
        .to include('Date range for taxon determination is not supported.')
    end
  end

  context 'identificationQualifier' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('identification_qualifier.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'creates a second, separate OTU carrying the qualifier as its own name, for the same TaxonName' do
      species = TaxonName.find_by(name: 'americanus')
      expect(species.otus.count).to eq(2)
      expect(species.otus.pluck(:name)).to contain_exactly(nil, 'cf.')
    end

    it "determines the row to the qualified OTU ('cf.'), not the plain species OTU" do
      qualified_otu = Otu.find_by(taxon_name: TaxonName.find_by(name: 'americanus'), name: 'cf.')
      expect(TaxonDetermination.first.otu).to eq(qualified_otu)
    end
  end

  context 'typeStatus "of X" matches an original combination directly' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      g_camponotus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
      g_formica = Protonym.create!(parent: root, name: 'Formica', rank_class: Ranks.lookup(:iczn, :genus))

      @s_americanus = Protonym.create!(parent: g_camponotus, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                                       verbatim_author: 'Mayr', year_of_publication: 1862)
      @s_americanus.original_genus = g_formica
      @s_americanus.original_species = @s_americanus
      @s_americanus.save!

      @import_dataset = stage_specification_file('type_status_original_combination.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it "matches the protonym whose original combination is exactly 'Formica americanus'" do
      expect(TypeMaterial.count).to eq(1)
      expect(TypeMaterial.first.protonym).to eq(@s_americanus)
    end
  end

  context 'typeStatus "of X" matches via a synonym' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      g_camponotus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
      g_formica = Protonym.create!(parent: root, name: 'Formica', rank_class: Ranks.lookup(:iczn, :genus))

      @s_americanus = Protonym.create!(parent: g_camponotus, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                                       verbatim_author: 'Mayr', year_of_publication: 1862, also_create_otu: true)

      @s_nigra = Protonym.create!(parent: g_formica, name: 'nigra', rank_class: Ranks.lookup(:iczn, :species),
                                  verbatim_author: 'Smith', year_of_publication: 1858, also_create_otu: true)
      @s_nigra.original_genus = g_formica
      @s_nigra.original_species = @s_nigra
      @s_nigra.save!

      TaxonNameRelationship::Iczn::Invalidating::Usage::Synonym.create!(subject_taxon_name: @s_nigra, object_taxon_name: @s_americanus)

      @import_dataset = stage_specification_file('type_status_synonym.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it "matches the synonym 'Formica nigra', not the current name 'Camponotus americanus' the row was determined to" do
      expect(TypeMaterial.count).to eq(1)
      expect(TypeMaterial.first.protonym).to eq(@s_nigra)
    end
  end

  context 'typeStatus "of X" wildcard subgenus match' do
    context 'unambiguous (one candidate)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        root = FactoryBot.create(:root_taxon_name)
        genus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
        subgenus = Protonym.create!(parent: genus, name: 'Tanaemyrmex', rank_class: Ranks.lookup(:iczn, :subgenus))
        @species = Protonym.create!(parent: subgenus, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                                    verbatim_author: 'Mayr', year_of_publication: 1862)

        @import_dataset = stage_specification_file('type_status_wildcard_subgenus_unambiguous.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row' do
        expect_row_tally(@results, imported: 1)
      end

      it "matches 'Camponotus americanus' to the subgenus-nested species, despite the typeStatus name omitting the subgenus" do
        expect(TypeMaterial.count).to eq(1)
        expect(TypeMaterial.first.protonym).to eq(@species)
      end
    end

    context 'ambiguous (two homonym candidates)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        root = FactoryBot.create(:root_taxon_name)
        genus = Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))
        subgenus_a = Protonym.create!(parent: genus, name: 'Tanaemyrmex', rank_class: Ranks.lookup(:iczn, :subgenus))
        subgenus_b = Protonym.create!(parent: genus, name: 'Myrmentoma', rank_class: Ranks.lookup(:iczn, :subgenus))
        Protonym.create!(parent: subgenus_a, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                         verbatim_author: 'Mayr', year_of_publication: 1862)
        Protonym.create!(parent: subgenus_b, name: 'americanus', rank_class: Ranks.lookup(:iczn, :species),
                         verbatim_author: 'Emery', year_of_publication: 1893)

        @import_dataset = stage_specification_file('type_status_wildcard_subgenus_ambiguous.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'errors the row, naming the ambiguous candidates, unlike the equivalent scientificName-matching case' do
        expect_row_tally(results, errored: 1)
        expect(row_error_messages(results.first, :typeStatus).join).to include('Multiple names returned in wildcard search')
      end

      it 'creates no TypeMaterial' do
        expect(TypeMaterial.count).to eq(0)
      end
    end
  end

  context 'a TypeMaterial that fails its own validation aborts the whole row' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      Protonym.create!(parent: root, name: 'Camponotus', rank_class: Ranks.lookup(:iczn, :genus))

      @import_dataset = stage_specification_file('type_status_invalid_type_material_aborts_row.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    # `occurrence.rb`'s own comment above this code (~line 332) states the intent plainly: "Best
    # effort only, import will proceed even if creating the type material fails." In practice it
    # does not: `TypeMaterial.new(collection_object:, ...)` registers the (unsaved, invalid) record
    # on `collection_object.type_materials` in memory via `inverse_of`; that association is
    # validated automatically as part of `collection_object.valid?`, which is itself checked shortly
    # after by `Identifier::Local::Import::Dwc`'s `validates_associated :identifier_object`
    # (`polymorphic_annotates`, app/models/concerns/shared/polymorphic_annotator.rb) when the
    # occurrenceID identifier is saved. The row errors, but the reported problem is a confusing,
    # unrelated-looking `identifier_object: "is invalid"` — nothing about the message points at the
    # actual cause. Recorded as the expected behavior (the code's own stated intent: proceed without
    # the type material), not the current one.
    xit 'imports the row without a TypeMaterial, per the "best effort" behavior described in code, instead of erroring' do
      expect_row_tally(results, imported: 1)
      expect(TypeMaterial.count).to eq(0)
    end

    it 'currently errors instead, with a message that does not mention TypeMaterial, protonym rank, or typeStatus at all' do
      expect_row_tally(results, errored: 1)
      expect(row_error_messages(results.first, :identifier_object)).to include('is invalid')
    end
  end

  context 'kingdom, phylum, class, order, and family columns' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)
      @taxon_name_count_before_import = TaxonName.count

      @import_dataset = stage_specification_file('taxon_rank_columns.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'creates a protonym at each rank given, plus the genus and species extracted from scientificName' do
      expect(TaxonName.count).to eq(@taxon_name_count_before_import + 7)
      names = %w[Animalia Arthropoda Insecta Hymenoptera Formicidae Camponotus americanus]
      expect(TaxonName.where(name: names).count).to eq(7)
    end

    it 'nests them in rank order: kingdom > phylum > class > order > family > genus > species' do
      species = TaxonName.find_by(name: 'americanus')
      lineage = []
      node = species
      while node
        lineage << node.name
        node = node.parent
      end
      expect(lineage).to eq(%w[americanus Camponotus Formicidae Hymenoptera Insecta Arthropoda Animalia Root])
    end
  end

  context 'higherClassification' do
    context 'when the higher ranks it names already exist' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        root = FactoryBot.create(:root_taxon_name)
        @kingdom = Protonym.create!(parent: root, name: 'Animalia', rank_class: Ranks.lookup(:iczn, :kingdom))
        phylum = Protonym.create!(parent: @kingdom, name: 'Arthropoda', rank_class: Ranks.lookup(:iczn, :phylum))
        klass = Protonym.create!(parent: phylum, name: 'Insecta', rank_class: Ranks.lookup(:iczn, :class))
        @order = Protonym.create!(parent: klass, name: 'Hymenoptera', rank_class: Ranks.lookup(:iczn, :order))
        @taxon_name_count_before_import = TaxonName.count

        @import_dataset = stage_specification_file('higher_classification.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row' do
        expect_row_tally(@results, imported: 1)
      end

      it 'creates only the family-group name; the higher ranks are matched, not recreated' do
        expect(TaxonName.count).to eq(@taxon_name_count_before_import + 3)
        family = TaxonName.find_by(name: 'Formicidae')
        expect(family.parent).to eq(@order)
        expect(TaxonName.where(parent: @kingdom).count).to eq(1)
      end
    end

    context "when a higher rank it names doesn't already exist" do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)

        @import_dataset = stage_specification_file('higher_classification.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      let(:results) { @results }

      it 'errors the row: higherClassification only creates family-group names, never ranks above family' do
        expect_row_tally(results, errored: 1)
      end

      it 'names the problem' do
        expect(row_error_messages(results.first, :higherClassification))
          .to include('Rank for Animalia could not be determined. Please create this taxon name manually and retry.')
      end
    end
  end

  context 'taxonRank overrides the rank of a single-word (uninomial) scientificName' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('taxon_rank_overrides_uninomial.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'creates the name at the rank taxonRank specifies, rather than assuming genus rank' do
      tribe = TaxonName.find_by(name: 'Camponotini')
      expect(tribe.rank_class.rank_name).to eq('tribe')
    end
  end

  context 'invalid taxonRank' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('taxon_rank_invalid.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row' do
      expect_row_tally(results, errored: 1)
    end

    it 'names the unrecognized rank' do
      expect(row_error_messages(results.first, :taxonRank)).to include('Unknown ICZN rank nonsenserank')
    end
  end

  context 'genus and specificEpithet columns are ignored in favor of scientificName' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('genus_specific_epithet_ignored.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'creates the genus and species named in scientificName, ignoring the genus/specificEpithet column values entirely' do
      expect(TaxonName.exists?(name: 'Camponotus')).to be true
      expect(TaxonName.exists?(name: 'americanus')).to be true
      expect(TaxonName.exists?(name: 'WrongGenus')).to be false
      expect(TaxonName.exists?(name: 'wrongepithet')).to be false
    end
  end

  context 'enable searching for Organization name in identifiedBy' do
    context 'setting off (default)' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:organization, name: 'Field Museum')

        @import_dataset = stage_specification_file('identified_by_organization.tsv')
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row' do
        expect_row_tally(@results, imported: 1)
      end

      it 'never checks Organizations; identifiedBy is always run through person-name parsing, even when it names an existing Organization' do
        td = TaxonDetermination.first
        expect(td.determiners_organization).to be_empty
      end
    end

    context 'setting on' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        @org = FactoryBot.create(:organization, name: 'Field Museum')

        @import_dataset = stage_specification_file(
          'identified_by_organization.tsv',
          import_settings: { 'enable_organization_determiners' => true }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row' do
        expect_row_tally(@results, imported: 1)
      end

      it 'matches identifiedBy to the Organization by name, instead of parsing it as a person' do
        td = TaxonDetermination.first
        expect(td.determiners_organization).to eq([@org])
        expect(td.determiners).to be_empty
      end
    end
  end

  context 'also search for Organization alternate name' do
    context 'setting off' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        FactoryBot.create(:organization, name: 'Field Museum', alternate_name: 'FM')

        @import_dataset = stage_specification_file(
          'identified_by_organization_alt_name.tsv',
          import_settings: { 'enable_organization_determiners' => true }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row' do
        expect_row_tally(@results, imported: 1)
      end

      it "does not match identifiedBy 'FM' to the Organization via its alternate name" do
        td = TaxonDetermination.first
        expect(td.determiners_organization).to be_empty
      end
    end

    context 'setting on' do
      before :all do
        DatabaseCleaner.start

        init_housekeeping
        FactoryBot.create(:root_taxon_name)
        @org = FactoryBot.create(:organization, name: 'Field Museum', alternate_name: 'FM')

        @import_dataset = stage_specification_file(
          'identified_by_organization_alt_name.tsv',
          import_settings: { 'enable_organization_determiners' => true, 'enable_organization_determiners_alt_name' => true }
        )
        @results = @import_dataset.import(5000, 100)
      end

      after(:all) { DatabaseCleaner.clean }

      it 'imports the row' do
        expect_row_tally(@results, imported: 1)
      end

      it "matches identifiedBy 'FM' to the Organization via its alternate name" do
        td = TaxonDetermination.first
        expect(td.determiners_organization).to eq([@org])
      end
    end
  end

  context 'TW:DataAttribute:<target_class>:<predicate>' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_predicate, name: 'ageInDays', project: root.project)

      @import_dataset = stage_specification_file('tw_data_attribute.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'attaches a data attribute to the CollectionObject, using the named (pre-existing) predicate' do
      da = CollectionObject.first.data_attributes.first
      expect(da.predicate.name).to eq('ageInDays')
      expect(da.value).to eq('5')
    end
  end

  context 'TW:DataAttribute: predicate not found' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('tw_data_attribute_predicate_not_found.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row: unlike georeferencedBy, this mechanism never auto-creates the predicate' do
      expect_row_tally(results, errored: 1)
    end

    it 'names the missing predicate' do
      expect(row_error_messages(results.first, 'tw:dataattribute:collectionobject:nonexistentpredicate'))
        .to include('Predicate with nonexistentpredicate URI or name not found')
    end
  end

  context 'TW:BiocurationGroup:<group>' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      group = FactoryBot.create(:valid_biocuration_group, name: 'Caste', project: root.project)
      klass = FactoryBot.create(:valid_biocuration_class, name: 'Queen', project: root.project)
      Tag.create!(keyword: group, tag_object: klass)

      @import_dataset = stage_specification_file('tw_biocuration_group.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'creates a BiocurationClassification using the named group and class, both of which must already exist' do
      bc = CollectionObject.first.biocuration_classifications.first
      expect(bc.biocuration_class.name).to eq('Queen')
    end
  end

  context 'TW:BiocurationGroup: group not found' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('tw_biocuration_group_not_found.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    # Unlike `sex` (a dedicated Occurrence-class term, which auto-creates its BiocurationGroup and
    # any new BiocurationClass value it hasn't seen before), this generic mechanism requires both
    # the group and the class to already exist in the project.
    it 'errors the row instead of auto-creating the group, unlike sex' do
      expect_row_tally(results, errored: 1)
    end

    it 'names the missing group' do
      expect(row_error_messages(results.first, 'tw:biocurationgroup:nonexistent'))
        .to include("Biocuration group with 'nonexistent' URI or name not found")
    end
  end

  context 'automatic mapping when a project predicate URI matches a DwC term' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      project = root.project
      @predicate = FactoryBot.create(
        :valid_predicate, name: 'my custom language field', project:,
        uri: 'http://rs.tdwg.org/dwc/terms/language'
      )
      # Simulates a curator registering the predicate for CollectionObject via Project Preferences,
      # merging into the existing default rather than replacing it (the default already has both
      # 'CollectionObject' and 'CollectingEvent' keys; replacing the whole hash would drop one).
      project.preferences['model_predicate_sets']['CollectionObject'] = [@predicate.id]
      project.save!

      @import_dataset = stage_specification_file('tw_dwc_predicate_auto_mapping.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it "attaches a data attribute using the project's own predicate, reading the column matching the predicate's DwC term" do
      da = CollectionObject.first.data_attributes.first
      expect(da.predicate).to eq(@predicate)
      expect(da.value).to eq('en')
    end
  end

  context 'TW:<model_class>:<field> direct field mapping' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('tw_direct_field_mapping.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it 'sets the named CollectingEvent model field directly' do
      expect(CollectingEvent.first.verbatim_label).to eq('Some Locality, 3-IV-1999, J. Smith')
    end
  end

  context 'TW:<model_class>:<field> naming a field that is not allowed' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      FactoryBot.create(:root_taxon_name)

      @import_dataset = stage_specification_file('tw_direct_field_mapping_invalid.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'errors the row' do
      expect_row_tally(results, errored: 1)
    end

    it 'names the field and states that it is not a valid attribute for the model' do
      expect(row_error_messages(results.first, 'tw:collectingevent:not_a_real_field'))
        .to include('not_a_real_field is not a valid CollectingEvent attribute')
    end
  end

  context 'TW:Tag:<class>:<selector>' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_keyword, name: 'Reviewed', project: root.project)

      @import_dataset = stage_specification_file('tw_tag.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    it 'imports the row' do
      expect_row_tally(@results, imported: 1)
    end

    it "applies the named (pre-existing) Keyword as a tag on the CollectionObject, since the value is 'true'" do
      expect(CollectionObject.first.tags.map { |t| t.keyword.name }).to eq(['Reviewed'])
    end
  end

  context 'TW:Tag: "false" and an invalid value' do
    before :all do
      DatabaseCleaner.start

      init_housekeeping
      root = FactoryBot.create(:root_taxon_name)
      FactoryBot.create(:valid_keyword, name: 'Reviewed', project: root.project)

      @import_dataset = stage_specification_file('tw_tag_false_and_invalid.tsv')
      @results = @import_dataset.import(5000, 100)
    end

    after(:all) { DatabaseCleaner.clean }

    let(:results) { @results }

    it 'imports the "false" row without applying the tag, and errors the row with an invalid value' do
      expect_row_tally(results, imported: 1, errored: 1)
    end

    it 'creates no tags at all' do
      expect(CollectionObject.first.tags).to be_empty
    end

    it 'names the accepted values for the invalid one' do
      expect(row_error_messages(results.second, 'TW:Tag:CollectionObject:Reviewed'))
        .to include('Tag value must be "true" or "1" to apply, or blank, "false", or "0", to not apply')
    end
  end
end
