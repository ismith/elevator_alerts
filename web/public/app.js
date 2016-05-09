(function($, window) {
  $.fn.replaceOptions = function(options) {
    var self, $option;

    this.empty();
    self = this;

    $.each(options, function(index, option) {
      $option = $("<option></option>")
        .attr("value", option.value)
        .text(option.text);
      self.append($option);
    });
  };
})(jQuery, window);

jQuery(function($) {
  jQuery.validator.setDefaults({
    success: "valid"
  });
  $('#phone_number').mask("(999) 999-9999");

  // This validation ... is not actually getting applied, I think.  Should
  // double-check that later.
  $('#phone_form').validate({
    rules: {
      phone_number: {
        required: true,
        phoneUS: true
      }
    }
  });
  $('#report_form').validate({
    rules: {
      // 'problem' no longer required b/c we accept 'no problem' as a type
      //problem: { required: true },

      // adding 'accessible faregate' means elevator is not necessarily required
      //elevator: { required: true }
      station: { required: true }
    }
  });

  var station_to_elevators = null;
  $.getJSON('/api/bart/elevators.json',
    function(data) {
      station_to_elevators = data;
  });

  $('#station_select').on('change', function() {
    station_id = this.value
    new_options = station_to_elevators[station_id];
    new_options.push({ text: 'Faregate',
                       value: 0 });
    $('#elevator_select').replaceOptions(new_options);
  });

  // if the user selects 'broken accessible faregate', set the #elevator value
  // to 0 to match
  $('#problem_type').on('change', function() {
    if(this.value == 'broken accessible faregate') {
      $('#elevator_select').val(0);
    }
  });

  $('#elevator_select').on('change', function() {
    if(this.value == 0) {
      $('#problem_type').val('broken accessible faregate');
    }
  });
});
