/*
 * M7 Socket IO Object
 * 
 *  This library is used to handle messages received from the socket.io server running
 *  on the M7 testing director. Right now communications are one way. The web client
 *  receives notifications and updates the interface accordingly.
 */

function M7Client(server) {
		
	// Constructor
	this.io_client		  = io.connect(server);
	this.script_container = '#m7_auto_script';
		
	// Icon pulse animation
	this.icon_pulse = icon_pulse;
	function icon_pulse(elem) {
		elem.animate({opacity:1}, 1000, 'swing', function() {
			elem.animate({opacity:0.5}, 1000, 'swing', function() { icon_pulse(elem); });
		}); 
	};
	
	// Testing animations
	this.test_animate = test_animate;
	function test_animate(action, host) {
		
		// Script block and map host icon ID
		var script_id = 'map_host_' + host + '_pulse';
		var icon_id   = 'map_host_' + host;
		switch(action) {
		
			// Start testing animation
			case 'start':
				var start_test_js = "<script id='" + script_id + "'>m7.icon_pulse($('#" + icon_id + "'));</script>";
				$(this.script_container).append(start_test_js);
				break;
				
			// Stop testing animation
			case 'stop':
				var stop_test_js = "<script id='" + script_id + "'>$('#" + icon_id + "').stop(); $('#" + icon_id + "').css('opacity', '0.7');</script>";
				$('#' + script_id).replaceWith(stop_test_js);
				break;
				
			// Invalid animation action
			default:
				console.log('Invalid test animation action: ' + action);
		}
	};
};

// Initialize the object
var m7 = new M7Client('http://110.34.221.34:61000');

// Handle incoming socket.io connections
m7.io_client.on('connect', function() {
	m7.io_client.on('web_receive', function(json) {
		event = json.packet[0].event;
		host  = json.packet[0].host;
		
		// Process base on the event
		switch(event) {
		
			// Test execution started
			case 'test-start':
				m7.test_animate('start', host);
				break;
			
			// Test execution stopped
			case 'test-stop':
				m7.test_animate('stop', host);
				break;
			
			// Invalid event received
			default:
				console.log('Received invalid event: ' + event);
		}
	});
});