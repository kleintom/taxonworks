require 'rails_helper'

describe ::Vendor::Biodiversity, type: :model, group: [:nomenclature] do
  context 'Result' do

    let(:result) { Vendor::Biodiversity::Result.new }

    specify '#name' do
      expect( result.name = 'Aus bus').to be_truthy
    end

    specify '#project_id' do
      expect( result.project_id = 1 ).to be_truthy
    end

    specify '#nomenclature_code' do
      expect( result.nomenclature_code = :icn ).to be_truthy
    end

    context '#parseable' do
      xspecify '#parseable 1' do # Example was unparseable up to biodiversity version 5.7.2
        result.name = 'Aus bus cf. bus Smith and Jones, 1920'
        result.parse
        expect(result.parseable).to eq(false)
      end 

      specify '#parseable 2' do
        result.name = 'asdfasdfasf'
        result.parse
        expect(result.parseable).to eq(false)
      end 

      specify '#parseable 3' do
        result.name = 'valerius (Eades, 1964)'
        result.parse
        expect(result.parseable).to eq(false)
      end 
    end

    context '#genus' do
      specify 'as uninominal' do
        result.name = 'Bus'
        result.parse
        expect(result.genus).to eq('Bus')
      end

      specify 'as binominal' do
        result.name = 'Bus aus'
        result.parse
        expect(result.genus).to eq('Bus')
      end
    end

    context 'parsing' do
      let!(:root) { FactoryBot.create(:root_taxon_name) }
      let!(:genus1) { Protonym.create(name: 'Aus', parent: root, rank_class: Ranks.lookup(:iczn, :genus) ) }
      let!(:species1) { Protonym.create(name: 'bus', parent: genus1, rank_class: Ranks.lookup(:iczn, :species) ) }

      before do
        result.project_id = 1
      end

      context 'author and year' do
        specify '#author exception 1' do
          result.name = 'TyphlocybaFicocyba icaria'
          result.parse
          expect(result.author).to eq(nil)
        end

        specify '#author exception 2' do
          result.name = '(Zygina)%20nivea'
          result.parse
          expect(result.author).to eq(nil)
        end

        specify '#author for genus' do
          result.name = 'Aus Smith and Jones, 1920'
          result.parse
          result.build_result
          expect(result.author).to eq('Smith & Jones')
        end

        specify '#author for subgenus' do
          result.name = 'Aus (Bus) Smith and Jones, 1920'
          result.parse
          result.build_result
          expect(result.author).to eq('Smith & Jones')
        end

        specify '#author for species' do
          result.name = 'Aus bus Smith and Jones, 1920'
          result.parse
          result.build_result
          expect(result.author).to eq('Smith & Jones')
        end

        specify '#author for subspecies' do
          result.name = 'Aus bus cus dus Smith, 1920'
          result.parse
          result.build_result
          expect(result.author).to eq('Smith')
        end

        specify '#year for genus' do
          result.name = 'Aus Smith and Jones, 1920'
          result.parse
          result.build_result
          expect(result.year).to eq('1920')
        end

        specify '#year for subgenus' do
          result.name = 'Aus (Bus) Smith and Jones'
          result.parse
          result.build_result
          expect(result.year).to eq(nil)
        end

        specify '#year for species' do
          result.name = 'Aus bus Smith and Jones, 1920'
          result.parse
          result.build_result
          expect(result.year).to eq('1920')
        end

        specify '#year for subspecies' do
          result.name = 'Aus bus cus dus Smith, 1920'
          result.parse
          result.build_result
          expect(result.year).to eq('1920')
        end
      end

      context 'existing matches' do
        before do
          result.name = 'Aus bus Smith and Jones, 1920'
          result.parse
          result.build_result
        end

        specify '#combination_exists? 1' do
          expect(result.combination_exists?).to eq(false)
        end

        specify '#combination_exists? 2' do
          a = Combination.create!(genus: genus1, species: species1)
          expect(result.combination_exists?).to eq(a)
        end
      end

      context '#other_matches' do
        let!(:genus2) { Protonym.create!(name: 'Zus', parent: genus1, rank_class: Ranks.lookup(:iczn, :subgenus)) }
        let!(:c) { Combination.create!(genus: genus1,  species: species1, verbatim_name: 'Aus buss') }

        specify '#other_matches :subgenus' do
          result.name = 'Zus'
          result.parse
          expect(result.other_matches[:subgenus]).to include(genus2)
        end

        specify '#other_matches :verbatim' do
          result.name = 'Aus buss Smith and Jones, 1920'
          result.parse
          expect(result.other_matches[:verbatim]).to include(c)
        end

        specify '#other_matches :original_combination' do
          species1.original_genus = genus2
          species1.save!
          result.name = 'Zus bus'
          result.parse
          expect(result.other_matches[:original_combination]).to include(species1)
        end
      end

      context 'matches' do
        context 'unambiguous' do
          before do
            result.name = 'Aus bus Smith and Jones, 1920'
            result.parse
            result.build_result
          end

          let(:combination) { result.combination }

          specify '#name_count' do
            expect(result.name_count).to eq(2)
          end

          specify '#genus' do
            expect(result.genus).to eq('Aus') 
          end

          specify '#protonym_result' do
            expect(result.protonym_result[:genus]).to include(genus1)
          end

          specify '#preparse' do
            expect(result.preparse).to contain_exactly(result.name)
          end

          specify '#author_word_position' do
            expect(result.author_word_position).to eq(8)
          end

          specify '#name_without_author_year' do
            expect(result.name_without_author_year).to eq('Aus bus')
          end

          specify '#is_unambiguous?' do
            expect(result.is_unambiguous?).to eq(true)
          end

          specify '#finest_rank' do
            expect(result.finest_rank). to eq(:species)
          end

          specify '#combination genus' do
            expect(combination.genus_id).to eq(genus1.id)
          end

          specify '#combination species' do
            expect(combination.species_id).to eq(species1.id)
          end

          specify '#grouped_protonyms1' do
            expect(result.grouped_protonyms(:species)).to contain_exactly(species1)
          end
        end

        context 'match author year' do
          let!(:species3) { Protonym.create(
            name: 'bus',
            year_of_publication: '1920', 
            verbatim_author: 'Smith and Jones',
            parent: genus1, 
            rank_class: Ranks.lookup(:iczn, :species) 
          ) }

          before do
            result.name = 'Aus bus Smith and Jones, 1920'
            result.parse
            result.build_result
          end

          specify '#is_unambiguous? (still)' do
            expect(result.is_unambiguous?).to eq(true)
          end

          specify '#grouped_protonyms1' do
            expect(result.grouped_protonyms(:species)).to contain_exactly(species3)
          end
        end 

        context 'infrageneric' do
          specify '#string 1' do
            result.name = 'Aus (Bus)'
            result.parse
            expect(result.genus).to eq('Aus')
            expect(result.subgenus).to eq('Bus')
          end
        end

        context 'infraspecifics' do
          specify '#string 1' do
            result.name = 'Aus bus form cus Smith and Jones, 1920'
            result.parse
            expect(result.string('form')).to eq('cus') 
          end

          specify '#string 2' do
            result.name = 'Aus bus var. cus Smith and Jones, 1920'
            result.parse
            expect(result.string('variety')).to eq('cus') 
          end

          specify '#string 3' do
            result.name = 'Aus bus cus var. dus Smith and Jones, 1920'
            result.parse
            expect(result.string('subspecies')).to eq('cus') 
          end

          specify '#string 4' do
            result.name = 'Aus cf bus'
            result.parse
            expect(result.genus).to eq('Aus')
            expect(result.species).to eq('bus')
          end

          # Not yet handled in Biodiversity
          # specify '#string 5' do
          #  result.name = 'Aus bus cf dus'
          #  result.parse
          #  expect(result.genus).to eq('Aus')
          #  expect(result.species).to eq('bus')
          #  expect(result.subspecies).to eq('dus')
          # end

          specify '#build_result succeeds' do
            result.name = 'Aus bus form cus Smith and Jones, 1920'
            result.parse
            expect(result.build_result).to be_truthy
          end
        end
      end

      context 'species with ambiguity' do

        let!(:species2)  { Protonym.create(
          name: 'bus', 
          parent: genus1, 
          rank_class: Ranks.lookup(:iczn, :species) 
        ) }

        context 'without author checks' do
          before do
            result.name = 'Aus bus Smith and Jones, 1920'
            result.parse
            result.build_result
          end

          specify '#ambiguous_ranks' do
            expect(result.ambiguous_ranks).to contain_exactly(:species)
          end

          specify '#disambiguate_combination' do
            c = result.disambiguate_combination( { species: species2.id } )
            expect(c.genus).to eq(genus1)
            expect(c.species).to eq(species2)
          end

          specify '#disambiguated_combination' do
            c = result.disambiguate_combination( { species: species2.id } )
            expect(result.disambiguated_combination).to eq(c)
          end

          specify '#is_authored?' do
            expect(result.is_authored?).to eq(true)
          end

          specify '#is_unambiguous?' do
            expect(result.is_unambiguous?).to eq(false)
          end 

          specify 'result[:unambiguous]' do
            expect(result.result[:unambiguous]).to eq(false)
          end

          specify '#genus' do
            expect(result.genus).to eq('Aus')
          end

          specify '#species' do
            expect(result.species).to eq('bus')
          end

          specify '#author' do
            expect(result.author).to eq('Smith & Jones')
          end

          specify '#year' do
            expect(result.year).to eq('1920')
          end

          specify '#detail' do
            expect(result.detail).to include( {
              species: {
                genus: "Aus",
                species: "bus",
                authorship: {
                  verbatim: "Smith and Jones, 1920",
                  normalized: "Smith & Jones 1920",
                  year: "1920",
                  authors: ["Smith", "Jones"],
                  originalAuth: {
                    authors: ["Smith", "Jones"],
                    year: {
                      year: "1920"
                    }
                  }
                }
              }
            }) 
          end

          specify '#string1' do
            expect(result.string(:genus)).to eq('Aus')
          end

          specify '#string2' do
            expect(result.string(:species)).to eq('bus')
          end

          specify '#parse' do
            expect(result.parse[:scientificName]).to be_truthy
          end

          context 'protonyms' do
            specify '#result1' do
              expect(result.result[:protonyms][:genus]).to contain_exactly(genus1)
            end

            specify '#result2' do
              expect(result.result[:protonyms][:species]).to contain_exactly(species1, species2)
            end
          end
        end
      end

      context 'mode: grouped' do
        let!(:subgenus) { Protonym.create(name: 'Aus', parent: genus1, rank_class: Ranks.lookup(:iczn, :subgenus) ) }

        before do
          result.name = 'Aus (Aus) bus dus'
          result.parse
          result.build_result
        end 

        specify '#subspecies' do
          expect(result.subspecies).to eq('dus') 
        end

        specify '#subgenus' do
          expect(result.subgenus).to eq('Aus') 
        end

        specify '#result1' do
          expect(result.result[:protonyms][:genus]).to contain_exactly(genus1, subgenus)
        end

        specify '#result2' do
          expect(result.result[:protonyms][:subgenus]).to contain_exactly(genus1, subgenus)
        end

        specify '#combination 1' do
          c = result.combination
          expect(c.genus_id).to eq(subgenus.id)
        end

        specify '#combination 2' do
          c = result.combination
          expect(c.subgenus_id).to eq(subgenus.id)
        end
      end
    end

    context 'an unmatched result' do
      before do
        result.name = 'Zzus (Arg) plort plurt Walbert, Nordberg and Zarf, 2017'
        result.parse
        result.build_result
      end

      context 'result[:parse]' do

        specify '#name_count' do
          expect(result.name_count).to eq(4)
        end

        specify '#result1' do
          expect(result.result[:parse][:genus]).to eq('Zzus')
        end

        specify '#result2' do
          expect(result.result[:parse][:subgenus]).to eq('Arg')
        end

        specify '#result3' do
          expect(result.result[:parse][:species]).to eq('plort')
        end

        specify '#result4' do
          expect(result.result[:parse][:subspecies]).to eq('plurt')
        end
      end
    end
  end

  # Authorship strings are Catalogue of Life's (dataset 3LR, 2026-11) for
  # the name noted, unless noted otherwise.
  context '.authorship_parts' do
    def parts(authorship)
      described_class.authorship_parts(authorship)
    end

    # [parenthetical_author, parenthetical_year, author, year]
    def parts_a(authorship)
      parts(authorship)&.values_at(
        :parenthetical_author, :parenthetical_year, :author, :year
      )
    end

    specify 'splits "Linnaeus, 1758" into author and year' do
      expect(parts('Linnaeus, 1758')).to eq(
        parenthetical_author: nil, parenthetical_year: nil,
        author: 'Linnaeus', year: 1758
      )
    end

    specify 'blank authorship is nil' do
      expect(parts(nil)).to be_nil
      expect(parts('')).to be_nil
    end

    specify 'is nil when gnparser finds no authorship' do
      expect(parts('sensu Smith')).to be_nil
    end

    # gnparser cleans up its input before parsing, and author text is
    # sliced out of its cleaned-up copy. None of these were in the 2026-11
    # 3LR sample (no entities, tags or line breaks in 4716 authorships), but
    # other sources have them.
    context 'text gnparser cleans up' do
      specify 'decodes an entity between authors' do
        expect(parts_a('Castellani &amp; Chalmers, 1919'))
          .to eq([nil, nil, 'Castellani & Chalmers', 1919])
      end

      specify 'decodes named entities CGI.unescapeHTML does not' do
        expect(parts_a('H&uuml;bner, 1819'))
          .to eq([nil, nil, 'Hübner', 1819])
      end

      specify 'decodes numeric entities' do
        expect(parts_a('H&#252;bner, 1819'))
          .to eq([nil, nil, 'Hübner', 1819])
        expect(parts_a('H&#xFC;bner, 1819'))
          .to eq([nil, nil, 'Hübner', 1819])
      end

      specify 'decodes entities on both sides of a recombination' do
        expect(parts_a('(H&uuml;bner, 1819) Smith &amp; Jones, 1900'))
          .to eq(['Hübner', 1819, 'Smith & Jones', 1900])
      end

      specify 'turns non-breaking spaces into spaces' do
        expect(parts_a('Smith&nbsp;&amp;&nbsp;Jones, 1900'))
          .to eq([nil, nil, 'Smith & Jones', 1900])
      end

      specify 'removes tags' do
        expect(parts_a('<i>Smith</i>, 1900'))
          .to eq([nil, nil, 'Smith', 1900])
      end

      specify 'collapses line breaks' do
        expect(parts_a("Smith &\r\nJones, 1900"))
          .to eq([nil, nil, 'Smith & Jones', 1900])
      end

      specify 'composes decomposed characters' do
        expect(parts_a("Hu\u0308bner, 1819"))
          .to eq([nil, nil, 'Hübner', 1819])
      end

      specify 'collapses repeated spaces' do
        expect(parts_a('  Linnaeus,   1758 '))
          .to eq([nil, nil, 'Linnaeus', 1758])
      end
    end

    # Guards against a gnparser whose word positions don't match its
    # verbatim authorship text; a real one has never been seen.
    specify 'is nil rather than garbled when gnparser words are misplaced' do
      allow(::Biodiversity::Parser).to receive(:parse).and_return(
        authorship: {
          verbatim: 'Smith & Jones, 1900',
          originalAuth: { authors: %w{Smith Jones}, year: { year: '1900' } }
        },
        words: [
          { verbatim: 'Aus', wordType: 'GENUS', start: 0, end: 3 },
          { verbatim: 'bus', wordType: 'SPECIES', start: 4, end: 7 },
          { verbatim: 'Smith', wordType: 'AUTHOR_WORD', start: 8, end: 13 },
          { verbatim: 'Jones', wordType: 'AUTHOR_WORD', start: 18, end: 23 },
          { verbatim: '1900', wordType: 'YEAR', start: 25, end: 29 }
        ]
      )
      expect(parts('Smith & Jones, 1900')).to be_nil
    end

    context 'a parenthetical author' do
      # Eukaryota
      specify 'is split from the author after it, each with its year' do
        expect(parts_a('(Chatton, 1925) Whittaker & Margulis, 1978'))
          .to eq(['Chatton', 1925, 'Whittaker & Margulis', 1978])
      end

      # Pieris rapae
      specify 'with nothing after it' do
        expect(parts_a('(Linnaeus, 1758)'))
          .to eq(['Linnaeus', 1758, nil, nil])
      end

      # Picea abies
      specify 'keeps abbreviations as written' do
        expect(parts_a('(L.) H.Karst.')).to eq(['L.', nil, 'H.Karst.', nil])
      end

      # Apioideae
      specify 'keeps ex authors' do
        expect(parts_a('(Drude) Thorne ex Royen'))
          .to eq(['Drude', nil, 'Thorne ex Royen', nil])
      end

      # Astonia australiensis. gnparser reads a leading "(Aston)" after a
      # uninomial as a subgenus, so the placeholder name must be a binomial.
      specify 'with no year' do
        expect(parts_a('(Aston) S.W.L.Jacobs'))
          .to eq(['Aston', nil, 'S.W.L.Jacobs', nil])
      end

      # Escherichia coli. ICNP Rule 33b Note 3
      specify 'drops the Approved Lists annotation' do
        expect(
          parts_a(
            '(Migula, 1895) Castellani & Chalmers 1919 (Approved Lists 1980)'
          )
        ).to eq(['Migula', 1895, 'Castellani & Chalmers', 1919])
      end
    end

    context 'years' do
      # Bracketed and lettered years aren't in 3LR, which normalizes them
      # (Coenonympha is "Hübner, 1819"), but other ChecklistBank datasets can
      # carry them.
      specify 'drops a bracketed year' do
        expect(parts_a('(Hübner, [1819])')).to eq(['Hübner', 1819, nil, nil])
        expect(parts_a('Hübner, [1819]')).to eq([nil, nil, 'Hübner', 1819])
      end

      specify 'drops a year with a letter suffix' do
        expect(parts_a('(Smith, 1900a)')).to eq(['Smith', 1900, nil, nil])
      end

      # Leptoceridae. ICZN Rec. 51E
      specify 'takes the year of an "in" citation' do
        expect(parts_a('Leach in Brewster, 1815'))
          .to eq([nil, nil, 'Leach in Brewster', 1815])
      end

      # Not in the 2026-11 3LR sample; a common form for Dejean's names. The
      # author after "ex" published the name (ICN Art. 46.5, Madrid Code).
      specify 'takes the year of an "ex" citation' do
        expect(parts_a('Dejean ex Boisduval, 1829'))
          .to eq([nil, nil, 'Dejean ex Boisduval', 1829])
      end

      # Oxychilidae. A family-group name kept under ICZN Art. 40.2.1 is
      # cited with the replaced name's date in parens (Rec. 40A); the name's
      # own year is the first one.
      specify 'takes the first of two family-group years' do
        expect(parts_a('Hesse, 1927 (1879)'))
          .to eq([nil, nil, 'Hesse', 1927])
      end

      # Enterobacteriaceae. ICNP Rule 33b Note 3
      specify 'does not take the Approved Lists year' do
        expect(parts_a('Rahn, 1937 (Approved Lists 1980)'))
          .to eq([nil, nil, 'Rahn', 1937])
      end
    end

    specify 'keeps a filius abbreviation as written' do
      expect(parts_a('Hook.f. & Thomson'))
        .to eq([nil, nil, 'Hook.f. & Thomson', nil])
    end

    # gnparser finds no authorship in these yet - see the gnparser TODO on
    # .authorship_parts.
    context 'authorship gnparser can not parse yet' do
      # Yigoga signifera. ICZN Rec. 51D
      xspecify 'keeps a bracketed author' do
        expect(parts_a('[Denis & Schiffermüller], 1775'))
          .to eq([nil, nil, '[Denis & Schiffermüller]', 1775])
      end

      # Yezognophos serotinaria
      xspecify 'keeps a bracketed parenthetical author' do
        expect(parts_a('([Denis & Schiffermüller], 1775)'))
          .to eq(['[Denis & Schiffermüller]', 1775, nil, nil])
      end

      # Anaerosinus
      xspecify 'splits an author with an accented letter' do
        expect(parts_a('Strömpl et al., 1999'))
          .to eq([nil, nil, 'Strömpl et al.', 1999])
      end

      # Agathotanais frutosae
      xspecify 'splits authors with Polish letters' do
        expect(parts_a('Stępień, Jakiel & Błażewicz, 2022'))
          .to eq([nil, nil, 'Stępień, Jakiel & Błażewicz', 2022])
      end

      # Jahnella thaxteri. A revived name (cited per ICNP Rule 33c Note 2) is
      # authored by its reviver and its priority dates from the revival (Rule
      # 28a, Note 2): the year after the parenthetical. (Reading the
      # parenthetical as a recombination, as
      # Protonym.verbatim_author_and_year does, is wrong for these.)
      xspecify 'finds the reviver\'s year after the parenthetical' do
        expect(parts('(ex Jahn, 1924) Reichenbach 2007')[:year]).to eq(2007)
      end

      # Jurundurella
      xspecify 'takes a parenthesized year after "in"' do
        expect(parts_a('Gellert, Błażewicz & Bird in Gellert et al. (2023)'))
          .to eq(
            [nil, nil, 'Gellert, Błażewicz & Bird in Gellert et al.', 2023]
          )
      end
    end
  end
end
