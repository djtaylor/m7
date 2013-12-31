<!DOCTYPE HTML>
<?php

	// Open a new database connection
    $db = new mysqli('hostname', 'root', 'password', 'm7');

    // Define network test categories
    $m7_net_test_categories = array(
    	// "ping"			=> "Ping",
    	"traceroute"	=> "Traceroute"
    	// "mtr" 			=> "MTR"
    );
    
    // Check the GET variables for a selected test
    if (isset($_GET['test_type']) && isset($_GET['test_id']) && isset($_GET['test_host']) && isset($_GET['test_cat'])) {
    	$m7_test_type        = $_GET['test_type'];
    	$m7_test_id          = $_GET['test_id'];
    	$m7_test_host        = $_GET['test_host'];
    	$m7_test_cat         = $_GET['test_cat'];
    	
    	// Check if any additional filter values are supplied
    	if(isset($_GET['test_destip']) && $_GET['test_destip'] != "all") {
    		$m7_test_destip  = $_GET['test_destip'];	
    	}
    }
    
    // Make sure the minimum test variables are defined in POST superglobals before trying to render a test
    $m7_test_render = false;
    if (isset($m7_test_type) && isset($m7_test_id) && isset($m7_test_host) && isset($m7_test_cat)) {
    	$m7_test_render      = true;
    	
    	// Set the cookies
    	setcookie('test_type', $m7_test_type);
    	setcookie('test_id',   $m7_test_id);
    	setcookie('test_host', $m7_test_host);
    	setcookie('test_cat',  $m7_test_cat);
    	
    	// Check if any additional filter values are supplied
    	if(isset($m7_test_destip)) {
    		setcookie('test_destip', $m7_test_destip);
    	} 
    } else {
    	
    	// Check if the relative cookies are set
    	if (isset($_COOKIE['test_type']) && isset($_COOKIE['test_id']) && isset($_COOKIE['test_host']) && isset($_COOKIE['test_cat'])) {
    		$m7_test_type		 = $_COOKIE['test_type'];
    		$m7_test_id 		 = $_COOKIE['test_id'];
    		$m7_test_host		 = $_COOKIE['test_host'];
    		$m7_test_cat		 = $_COOKIE['test_cat'];
    	}
    	
    	// If all the required cookies are set
    	if (isset($m7_test_type) && isset($m7_test_id) && isset($m7_test_host) && isset($m7_test_cat)) {
    		$m7_test_render  = true;
    	} else {
    		$m7_test_render  = false;
    	}
    }

    // If enough properties are set to render a test
    if ($m7_test_render === true) {
    	
    	// Make a DB friendly host name
    	$m7_host_db_prefix   = preg_replace("/-/", "_", $m7_test_host);
    	
    	// Initialize the test parameters array
    	$m7_test_properties = array( $m7_host_db_prefix => array());
    	
    	// If a destination IP is set
    	if(isset($m7_test_destip) && $m7_test_destip != "all") {
    		array_push($m7_test_properties[$m7_host_db_prefix], $m7_test_destip);
    	} else {
    		
    		// Build an array of all destination IPs for the specified test ID / host / category
    		$m7_test_host_res	 = $db->query("SELECT DISTINCT dest_ip FROM " . $m7_host_db_prefix . "_" . $m7_test_type . "_" . $m7_test_cat);
    		while ($m7_test_host_dip_row = $m7_test_host_res->fetch_assoc()) {
    			array_push($m7_test_properties[$m7_host_db_prefix], $m7_test_host_dip_row['dest_ip']);
    		}	
    	}
    	
    	$m7_dest_ip_results = array();
    	foreach($m7_test_properties[$m7_host_db_prefix] as $m7_test_dest_ip) {
    		
    		// Initialize the array for the destination IP
    		$m7_dest_ip_results[$m7_test_dest_ip] = array();
    		
    		// Build an array for the test results for each destination IP address
    		$m7_dest_ip_query   = $db->query("SELECT * FROM " . $m7_host_db_prefix . "_" . $m7_test_type . "_" . $m7_test_cat . " WHERE dest_ip='" . $m7_test_dest_ip . "' ORDER BY hop ASC");	
    		while ($m7_dest_ip_row = $m7_dest_ip_query->fetch_assoc()) {
    				
    			// Get the hop number
    			$m7_dest_ip_hop = $m7_dest_ip_row['hop'];
    	
    			// If running an MTR test
    			if ($m7_test_type == 'mtr') {
    	
    				// For now get the single set of coordinates
    				$m7_dest_ip_results[$m7_test_dest_ip][$m7_dest_ip_hop]['lat'] = preg_replace("/(^[^:]*):[^:]*$/", "$1", $m7_dest_ip_row['ips_gps']);
    				$m7_dest_ip_results[$m7_test_dest_ip][$m7_dest_ip_hop]['lon'] = preg_replace("/^[^:]*:([^:]*$)/", "$1", $m7_dest_ip_row['ips_gps']);
    			} else {
    					
    				// Insert the latitude and longitude
    				$m7_dest_ip_results[$m7_test_dest_ip][$m7_dest_ip_hop]['lat'] = $m7_dest_ip_row['ip_lat'];
    				$m7_dest_ip_results[$m7_test_dest_ip][$m7_dest_ip_hop]['lon'] = $m7_dest_ip_row['ip_lon'];
    			}
    		}
    	}
    }
    
    // Right now we are limited to rendering network tests
    $m7_test_type            = "net";
     
    // Get a list of all test IDs for the test type
    $m7_test_ids_res         = $db->query("SELECT * FROM tests WHERE type='" . $m7_test_type . "'");
    $m7_test_ids = array();
    while ($m7_test_id_row   = $m7_test_ids_res->fetch_assoc()) {
    	array_push($m7_test_ids, $m7_test_id_row['test_id']);
    }
     
    // Build an array of all test hosts
    $m7_test_hosts_res       = $db->query("SELECT * FROM hosts");
    $m7_test_hosts = array();
    while ($m7_test_hosts_row = $m7_test_hosts_res->fetch_assoc()) {
    	array_push($m7_test_hosts, $m7_test_hosts_row['name']);
    }

