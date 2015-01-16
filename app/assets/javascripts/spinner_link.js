// wogri@wogri.com
$(document).ready(function() {
  // bind all elements that are links in the DOM to a click event 
  $('.spinner').click(function() { 
    $('#waiting_bar').fadeIn(); 
    $('.navbar-brand').addClass('navbar-spinner')
  });
  // on every ajax-request that has completed, fade the waiting-bar element
  $(document).ajaxComplete(function() { 
    $('#waiting_bar').fadeOut(1000); 
    $('.navbar-brand').removeClass('navbar-spinner')
    // but also re-bind the spinner-link events, otherwhise the freshly loaded ajax elements don't have this information
    $('.spinner').bind('click', function() { 
      $('#waiting_bar').fadeIn(); 
      $('.navbar-brand').addClass('navbar-spinner')
    });
    $('.ui-dialog-titlebar-close').bind('click', function() {
      $('#waiting_bar').fadeOut(1000); 
      $('.navbar-brand').removeClass('navbar-spinner')
    });
  });
});
