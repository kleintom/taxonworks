require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

describe OtuPageLayoutSectionsController, type: :controller do
  before(:each) {
    sign_in
  }

  # This should return the minimal set of attributes required to create a valid
  # OtuPageLayoutSection. As you add validations to OtuPageLayoutSection, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { strip_housekeeping_attributes( FactoryBot.build(:valid_otu_page_layout_section).attributes) }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # OtuPageLayoutSectionsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  before {
    request.env['HTTP_REFERER'] = list_otus_path # logical example
  }

  describe 'POST create' do
    describe 'with valid params' do
      it 'creates a new OtuPageLayoutSection' do
        expect {
          post :create, params: {otu_page_layout_section: valid_attributes}, session: valid_session
        }.to change(OtuPageLayoutSection, :count).by(1)
      end

      it 'assigns a newly created otu_page_layout_section as @otu_page_layout_section' do
        post :create, params: {otu_page_layout_section: valid_attributes}, session: valid_session
        expect(assigns(:otu_page_layout_section)).to be_a(OtuPageLayoutSection)
        expect(assigns(:otu_page_layout_section)).to be_persisted
      end

      it 'redirects to :back' do
        post :create, params: {otu_page_layout_section: valid_attributes}, session: valid_session
        expect(response).to redirect_to(list_otus_path)
      end
    end

    describe 'with invalid params' do
      it 'assigns a newly created but unsaved otu_page_layout_section as @otu_page_layout_section' do
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(OtuPageLayoutSection).to receive(:save).and_return(false)
        post :create, params: {otu_page_layout_section: {:invalid => 'parms'}}, session: valid_session
        expect(assigns(:otu_page_layout_section)).to be_a_new(OtuPageLayoutSection)
      end

      it 're-renders the :back template' do
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(OtuPageLayoutSection).to receive(:save).and_return(false)
        post :create, params: {otu_page_layout_section: {:invalid => 'parms'}}, session: valid_session
        expect(response).to redirect_to(list_otus_path)
      end
    end
  end

  describe 'PUT update' do

    describe 'with valid params' do
      it 'updates the requested otu_page_layout_section' do
        otu_page_layout_section = OtuPageLayoutSection.create! valid_attributes
        # Assuming there are no other otu_page_layout_sections in the database, this
        # specifies that the OtuPageLayoutSection created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        t = FactoryBot.create(:random_controlled_vocabulary_term, type: 'Topic')
        update_params = ActionController::Parameters.new({topic_id: t.id.to_s}).permit(:topic_id)
        expect_any_instance_of(OtuPageLayoutSection).to receive(:update).with(update_params)
        put :update, params: {id: otu_page_layout_section.to_param, otu_page_layout_section: update_params}, session: valid_session
      end

      it 'assigns the requested otu_page_layout_section as @otu_page_layout_section' do
        otu_page_layout_section = OtuPageLayoutSection.create! valid_attributes
        put :update, params: {id: otu_page_layout_section.to_param, otu_page_layout_section: valid_attributes}, session: valid_session
        expect(assigns(:otu_page_layout_section)).to eq(otu_page_layout_section)
      end

      it 'redirects to :back' do
        otu_page_layout_section = OtuPageLayoutSection.create! valid_attributes
        put :update, params: {id: otu_page_layout_section.to_param, otu_page_layout_section: valid_attributes}, session: valid_session
        expect(response).to redirect_to(list_otus_path)
      end
    end

    describe 'with invalid params' do
      it 'assigns the otu_page_layout_section as @otu_page_layout_section' do
        otu_page_layout_section = OtuPageLayoutSection.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(OtuPageLayoutSection).to receive(:save).and_return(false)
        put :update, params: {id: otu_page_layout_section.to_param, otu_page_layout_section: {:invalid => 'parms'}}, session: valid_session
        expect(assigns(:otu_page_layout_section)).to eq(otu_page_layout_section)
      end

      it 're-renders the :back template' do
        otu_page_layout_section = OtuPageLayoutSection.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(OtuPageLayoutSection).to receive(:save).and_return(false)
        put :update, params: {id: otu_page_layout_section.to_param, otu_page_layout_section: {:invalid => 'parms'}}, session: valid_session
        expect(response).to redirect_to(list_otus_path)
      end
    end
  end

  describe 'DELETE destroy' do
    it 'destroys the requested otu_page_layout_section' do
      otu_page_layout_section = OtuPageLayoutSection.create! valid_attributes
      expect {
        delete :destroy, params: {id: otu_page_layout_section.to_param}, session: valid_session
      }.to change(OtuPageLayoutSection, :count).by(-1)
    end

    it 'redirects to :back' do
      otu_page_layout_section = OtuPageLayoutSection.create! valid_attributes
      delete :destroy, params: {id: otu_page_layout_section.to_param}, session: valid_session
      expect(response).to redirect_to(list_otus_path)
    end
  end

end
