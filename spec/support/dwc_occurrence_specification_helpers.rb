module DwcOccurrenceSpecificationHelpers
  # Stages a fixture from spec/files/import_datasets/occurrences/specification/.
  def stage_specification_file(file_name, import_settings: {})
    ImportDataset::DarwinCore::Occurrences.create!(
      source: fixture_file_upload(Rails.root + "spec/files/import_datasets/occurrences/specification/#{file_name}", 'text/plain'),
      description: file_name,
      import_settings:
    ).tap(&:stage)
  end

  # expect_row_tally(results, imported: 2, errored: 1)
  def expect_row_tally(results, imported: 0, errored: 0, not_ready: 0, unsupported: 0)
    tally = results.map(&:status).tally
    expect(tally.fetch('Imported', 0)).to eq(imported)
    expect(tally.fetch('Errored', 0)).to eq(errored)
    expect(tally.fetch('NotReady', 0)).to eq(not_ready)
    expect(tally.fetch('Unsupported', 0)).to eq(unsupported)
    expect(results.length).to eq(imported + errored + not_ready + unsupported)
  end

  # row_error_messages(results.first, :scientificName) => ['Multiple matches found ...']
  def row_error_messages(row, field)
    row.metadata.dig('error_data', 'messages', field.to_s) || []
  end
end