?>
<html>
	<head>
		<title>M7 Dashboard</title>
    	<meta charset="utf-8">
    	<script src="js/d3.v3.min.js"></script>
    	<script src="js/topojson.v1.min.js"></script>
        <link rel="stylesheet" type="text/css" href="css/dashboard.css">
	</head>
	<body>
        <div class="m7_dashboard_nav">
	        <form action="index.php" action="post">
	        	<div class="m7_dashboard_content">
	            	<div class="m7_test_submit"><input type="submit" value="Submit"></div>
	                <div class="m7_test_type">
	                	<div class="m7_test_type_title">Test Type</div>
	                    <div class="m7_test_type_menu">
	                    	<select name="test_type">
	                        	<option value="net">Network</option>
	                        </select>
	                    </div>
	                </div>
	                <div class="m7_test_id">
	                	<div class="m7_test_id_title">Test ID</div>
	                    <div class="m7_test_id_menu">
	                    	<select name="test_id">
	                        <?php
	                        foreach($m7_test_ids as $m7_test_id) {
	                        	echo '<option value="' . $m7_test_id . '">' . $m7_test_id . '</option>' . "\n";
	                        }
	                        ?>
	                        </select>
	                    </div>
	                </div>
	                <div class="m7_test_host">
	                	<div class="m7_test_host_title">Test Host</div>
	                    <div class="m7_test_host_menu">
	                    	<select name="test_host">
	                        <?php
	                        foreach($m7_test_hosts as $m7_test_host_name) {
								if($m7_test_host_name == $m7_test_host) {
									echo '<option selected="selected" value="' . $m7_test_host_name . '">' . $m7_test_host_name . '</option>' . "\n";
								} else {
									echo '<option value="' . $m7_test_host_name . '">' . $m7_test_host_name . '</option>' . "\n";
								}
	                        }
	                        ?>
	                        </select>
	                    </div>
	                </div>
	                <div class="m7_test_cat_type">
	                	<div class="m7_test_cat_title">Test Category</div>
	                    <div class="m7_test_cat_menu">
	                    	<select name="test_cat">
	                    		<?php 
	                    		foreach($m7_net_test_categories as $m7_net_test_id => $m7_net_test_desc) {
									if($m7_net_test_id == $m7_test_cat) {
										echo '<option selected="selected" value="' . $m7_net_test_id . '">' . $m7_net_test_desc . '</option>' . "\n";
									} else {
										echo '<option value="' . $m7_net_test_id . '">' . $m7_net_test_desc . '</option>' . "\n";
									}
								}
	                    		?>
	                        </select>
	                    </div>
	                </div>
	                <div class="m7_test_destip_type">
	                	<div class="m7_test_destip_title">Destination IP</div>
	                    <div class="m7_test_destip_menu">
	                    	<select name="test_destip">
	                        	<option value="all">--All--</option>
	                        	<?php
	                        	if(isset($m7_dest_ip_results)) {
	                        		foreach($m7_dest_ip_results as $m7_dest_ip_val => $m7_dest_ip_array) {
										if($m7_dest_ip_val == $m7_test_destip) {
											echo '<option selected="selected" value="' . $m7_dest_ip_val . '">' . $m7_dest_ip_val . '</option>' . "\n";
										} else {
											echo '<option value="' . $m7_dest_ip_val . '">' . $m7_dest_ip_val . '</option>' . "\n";
										}
									}
	                        	}
	                        	?>
	                        </select>
	                    </div>
	                </div>
	            </div>
	        </form>
    	</div>
    	<div id="map_container"></div>
    	<script>

