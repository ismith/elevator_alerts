jQuery(function($) {
  jQuery.validator.setDefaults({
    success: "valid"
  });
  $('#phone_number').mask("(999) 999-9999");
  $('#phone_form').validate({
    rules: {
      phone_number: {
        required: true,
        phoneUS: true
      }
    }
  });
});
