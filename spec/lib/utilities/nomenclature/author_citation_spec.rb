require 'rails_helper'

describe Utilities::Nomenclature::AuthorCitation do
  let(:v) { Utilities::Nomenclature::AuthorCitation }

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

  context '.recombination' do
    specify 'is build for a recombination' do
      expect(v.recombination(:icn, 'Moench', 'Voss')).to eq('(Moench) Voss')
      expect(v.recombination(:iczn, 'Chatton')).to eq('(Chatton)')
    end

    specify 'an empty original author is returned as-is' do
      expect(v.recombination(:iczn, '')).to eq('')
      expect(v.recombination(:icn, '', 'Voss')).to eq('')
    end
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

  # The ICVCN has no rules on citing authors; cited as the ICN is.
  specify 'an :icvcn recombination is cited as an :icn one' do
    expect(
      v.build(
        original_author: 'Smith', combination_author: 'Jones',
        recombination: true, nomenclatural_code: :icvcn
      )
    ).to eq('(Smith) Jones')
  end

  specify 'an :iczn original author with its year keeps the year inside' do
    expect(
      v.build(
        original_author: 'Linnaeus, 1758', recombination: true,
        nomenclatural_code: :iczn
      )
    ).to eq('(Linnaeus, 1758)')
  end

  context '.recombination_form?' do
    specify 'a citation leading with a parenthetical' do
      [
        '(Linnaeus, 1758)', '(Moench) Voss',
        '(Sahlberg, 1871) non Boheman, 1852'
      ].each { |c| expect(v.recombination_form?(c)).to be true }
    end

    specify 'any other citation' do
      ['Linnaeus, 1758', 'auct. non (L.) Benth.', 'Retz. (fruit)']
        .each { |c| expect(v.recombination_form?(c)).to be false }
    end
  end

  context '.interpret' do
    # Eukaryota
    specify 'a parenthetical author is the original author of a ' \
      'recombination' do
      expect(
        v.interpret(
          parenthetical_author: 'Chatton', parenthetical_year: 1925,
          author: 'Whittaker & Margulis', year: 1978
        )
      ).to eq(
        original_author: 'Chatton', original_year: 1925,
        combination_author: 'Whittaker & Margulis', recombination: true
      )
    end

    specify 'with no parenthetical author, the author is the original ' \
      'author' do
      expect(
        v.interpret(
          parenthetical_author: nil, parenthetical_year: nil,
          author: 'Linnaeus', year: 1758
        )
      ).to eq(
        original_author: 'Linnaeus', original_year: 1758,
        combination_author: nil, recombination: false
      )
    end
  end

  # Citations from real names.
  context '.original_author' do
    {
      iczn: {
        '(Baker, 1899)' => 'Baker, 1899',
        '(Baker, 1899) non Gillette, 1898' => nil,
        'Baker, 1899' => nil
      },
      icn: {
        '(Seub.) Lowden' => 'Seub.',
        '(Douglas ex D. Don) Lindley (1833)' => 'Douglas ex D. Don',
        '(Wall.) (1831)' => 'Wall.',
        'auct. non (L.) Benth.' => nil,
        'Retz. (fruit)' => nil,
        'Moench (pro sp.) [deltoides × nigra]' => nil,
        'Lemmon (1892)' => nil
      },
      icnp: { '(Migula) Castellani & Chalmers' => 'Migula' },
      icvcn: { '(Migula) Castellani & Chalmers' => 'Migula' },
      nil => { '(Baker, 1899)' => nil }
    }.each do |code, citations|
      citations.each do |citation, expected|
        specify "#{code.inspect} #{citation} -> #{expected.inspect}" do
          expect(v.original_author(code, citation)).to eq(expected)
        end
      end
    end
  end

  context '.well_formed?' do
    specify ':iczn and no code allow wholly parenthesized or no parens' do
      [:iczn, nil].each do |code|
        %w{(Chatton) Chatton}.each do |a|
          expect(v.well_formed?(a, nomenclatural_code: code)).to be true
        end
        ['(Chatton', 'Chatton)', '(Chatton) Whittaker'].each do |a|
          expect(v.well_formed?(a, nomenclatural_code: code)).to be false
        end
      end
    end

    specify 'codes that cite the combination author allow anything' do
      %i{icn icnp icvcn}.each do |code|
        ['(Migula) Castellani & Chalmers', '(Migula'].each do |a|
          expect(v.well_formed?(a, nomenclatural_code: code)).to be true
        end
      end
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
