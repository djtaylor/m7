function position_details() {
	var test_details_top	= ($(window).height() / 2) - ($('.m7_test_details_content').height() / 2);
	var test_details_left	= ($(window).width() / 2) - ($('.m7_test_details_content').width() / 2);
	$('.m7_test_details_content').css('top',test_details_top+'px');
	$('.m7_test_details_content').css('left',test_details_left+'px');
	var host_details_top	= ($(window).height() / 2) - ($('.m7_map_host_details_content').height() / 2);
	var host_details_left	= ($(window).width() / 2) - ($('.m7_map_host_details_content').width() / 2);
	$('.m7_map_host_details_content').css('top',host_details_top+'px');
	$('.m7_map_host_details_content').css('left',host_details_left+'px');

}

function clock() {
	
	// Get the current time objects
	var second = parseInt($("#second").text());
	var minute = parseInt($("#minute").text());
	var hour   = parseInt($("#hour").text());
	
	// Start the increment tests
	var next_second = second + 1;
	if (next_second > 59) {
		next_second = '00';
		$("#second").text(next_second);
		var next_minute = minute + 1;
		if (next_minute > 59) {
			next_minute = '00';
			$("#minute").text(next_minute);
			var next_hour = hour + 1;
			if (next_hour > 23) {
				next_hour = '00';
				$("#hour").text(next_hour);
			} else {
				if (next_hour < 10) {
					next_hour = '0' + next_hour;
					$("#hour").text(next_hour);
				} else {
					$("#hour").text(next_hour);
				}
			}
		} else {
			if (next_minute < 10) {
				next_minute = '0' + next_minute;
				$("#minute").text(next_minute);
			} else {
				$("#minute").text(next_minute);
			}
		}
	} else {
		if (next_second < 10) {
			next_second = '0' + next_second;
			$("#second").text(next_second);
		} else {
			$("#second").text(next_second);
		}
	}
	setTimeout(clock, 1000);
}

function position_key() {
	var map_key_top			= ($(window).height() / 2) - ($('.m7_map_key').height() / 2);
	$('.m7_map_key').css('top', map_key_top+'px');
}

$(document).ready(function() {
	position_details();
	position_key();
	clock();
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
		window.location.href = '/configure.php';
	});
	
	$('.m7_map_host').click(function(event) {
		var clicked_id = event.target.id;
		var clicked_host = clicked_id.match(/^map_host_(.*$)/)[1];
		var host_details = "map_host_details_"+clicked_host;
		$('.m7_map_host_details').fadeIn("fast", function() {
			$(host_details).fadeIn("fast");
		});
	});
	$(".m7_map_host_details_bg").click(function() {
		$(".m7_map_host_details_info").fadeOut("fast", function() {
			$(".m7_map_host_details").fadeOut("fast");
		});
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