// Empties search text box and hide new_person div
function clear_topic_picker(form) {
  var topic_picker;
  topic_picker = form.find('.topic_picker_autocomplete');
  $(topic_picker).val("");
  form.find(".new_topic").attr("hidden", true);
}

function initialize_topic_autocomplete(form) {
  var autocomplete_input = form.find(".topic_picker_autocomplete");

  autocomplete_input.autocomplete({
    source: '/topics/lookup_topic',
    open: function (event, ui) {
      bind_hover(form);
    },
    select: function (event, ui) {    // execute on select event in search text box
      insert_existing_topic(form, ui.item.object_id, ui.item.label)
      clear_topic_picker(form);
      return false;
    }
  }).autocomplete("instance")._renderItem = function (ul, item) {
    return $("<li class='foo'>")
      .append("<a>" + item.label + ' <span class="hoverme" data-topic-id="' + item.object_id + '">...</span></a>')
      .appendTo(ul);
  };

  // Copy search textbox content to .new_person .name_label ////// not used here
  //autocomplete_input.keyup(function () {
  //  var input_term = autocomplete_input.val();
  //  var last_name = get_last_name(input_term);
  //  var first_name = get_first_name(input_term);
  //
  //  if (input_term.length == 0) {
  //    form.find(".new_person").attr("hidden", true);
  //  }
  //  else {
  //    form.find(".new_person").removeAttr("hidden");
  //  };
  //
  //  if (input_term.indexOf(",") > 1) {   //last name, first name format
  //    var swap = first_name;
  //    first_name = last_name;
  //    last_name = swap;
  //  }
  //
  //  form.find(".first_name").val(first_name).change();
  //  form.find(".last_name").val(last_name).change();
  //});
};


//
// Binding actions (clicks) to links
//

//function bind_new_link(form) {     ////// not used here
//  // Add a role to the list via the add new form
//  form.find(".topic_picker_add_new").click(function () {
//    insert_new_topic(form);
//    form.find('.new_topic').attr("hidden", true); // hide the form fields
//    clear_topic_picker(form); // clear autocomplete input box
//  });
//}

function insert_existing_person(form, topic_id, label) {
  var base_class = form.data('base-class');
  var random_index = new Date().getTime();
  var topic_list = form.find(".topic_list");

  // type
  topic_list.append( $('<input hidden name="' + base_class + '[topics_attributes][' +  random_index + '][type]" value="' + form.data('topic-type') +  '" >') );
  topic_list.append( $('<input hidden name="' + base_class + '[topics_attributes][' +  random_index + '][topic_id]" value="' + topic_id +  '" >') );

  // insert visible list item
  topic_list.append( $('<li class="topic_item" data-topic-index="' + random_index + '">').append( label).append('&nbsp;').append(remove_link()) );
};

var _initialize_topic_picker_widget;

_initialize_topic_picker_widget = function
  init_topic_picker() {
  $('.topic_picker').each( function() {
    var topic_type = $(this).data('topic-type');
    initialize_topic_picker($(this), topic_type);
  });
};

// Initialize the script on page load
$(document).ready(_initialize_topic_picker_widget);

