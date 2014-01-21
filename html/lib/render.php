<?php
class Render extends D3JS {
	
	// Test parameters / properties / destination IPs
	public $m7_params = array ();
	public $m7_tprops = array ();
	public $m7_destips = array ();
	public $m7_ready;
	
	// Class constructor
	public function __construct() {
		parent::__construct();
		$this->planInit();
	}
	
	/**
	 * Render Test Host Map Points
	 */
	public function mapHosts() {
		$map_hosts_js = null;
		
		// Find the director latitude and longitude
		$m7_cluster_dir_query = $this->m7_db->query( "SELECT * FROM nodes WHERE type='director'" );
		$m7_cluster_dir_row   = $m7_cluster_dir_query->fetch_assoc();
		$m7_cluster_dir_lat   = $m7_cluster_dir_row['latitude'];
		$m7_cluster_dir_lon   = $m7_cluster_dir_row['longitude'];
		
		// Build the map points and node interconnects
		$m7_cluster_hosts_query = $this->m7_db->query( "SELECT * FROM nodes" );
		while ($m7_cluster_hosts_row = $m7_cluster_hosts_query->fetch_assoc()) {
			$m7_host_alias = $m7_cluster_hosts_row['name'];
			$m7_host_alias = preg_replace( "/-/", "_", $m7_host_alias);
			$m7_host_lat   = $m7_cluster_hosts_row['latitude'];
			$m7_host_lon   = $m7_cluster_hosts_row['longitude'];
			
			// Define the director node class
			$m7_dir_class = null;
			if ($m7_cluster_hosts_row['type'] == 'director') {
				$m7_dir_class = ' m7_map_host_director';
			
			// If not director, draw a path to the director node
			} else {
				if ($this->m7_ready === false) {
					$map_hosts_js .= 'features.insert("path")' . "\n";
					$map_hosts_js .= '.datum({type: "LineString", coordinates: [["' . $m7_cluster_dir_lon . '","' . $m7_cluster_dir_lat . '"],["' . $m7_cluster_hosts_row['longitude'] . '","' . $m7_cluster_hosts_row['latitude'] . '"]]})';
					$map_hosts_js .= '.style("stroke", "#0087BD")';
					$map_hosts_js .= '.style("fill", "none")';
					$map_hosts_js .= '.style("stroke-width", "2px")';
					$map_hosts_js .= '.attr("d", path);';
				}
			}
			
			// Define the JS block
			$map_hosts_js .= 'var coords_' . $m7_host_alias . ' = projection(["' . $m7_host_lon . '","' . $m7_host_lat . '"]);';
			$map_hosts_js .= 'var x_' . $m7_host_alias . ' = coords_' . $m7_host_alias . '[0];';
			$map_hosts_js .= 'var y_' . $m7_host_alias . ' = coords_' . $m7_host_alias . '[1];';
			$map_hosts_js .= 'features.insert("foreignObject")';
			$map_hosts_js .= '.attr("x", coords_' . $m7_host_alias . '[0])';
			$map_hosts_js .= '.attr("y", coords_' . $m7_host_alias . '[1])';
			$map_hosts_js .= '.attr("class", "fobj_' . $m7_host_alias . '")';
			$map_hosts_js .= '.append("xhtml:div")';
			$map_hosts_js .= '.attr("class", "m7_map_host' . $m7_dir_class . '").attr("id", "map_host_' . $m7_host_alias . '").attr("host_tooltip_' . $m7_host_alias . '", " ").on("click", function() { toggle_host("map_host_' . $m7_host_alias . '"); });' . "\n";
		}
		return $map_hosts_js;
	}
	
