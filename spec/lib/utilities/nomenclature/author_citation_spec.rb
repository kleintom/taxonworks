require 'rails_helper'

describe Utilities::Nomenclature::AuthorCitation do
  let(:v) { Utilities::Nomenclature::AuthorCitation }

  # Parts of the Catalogue of Life citations (dataset 3LR, 2026-11) for the
  # name noted.
  context '.from_parts' do
    def parts(parenthetical_author: nil, parenthetical_year: nil,
      author: nil, year: nil)
      { parenthetical_author:, parenthetical_year:, author:, year: }
    end

    context 'a name in its original combination' do
      specify 'is the author as written, whatever the code' do
        %i{iczn icn icnp icvcn}.each do |code|
          expect(
            v.from_parts(
              code, **parts(author: 'Dejean ex Boisduval', year: 1829)
            )
          ).to eq(['Dejean ex Boisduval', 1829])
        end
      end

      specify 'takes current_combination_year when the citation has none' do
        expect(
          v.from_parts(
            :iczn, **parts(author: 'Linnaeus'), current_combination_year: 1758
          )
        ).to eq(['Linnaeus', 1758])
      end

      specify 'prefers the citation\'s own year' do
        expect(
          v.from_parts(
            :iczn, **parts(author: 'Linnaeus', year: 1758),
            current_combination_year: 1900
          )
        ).to eq(['Linnaeus', 1758])
      end
    end

    # Eukaryota
    context 'a recombination' do
      let(:chatton) {
        parts(
          parenthetical_author: 'Chatton', parenthetical_year: 1925,
          author: 'Whittaker & Margulis', year: 1978
        )
      }

      specify 'is cited by the code, with the original name\'s year' do
        expect(v.from_parts(:iczn, **chatton))
          .to eq(['(Chatton)', 1925])
        expect(v.from_parts(:icn, **chatton))
          .to eq(['(Chatton) Whittaker & Margulis', 1925])
      end

      specify 'never takes current_combination_year' do
        expect(
          v.from_parts(
            :icn,
            **parts(parenthetical_author: 'Moench', author: 'Voss'),
            current_combination_year: 1890
          )
        ).to eq(['(Moench) Voss', nil])
      end
    end

    specify 'no author is nil' do
      expect(v.from_parts(:iczn, **parts)).to eq([nil, nil])
    end
  end

  context '.citation' do
    context ':iczn' do
      specify 'joins author and year' do
        expect(v.citation(:iczn, 'Linnaeus', 1758, recombination: false))
          .to eq('Linnaeus, 1758')
      end

      specify 'wraps both for a recombination' do
        expect(v.citation(:iczn, 'Linnaeus', 1758, recombination: true))
          .to eq('(Linnaeus, 1758)')
      end

      specify 'unwraps a stored recombination form before adding the year' do
        expect(
          v.citation(:iczn, '(Linnaeus)', 1758, recombination: true)
        ).to eq('(Linnaeus, 1758)')
      end

      # e.g. a genus-group name: parentheses are for species-group names.
      specify 'drops a stored recombination form when it isn\'t one' do
        expect(
          v.citation(:iczn, '(Linnaeus)', 1758, recombination: false)
        ).to eq('Linnaeus, 1758')
      end

      specify 'with no year is the author' do
        expect(v.citation(:iczn, 'Linnaeus', nil, recombination: true))
          .to eq('(Linnaeus)')
      end

      specify 'with no author is the year' do
        expect(v.citation(:iczn, nil, 1758, recombination: false))
          .to eq('1758')
      end

      specify 'with neither is empty' do
        expect(v.citation(:iczn, nil, nil, recombination: true)).to eq('')
      end

      # THAUMALEIDAE, Art. 40.2.1, Rec. 40A.
      context 'with a priority_year' do
        specify 'cites it after the year' do
          expect(
            v.citation(
              :iczn, 'Bezzi', 1913, recombination: false, priority_year: 1847
            )
          ).to eq('Bezzi, 1913 [1847]')
        end

        specify 'not when it\'s the year' do
          expect(
            v.citation(
              :iczn, 'Bezzi', 1913, recombination: false, priority_year: 1913
            )
          ).to eq('Bezzi, 1913')
        end

        specify 'cites it with no year' do
          expect(
            v.citation(
              :iczn, 'Bezzi', nil, recombination: false, priority_year: 1847
            )
          ).to eq('Bezzi [1847]')
        end
      end
    end

    specify 'is only written for :iczn' do
      expect {
        v.citation(:icn, 'Moench', 1794, recombination: false)
      }.to raise_error(ArgumentError)
    end
  end

  # ICN Art. 46.5 Ex. 32
  context '.ex' do
    specify 'puts the ascribed author before the publishing author' do
      expect(v.ex(:icn, 'Nutt.', 'Seem.')).to eq('Nutt. ex Seem.')
    end

    specify 'with no ascribed author is the publishing author' do
      [nil, '', ' '].each do |a|
        expect(v.ex(:icn, a, 'Seem.')).to eq('Seem.')
      end
    end

    specify 'goes inside the parentheses of a recombination' do
      expect(v.recombination(:icn, v.ex(:icn, 'Douglas', 'D. Don'), 'Lindl.'))
        .to eq('(Douglas ex D. Don) Lindl.')
    end

    specify 'is only written for :icn' do
      expect { v.ex(:iczn, 'Nutt.', 'Seem.') }.to raise_error(ArgumentError)
    end
  end

  context '.misapplication' do
    # Bocchar leucaspis, a misapplication of Leptocentrus leucaspis.
    specify ':iczn cites the name as established with its year' do
      expect(v.misapplication(:iczn, 'Melichar, 1905', 'Walker', 1858))
        .to eq('Melichar, 1905 non Walker, 1858')
    end

    specify ':icn cites the name as established without a year' do
      expect(v.misapplication(:icn, 'De Wild.', 'Vahl'))
        .to eq('De Wild. non Vahl')
    end

    specify 'with no author is the citation' do
      [nil, '', ' '].each do |a|
        expect(v.misapplication(:iczn, 'Melichar, 1905', a, 1858))
          .to eq('Melichar, 1905')
      end
    end

    specify 'is only written for :iczn and :icn' do
      expect {
        v.misapplication(:icnp, 'Smith', 'Jones')
      }.to raise_error(ArgumentError)
    end
  end

  context '.recombination' do
    specify 'an empty original author is returned as-is' do
      expect(v.recombination(:iczn, '')).to eq('')
      expect(v.recombination(:icn, '', 'Voss')).to eq('')
    end

    specify 'no original author is nil' do
      expect(v.recombination(:iczn, nil)).to be_nil
    end

    # ICZN Art. 51.3, Rec. 51G
    context ':iczn' do
      # Eukaryota
      specify 'wraps the original author and drops the combination author' do
        expect(v.recombination(:iczn, 'Chatton', 'Whittaker & Margulis'))
          .to eq('(Chatton)')
      end

      specify 'keeps an original author\'s year inside' do
        expect(v.recombination(:iczn, 'Linnaeus, 1758'))
          .to eq('(Linnaeus, 1758)')
      end
    end

    # ICN Art. 49.1
    context ':icn' do
      # Apioideae
      specify 'is the whole citation' do
        expect(v.recombination(:icn, 'Drude', 'Thorne ex Royen'))
          .to eq('(Drude) Thorne ex Royen')
      end

      specify 'with no combination author is just the wrapped original' do
        expect(v.recombination(:icn, 'Moench')).to eq('(Moench)')
      end
    end

    # ICNP Rules 34b, 34c
    # Escherichia coli
    specify ':icnp is the whole citation' do
      expect(v.recombination(:icnp, 'Migula', 'Castellani & Chalmers'))
        .to eq('(Migula) Castellani & Chalmers')
    end

    # The ICVCN has no rules on citing authors; cited as the ICN is.
    specify ':icvcn is cited as :icn' do
      expect(v.recombination(:icvcn, 'Smith', 'Jones')).to eq('(Smith) Jones')
    end

    specify 'an unknown code gets the unwrapped original author' do
      expect(v.recombination(nil, 'Linnaeus')).to eq('Linnaeus')
    end
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

  # Citations from real names.
  context '.original_author_year' do
    {
      iczn: { '(Baker, 1899)' => 'Baker, 1899' },
      icn: {
        '(Seub.) Lowden' => 'Seub.',
        '(Douglas ex D. Don) Lindley (1833)' => 'Douglas ex D. Don',
        '(Wall.) (1831)' => 'Wall.'
      },
      icnp: { '(Migula) Castellani & Chalmers' => 'Migula' },
      icvcn: { '(Migula) Castellani & Chalmers' => 'Migula' }
    }.each do |code, citations|
      citations.each do |citation, expected|
        specify "#{code.inspect} #{citation} -> #{expected}" do
          expect(v.original_author_year(code, citation)).to eq(expected)
        end
      end
    end

    {
      iczn: ['Baker, 1899', '(Baker, 1899) non Gillette, 1898'],
      icn: [
        'auct. non (L.) Benth.', 'Retz. (fruit)',
        'Moench (pro sp.) [deltoides × nigra]', 'Lemmon (1892)'
      ],
      nil => ['(Baker, 1899)']
    }.each do |code, citations|
      citations.each do |citation|
        specify "#{code.inspect} #{citation} is returned as-is" do
          expect(v.original_author_year(code, citation)).to eq(citation)
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
end
