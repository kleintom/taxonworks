<template>

  <div
    v-if="otuList && checked"
    v-for="(otu, i) in otuList"
    :index="otu.id"
  >
    <span
      v-if="checked.findIndex((c) => (c == i)) != -1"
      class="in"
    >
      &#10003;
    </span>

    <span
      v-else
      class="out"
      @click="emit('addOtuIndex', i)"
    >
      Add
    </span>
    <span v-html="otu.object_tag" />
  </div>

</template>

<script setup>

const props = defineProps({
  otuList: {
    type: Array,
    default: []
  },
  checked: {
    type: Array,
    default: []
  }
})

const emit = defineEmits(['addOtuIndex'])

</script>

<style scoped>
.in {
  display: inline-block;
  width: 16px;
  height: 16px;
  margin-right: 1.5em;
  color: green;
}
.out {
  display: inline-block;
  width: 16px;
  height: 16px;
  margin-right: 1.5em;
  cursor: pointer;
}
</style>