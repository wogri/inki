// wogri@google.com
// all filter input fields are automatically submitted when the focus is going away

$(document).ready(function() {
  $(document).ajaxComplete(function() {
  // $(document).on('page:change', function () {
  // $('form').on('click', function() {
    $(".filter_form :input.filter_input").blur(function() {
      $('form.filter_form').trigger('submit.rails');
    });
  });
});

 