	/**
	 * Render Test Host Details
	 */
	public function mapHostDetails() {
		$m7_cluster_hosts_query = $this->m7_db->query( "SELECT * FROM nodes" );
		
		$map_hosts_html = '<div class="m7_map_host_details">';
		$map_hosts_html .= '<div class="m7_map_host_details_bg"></div>';
		$map_hosts_html .= '<div class="m7_map_host_details_content">';
		
		// Initialize the tooltip items array and popup code
		$map_hosts_tooltip_items = array();
		$map_hosts_tooltip_popups = null;
		
		while ($m7_cluster_hosts_row = $m7_cluster_hosts_query->fetch_assoc() ) {
			$m7_host_alias = $m7_cluster_hosts_row['name'];
			$m7_host_alias = preg_replace( "/-/", "_", $m7_host_alias);
			$map_hosts_html .= '<div class="m7_map_host_details_info" id="map_host_details_' . $m7_host_alias . '">';
			
			// Top Row
			$map_hosts_html .= '<div class="m7_node_info_top">';
			// Top Left Column
			$map_hosts_html .= '<div class="m7_node_info_left">';
			$map_hosts_html .= '<div class="m7_host_nic_cheader"><p>Ethernet Adapters</p></div>';
			$m7_node_nic_query = $this->m7_db->query("SELECT * FROM nodes_nic WHERE name='" . $m7_cluster_hosts_row['name'] . "'");
			while ($m7_node_nic_row = $m7_node_nic_query->fetch_assoc()) {
				$map_hosts_html .= '<div class="m7_node_nic">';
				$map_hosts_html .= '<div class="m7_node_nic_name"><div class="nic_name_title">Adapter: </div><div class="nic_name_val">' . $m7_node_nic_row['nic'] . '</div></div>';
				$map_hosts_html .= '<div class="m7_node_nic_ip"><div class="nic_ip_title">IP: </div><div class="nic_ip_val">' . $m7_node_nic_row['ip'] . '</div></div>';
				$map_hosts_html .= '<div class="m7_node_nic_asn"><div class="nic_asn_title">ASN Inbound: </div><div class="nic_asn_val">' . $m7_node_nic_row['asn_in'] . '</div></div>';
				$map_hosts_html .= '</div>';
			}
			$map_hosts_html .= '</div>';
			// Top Right Column
			$map_hosts_html .= '<div class="m7_node_info_right">';
			$map_hosts_html .= '<div class="m7_host_status_cheader"><p>System Status</p></div></div>';
			$map_hosts_html .= '</div></div>';
			// Bottom Row
			
			
			
			// Push to the tooltip items array
			array_push($map_hosts_tooltip_items, 'host_tooltip_' . $m7_host_alias);
			
			// Define the tooltip popup
			$map_hosts_tooltip_popup = "\t\t\tif (element.is('[host_tooltip_" . $m7_host_alias . "]')) {\n";
			$map_hosts_tooltip_popup .= "\t\t\t\treturn \"<div class='m7_map_tooltip'>";
			$map_hosts_tooltip_popup .= "<div class='m7_tooltip_entry'><div class='m7_tooltip_left'>Name:</div><div class='m7_tooltip_right'>" . $m7_host_alias . "</div></div>";
			$map_hosts_tooltip_popup .= "<div class='m7_tooltip_entry'><div class='m7_tooltip_left'>IP:</div><div class='m7_tooltip_right'>" . $m7_cluster_hosts_row['ipaddr'] . "</div></div>";
			$map_hosts_tooltip_popup .= "<div class='m7_tooltip_entry'><div class='m7_tooltip_left'>Region:</div><div class='m7_tooltip_right'>" . $m7_cluster_hosts_row['region'] . "</div></div>";
			$map_hosts_tooltip_popup .= "<div class='m7_tooltip_entry'><div class='m7_tooltip_left'>Type:</div><div class='m7_tooltip_right'>" . $m7_cluster_hosts_row['type'] . "</div></div>";
			$map_hosts_tooltip_popup .= "<div class='m7_tooltip_entry'><div class='m7_tooltip_left'>Description:</div><div class='m7_tooltip_right'>" . $m7_cluster_hosts_row['desc'] . "</div></div>";
			$map_hosts_tooltip_popup .= "<div class='m7_tooltip_click_info'>Click icon to view host details</div>";
			$map_hosts_tooltip_popup .= "</div>\"\n";
			$map_hosts_tooltip_popup .= "\t\t\t}\n";
			
			// Append to the popups string
			$map_hosts_tooltip_popups .= $map_hosts_tooltip_popup;
		}
		
		// Flatten the items array
		$map_hosts_tooltip_item_string = implode('],[', $map_hosts_tooltip_items);
		
		// Define the tooltips JS block
		$map_hosts_tooltip_js = "<script>\n";
		$map_hosts_tooltip_js .= "$(document).ready(function() {\n";
		$map_hosts_tooltip_js .= "\t$(document).tooltip({\n";
		$map_hosts_tooltip_js .= "\t\titems: '[" . $map_hosts_tooltip_item_string . "]',\n";
		$map_hosts_tooltip_js .= "\t\tcontent: function() {\n";
		$map_hosts_tooltip_js .= "\t\t\tvar element = $(this);\n";
		$map_hosts_tooltip_js .= $map_hosts_tooltip_popups;
		$map_hosts_tooltip_js .= "\t\t}\n\t});\n});</script>";
		
		// Return the HTML and JS blocks
		$map_hosts_html .= '</div></div>' . $map_hosts_tooltip_js;
		return $map_hosts_html;
	}
	
