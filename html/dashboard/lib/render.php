<?php
class Render extends D3JS {
	
	// Test parameters / properties / destination IPs
	public $m7_params = array ();
	public $m7_tprops = array ();
	public $m7_destips = array ();
	public $m7_ready;
	
	// Class constructor
	public function __construct() {
		parent::__construct ();
		$this->planInit ();
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
	public function m7MapPaths() {
		$m7_paths_js = null;
		switch ($this->m7_active ['cat']) {
			case 'web' :
				
				// TODO: Still not sure how I'm going to handle rendering web tests on the world map
				break;
			case 'net' :
				$m7_stroke_count = 1;
				
				// Render one path per destination IP
				foreach ( $this->m7_destips as $m7_destip ) {
					$m7_hop_coords_str = null;
					switch ($this->m7_active ['type']) {
						case 'ping' :
							
							// Get the latitude and longitude for the source and destination hosts
							$m7_ping_slat = $this->m7_plan [$this->m7_active ['plan']] [$this->m7_active ['host']] ['lat'];
							$m7_ping_slon = $this->m7_plan [$this->m7_active ['plan']] [$this->m7_active ['host']] ['lon'];
							$m7_ping_dlat = $this->m7_plan [$this->m7_active ['plan']] [$this->m7_active ['host']] [$this->m7_active ['cat']] [$m7_destip] ['lat'];
							$m7_ping_dlon = $this->m7_plan [$this->m7_active ['plan']] [$this->m7_active ['host']] [$this->m7_active ['cat']] [$m7_destip] ['lon'];
							
							// Only print if all coordinates are known
							if ($m7_ping_slat != '*' && $m7_ping_slon != '*' && $m7_ping_dlat != '*' && $m7_ping_dlon != '*') {
								$m7_coords_str = '[' . $m7_ping_slon . ',' . $m7_ping_slat . '],';
								$m7_coords_str .= '[' . $m7_ping_dlon . ',' . $m7_ping_dlat . ']';
								$m7_paths_js .= 'svg.append("path")' . "\n";
								$m7_paths_js .= '.datum({type: "LineString", coordinates: [' . $m7_coords_str . ']})' . "\n";
								$m7_paths_js .= '.style("stroke", function(d) { return color(' . $m7_stroke_count . '); })' . "\n";
								$m7_paths_js .= '.style("fill", "none")' . "\n";
								$m7_paths_js .= '.style("stroke-width", "2px")' . "\n";
								$m7_paths_js .= '.attr("d", path);' . "\n";
							}
							break;
						case 'traceroute' :
							foreach ( $this->m7_plan [$this->m7_active ['plan']] [$this->m7_active ['host']] [$this->m7_active ['cat']] [$m7_destip] ['traceroute'] [$this->m7_active ['start']] as $m7_traceroute_hop => $m7_traceroute_hop_params ) {
								
								// Get the hop latitude and longitude
								$m7_hop_lat = $m7_traceroute_hop_params ['ip'] ['lat'];
								$m7_hop_lon = $m7_traceroute_hop_params ['ip'] ['lon'];
								
								// Only print if both coordinates are known
								if ($m7_hop_lat != '*' && $m7_hop_lon != '*') {
									$m7_hop_coords = '[' . $m7_hop_lon . ',' . $m7_hop_lat . ']';
									if (! isset ( $m7_hop_coords_str )) {
										$m7_hop_coords_str = $m7_hop_coords;
									} else {
										$m7_hop_coords_str .= ',' . $m7_hop_coords;
									}
								}
							}
							$m7_paths_js .= 'svg.append("path")' . "\n";
							$m7_paths_js .= '.datum({type: "LineString", coordinates: [' . $m7_hop_coords_str . ']})' . "\n";
							$m7_paths_js .= '.style("stroke", function(d) { return color(' . $m7_stroke_count . '); })' . "\n";
							$m7_paths_js .= '.style("fill", "none")' . "\n";
							$m7_paths_js .= '.style("stroke-width", "2px")' . "\n";
							$m7_paths_js .= '.attr("d", path);' . "\n";
							break;
						case 'mtr' :
							foreach ( $this->m7_plan [$this->m7_active ['plan']] [$this->m7_active ['host']] [$this->m7_active ['cat']] [$m7_destip] ['mtr'] [$this->m7_active ['start']] as $m7_mtr_hop => $m7_mtr_hop_params ) {
								$m7_mtr_hop_ip = current ( array_keys ( $m7_mtr_hop_params ['ips'] ) );
								
								// Get the hop latitude and longitude
								$m7_hop_lat = $m7_mtr_hop_params ['ips'] [$m7_mtr_hop_ip] ['lat'];
								$m7_hop_lon = $m7_mtr_hop_params ['ips'] [$m7_mtr_hop_ip] ['lon'];
								
								// Only print if both coordinates are known
								if ($m7_hop_lat != '*' && $m7_hop_lon != '*') {
									$m7_hop_coords = '[' . $m7_hop_lon . ',' . $m7_hop_lat . ']';
									if (! isset ( $m7_hop_coords_str )) {
										$m7_hop_coords_str = $m7_hop_coords;
									} else {
										$m7_hop_coords_str .= ',' . $m7_hop_coords;
									}
								}
							}
							$m7_paths_js .= 'svg.append("path")' . "\n";
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
		$post = '_' . $chart_params ['post'];
		$x_data = $chart_params ['x_data'];
		$y_data = $chart_params ['y_data'];
		
		// Get the max value for the X axis
		$x_max = max ( $x_data );
		
		// Set the X axis label
		if ($test_range) {
			$x_label = 'Run Time';
		} else {
			$x_label = 'Hop';
		}
		
		// Calculate the max value for the Y-axis w/ padding
		$y_data_max_array = array ();
		foreach ( $y_data as $data_type => $data_params ) {
			foreach ( $data_params ['values'] as $data_value ) {
				array_push ( $y_data_max_array, $data_value );
			}
		}
		$y_max_base = max ( $y_data_max_array );
		$y_buffer = bcdiv ( $y_max_base, '5', '0' );
		$y_max = bcadd ( $y_max_base, $y_buffer );
		
		// Construct the D3JS JavaScript
		$chart_js = $this->buildLineChart ( array (
				'post' => $post,
				'x' => array (
						'unit' => 'hop',
						'max' => $x_max,
						'label' => $x_label,
						'data' => array (
								'label' => false,
								'values' => $x_data 
						) 
				),
				'y' => array (
						'unit' => 'ms',
						'max' => $y_max,
						'label' => 'Time (ms)',
						'data' => $y_data 
				) 
		), $test_range );
		return $chart_js;
	}
	
	// Get the properties for a single destination IP
	public function singleIPTestResults($test_params = array()) {
		$test_details_html = null;
		
		// If building test results for a date range
		$test_range = false;
		if ($test_params ['stop'] != 'start') {
			$test_range = true;
			
			// Build the test query
			$m7_test_query_str = "SELECT * FROM " . $this->m7_active ['db_prefix'] . "_" . $test_params ['cat'] . "_" . $test_params ['type'];
			$m7_test_query_str .= " WHERE plan_id='" . $test_params ['id'] . "' AND run_time BETWEEN '" . $test_params ['start'] . "' AND '" . $test_params ['stop'] . "' AND dest_ip='" . $test_params ['destip'] . "'";
		} else {
			
			// Build the test query
			$m7_test_query_str = "SELECT * FROM " . $this->m7_active ['db_prefix'] . "_" . $test_params ['cat'] . "_" . $test_params ['type'];
			$m7_test_query_str .= " WHERE plan_id='" . $test_params ['id'] . "' AND run_time='" . $test_params ['start'] . "' AND dest_ip='" . $test_params ['destip'] . "'";
		}
		
		// Execute the test query
		$m7_test_query = $this->m7_db->query ( $m7_test_query_str );
		
		// If rendering the current item
		if ($test_params ['render'] === true) {
			$m7_test_details_render = 'block';
		} else {
			$m7_test_details_render = 'none';
		}
		
		// Build the destination IP HTML ID
		$m7_test_destip_tag = preg_replace ( "/\./", "_", $test_params ['destip'] );
		
		// Build the column headers
		if ($test_params ['cat'] == 'net') {
			if ($test_params ['type'] == 'ping') {
				$test_results_html = '<div class="m7_test_details_stats" style="display:' . $m7_test_details_render . ';" id="scontent_' . $m7_test_destip_tag . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_sheader"><p>Test Statistics - ' . $test_params ['destip'] . '</p></div>' . "\n";
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
			if ($test_params ['type'] == 'traceroute') {
				$test_results_html = '<div class="m7_test_details_stats" style="display:' . $m7_test_details_render . ';" id="scontent_' . $m7_test_destip_tag . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_sheader"><p>Test Statistics - ' . $test_params ['destip'] . '</p></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_scontent">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_headers">' . "\n";
				if ($test_range) {
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Runtime</div></div>' . "\n";
				} else {
					$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Hop</div></div>' . "\n";
				}
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Try</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">IP</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Time</div></div>' . "\n";
				$test_results_html .= '</div>' . "\n";
			}
			if ($test_params ['type'] == 'mtr') {
				$test_results_html = '<div class="m7_test_details_stats" style="display:' . $m7_test_details_render . ';" id="scontent_' . $m7_test_destip_tag . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_sheader"><p>Test Statistics - ' . $test_params ['destip'] . '</p></div>' . "\n";
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
		if ($test_params ['type'] == 'traceroute') {
			$m7_test_x_axis = array ();
			$m7_test_y_axis = array (
					'time' => array (
							'label' => false,
							'values' => array () 
					) 
			);
		}
		if ($test_params ['type'] == 'mtr') {
			$m7_test_x_axis = array ();
			$m7_test_y_axis = array (
					'min_time' => array (
							'label' => 'Min. Time',
							'values' => array () 
					),
					'avg_time' => array (
							'label' => 'Avg. Time',
							'values' => array () 
					),
					'max_time' => array (
							'label' => 'Max. Time',
							'values' => array () 
					) 
			);
		}
		
		// Construct the result rows
		$m7_test_row_alt = false;
		if ($test_range) {
			foreach ( $this->m7_plan [$this->m7_active ['plan']] [$this->m7_active ['host']] [$this->m7_active ['cat']] [$test_params ['destip']] [$this->m7_active ['type']] as $m7_plan_runtime => $m7_plan_runtime_data ) {
				if ($m7_test_row_alt === false) {
					$m7_test_row_class = 'row_main';
					$m7_test_row_alt = true;
				} else {
					$m7_test_row_class = 'row_alt';
					$m7_test_row_alt = false;
				}
				if ($test_params ['type'] == 'ping') {
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data ['pkt_loss'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data ['min_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data ['avg_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data ['max_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_plan_runtime_data ['avg_dev'] . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
				if ($test_params ['type'] == 'traceroute') {
					
					// TODO: Need to copy the functionality from MTR to here. And render the single line.
				}
				if ($test_params ['type'] == 'mtr') {
					
					// Get the hop averages
					$m7_mtr_pkt_loss_avg_array = array ();
					$m7_mtr_min_time_avg_array = array ();
					$m7_mtr_avg_time_avg_array = array ();
					$m7_mtr_max_time_avg_array = array ();
					$m7_mtr_avg_dev_avg_array = array ();
					foreach ( $m7_plan_runtime_data as $m7_hop => $m7_hop_data ) {
						
						// Strip out trailing decimal points for the time (Y axis) and convert * to 0
						$m7_time_min_clean = preg_replace ( "/(^[0-9]*)\.[0-9]*$/", "$1", $m7_hop_data ['min_time'] );
						$m7_time_min_clean = preg_replace ( "/\*/", "0", $m7_time_min_clean );
						$m7_time_avg_clean = preg_replace ( "/(^[0-9]*)\.[0-9]*$/", "$1", $m7_hop_data ['avg_time'] );
						$m7_time_avg_clean = preg_replace ( "/\*/", "0", $m7_time_avg_clean );
						$m7_time_max_clean = preg_replace ( "/(^[0-9]*)\.[0-9]*$/", "$1", $m7_hop_data ['max_time'] );
						$m7_time_max_clean = preg_replace ( "/\*/", "0", $m7_time_max_clean );
						
						// Insert the averages in the arrays
						array_push ( $m7_mtr_pkt_loss_avg_array, $m7_hop_data ['pkt_loss'] );
						array_push ( $m7_mtr_min_time_avg_array, $m7_time_min_clean );
						array_push ( $m7_mtr_avg_time_avg_array, $m7_time_avg_clean );
						array_push ( $m7_mtr_max_time_avg_array, $m7_time_max_clean );
						array_push ( $m7_mtr_avg_dev_avg_array, $m7_hop_data ['avg_dev'] );
					}
					
					// Get the raw average values of each array
					$m7_mtr_pkt_loss_avg_raw = array_sum ( $m7_mtr_pkt_loss_avg_array ) / count ( $m7_mtr_pkt_loss_avg_array );
					$m7_mtr_min_time_avg_raw = array_sum ( $m7_mtr_min_time_avg_array ) / count ( $m7_mtr_min_time_avg_array );
					$m7_mtr_avg_time_avg_raw = array_sum ( $m7_mtr_avg_time_avg_array ) / count ( $m7_mtr_avg_time_avg_array );
					$m7_mtr_max_time_avg_raw = array_sum ( $m7_mtr_max_time_avg_array ) / count ( $m7_mtr_max_time_avg_array );
					$m7_mtr_avg_dev_avg_raw = array_sum ( $m7_mtr_avg_dev_avg_array ) / count ( $m7_mtr_avg_dev_avg_array );
					
					// Round the average values to 2 decimal places
					$m7_mtr_pkt_loss_avg = round ( $m7_mtr_pkt_loss_avg_raw, 2 );
					$m7_mtr_min_time_avg = round ( $m7_mtr_min_time_avg_raw, 2 );
					$m7_mtr_avg_time_avg = round ( $m7_mtr_avg_time_avg_raw, 2 );
					$m7_mtr_max_time_avg = round ( $m7_mtr_max_time_avg_raw, 2 );
					$m7_mtr_avg_dev_avg = round ( $m7_mtr_avg_dev_avg_raw, 2 );
					
					// Append the X/Y axis data
					array_push ( $m7_test_x_axis, $m7_plan_runtime );
					array_push ( $m7_test_y_axis ['min_time'] ['values'], $m7_mtr_min_time_avg );
					array_push ( $m7_test_y_axis ['avg_time'] ['values'], $m7_mtr_avg_time_avg );
					array_push ( $m7_test_y_axis ['max_time'] ['values'], $m7_mtr_max_time_avg );
					
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
			while ( $m7_test_row = $m7_test_query->fetch_assoc () ) {
				if ($m7_test_row_alt === false) {
					$m7_test_row_class = 'row_main';
					$m7_test_row_alt = true;
				} else {
					$m7_test_row_class = 'row_alt';
					$m7_test_row_alt = false;
				}
				
				// Build the chart data
				if ($test_params ['type'] == 'ping') {
					
					// Render the HTML block
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['pkt_loss'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['min_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['avg_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['max_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['avg_dev'] . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
				if ($test_params ['type'] == 'traceroute') {
					
					// Strip out trailing decimal points for the time (Y axis) and convert * to 0
					$m7_time_ms_clean = preg_replace ( "/(^[0-9]*)\.[0-9]*$/", "$1", $m7_test_row ['time'] );
					$m7_time_ms_clean = preg_replace ( "/\*/", "0", $m7_time_ms_clean );
					
					// Append the X/Y axis data
					array_push ( $m7_test_x_axis, $m7_test_row ['hop'] );
					array_push ( $m7_test_y_axis ['time'] ['values'], $m7_time_ms_clean );
					
					// Define the row HTML
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['hop'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['try'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['ip'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['time'] . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
				if ($test_params ['type'] == 'mtr') {
					
					// Strip out trailing decimal points for the time (Y axis) and convert * to 0
					$m7_time_min_clean = preg_replace ( "/(^[0-9]*)\.[0-9]*$/", "$1", $m7_test_row ['min_time'] );
					$m7_time_min_clean = preg_replace ( "/\*/", "0", $m7_time_min_clean );
					$m7_time_avg_clean = preg_replace ( "/(^[0-9]*)\.[0-9]*$/", "$1", $m7_test_row ['avg_time'] );
					$m7_time_avg_clean = preg_replace ( "/\*/", "0", $m7_time_avg_clean );
					$m7_time_max_clean = preg_replace ( "/(^[0-9]*)\.[0-9]*$/", "$1", $m7_test_row ['max_time'] );
					$m7_time_max_clean = preg_replace ( "/\*/", "0", $m7_time_max_clean );
					
					// Append the X/Y axis data
					array_push ( $m7_test_x_axis, $m7_test_row ['hop'] );
					array_push ( $m7_test_y_axis ['min_time'] ['values'], $m7_time_min_clean );
					array_push ( $m7_test_y_axis ['avg_time'] ['values'], $m7_time_avg_clean );
					array_push ( $m7_test_y_axis ['max_time'] ['values'], $m7_time_max_clean );
					
					// Grab the first IP, we will deal with secondary IPs later
					$m7_test_mtr_ip = preg_replace ( "/(^[^,]*),.*$/", "$1", $m7_test_row ['ips'] );
					
					// Render the HTML block
					$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['hop'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_mtr_ip . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['pkt_loss'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['min_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['avg_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['max_time'] . '</div></div>' . "\n";
					$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row ['avg_dev'] . '</div></div>' . "\n";
					$test_results_html .= '</div>' . "\n";
				}
			}
		}
		$test_results_html .= '</div>' . "\n";
		
		// Only render a chart for traceroute or MTR
		if ($test_params ['type'] == 'traceroute' || $test_params ['type'] == 'mtr') {
			
			// Generate the chart HTML block
			$test_chart_html = '<div class="m7_test_details_chart" style="display:' . $m7_test_details_render . ';" id="ccontent_' . $m7_test_destip_tag . '">' . "\n";
			$test_chart_html .= '<div class="m7_test_details_cheader"><p>Test Chart - ' . $test_params ['destip'] . '</p></div>' . "\n";
			$test_chart_html .= '<div class="m7_test_details_ccontent">' . "\n";
			$test_chart_html .= '<div id="chart_' . $m7_test_destip_tag . '"></div>' . "\n";
			$test_chart_html .= $this->lineChart ( array (
					'post' => $m7_test_destip_tag,
					'x_data' => $m7_test_x_axis,
					'y_data' => $m7_test_y_axis 
			), $test_range );
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
				'plan_id' => 'ID',
				'desc' => 'Description',
				'host' => 'Host',
				'cat' => 'Category',
				'type' => 'Type',
				'first_run' => 'First Run',
				'last_run' => 'Last Run' 
		);
		
		// Open the test details HTML block
		$test_details_html = '<div class="m7_test_details_show">Show Test Details</div>';
		$test_details_html .= '<div class="m7_test_details">';
		$test_details_html .= '<div class="m7_test_details_bg"></div>';
		$test_details_html .= '<div class="m7_test_details_content">';
		
		// Query the tests table
		$m7_test_table_query = $this->m7_db->query ( "SELECT * FROM plans WHERE plan_id='" . $this->m7_active ['plan'] . "'" );
		
		// Build the test detail properties
		$test_details_html .= '<div class="m7_test_details_properties">' . "\n";
		$test_details_html .= '<div class="m7_test_details_pheader" id="ptoggle"><p>Test Properties</p></div>' . "\n";
		while ( $m7_test_table_row = $m7_test_table_query->fetch_assoc () ) {
			$test_details_html .= '<div class="m7_test_details_pcontent" id="pcontent">' . "\n";
			foreach ( $m7_test_details_properties as $m7_test_details_key => $m7_test_details_desc ) {
				if ($m7_test_details_key == 'host' || $m7_test_details_key == 'cat' || $m7_test_details_key == 'type') {
					$m7_test_details_value = $this->m7_active [$m7_test_details_key];
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
		if (isset ( $this->m7_active ['destip'] ) && $this->m7_active ['destip'] != 'all') {
			$test_details_html .= $this->singleIPTestResults ( array (
					'id' => $this->m7_active ['plan'],
					'host' => $this->m7_active ['host'],
					'cat' => $this->m7_active ['cat'],
					'destip' => $this->m7_active ['destip'],
					'type' => $this->m7_active ['type'],
					'start' => $this->m7_active ['start'],
					'stop' => $this->m7_active ['stop'],
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
						'id' => $this->m7_active ['plan'],
						'host' => $this->m7_active ['host'],
						'type' => $this->m7_active ['type'],
						'cat' => $this->m7_active ['cat'],
						'destip' => $m7_test_destip,
						'start' => $this->m7_active ['start'],
						'stop' => $this->m7_active ['stop'],
						'render' => $m7_test_details_render 
				) );
				$m7_test_details_render = false;
			}
		}
		
		// Return the HTML block
		$test_details_html .= '</div></div>';
		return $test_details_html;
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
			$plan_menu_html .= '<option value="' . $m7_plan_id . '">' . $m7_plan_id . ' - ' . $m7_plan_params['desc'] . '</option>' . "\n";
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
				if (isset ( $this->m7_active['type'] ) && $m7_plan_cat_type == $this_active['type']) {
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

?>