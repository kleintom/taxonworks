require 'rails_helper'

describe 'TaxonDeterminations', :type => :feature do
  let(:page_index_name) { 'taxon determinations' }
  let(:index_path) { taxon_determinations_path }

  it_behaves_like 'a_login_required_and_project_selected_controller'

  context 'signed in as a user, with some records created' do
    before {
      sign_in_user_and_select_project
# todo @mjy, need to build object explicitly with user and project
#       10.times { factory_girl_create_for_user_and_project(:valid_taxon_determination, @user, @project) }
    }

    describe 'GET /taxon_determinations' do
    before {
      visit taxon_determinations_path }

    it_behaves_like 'a_data_model_with_standard_index'
  end

    # todo @mjy, following lines commented out until we can create a valid object
    # describe 'GET /taxon_determinations/list' do
    #   before { visit list_taxon_determinations_path }
    #
    #   it_behaves_like 'a_data_model_with_standard_list'
    # end
    #
    # describe 'GET /taxon_determinations/n' do
    #   before {
    #     visit taxon_determination_path(TaxonDetermination.second)
    #   }
    #
    #   it_behaves_like 'a_data_model_with_standard_show'
    # end
  end
end