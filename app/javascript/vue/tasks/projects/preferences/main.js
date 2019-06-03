import Vue from 'vue'
import App from './app.vue'

function init() {
  new Vue({
    el: '#vue-task-preferences',
    render: function (createElement) {
      return createElement(App)
    }
  })
}

$(document).on('turbolinks:load', function () {
  if (document.querySelector('#vue-task-preferences')) {
    init()
  }
})