	/**
	 * Render Map Paths D3JS
	 *
	 * Render the JavaScript required to plot the map paths for the test on the world map. This
	 * method looks through the various plan arrays generated in the Core class and renders the
	 * JavaScript based on the current test parameters.
	 *
	 * @return string
	 */
	public function mapPaths() {
		$m7_paths_js = null;
		switch ($this->m7_active['cat']) {
			case 'dns':
				
				//
				break;
			case 'web':
				
				// TODO: Still not sure how I'm going to handle rendering web tests on the world map
				break;
			case 'net':
				$m7_stroke_count = 1;
				
				// Render one path per destination IP
				foreach ($this->m7_destips as $m7_destip) {
					$m7_hop_coords_str = null;
					switch ($this->m7_active['type']) {
						case 'ping' :
							
							// Get the latitude and longitude for the source and destination hosts
							$m7_ping_slat = $this->m7_plan[$this->m7_active['plan']][$this->m7_active ['host']]['lat'];
							$m7_ping_slon = $this->m7_plan[$this->m7_active['plan']][$this->m7_active ['host']]['lon'];
							$m7_ping_dlat = $this->m7_plan[$this->m7_active['plan']][$this->m7_active ['host']][$this->m7_active['cat']][$m7_destip]['lat'];
							$m7_ping_dlon = $this->m7_plan[$this->m7_active['plan']][$this->m7_active ['host']][$this->m7_active['cat']][$m7_destip]['lon'];
							
							// Only print if all coordinates are known
							if ($m7_ping_slat != '*' && $m7_ping_slon != '*' && $m7_ping_dlat != '*' && $m7_ping_dlon != '*') {
								$m7_coords_str = '[' . $m7_ping_slon . ',' . $m7_ping_slat . '],';
								$m7_coords_str .= '[' . $m7_ping_dlon . ',' . $m7_ping_dlat . ']';
								$m7_paths_js .= 'features.append("path")' . "\n";
								$m7_paths_js .= '.datum({type: "LineString", coordinates: [' . $m7_coords_str . ']})' . "\n";
								$m7_paths_js .= '.style("stroke", function(d) { return color(' . $m7_stroke_count . '); })' . "\n";
								$m7_paths_js .= '.style("fill", "none")' . "\n";
								$m7_paths_js .= '.style("stroke-width", "2px")' . "\n";
								$m7_paths_js .= '.attr("d", path);' . "\n";
							}
							break;
						case 'traceroute' :
							foreach ($this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']][$this->m7_active['cat']][$m7_destip]['traceroute'][$this->m7_active['start']] as $m7_traceroute_hop => $m7_traceroute_hop_params) {
								
								// Get the hop latitude and longitude
								$m7_hop_lat = $m7_traceroute_hop_params['ip']['lat'];
								$m7_hop_lon = $m7_traceroute_hop_params['ip']['lon'];
								
								// Only print if both coordinates are known
								if ($m7_hop_lat != '*' && $m7_hop_lon != '*') {
									$m7_hop_coords = '[' . $m7_hop_lon . ',' . $m7_hop_lat . ']';
									if (!isset($m7_hop_coords_str)) {
										$m7_hop_coords_str = $m7_hop_coords;
									} else {
										$m7_hop_coords_str .= ',' . $m7_hop_coords;
									}
								}
							}
							$m7_paths_js .= 'features.append("path")' . "\n";
							$m7_paths_js .= '.datum({type: "LineString", coordinates: [' . $m7_hop_coords_str . ']})' . "\n";
							$m7_paths_js .= '.style("stroke", function(d) { return color(' . $m7_stroke_count . '); })' . "\n";
							$m7_paths_js .= '.style("fill", "none")' . "\n";
							$m7_paths_js .= '.style("stroke-width", "2px")' . "\n";
							$m7_paths_js .= '.attr("d", path);' . "\n";
							break;
						case 'mtr' :
							foreach ( $this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']][$this->m7_active['cat']][$m7_destip]['mtr'][$this->m7_active['start']] as $m7_mtr_hop => $m7_mtr_hop_params) {
								$m7_mtr_hop_ip = current(array_keys($m7_mtr_hop_params['ips']));
								
								// Get the hop latitude and longitude
								$m7_hop_lat = $m7_mtr_hop_params['ips'][$m7_mtr_hop_ip]['lat'];
								$m7_hop_lon = $m7_mtr_hop_params['ips'][$m7_mtr_hop_ip]['lon'];
								
								// Only print if both coordinates are known
								if ($m7_hop_lat != '*' && $m7_hop_lon != '*') {
									$m7_hop_coords = '[' . $m7_hop_lon . ',' . $m7_hop_lat . ']';
									if (!isset($m7_hop_coords_str)) {
										$m7_hop_coords_str = $m7_hop_coords;
									} else {
										$m7_hop_coords_str .= ',' . $m7_hop_coords;
									}
								}
							}
							$m7_paths_js .= 'features.append("path")' . "\n";
							$m7_paths_js .= '.datum({type: "LineString", coordinates: [' . $m7_hop_coords_str . ']})' . "\n";
							$m7_paths_js .= '.style("stroke", function(d) { return color(' . $m7_stroke_count . '); })' . "\n";
							$m7_paths_js .= '.style("fill", "none")' . "\n";
							$m7_paths_js .= '.style("stroke-width", "2px")' . "\n";
							$m7_paths_js .= '.attr("d", path);' . "\n";
							break;
					}
					$m7_stroke_count ++;
				}
				break;
		}
		return $m7_paths_js;
	}
	
	/**
	 * Render 2-Axis Line Chart
	 *
	 * This method generates the JavaScript required to render a 2-axis single or multi-line
	 * chart based on the passed parameters. To make sure variables don't overlap, all variables
	 * are made unique by appending a $post variable. The X and Y data parameters can either by
	 * a single or multi-level array depending on how many lines you want to graph.
	 *
	 * @param array $chart_params        	
	 * @return string
	 */
	public function lineChart($chart_params = array(), $test_range) {
		$post = '_' . $chart_params['post'];
		$x_data = $chart_params['x_data'];
		$y_data = $chart_params['y_data'];
		
		// Get the max value for the X axis
		$x_max = max ($x_data);
		
		// Set the X axis label
		if ($test_range) {
			$x_label = 'Run Time';
		} else {
			$x_label = 'Hop';
		}
		
		// Calculate the max value for the Y-axis w/ padding
		$y_data_max_array = array ();
		foreach ($y_data as $data_type => $data_params) {
			foreach ($data_params['values'] as $data_value) {
				array_push($y_data_max_array, $data_value);
			}
		}
		$y_max_base = max($y_data_max_array);
		$y_buffer	= bcdiv($y_max_base, '5', '0');
		$y_max		= bcadd($y_max_base, $y_buffer);
		
		// Construct the D3JS JavaScript
		$chart_js = $this->buildLineChart(array (
			'post' => $post,
			'x'    => array (
				'unit'  => 'hop',
				'max'   => $x_max,
				'label' => $x_label,
				'data'  => array (
					'label'  => false,
					'values' => $x_data 
				) 
			),
			'y'    => array (
				'unit'  => 'ms',
				'max'   => $y_max,
				'label' => 'Time (ms)',
				'data'  => $y_data 
			) 
		), $test_range);
		return $chart_js;
	}
	
