// wogri@wogri.com
$(document).ready(function() {
  // bind all elements that are links in the DOM to a click event 
  $('.spinner').click(function() { 
    $('#waiting_bar').fadeIn(); 
  });
  // on every ajax-request that has completed, fade the waiting-bar element
  $(document).ajaxComplete(function() { 
    $('#waiting_bar').fadeOut(1000); 
    // but also re-bind the spinner-link events, otherwhise the freshly loaded ajax elements don't have this information
    $('.spinner').bind('click', function() { 
      $('#waiting_bar').fadeIn(); 
    });
    $('.ui-dialog-titlebar-close').bind('click', function() {
      $('#waiting_bar').fadeOut(1000); 
    });
  });
	/*
  $("#tool-form")
    .bind("ajax:loading",  toggleLoading)
    .bind("ajax:complete", toggleLoading)
    .bind("ajax:success", function(event, data, status, xhr) {
      $("#response").html(data);
    });
  */
});
