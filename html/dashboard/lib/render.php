<?php 

class Render extends D3JS {
	
	// Test parameters / properties / destination IPs
	public $m7_params	= array();
	public $m7_tprops	= array();
	public $m7_destips	= array();
	
	// Class constructor
	public function __construct() {
		parent::__construct();
		$this->m7PlanInit();
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
		switch($this->m7_active['cat']) {
			case 'web':
				
				// TODO: Still not sure how I'm going to handle rendering web tests on the world map
				break;
			case 'net':
				$m7_stroke_count = 1;
				
				// Render one path per destination IP
				foreach($this->m7_destips as $m7_destip) {
					$m7_hop_coords_str = null;
					switch($this->m7_active['type']) {
						case 'ping':
							$m7_coords_str = '[' . $this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']]['lon'] . ',' . $this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']]['lat'] . '],';
							$m7_coords_str .= '[' . $this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']][$this->m7_active['cat']][$m7_destip]['lon'] . ',' . $this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']][$this->m7_active['cat']][$m7_destip]['lat'] . ']';
							$m7_paths_js .= 'svg.append("path")' . "\n";
							$m7_paths_js .= '.datum({type: "LineString", coordinates: [' . $m7_coords_str . ']})' . "\n";
							$m7_paths_js .= '.attr("class", "arc' . $m7_stroke_count . '")' . "\n";
							$m7_paths_js .= '.attr("d", path);' . "\n";
							break;
						case 'traceroute':
							foreach($this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']][$this->m7_active['cat']][$m7_destip]['traceroute'][$this->m7_active['runtime']] as $m7_traceroute_hop => $m7_traceroute_hop_params) {
								$m7_hop_coords = '[' . $m7_traceroute_hop_params['ip']['lon'] . ',' . $m7_traceroute_hop_params['ip']['lat'] . ']';
								if(!isset($m7_hop_coords_str)) {
									$m7_hop_coords_str = $m7_hop_coords;
								} else {
									$m7_hop_coords_str .= ',' . $m7_hop_coords;
								}
							}
							$m7_paths_js .= 'svg.append("path")' . "\n";
							$m7_paths_js .= '.datum({type: "LineString", coordinates: [' . $m7_hop_coords_str . ']})' . "\n";
							$m7_paths_js .= '.attr("class", "arc' . $m7_stroke_count . '")' . "\n";
							$m7_paths_js .= '.attr("d", path);' . "\n";
							break;
						case 'mtr':
							foreach($this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']][$this->m7_active['cat']][$m7_destip]['mtr'][$this->m7_active['runtime']] as $m7_mtr_hop => $m7_mtr_hop_params) {
								$m7_mtr_hop_ip = current(array_keys($m7_mtr_hop_params['ips']));
								$m7_hop_coords = '[' . $m7_mtr_hop_params['ips'][$m7_mtr_hop_ip]['lon'] . ',' . $m7_mtr_hop_params['ips'][$m7_mtr_hop_ip]['lat'] . ']';
								if(!isset($m7_hop_coords_str)) {
									$m7_hop_coords_str = $m7_hop_coords;
								} else {
									$m7_hop_coords_str .= ',' . $m7_hop_coords;
								}
							}
							$m7_paths_js .= 'svg.append("path")' . "\n";
							$m7_paths_js .= '.datum({type: "LineString", coordinates: [' . $m7_hop_coords_str . ']})' . "\n";
							$m7_paths_js .= '.attr("class", "arc' . $m7_stroke_count . '")' . "\n";
							$m7_paths_js .= '.attr("d", path);' . "\n";
							break;
					}
					$m7_stroke_count++;
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
	
	public function lineChart($chart_params = array()) {
		$post	= '_' . $chart_params['post'];
		$x_data = $chart_params['x_data'];
		$y_data = $chart_params['y_data'];
		
		// Get the max value for the X axis
		$x_max = max($x_data);
		
		// Calculate the max value for the Y-axis w/ padding
		$y_data_max_array = array();
		foreach ($y_data as $data_type => $data_params) {
			foreach ($data_params['values'] as $data_value) {
				array_push($y_data_max_array, $data_value);
			}
		}
		$y_max_base = max($y_data_max_array);
		$y_buffer   = bcdiv($y_max_base, '5', '0');
		$y_max 		= bcadd($y_max_base, $y_buffer);
		
		// Construct the D3JS JavaScript
		$chart_js = $this->buildLineChart(array(
				'post'	=> $post,
				'x'		=> array(
					'unit'	=> 'hop',
					'max'	=> $x_max,
					'label' => 'Hops',
					'data'  => array(
						'label'		=> false,
						'values'	=> $x_data
					)
				),
				'y'		=> array(
					'unit'	=> 'ms',
					'max'	=> $y_max,
					'label'	=> 'Time (ms)',
					'data'	=>	$y_data
				)
			)
		);
		return $chart_js;
	}
	
	// Get the properties for a single destination IP
	public function singleIPTestResults($test_params = array()) {
		$test_details_html = null;
		
		// Build the test query
		$m7_test_query_str  = "SELECT * FROM " . $this->m7_active['db_prefix'] . "_" . $test_params['cat'] . "_" . $test_params['type'];
		$m7_test_query_str .= " WHERE plan_id='" . $test_params['id'] . "' AND run_time='" . $test_params['runtime'] . "' AND dest_ip='" . $test_params['destip'] . "'";	

		// Execute the test query
		$m7_test_query = $this->m7_db->query($m7_test_query_str);
			
		// If rendering the current item
		if($test_params['render'] === true) {
			$m7_test_details_render = 'block';
		} else {
			$m7_test_details_render = 'none';
		}
		
		// Build the destination IP HTML ID
		$m7_test_destip_tag = preg_replace("/\./", "_", $test_params['destip']);
		
		// Build the column headers
		if($test_params['cat'] == 'net') {
			if($test_params['type'] == 'ping') {
				$test_results_html = '<div class="m7_test_details_stats" style="display:' . $m7_test_details_render . ';" id="scontent_' . $m7_test_destip_tag . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_sheader"><p>Test Statistics - ' . $test_params['destip'] . '</p></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_scontent">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_headers">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Pkt. Loss</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Min. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Avg. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Max. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Avg. Deviation</div></div>' . "\n";
				$test_results_html .= '</div>' . "\n";
			}
			if($test_params['type'] == 'traceroute') {
				$test_results_html = '<div class="m7_test_details_stats" style="display:' . $m7_test_details_render . ';" id="scontent_' . $m7_test_destip_tag . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_sheader"><p>Test Statistics - ' . $test_params['destip'] . '</p></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_scontent">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_headers">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Hop</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Try</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">IP</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Time</div></div>' . "\n";
				$test_results_html .= '</div>' . "\n";
			}
			if($test_params['type'] == 'mtr') {
				$test_results_html = '<div class="m7_test_details_stats" style="display:' . $m7_test_details_render . ';" id="scontent_' . $m7_test_destip_tag . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_sheader"><p>Test Statistics - ' . $test_params['destip'] . '</p></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_scontent">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_headers">' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Hop</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">IP</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Pkt. Loss</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Min. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Avg. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Max. Time</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_col_header"><div class="m7_test_details_col_header_txt">Avg. Deviation</div></div>' . "\n";
				$test_results_html .= '</div>' . "\n";
			}
		}
		
		// Define the X/Y axis data arrays
		if ($test_params['type'] == 'traceroute') {
			$m7_test_x_axis = array();
			$m7_test_y_axis = array(
				'time' => array(
					'label'		=> false,
					'values'	=> array()
				)
			);
		}
		if ($test_params['type'] == 'mtr') {
			$m7_test_x_axis = array();
			$m7_test_y_axis = array(
				'min_time' => array(
					'label'		=> 'Min. Time',
					'values'	=> array()
				),
				'avg_time' => array(
					'label'		=> 'Avg. Time',
					'values'	=> array()
				),
				'max_time' => array(
					'label'		=> 'Max. Time',
					'values'	=> array()
				)
			);
		}
		
		// Construct the result rows
		$m7_test_row_alt = false;
		while($m7_test_row = $m7_test_query->fetch_assoc()) {
			if ($m7_test_row_alt === false) {
				$m7_test_row_class = 'row_main';
				$m7_test_row_alt = true;
			} else {
				$m7_test_row_class = 'row_alt';
				$m7_test_row_alt = false;
			}
			
			// Build the chart data
			if($test_params['type'] == 'ping') {
				
				// Render the HTML block
				$test_results_html .= '<div class="m7_test_details_row ' . $m7_test_row_class . '">' . "\n";
				$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['pkt_loss'] . '</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['min_time'] . '</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['avg_time'] . '</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['max_time'] . '</div></div>' . "\n";
				$test_results_html .= '<div class="m7_test_details_cell"><div class="m7_test_details_cell_txt">' . $m7_test_row['avg_dev'] . '</div></div>' . "\n";
				$test_results_html .= '</div>' . "\n";
				
			}
			if($test_params['type'] == 'traceroute') {

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
			if($test_params['type'] == 'mtr') {
				
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
				$m7_test_mtr_ip = preg_replace("/(^[^,]*),.*$/", "$1", $m7_test_row['ips']);
				
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
		$test_results_html .= '</div>' . "\n";
		
		// Only render a chart for traceroute or MTR
		if ($test_params['type'] == 'traceroute' || $test_params['type'] == 'mtr') {
			
			// Generate the chart HTML block
			$test_chart_html = '<div class="m7_test_details_chart" style="display:' . $m7_test_details_render . ';" id="ccontent_' . $m7_test_destip_tag . '">' . "\n";
			$test_chart_html .= '<div class="m7_test_details_cheader"><p>Test Chart - ' . $test_params['destip'] . '</p></div>' . "\n";
			$test_chart_html .= '<div class="m7_test_details_ccontent">' . "\n";
			$test_chart_html .= '<div id="chart_' . $m7_test_destip_tag . '"></div>' . "\n";
			$test_chart_html .= $this->lineChart(array(
					'post'		=> $m7_test_destip_tag,
					'x_data'	=> $m7_test_x_axis,
					'y_data'	=> $m7_test_y_axis
			));
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
		$m7_test_details_properties = array(
			'plan_id'	=> 'ID',
			'desc'		=> 'Description',
			'host'		=> 'Host',
			'cat'		=> 'Category',
			'type'		=> 'Type',
			'first_run'	=> 'First Run',
			'last_run'	=> 'Last Run'
		);
		
		// Open the test details HTML block
		$test_details_html = '<div class="m7_test_details_show">Show Test Details</div>';
		$test_details_html .= '<div class="m7_test_details">';
		$test_details_html .= '<div class="m7_test_details_bg"></div>';
		$test_details_html .= '<div class="m7_test_details_content">';
		
		// Query the tests table
		$m7_test_table_query = $this->m7_db->query("SELECT * FROM plans WHERE plan_id='" . $this->m7_active['plan'] . "'");
		
		// Build the test detail properties
		$test_details_html .= '<div class="m7_test_details_properties">' . "\n";
		$test_details_html .= '<div class="m7_test_details_pheader" id="ptoggle"><p>Test Properties</p></div>' . "\n";
		while($m7_test_table_row = $m7_test_table_query->fetch_assoc()) {
			$test_details_html .= '<div class="m7_test_details_pcontent" id="pcontent">' . "\n";
			foreach($m7_test_details_properties as $m7_test_details_key => $m7_test_details_desc) {
				if ($m7_test_details_key == 'host' || $m7_test_details_key == 'cat' || $m7_test_details_key == 'type') {
					$m7_test_details_value = $this->m7_active[$m7_test_details_key];
				} else {
					$m7_test_details_value = $m7_test_table_row[$m7_test_details_key];
				}
				$test_details_html .= '<div class="m7_test_details_pcontent_info">' . "\n";
				$test_details_html .= '<div class="m7_test_details_pcontent_label">'. $m7_test_details_desc .'</div>' . "\n";
				$test_details_html .= '<div class="m7_test_details_pcontent_value">' . $m7_test_details_value . '</div>' . "\n";
				$test_details_html .= '</div>' . "\n";
			}
		}
		$test_details_html .= '</div></div>' . "\n";

		// If a destination IP specified
		if(isset($this->m7_active['destip']) && $this->m7_active['destip'] != 'all') {
			$test_details_html .= $this->singleIPTestResults(array(
					'id'		=> $this->m7_active['plan'],
					'host' 		=> $this->m7_active['host'],
					'cat' 		=> $this->m7_active['cat'],
					'destip' 	=> $this->m7_active['destip'],
					'type'		=> $this->m7_active['type'],
					'runtime' 	=> $this->m7_active['runtime'],
					'render' 	=> true
			));
		} else {
		
			// Build the toggle buttons for each destination IP
			$test_details_html .= '<div class="m7_test_destination_ip">' . "\n";
			$test_details_html .= '<div class="m7_test_destination_ip_title">Destination IP: </div>' . "\n";
			$test_details_html .= '<div class="m7_test_destination_ip_menu">' . "\n";
			$test_details_html .= '<select id="dest_ip">' . "\n";
			foreach($this->m7_destips as $m7_test_destip) {
				$m7_test_destip_tag = preg_replace("/\./", "_", $m7_test_destip);
				$test_details_html .= '<option value="' . $m7_test_destip_tag . '">' . $m7_test_destip . '</option>' . "\n";
			}
			$test_details_html .= '</select></div></div>' . "\n";
		
			// Build the results for each destination IP
			$m7_test_details_render = true;
			foreach($this->m7_destips as $m7_test_destip) {
				$test_details_html .= $this->singleIPTestResults(array(
						'id'		=> $this->m7_active['plan'],
						'host' 		=> $this->m7_active['host'],
						'type'		=> $this->m7_active['type'],
						'cat' 		=> $this->m7_active['cat'],
						'runtime' 	=> $this->m7_active['runtime'],
						'destip' 	=> $m7_test_destip,
						'render' 	=> $m7_test_details_render
				));
				$m7_test_details_render = false;
			}
		}
			
		// Return the HTML block
		$test_details_html .= '</div></div>';
		return $test_details_html;
	}
}

?>