	// Get the properties for a single destination IP
	public function singleIPTestResults($test_params = array()) {
		$id		= $test_params['id'];
		$cat	= $test_params['cat'];
		$type	= $test_params['type'];
		$destip = $test_params['destip'];
		$start	= $test_params['start'];
		$stop	= $test_params['stop'];
		$render = $test_params['render'];
		$test_details_html = null;
		
		// Build the test results for a single date or date range
		$test_range = false;
		if ($stop != 'start') {
			$test_range = true;
			$m7_test_query_str = "SELECT * FROM " . $this->m7_active['db_prefix'] . "_" . $cat . "_" . $type;
			$m7_test_query_str .= " WHERE plan_id='" . $id . "' AND run_time BETWEEN '" . $start . "' AND '" . $stop . "' AND dest_ip='" . $destip . "'";
		} else {
			$m7_test_query_str = "SELECT * FROM " . $this->m7_active['db_prefix'] . "_" . $cat . "_" . $type;
			$m7_test_query_str .= " WHERE plan_id='" . $id . "' AND run_time='" . $start . "' AND dest_ip='" . $destip . "'";
		}
		
		// Execute the test query
		$m7_test_query = $this->m7_db->query($m7_test_query_str);
		
		// If rendering the current item
		if ($render === true) {
			$m7_test_details_render = 'block';
		} else {
			$m7_test_details_render = 'none';
		}
		
		// Build the destination IP HTML ID
		$m7_test_destip_tag = preg_replace("/\./", "_", $destip);
		
		// Build the column headers
		if ($cat == 'net') {
			if ($test_params['type'] == 'ping') {
				$test_results_html = '<div class="m7_test_details_stats" style="display:' . $m7_test_details_render . ';" id="scontent_' . $m7_test_destip_tag . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_sheader"><p>Test Statistics - ' . $destip . '</p></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_scontent">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_headers">' . "\n";
				if ($test_range) {
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Runtime</div></div>' . "\n";
				}
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Pkt. Loss</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Min. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Avg. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Max. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Avg. Deviation</div></div>' . "\n";
				$test_results_html .= '</div>' . "\n";
			}
			if ($test_params['type'] == 'traceroute') {
				$test_results_html = '<div class="m7_test_details_stats" style="display:' . $m7_test_details_render . ';" id="scontent_' . $m7_test_destip_tag . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_sheader"><p>Test Statistics - ' . $destip . '</p></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_scontent">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_headers">' . "\n";
				if ($test_range) {
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Runtime</div></div>' . "\n";
				} else {
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Hop</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Try</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">IP</div></div>' . "\n";
				}
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Time</div></div>' . "\n";
				$test_results_html .= '</div>' . "\n";
			}
			if ($test_params['type'] == 'mtr') {
				$test_results_html = '<div class="m7_test_details_stats" style="display:' . $m7_test_details_render . ';" id="scontent_' . $m7_test_destip_tag . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_sheader"><p>Test Statistics - ' . $destip . '</p></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_scontent">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_headers">' . "\n";
				if ($test_range) {
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Runtime</div></div>' . "\n";
				} else {
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Hop</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">IP</div></div>' . "\n";
				}
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Pkt. Loss</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Min. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Avg. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Max. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Avg. Deviation</div></div>' . "\n";
				$test_results_html .= '</div>' . "\n";
			}
		}
		
		// Define the X/Y axis data arrays
		if ($type == 'traceroute') {
			$m7_test_x_axis = array();
			$m7_test_y_axis = array(
				'time' => array(
					'label'  => false,
					'values' => array() 
				) 
			);
		}
		if ($type == 'mtr') {
			$m7_test_x_axis = array();
			$m7_test_y_axis = array(
				'min_time' => array(
					'label'  => 'Min. Time',
					'values' => array() 
				),
				'avg_time' => array (
					'label'  => 'Avg. Time',
					'values' => array() 
				),
				'max_time' => array(
					'label'  => 'Max. Time',
					'values' => array() 
				) 
			);
		}
		
		// Construct the result rows
		$m7_test_row_alt = false;
		if ($test_range) {
			foreach ($this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']][$this->m7_active['cat']][$destip][$this->m7_active['type']] as $m7_plan_runtime => $m7_plan_runtime_data) {
				if ($m7_test_row_alt === false) {
					$m7_test_row_class = 'row_main';
					$m7_test_row_alt = true;
				} else {
					$m7_test_row_class = 'row_alt';
					$m7_test_row_alt = false;
				}
				if ($type == 'ping') {
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data['pkt_loss'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data['min_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data['avg_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data['max_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data['avg_dev'] . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
				if ($type == 'traceroute') {
					
					// Get the hop averages
					$m7_troute_time_avg_array = array();
					foreach ($m7_plan_runtime_data as $m7_hop => $m7_hop_data) {
					
						// Strip out trailing decimal points for the time (Y axis) and convert * to 0
						$m7_time_clean = preg_replace("/(^[0-9]*)\.[0-9]*$/", "$1", $m7_hop_data['time']);
						$m7_time_clean = preg_replace("/\*/", "0", $m7_time_clean);
					
						// Insert the averages in the arrays
						array_push($m7_troute_time_avg_array, $m7_time_clean);
					}
						
					// Get the raw average value and round
					$m7_troute_time_avg_raw = array_sum($m7_troute_time_avg_array) / count($m7_troute_time_avg_array);
					$m7_troute_time_avg = round($m7_troute_time_avg_raw, 2);
						
					// Append the X/Y axis data
					array_push($m7_test_x_axis, $m7_plan_runtime);
					array_push($m7_test_y_axis['time']['values'], $m7_troute_time_avg);
						
					// Render the HTML block
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_troute_time_avg . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
				if ($type == 'mtr') {
					
					// Get the hop averages
					$m7_mtr_pkt_loss_avg_array = array();
					$m7_mtr_min_time_avg_array = array();
					$m7_mtr_avg_time_avg_array = array();
					$m7_mtr_max_time_avg_array = array();
					$m7_mtr_avg_dev_avg_array = array();
					foreach ($m7_plan_runtime_data as $m7_hop => $m7_hop_data) {
						
						// Strip out trailing decimal points for the time (Y axis) and convert * to 0
						$m7_time_min_clean = preg_replace("/(^[0-9]*)\.[0-9]*$/", "$1", $m7_hop_data['min_time']);
						$m7_time_min_clean = preg_replace("/\*/", "0", $m7_time_min_clean);
						$m7_time_avg_clean = preg_replace("/(^[0-9]*)\.[0-9]*$/", "$1", $m7_hop_data['avg_time']);
						$m7_time_avg_clean = preg_replace("/\*/", "0", $m7_time_avg_clean);
						$m7_time_max_clean = preg_replace("/(^[0-9]*)\.[0-9]*$/", "$1", $m7_hop_data['max_time']);
						$m7_time_max_clean = preg_replace("/\*/", "0", $m7_time_max_clean);
						
						// Insert the averages in the arrays
						array_push ($m7_mtr_pkt_loss_avg_array, $m7_hop_data['pkt_loss']);
						array_push ($m7_mtr_min_time_avg_array, $m7_time_min_clean);
						array_push ($m7_mtr_avg_time_avg_array, $m7_time_avg_clean);
						array_push ($m7_mtr_max_time_avg_array, $m7_time_max_clean);
						array_push ($m7_mtr_avg_dev_avg_array, $m7_hop_data['avg_dev']);
					}
					
					// Get the raw average values of each array
					$m7_mtr_pkt_loss_avg_raw = array_sum($m7_mtr_pkt_loss_avg_array) / count($m7_mtr_pkt_loss_avg_array);
					$m7_mtr_min_time_avg_raw = array_sum($m7_mtr_min_time_avg_array) / count($m7_mtr_min_time_avg_array);
					$m7_mtr_avg_time_avg_raw = array_sum($m7_mtr_avg_time_avg_array) / count($m7_mtr_avg_time_avg_array);
					$m7_mtr_max_time_avg_raw = array_sum($m7_mtr_max_time_avg_array) / count($m7_mtr_max_time_avg_array);
					$m7_mtr_avg_dev_avg_raw = array_sum($m7_mtr_avg_dev_avg_array) / count($m7_mtr_avg_dev_avg_array);
					
					// Round the average values to 2 decimal places
					$m7_mtr_pkt_loss_avg = round($m7_mtr_pkt_loss_avg_raw, 2);
					$m7_mtr_min_time_avg = round($m7_mtr_min_time_avg_raw, 2);
					$m7_mtr_avg_time_avg = round($m7_mtr_avg_time_avg_raw, 2);
					$m7_mtr_max_time_avg = round($m7_mtr_max_time_avg_raw, 2);
					$m7_mtr_avg_dev_avg = round($m7_mtr_avg_dev_avg_raw, 2);
					
					// Append the X/Y axis data
					array_push($m7_test_x_axis, $m7_plan_runtime);
					array_push($m7_test_y_axis['min_time']['values'], $m7_mtr_min_time_avg);
					array_push($m7_test_y_axis['avg_time']['values'], $m7_mtr_avg_time_avg);
					array_push($m7_test_y_axis['max_time']['values'], $m7_mtr_max_time_avg);
					
					// Render the HTML block
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_mtr_pkt_loss_avg . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_mtr_min_time_avg . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_mtr_avg_time_avg . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_mtr_max_time_avg . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_mtr_avg_dev_avg . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
			}
		} else {
			while ($m7_test_row = $m7_test_query->fetch_assoc()) {
				if ($m7_test_row_alt === false) {
					$m7_test_row_class = 'row_main';
					$m7_test_row_alt = true;
				} else {
					$m7_test_row_class = 'row_alt';
					$m7_test_row_alt = false;
				}
				
				// Build the chart data
				if ($type == 'ping') {
					
					// Render the HTML block
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['pkt_loss'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['min_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['avg_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['max_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['avg_dev'] . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
				if ($type == 'traceroute') {
					
					// Strip out trailing decimal points for the time (Y axis) and convert * to 0
					$m7_time_ms_clean = preg_replace("/(^[0-9]*)\.[0-9]*$/", "$1", $m7_test_row['time']);
					$m7_time_ms_clean = preg_replace("/\*/", "0", $m7_time_ms_clean);
					
					// Append the X/Y axis data
					array_push($m7_test_x_axis, $m7_test_row['hop']);
					array_push($m7_test_y_axis['time']['values'], $m7_time_ms_clean);
					
					// Define the row HTML
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['hop'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['try'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['ip'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['time'] . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
				if ($type == 'mtr') {
					
					// Strip out trailing decimal points for the time (Y axis) and convert * to 0
					$m7_time_min_clean = preg_replace("/(^[0-9]*)\.[0-9]*$/", "$1", $m7_test_row['min_time']);
					$m7_time_min_clean = preg_replace("/\*/", "0", $m7_time_min_clean);
					$m7_time_avg_clean = preg_replace("/(^[0-9]*)\.[0-9]*$/", "$1", $m7_test_row['avg_time']);
					$m7_time_avg_clean = preg_replace("/\*/", "0", $m7_time_avg_clean);
					$m7_time_max_clean = preg_replace("/(^[0-9]*)\.[0-9]*$/", "$1", $m7_test_row['max_time']);
					$m7_time_max_clean = preg_replace("/\*/", "0", $m7_time_max_clean);
					
					// Append the X/Y axis data
					array_push($m7_test_x_axis, $m7_test_row['hop']);
					array_push($m7_test_y_axis['min_time']['values'], $m7_time_min_clean);
					array_push($m7_test_y_axis['avg_time']['values'], $m7_time_avg_clean);
					array_push($m7_test_y_axis['max_time']['values'], $m7_time_max_clean);
					
					// Grab the first IP, we will deal with secondary IPs later
					$m7_test_mtr_ip = preg_replace("/(^[^,]*),.*$/", "$1", $m7_test_row['ips'] );
					
					// Render the HTML block
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['hop'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_mtr_ip . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['pkt_loss'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['min_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['avg_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['max_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['avg_dev'] . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
			}
		}
		$test_results_html .= '</div>' . "\n";
		
		// Only render a chart for traceroute or MTR
		if ($type == 'traceroute' || $type == 'mtr') {
			
			// Generate the chart HTML block
			$test_chart_html = '<div class="m7_test_details_chart" style="display:' . $m7_test_details_render . ';" id="ccontent_' . $m7_test_destip_tag . '">' . "\n";
			$test_chart_html .= '<div class="m7_test_details_cheader"><p>Test Chart - ' . $destip . '</p></div>' . "\n";
			$test_chart_html .= '<div class="m7_test_details_ccontent">' . "\n";
			$test_chart_html .= '<div id="chart_' . $m7_test_destip_tag . '"></div>' . "\n";
			$test_chart_html .= $this->lineChart(array(
					'post'   => $m7_test_destip_tag,
					'x_data' => $m7_test_x_axis,
					'y_data' => $m7_test_y_axis 
			),$test_range);
			$test_chart_html .= '</div></div>' . "\n";
			$test_details_html .= $test_chart_html;
		}
		
		// Close the test details block
		$test_details_html .= $test_results_html;
		$test_details_html .= '</div>';
		return $test_details_html;
	}
	
	// Return test details in HTML format
	public function testDetails() {
		$m7_test_details_properties = array (
				'plan_id'	=> 'ID',
				'desc'		=> 'Description',
				'host'		=> 'Host',
				'cat'		=> 'Category',
				'type'		=> 'Type',
				'first_run' => 'First Run',
				'last_run'	=> 'Last Run' 
		);
		
		// Open the test details HTML block
		$test_details_html = '<div class="m7_test_details_show">Show Test Details</div>';
		$test_details_html .= '<div class="m7_test_details">';
		$test_details_html .= '<div class="m7_test_details_bg"></div>';
		$test_details_html .= '<div class="m7_test_details_content">';
		
		// Query the tests table
		$m7_test_table_query = $this->m7_db->query ( "SELECT * FROM plans WHERE plan_id='" . $this->m7_active['plan'] . "'" );
		
		// Build the test detail properties
		$test_details_html .= '<div class="m7_test_details_properties">' . "\n";
		$test_details_html .= '<div class="m7_test_details_pheader" id="ptoggle"><p>Test Properties</p></div>' . "\n";
		while ( $m7_test_table_row = $m7_test_table_query->fetch_assoc () ) {
			$test_details_html .= '<div class="m7_test_details_pcontent" id="pcontent">' . "\n";
			foreach ( $m7_test_details_properties as $m7_test_details_key => $m7_test_details_desc ) {
				if ($m7_test_details_key == 'host' || $m7_test_details_key == 'cat' || $m7_test_details_key == 'type') {
					$m7_test_details_value = $this->m7_active[$m7_test_details_key];
				} else {
					$m7_test_details_value = $m7_test_table_row [$m7_test_details_key];
				}
				$test_details_html .= '<div class="m7_test_details_pcontent_info">' . "\n";
				$test_details_html .= '<div class="m7_test_details_pcontent_label">' . $m7_test_details_desc . '</div>' . "\n";
				$test_details_html .= '<div class="m7_test_details_pcontent_value">' . $m7_test_details_value . '</div>' . "\n";
				$test_details_html .= '</div>' . "\n";
			}
		}
		$test_details_html .= '</div></div>' . "\n";
		
		// If a destination IP specified
		if (isset ( $this->m7_active['destip'] ) && $this->m7_active['destip'] != 'all') {
			$test_details_html .= $this->singleIPTestResults ( array (
					'id'	 => $this->m7_active['plan'],
					'host'	 => $this->m7_active['host'],
					'cat'	 => $this->m7_active['cat'],
					'destip' => $this->m7_active['destip'],
					'type' 	 => $this->m7_active['type'],
					'start'  => $this->m7_active['start'],
					'stop'   => $this->m7_active['stop'],
					'render' => true 
			) );
		} else {
			
			// Build the toggle buttons for each destination IP
			$test_details_html .= '<div class="m7_test_destination_ip">' . "\n";
			$test_details_html .= '<div class="m7_test_destination_ip_title">Destination IP: </div>' . "\n";
			$test_details_html .= '<div class="m7_test_destination_ip_menu">' . "\n";
			$test_details_html .= '<select id="dest_ip">' . "\n";
			foreach ( $this->m7_destips as $m7_test_destip_alias => $m7_test_destip_val ) {
				$m7_test_destip_tag = preg_replace ( "/\./", "_", $m7_test_destip_val );
				$test_details_html .= '<option value="' . $m7_test_destip_tag . '">' . $m7_test_destip_val . ' - ' . $m7_test_destip_alias . '</option>' . "\n";
			}
			$test_details_html .= '</select></div></div>' . "\n";
			
			// Build the results for each destination IP
			$m7_test_details_render = true;
			foreach ( $this->m7_destips as $m7_test_destip ) {
				$test_details_html .= $this->singleIPTestResults ( array (
						'id'	 => $this->m7_active['plan'],
						'host'	 => $this->m7_active['host'],
						'type'	 => $this->m7_active['type'],
						'cat'	 => $this->m7_active['cat'],
						'destip' => $m7_test_destip,
						'start'  => $this->m7_active['start'],
						'stop'   => $this->m7_active['stop'],
						'render' => $m7_test_details_render 
				) );
				$m7_test_details_render = false;
			}
		}
		
		// Return the HTML block
		$test_details_html .= '</div></div>';
		return $test_details_html;
	}
	
	/**
	 * Render World Map
	 */
	public function renderWorldMap($map_json) {
		
		// Construct the world map code
		$world_map = $this->mapHostDetails();
		$world_map .=  $this->mapKey(); 
		$world_map .= '<div id="alert_box_container"></div>';
		$world_map .= '<div id="server_info" class="m7_server_info">';
		$world_map .= '<div class="m7_server_clock">';
		$world_map .= '<div class="m7_date_label">Server Time:</div>';
		$world_map .= '<div class="m7_date_unit" id="year">' . date('Y') . '</div><div class="m7_date_seperator">-</div>';
		$world_map .= '<div class="m7_date_unit" id="month">' . date('m') . '</div><div class="m7_date_seperator">-</div>';
		$world_map .= '<div class="m7_date_unit" id="day">' . date('d') . '</div>';
		$world_map .= '<div class="m7_date_unit" id="hour">' . date('H') . '</div><div class="m7_date_seperator">:</div>';
		$world_map .= '<div class="m7_date_unit" id="minute">' . date('i') . '</div><div class="m7_date_seperator">:</div>';
		$world_map .= '<div class="m7_date_unit" id="second">' . date('s') . '</div></div>';
		$world_map .= '<div class="m7_server_status">';
		$world_map .= '<div class="m7_server_status_block"><div class="m7_server_status_left">Scheduler: </div><div class="m7_server_status_right" id="scheduler"></div></div>';
		$world_map .= '<div class="m7_server_status_block"><div class="m7_server_status_left">SocketIO: </div><div class="m7_server_status_right" id="socketio"></div></div>';
		$world_map .= '</div></div>';
		$world_map .= '<div id="map_container"></div>';
		$world_map .= '<script>';
	
		// Window dimensions
		$world_map .= 'var width = $(window).width();';
		$world_map .= 'var height = $(window).height() - 50;';
		
		// Map projection
		$world_map .= 'var projection = d3.geo.mercator()';
		$world_map .= '.scale((width + 1) / 2 / Math.PI)';
		$world_map .= '.translate([width / 2, height / 2])';
		$world_map .= '.precision(.1);';
		
		// Map path, color scale, and graticule
		$world_map .= 'var path = d3.geo.path()';
		$world_map .= '.projection(projection);';
		$world_map .= 'var color = d3.scale.category20();';
		$world_map .= 'var graticule = d3.geo.graticule();';
		
		// Initialize the map SVG
		$world_map .= 'var svg = d3.select("#map_container").append("svg")';
		$world_map .= '.attr("width", width)';
		$world_map .= '.attr("height", height);';
		$world_map .= 'svg.append("path")';
		$world_map .= '.datum(graticule)';
		$world_map .= '.attr("class", "graticule")';
		$world_map .= '.attr("d", path);';
		
		// Define map features
		$world_map .= 'var features = svg.append("g");';
		$world_map .= 'var maphosts = svg.append("g");';
		
		// Construct the world map
		$world_map .= 'd3.json("' . $map_json . '", function(error, world) {';
		
		// Define zooming behavior
		$world_map .= 'var zoom = d3.behavior.zoom()';
		$world_map .= '.scaleExtent([1, 8])';
		$world_map .= '.on("zoom", zoomed);';
		
		// Create the mouse actions overlay
		$world_map .= 'svg.append("rect")';
		$world_map .= '.attr("class", "overlay")';
		$world_map .= '.attr("width", width)';
		$world_map .= '.attr("height", height)';
		$world_map .= '.call(zoom);';
		
		// Insert the world map land objects
		$world_map .= 'features.insert("path", ".graticule")';
		$world_map .= '.datum(topojson.feature(world, world.objects.land))';
		$world_map .= '.attr("class", "land")';
		$world_map .= '.attr("d", path);';
		
		// Inser the land mass boundaries
		$world_map .= 'features.insert("path", ".graticule")';
		$world_map .= '.datum(topojson.mesh(world, world.objects.countries, function(a, b) { return a !== b; }))';
		$world_map .= '.attr("class", "boundary")';
		$world_map .= '.attr("d", path);';
		
		// Render the cluster node map points
		$world_map .= $this->mapHosts();
		
		// Render testing map paths if global rendering is true
		if($this->m7_ready) {
			$world_map .= $this->mapPaths();
		}
		
		// Define the zoom function
		$world_map .= 'function zoomed() {';
		$world_map .= 'var t = d3.event.translate;';
		$world_map .= 'var s = d3.event.scale;';
		$world_map .= 'zscale = s;';
		$world_map .= 'var h = height/4;';
		$world_map .= 't[0] = Math.min((width / height) * (s - 1), Math.max(width * (1 - s), t[0]));';
		$world_map .= 't[1] = Math.min(h * (s - 1) + h * s, Math.max(height * (1 - s) - h * s, t[1]));';
		$world_map .= 'zoom.translate(t);';
		$world_map .= 'features.style("stroke-width", 1 / s).attr("transform", "translate(" + t + "),scale(" + s + ")");}';
		$world_map .= '});';
		
		// Use the world map container
		$world_map .= 'd3.select(self.frameElement).style("height", height + "px");';
		$world_map .= '</script>';
		return $world_map;
	}
	
	// Render the map key
	public function mapKey() {
		if ($this->m7_ready) {
			$map_key_html = null;
			
			// Network test map key
			if ($this->m7_active['cat'] == 'net') {
				if (!empty ($this->m7_destips)) {
					$map_key_html .= '<div class="m7_map_key">';
					$map_key_html .= '<div class="m7_map_key_title">Map Key</div>';
					$m7_key_count = 1;
					foreach ($this->m7_destips as $m7_destip_val) {
						$map_key_html .= '<div class="m7_map_key_entry">';
						$map_key_html .= '<div class="m7_map_key_color key' . $m7_key_count . '"></div>';
						$map_key_html .= '<div class="m7_map_key_txt">Destination - ' . $m7_destip_val . '</div>';
						$map_key_html .= '</div>';
						$m7_key_count ++;
					}
					$map_key_html .= '</div>';
				}
			}
			
			// DNS test map key
			if ($this->m7_active['cat'] == 'dns') {
				
			}
			
			// Web test map key
			if ($this->m7_active['cat'] == 'web') {
				
			}
			
			// Return the map key HTML
			return $map_key_html;
		}
	}
	
	// Render the test plan menu
	public function planMenu() {
		
		// Plan ID dropdown
		$plan_menu_html = '<div class="m7_plan_id">';
		$plan_menu_html .= '<div class="m7_plan_id_title">Plan</div>';
		$plan_menu_html .= '<div class="m7_plan_id_menu">';
		$plan_menu_html .= '<select name="id">';
		foreach ( $this->m7_plans as $m7_plan_id => $m7_plan_params ) {
			if (isset ( $this->m7_active['plan'] ) && $m7_plan_id == $this->m7_active['plan']) {
				$plan_menu_html .= '<option selected="selected" value="' . $m7_plan_id . '">' . $m7_plan_id . ' - ' . $m7_plan_params['desc'] . '</option>' . "\n";
			} else {
				$plan_menu_html .= '<option value="' . $m7_plan_id . '">' . $m7_plan_id . ' - ' . $m7_plan_params['desc'] . '</option>' . "\n";
			}
		}
		$plan_menu_html .= '</select></div></div>';

		// Only render the rest of the menu if a plan ID is selected
		if ($this->m7_ready) {

			// Source host dropdown
			$plan_menu_html .= '<div class="m7_test_host">';
			$plan_menu_html .= '<div class="m7_test_shost_title">Host</div>';
			$plan_menu_html .= '<div class="m7_test_shost_menu">';
			$plan_menu_html .= '<select name="shost">';
			foreach ( $this->m7_hosts as $m7_host => $m7_host_params ) {
				if (isset ( $this->m7_active['host'] ) && $m7_host == $this->m7_active['host']) {
					$plan_menu_html .= '<option selected="selected" value="' . $m7_host . '">' . $m7_host . ' - ' . $m7_host_params ['desc'] . '</option>' . "\n";
				} else {
					$plan_menu_html .= '<option value="' . $m7_host . '">' . $m7_host . ' - ' . $m7_host_params ['desc'] . '</option>' . "\n";
				}
			}
			$plan_menu_html .= '</select></div></div>';
			
			// Test plan type dropdown
			$plan_menu_html .= '<div class="m7_test_type">';
			$plan_menu_html .= '<div class="m7_test_type_title">Type</div>';
			$plan_menu_html .= '<div class="m7_test_type_menu">';
			$plan_menu_html .= '<select name="type">';
			
			// Get an array of all types by plan ID
			$m7_plan_cat_types = explode(',', $this->m7_plans[$this->m7_active['plan']]['types']);
			foreach ( $m7_plan_cat_types as $m7_plan_cat_type ) {
				if (isset ( $this->m7_active['type'] ) && $m7_plan_cat_type == $this->m7_active['type']) {
					$plan_menu_html .= '<option selected="selected" value="' . $m7_plan_cat_type . '">' . $m7_plan_cat_type . '</option>' . "\n";
				} else {
					$plan_menu_html .= '<option value="' . $m7_plan_cat_type . '">' . $m7_plan_cat_type . '</option>' . "\n";
				}
			}
			$plan_menu_html .= '</select></div></div>';
			
			// Destination IPs dropdown
			if ($this->m7_active['cat'] == 'net') {
				$plan_menu_html .= '<div class="m7_test_destip_type">';
				$plan_menu_html .= '<div class="m7_test_destip_title">Destination IP</div>';
				$plan_menu_html .= '<div class="m7_test_destip_menu">';
				$plan_menu_html .= '<select name="destip">';
				$plan_menu_html .= '<option value="all">--All--</option>';
				if (isset ( $this->m7_destips )) {
					foreach ( $this->m7_destips as $m7_destip_alias => $m7_destip_val ) {
						if ($m7_destip_val == $this->m7_active['destip']) {
							$plan_menu_html .= '<option selected="selected" value="' . $m7_destip_val . '">' . $m7_destip_val . ' - ' . $m7_destip_alias . '</option>' . "\n";
						} else {
							$plan_menu_html .= '<option value="' . $m7_destip_val . '">' . $m7_destip_val . ' - ' . $m7_destip_alias . '</option>' . "\n";
						}
					}
				}
				$plan_menu_html .= '</select></div></div>';
			}
			
			// Test start time dropdown
			$plan_menu_html .= '<div class="m7_test_start">';
			$plan_menu_html .= '<div class="m7_test_start_title">Start Time</div>';
			$plan_menu_html .= '<div class="m7_test_start_menu">';
			$plan_menu_html .= '<select name="start">';
			$plan_menu_html .= '<option value="recent">--Most Recent--</option>';
			if (isset ( $this->m7_runtimes )) {
				foreach ( $this->m7_runtimes as $m7_start_val ) {
					if (isset ( $this->m7_active['start'] ) && $m7_start_val == $this->m7_active['start']) {
						$plan_menu_html .= '<option selected="selected" value="' . $m7_start_val . '">' . $m7_start_val . '</option>';
					} else {
						$plan_menu_html .= '<option value="' . $m7_start_val . '">' . $m7_start_val . '</option>';
					}
				}
			}
			$plan_menu_html .= '</select></div></div>';
			 
			// Test stop time dropdown
			$plan_menu_html .= '<div class="m7_test_stop">';
			$plan_menu_html .= '<div class="m7_test_stop_title">Stop Time</div>';
			$plan_menu_html .= '<div class="m7_test_stop_menu">';
			$plan_menu_html .= '<select name="stop">';
			$plan_menu_html .= '<option value="start">--Start--</option>';
			if (isset ( $this->m7_runtimes )) {
				foreach ( $this->m7_runtimes as $m7_stop_val ) {
					if (isset ( $this->m7_active['stop'] ) && $m7_stop_val == $this->m7_active['stop']) {
						$plan_menu_html .= '<option selected="selected" value="' . $m7_stop_val . '">' . $m7_stop_val . '</option>';
					} else {
						$plan_menu_html .= '<option value="' . $m7_stop_val . '">' . $m7_stop_val . '</option>';
					}
				}
			}
			$plan_menu_html .= '</select></div></div>';
			$plan_menu_html .= $this->testDetails();
		}
		
		// Return the plan menu HTML
		return $plan_menu_html;
	}
}