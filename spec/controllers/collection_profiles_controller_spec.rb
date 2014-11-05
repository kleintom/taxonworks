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

describe CollectionProfilesController, :type => :controller do
  before(:each) {
    sign_in
  }

  # This should return the minimal set of attributes required to create a valid
  # CollectionProfile. As you add validations to CollectionProfile, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { strip_housekeeping_attributes(FactoryGirl.build(:valid_collection_profile).attributes) }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # CollectionProfilesController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET index" do
    it "assigns all collection_profiles as @collection_profiles" do
      collection_profile = CollectionProfile.create! valid_attributes
      get :index, {}, valid_session
      expect(assigns(:collection_profiles)).to eq([collection_profile])
    end
  end

  describe "GET show" do
    it "assigns the requested collection_profile as @collection_profile" do
      collection_profile = CollectionProfile.create! valid_attributes
      get :show, {:id => collection_profile.to_param}, valid_session
      expect(assigns(:collection_profile)).to eq(collection_profile)
    end
  end

  describe "GET new" do
    it "assigns a new collection_profile as @collection_profile" do
      get :new, {}, valid_session
      expect(assigns(:collection_profile)).to be_a_new(CollectionProfile)
    end
  end

  describe "GET edit" do
    it "assigns the requested collection_profile as @collection_profile" do
      collection_profile = CollectionProfile.create! valid_attributes
      get :edit, {:id => collection_profile.to_param}, valid_session
      expect(assigns(:collection_profile)).to eq(collection_profile)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new CollectionProfile" do
        expect {
          post :create, {:collection_profile => valid_attributes}, valid_session
        }.to change(CollectionProfile, :count).by(1)
      end

      it "assigns a newly created collection_profile as @collection_profile" do
        post :create, {:collection_profile => valid_attributes}, valid_session
        expect(assigns(:collection_profile)).to be_a(CollectionProfile)
        expect(assigns(:collection_profile)).to be_persisted
      end

      it "redirects to the created collection_profile" do
        post :create, {:collection_profile => valid_attributes}, valid_session
        expect(response).to redirect_to(CollectionProfile.last)
      end
    end

    describe 'with invalid params' do
      it 'assigns a newly created but unsaved collection_profile as @collection_profile' do
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(CollectionProfile).to receive(:save).and_return(false)
        post :create, {:collection_profile => {:invalid => 'parms'}}, valid_session
        expect(assigns(:collection_profile)).to be_a_new(CollectionProfile)
      end

      it 're-renders the \'new\' template' do
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(CollectionProfile).to receive(:save).and_return(false)
        post :create, {:collection_profile => {:invalid => 'parms'}}, valid_session
        expect(response).to render_template('new')
      end
    end
  end

  describe 'PUT update' do
    describe 'with valid params' do
      let(:otu) {FactoryGirl.create(:valid_otu) } 
      it 'updates the requested collection_profile' do
        collection_profile = CollectionProfile.create! valid_attributes
        # Assuming there are no other collection_profiles in the database, this
        # specifies that the CollectionProfile created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        expect_any_instance_of(CollectionProfile).to receive(:update).with({'otu_id' => otu.id.to_s})
        put :update, {:id => collection_profile.to_param, :collection_profile => {otu_id: otu.id}}, valid_session
      end

      it "assigns the requested collection_profile as @collection_profile" do
        collection_profile = CollectionProfile.create! valid_attributes
        put :update, {:id => collection_profile.to_param, :collection_profile => valid_attributes}, valid_session
        expect(assigns(:collection_profile)).to eq(collection_profile)
      end

      it "redirects to the collection_profile" do
        collection_profile = CollectionProfile.create! valid_attributes
        put :update, {:id => collection_profile.to_param, :collection_profile => valid_attributes}, valid_session
        expect(response).to redirect_to(collection_profile)
      end
    end

    describe "with invalid params" do
      it "assigns the collection_profile as @collection_profile" do
        collection_profile = CollectionProfile.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(CollectionProfile).to receive(:save).and_return(false)
        put :update, {:id => collection_profile.to_param, :collection_profile => {:invalid => 'parms'}}, valid_session
        expect(assigns(:collection_profile)).to eq(collection_profile)
      end

      it "re-renders the 'edit' template" do
        collection_profile = CollectionProfile.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        allow_any_instance_of(CollectionProfile).to receive(:save).and_return(false)
        put :update, {:id => collection_profile.to_param, :collection_profile => {:invalid => 'parms'}}, valid_session
        expect(response).to render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested collection_profile" do
      collection_profile = CollectionProfile.create! valid_attributes
      expect {
        delete :destroy, {:id => collection_profile.to_param}, valid_session
      }.to change(CollectionProfile, :count).by(-1)
    end

    it "redirects to the collection_profiles list" do
      collection_profile = CollectionProfile.create! valid_attributes
      delete :destroy, {:id => collection_profile.to_param}, valid_session
      expect(response).to redirect_to(collection_profiles_url)
    end
  end

end
