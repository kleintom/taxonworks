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

RSpec.describe ProtocolRelationshipsController, type: :controller do
  before(:each){
    sign_in
  }

  # This should return the minimal set of attributes required to create a valid
  # ProtocolRelationship. As you add validations to ProtocolRelationship, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    strip_housekeeping_attributes(FactoryBot.build(:valid_protocol_relationship).attributes)
  }

  let(:invalid_attributes) {
    {protocol_id: nil, protocol_relationship_object_id: nil, protocol_relationship_object_type: nil}
  }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # ProtocolRelationshipsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe 'GET #index' do
    it 'assigns all protocol_relationships as @protocol_relationships' do
      protocol_relationship = ProtocolRelationship.create! valid_attributes
      get :index, params: {}, session: valid_session
      expect(assigns(:recent_objects)).to eq([protocol_relationship])
    end
  end

  describe 'GET #show' do
    it 'assigns the requested protocol_relationship as @protocol_relationship' do
      protocol_relationship = ProtocolRelationship.create! valid_attributes
      get :show, params: {id: protocol_relationship.to_param}, session: valid_session
      expect(assigns(:protocol_relationship)).to eq(protocol_relationship)
    end
  end

  describe 'GET #new' do
    it 'assigns a new protocol_relationship as @protocol_relationship' do
      get :new, params: {}, session: valid_session
      expect(assigns(:protocol_relationship)).to be_a_new(ProtocolRelationship)
    end
  end

  describe 'GET #edit' do
    it 'assigns the requested protocol_relationship as @protocol_relationship' do
      protocol_relationship = ProtocolRelationship.create! valid_attributes
      get :edit, params: {id: protocol_relationship.to_param}, session: valid_session
      expect(assigns(:protocol_relationship)).to eq(protocol_relationship)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new ProtocolRelationship' do
        expect {
          post :create, params: {protocol_relationship: valid_attributes}, session: valid_session
        }.to change(ProtocolRelationship, :count).by(1)
      end

      it 'assigns a newly created protocol_relationship as @protocol_relationship' do
        post :create, params: {protocol_relationship: valid_attributes}, session: valid_session
        expect(assigns(:protocol_relationship)).to be_a(ProtocolRelationship)
        expect(assigns(:protocol_relationship)).to be_persisted
      end

      it 'redirects to the created protocol_relationship' do
        post :create, params: {protocol_relationship: valid_attributes}, session: valid_session
        expect(response).to redirect_to(ProtocolRelationship.last)
      end
    end

    context 'with invalid params' do
      it 'assigns a newly created but unsaved protocol_relationship as @protocol_relationship' do
        post :create, params: {protocol_relationship: invalid_attributes}, session: valid_session
        expect(assigns(:protocol_relationship)).to be_a_new(ProtocolRelationship)
      end

      it "re-renders the 'new' template" do
        post :create, params: {protocol_relationship: invalid_attributes}, session: valid_session
        expect(response).to render_template('new')
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:other_object) { FactoryBot.create(:valid_collection_object) }
      let(:new_attributes) {
        { protocol_relationship_object_id: other_object.id, protocol_relationship_object_type: 'CollectionObject'}  
      }

      it 'updates the requested protocol_relationship' do
        protocol_relationship = ProtocolRelationship.create! valid_attributes
        put :update, params: {id: protocol_relationship.to_param, protocol_relationship: new_attributes}, session: valid_session
        protocol_relationship.reload
        expect(protocol_relationship.protocol_relationship_object.id).to eq(other_object.id) 
      end

      it 'assigns the requested protocol_relationship as @protocol_relationship' do
        protocol_relationship = ProtocolRelationship.create! valid_attributes
        put :update, params: {id: protocol_relationship.to_param, protocol_relationship: valid_attributes}, session: valid_session
        expect(assigns(:protocol_relationship)).to eq(protocol_relationship)
      end

      it 'redirects to the protocol_relationship' do
        protocol_relationship = ProtocolRelationship.create! valid_attributes
        put :update, params: {id: protocol_relationship.to_param, protocol_relationship: valid_attributes}, session: valid_session
        expect(response).to redirect_to(protocol_relationship)
      end
    end

    context 'with invalid params' do
      it 'assigns the protocol_relationship as @protocol_relationship' do
        protocol_relationship = ProtocolRelationship.create! valid_attributes
        put :update, params: {id: protocol_relationship.to_param, protocol_relationship: invalid_attributes}, session: valid_session
        expect(assigns(:protocol_relationship)).to eq(protocol_relationship)
      end

      it "re-renders the 'edit' template" do
        protocol_relationship = ProtocolRelationship.create! valid_attributes
        put :update, params: {id: protocol_relationship.to_param, protocol_relationship: invalid_attributes}, session: valid_session
        expect(response).to render_template('edit')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested protocol_relationship' do
      protocol_relationship = ProtocolRelationship.create! valid_attributes
      expect {
        delete :destroy, params: {id: protocol_relationship.to_param}, session: valid_session
      }.to change(ProtocolRelationship, :count).by(-1)
    end

    it 'redirects to the protocol_relationships list' do
      protocol_relationship = ProtocolRelationship.create! valid_attributes
      delete :destroy, params: {id: protocol_relationship.to_param}, session: valid_session
      expect(response).to redirect_to(protocol_relationships_url)
    end
  end

end
