import { MutationNames } from '../mutations/mutations'
import { Identifier, ContainerItem, CollectionObject } from '@/routes/endpoints'
import { useIdentifierStore } from '../pinia/identifiers'
import { CONTAINER, IDENTIFIER_LOCAL_RECORD_NUMBER } from '@/constants'

export default ({ commit, state }) =>
  new Promise((resolve, reject) => {
    const recordNumber = useIdentifierStore(IDENTIFIER_LOCAL_RECORD_NUMBER)()

    if (
      state.container &&
      !state.containerItems.find(
        (item) => item.contained_object_id === state.collection_object.id
      )
    ) {
      const item = {
        container_id: state.container.id,
        global_entity: state.collection_object.global_id
      }

      ContainerItem.create({ container_item: item }).then(({ body }) => {
        commit(MutationNames.AddContainerItem, body)
        if (state.containerItems.length === 1 && state.identifiers.length) {
          const identifier = {
            id: state.identifiers[0].id,
            identifier_object_type: CONTAINER,
            identifier_object_id: state.container.id
          }

          recordNumber.save({
            objectType: CONTAINER,
            objectId: state.container.id
          })

          Identifier.update(identifier.id, { identifier }).then((response) => {
            state.identifiers[0] = response.body
          })
        }
        if (state.collection_object.id === body.contained_object_id) {
          CollectionObject.find(body.contained_object_id).then((response) => {
            commit(MutationNames.SetCollectionObject, response.body)
          })
        }
        return resolve(body)
      })
    }
  })
