$(document).ready(function() {
    $('.m7_test_details_show').click(function() {
    	$('.m7_test_details').fadeIn('fast');
	});
	$('.m7_test_details_bg').click(function() {
		$('.m7_test_details').fadeOut('fast');
	});
	$('.m7_test_submit').click(function() {
		$('#test_params').submit();
	});
	$('.m7_configure').click(function() {
		window.location.href = '/dashboard/configure.php';
	});
});