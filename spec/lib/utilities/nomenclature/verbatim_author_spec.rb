require 'rails_helper'

describe Utilities::Nomenclature::VerbatimAuthor do
  let(:v) { Utilities::Nomenclature::VerbatimAuthor }

  # Parts of the Catalogue of Life citations (dataset 3LR, 2026-11) for the
  # name noted.
  context 'a name in its original combination' do
    specify 'is the original author, whatever the code' do
      %i{iczn icn icnp icvcn}.each do |code|
        expect(
          v.build(
            original_author: 'Dejean ex Boisduval', nomenclatural_code: code
          )
        ).to eq('Dejean ex Boisduval')
      end
    end
  end

  specify 'no original author is nil' do
    expect(
      v.build(
        original_author: nil, recombination: true, nomenclatural_code: :iczn
      )
    ).to be_nil
  end

  # ICZN Art. 51.3, Rec. 51G
  context ':iczn recombination' do
    # Eukaryota
    specify 'wraps the original author and drops the combination author' do
      expect(
        v.build(
          original_author: 'Chatton',
          combination_author: 'Whittaker & Margulis',
          recombination: true, nomenclatural_code: :iczn
        )
      ).to eq('(Chatton)')
    end
  end

  # ICN Art. 49.1
  context ':icn recombination' do
    # Apioideae
    specify 'is the whole citation' do
      expect(
        v.build(
          original_author: 'Drude', combination_author: 'Thorne ex Royen',
          recombination: true, nomenclatural_code: :icn
        )
      ).to eq('(Drude) Thorne ex Royen')
    end

    specify 'with no combination author is just the wrapped original' do
      expect(
        v.build(
          original_author: 'Moench', recombination: true,
          nomenclatural_code: :icn
        )
      ).to eq('(Moench)')
    end
  end

  # ICNP Rules 34b, 34c
  context ':icnp recombination' do
    # Escherichia coli
    specify 'is the whole citation' do
      expect(
        v.build(
          original_author: 'Migula',
          combination_author: 'Castellani & Chalmers',
          recombination: true, nomenclatural_code: :icnp
        )
      ).to eq('(Migula) Castellani & Chalmers')
    end
  end

  specify 'an unknown code gets the unwrapped original author' do
    expect(
      v.build(
        original_author: 'Linnaeus', recombination: true,
        nomenclatural_code: nil
      )
    ).to eq('Linnaeus')
  end
end
