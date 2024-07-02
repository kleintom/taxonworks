import AjaxCall from '@/helpers/ajaxCall'
import baseCRUD from './base'

const controller = 'dwc_occurrences'

export const DwcOcurrence = {
  ...baseCRUD(controller),

  metadata: (params) =>
    AjaxCall('get', `/${controller}/metadata.json`, { params }),

  status: (params) => AjaxCall('get', `/${controller}/status.json`, { params }),

  collectorMetadata: () =>
    AjaxCall('get', `/${controller}/collector_id_metadata`),

  filter: (params) => AjaxCall('post', `/${controller}/filter.json`, params),

  predicates: () => AjaxCall('get', `/${controller}/predicates.json`),

  taxonworksExtensionMethods: () =>
    AjaxCall('get', '/tasks/dwc/dashboard/taxonworks_extension_methods'),

  indexVersion: () => AjaxCall('get', '/tasks/dwc/dashboard/index_versions'),

  generateDownload: (params) =>
    AjaxCall('post', '/tasks/dwc/dashboard/generate_download.json', params),

  createIndex: (params) =>
    AjaxCall('post', '/tasks/dwc/dashboard/create_index', params)
}
