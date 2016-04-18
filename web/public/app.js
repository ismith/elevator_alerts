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
      problem: { required: true },
      elevator: { required: true }
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
    $('#elevator_select').replaceOptions(new_options);
  });
});
