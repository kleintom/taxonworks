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

describe OtuPageLayoutsController, :type => :controller do
  before(:each) {
    sign_in
  }

  # This should return the minimal set of attributes required to create a valid
  # OtuPageLayout. As you add validations to OtuPageLayout, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { strip_housekeeping_attributes(FactoryBot.build(:valid_otu_page_layout).attributes) }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # OtuPageLayoutsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe 'GET index' do
    it 'assigns all otu_page_layouts as @recent_objects' do
      otu_page_layout = OtuPageLayout.create! valid_attributes
      get :index, params: {}, session: valid_session
      expect(assigns(:recent_objects)).to eq([otu_page_layout])
    end
  end

  describe 'GET show' do
    it 'assigns the requested otu_page_layout as @otu_page_layout' do
      otu_page_layout = OtuPageLayout.create! valid_attributes
      get :show, params: {id: otu_page_layout.to_param}, session: valid_session
      expect(assigns(:otu_page_layout)).to eq(otu_page_layout)
    end
  end

  describe 'GET new' do
    it 'assigns a new otu_page_layout as @otu_page_layout' do
      get :new, params: {}, session: valid_session
      expect(assigns(:otu_page_layout)).to be_a_new(OtuPageLayout)
    end
  end

  describe 'GET edit' do
    it 'assigns the requested otu_page_layout as @otu_page_layout' do
      otu_page_layout = OtuPageLayout.create! valid_attributes
      get :edit, params: {id: otu_page_layout.to_param}, session: valid_session
      expect(assigns(:otu_page_layout)).to eq(otu_page_layout)
    end
  end

  describe 'POST create' do
    describe 'with valid params' do
      it 'creates a new OtuPageLayout' do
        expect {
          post :create, params: {otu_page_layout: valid_attributes}, session: valid_session
        }.to change(OtuPageLayout, :count).by(1)
      end

      it 'assigns a newly created otu_page_layout as @otu_page_layout' do
        post :create, params: {otu_page_layout: valid_attributes}, session: valid_session
        expect(assigns(:otu_page_layout)).to be_a(OtuPageLayout)
        expect(assigns(:otu_page_layout)).to be_persisted
      end

      it 'redirects to the created otu_page_layout' do
        post :create, params: {otu_page_layout: valid_attributes}, session: valid_session
        expect(response).to redirect_to(OtuPageLayout.last)
      end
    end

    describe 'with invalid params' do
      it 'assigns a newly created but unsaved otu_page_layout as @otu_page_layout' do
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(OtuPageLayout).to receive(:save).and_return(false)
        post :create, params: {otu_page_layout: {:invalid => 'parms'}}, session: valid_session
        expect(assigns(:otu_page_layout)).to be_a_new(OtuPageLayout)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(OtuPageLayout).to receive(:save).and_return(false)
        post :create, params: {otu_page_layout: {:invalid => 'parms'}}, session: valid_session
        expect(response).to render_template('new')
      end
    end
  end

  describe 'PUT update' do
    describe 'with valid params' do
      it 'updates the requested otu_page_layout' do
        otu_page_layout = OtuPageLayout.create! valid_attributes
        # Assuming there are no other otu_page_layouts in the database, this
        # specifies that the OtuPageLayout created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        update_params = ActionController::Parameters.new({name: 'sunshine'}).permit(:name)
        expect_any_instance_of(OtuPageLayout).to receive(:update).with(update_params)
        put :update, params: {id: otu_page_layout.to_param, otu_page_layout: {name: 'sunshine'}}, session: valid_session
      end

      it 'assigns the requested otu_page_layout as @otu_page_layout' do
        otu_page_layout = OtuPageLayout.create! valid_attributes
        put :update, params: {id: otu_page_layout.to_param, otu_page_layout: valid_attributes}, session: valid_session
        expect(assigns(:otu_page_layout)).to eq(otu_page_layout)
      end

      it 'redirects to the otu_page_layout' do
        otu_page_layout = OtuPageLayout.create! valid_attributes
        put :update, params: {id: otu_page_layout.to_param, otu_page_layout: valid_attributes}, session: valid_session
        expect(response).to redirect_to(otu_page_layout)
      end
    end

    describe 'with invalid params' do
      it 'assigns the otu_page_layout as @otu_page_layout' do
        otu_page_layout = OtuPageLayout.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(OtuPageLayout).to receive(:save).and_return(false)
        put :update, params: {id: otu_page_layout.to_param, otu_page_layout: {:invalid => 'parms'}}, session: valid_session
        expect(assigns(:otu_page_layout)).to eq(otu_page_layout)
      end

      it "re-renders the 'edit' template" do
        otu_page_layout = OtuPageLayout.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(OtuPageLayout).to receive(:save).and_return(false)
        put :update, params: {id: otu_page_layout.to_param, otu_page_layout: {:invalid => 'parms'}}, session: valid_session
        expect(response).to render_template('edit')
      end
    end
  end

  describe 'DELETE destroy' do
    it 'destroys the requested otu_page_layout' do
      otu_page_layout = OtuPageLayout.create! valid_attributes
      expect {
        delete :destroy, params: {id: otu_page_layout.to_param}, session: valid_session
      }.to change(OtuPageLayout, :count).by(-1)
    end

    it 'redirects to the otu_page_layouts list' do
      otu_page_layout = OtuPageLayout.create! valid_attributes
      delete :destroy, params: {id: otu_page_layout.to_param}, session: valid_session
      expect(response).to redirect_to(otu_page_layouts_url)
    end
  end

end
