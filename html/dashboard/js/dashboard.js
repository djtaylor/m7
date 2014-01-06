function position_details() {
	var test_details_top	= ($(window).height() / 2) - ($('.m7_test_details_content').height() / 2);
	var test_details_left	= ($(window).width() / 2) - ($('.m7_test_details_content').width() / 2);
	$('.m7_test_details_content').css('top',test_details_top+'px');
	$('.m7_test_details_content').css('left',test_details_left+'px');
}

function position_key() {
	var map_key_top			= ($(window).height() / 2) - ($('.m7_map_key').height() / 2);
	$('.m7_map_key').css('top', map_key_top+'px');
}

$(document).ready(function() {
	position_details();
	position_key();
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
	
	if (test_details_render === true) {
		
		// Set the test details column width
		var tables = $('.m7_test_details_stats').length;
		var cols = ($('.m7_test_details_col_header').length) / tables;
		var col_width = 100 / cols;
		$('.m7_test_details_col_header').css('width', col_width+'%');
		$('.m7_test_details_cell').css('width', col_width+'%');
		
		// Switch between destination IP frames
		$('#dest_ip').change(function() {
			var dest_ip_content = $("#dest_ip").val();
			$('.m7_test_details_stats, .m7_test_details_chart').fadeOut('fast', function() {
				$('#ccontent_'+dest_ip_content).fadeIn('fast');
				$('#scontent_'+dest_ip_content).fadeIn('fast');
			});
		});
	}
});

$(window).resize(function() {
	position_details();
	position_key();
});