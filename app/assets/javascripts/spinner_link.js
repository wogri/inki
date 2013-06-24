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
	/*$('.has_and_belongs_to_many_check_box').click(function() {
		alert('Hooray!');
		$(this).closest("form").submit();
		// $("#form").trigger('submit');
	});
	$('.check_box_form').click(function() { 
		var $checkbox = $(this).find(':checkbox');
		alert('schnacksi');
	});
	$("input[name='associated']").click(function(){
		alert("aaaaaa");
	});
	$(':checkbox').change(function() {
		alert("bbbbb");
		$(this).closest('form').submit();
	});
	$(":checkbox[name='associated']").click(function(){
		alert("aaaaaa");
	});
	*/
});