var width = window.innerWidth;
height = window.innerHeight;

var projection = d3.geo.mercator()
	.scale((width + 1) / 2 / Math.PI)
	.translate([width / 2, height / 2])
	.precision(.1);

var path = d3.geo.path()
    .projection(projection);

var graticule = d3.geo.graticule();

var svg = d3.select("#map_container").append("svg")
    .attr("width", width)
    .attr("height", height);

svg.append("path")
    .datum(graticule)
    .attr("class", "graticule")
    .attr("d", path);

<?php 

if ($m7_test_render === true) {
	$m7_stroke_count = 1;
	foreach($m7_dest_ip_results as $m7_dest_ip_hops) {
		$m7_dest_ip_hop_coords_string = null;
		foreach($m7_dest_ip_hops as $m7_dest_ip_hop_coords) {
			if(!isset($m7_dest_ip_hop_coords_string)) {
				$m7_dest_ip_hop_coords_string = "[" . $m7_dest_ip_hop_coords['lon'] . "," . $m7_dest_ip_hop_coords['lat'] . "]";
			} else {
				$m7_dest_ip_hop_coords_string .= ",[" . $m7_dest_ip_hop_coords['lon'] . "," . $m7_dest_ip_hop_coords['lat'] . "]";
			}
		}
		echo 'svg.append("path")' . "\n";
		echo '.datum({type: "LineString", coordinates: [' . $m7_dest_ip_hop_coords_string . ']})' . "\n";
		echo '.attr("class", "arc' . $m7_stroke_count . '")' . "\n";
		echo '.attr("d", path);' . "\n";
		$m7_stroke_count++;
	}
}	                      

?>

d3.json("/dashboard/json/world-50m.json", function(error, world) {
	svg.insert("path", ".graticule")
		.datum(topojson.feature(world, world.objects.land))
		.attr("class", "land")
		.attr("d", path);

	svg.insert("path", ".graticule")
		.datum(topojson.mesh(world, world.objects.countries, function(a, b) { return a !== b; }))
		.attr("class", "boundary")
		.attr("d", path);
});

d3.select(self.frameElement).style("height", height + "px");
    	</script>
	</body>
</html>