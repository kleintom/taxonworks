import {
  OBSERVATION_CONTINUOUS,
  OBSERVATION_QUALITATIVE,
  OBSERVATION_WORKING,
  OBSERVATION_MEDIA,
  OBSERVATION_PRESENCE,
  OBSERVATION_SAMPLE
} from '@/constants/index.js'

const ObservationTypes = {
  Qualitative: OBSERVATION_QUALITATIVE,
  Presence: OBSERVATION_PRESENCE,
  Continuous: OBSERVATION_CONTINUOUS,
  Sample: OBSERVATION_SAMPLE,
  Media: OBSERVATION_MEDIA,
  FreeText: OBSERVATION_WORKING
}

export default ObservationTypes
