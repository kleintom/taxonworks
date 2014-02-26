require 'spec_helper'

describe GeographicAreaType do
  let(:geographic_area_type) {FactoryGirl.build(:geographic_area_type)}
  context 'associations' do
    context 'has_many' do
      specify 'geographic_areas' do
        expect(geographic_area_type).to respond_to(:geographic_areas)
      end
    end
  end

  context 'validation' do
    before(:each) {
      geographic_area_type.valid?
    }
    specify 'name' do
      expect(geographic_area_type.errors.include?(:name)).to be_true
    end
  
    specify 'only a name is required' do
      geographic_area_type.name = 'Country'
      expect(geographic_area_type.save).to be_true
    end 
  end
end
