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
end
