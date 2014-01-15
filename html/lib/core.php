<?php
class Core {
	
	// Configuration values
	private $m7_config;
	
	// Database object
	public $m7_db;
	
	// M7 plan and result properties
	public $m7_plan       = array();
	public $m7_active     = array();
	public $m7_plans      = array();
	public $m7_hosts      = array();
	public $m7_destips    = array();
	public $m7_runtimes   = array();
	public $m7_test_types = array();
	
	// Class constructor
	public function __construct() {
		$this->m7_config = parse_ini_file('config.ini');
		$this->m7_db = new mysqli(	
			$this->m7_config['db_host'], 
			$this->m7_config['db_name'], 
			$this->m7_config['db_pass'], 
			$this->m7_config['db_user'] 
		);
		
		// Load up all the plan IDs
		$m7_plans_query = $this->m7_db->query( "SELECT * FROM plans" );
		while ($m7_plans_row = $m7_plans_query->fetch_assoc() ) {
			$this->m7_plans[$m7_plans_row['plan_id']] = array(
					'desc'  => $m7_plans_row['desc'],
					'types' => $m7_plans_row['types']
			);
		}
		
		// Load up all the cluster hosts
		$m7_hosts_query = $this->m7_db->query( "SELECT * FROM hosts" );
		while ($m7_hosts_row = $m7_hosts_query->fetch_assoc() ) {
			$this->m7_hosts[$m7_hosts_row['name']] = array(
					'desc' => $m7_hosts_row['desc'] 
			);
		}
	}
	
	/**
	 * Load Single Test Instance
	 *
	 * This method is used to load a single test instance into the '$m7_plan' array. This will only work
	 * for a single test with a defined test ID, source host, category, destination IP, test type, and
	 * specific run time.
	 */
	public function loadTestSingle($params = array()) {
		$plan_id	= $params['id'];
		$shost		= $params['shost'];
		$cat		= $params['cat'];
		$destip 	= $params['destip'];
		$type 		= $params['type'];
		$runtime 	= $params['runtime'];
		$table 		= $this->m7_active['db_prefix'] . "_" . $cat . "_" . $type;
		
		# Initialize the runtime nested array
		$this->m7_plan[$plan_id][$shost][$cat][$destip][$type][$runtime] = array();
		
		// Load the results for the specific test runtime
		$m7_test_query = $this->m7_db->query( "SELECT * FROM " . $table . " WHERE plan_id='" . $plan_id . "' AND dest_ip='" . $destip . "' AND run_time='" . $runtime . "'" );
		
		// Load properties depending on the test type
		switch($type) {
			case 'ping' :
				while ($m7_ping_result = $m7_test_query->fetch_assoc() ) {
					$this->m7_plan[$plan_id][$shost][$cat][$destip][$type][$runtime]['pkt_loss'] = $m7_ping_result['pkt_loss'];
					$this->m7_plan[$plan_id][$shost][$cat][$destip][$type][$runtime]['min_time'] = $m7_ping_result['min_time'];
					$this->m7_plan[$plan_id][$shost][$cat][$destip][$type][$runtime]['avg_time'] = $m7_ping_result['avg_time'];
					$this->m7_plan[$plan_id][$shost][$cat][$destip][$type][$runtime]['max_time'] = $m7_ping_result['max_time'];
					$this->m7_plan[$plan_id][$shost][$cat][$destip][$type][$runtime]['avg_dev'] = $m7_ping_result['avg_dev'];
				}
				break;
			case 'traceroute' :
				while ($m7_traceroute_result = $m7_test_query->fetch_assoc() ) {
					$m7_traceroute_hop = $m7_traceroute_result['hop'];
					$this->m7_plan[$plan_id][$shost][$cat][$destip][$type][$runtime][$m7_traceroute_hop] = array(
							'try' => $m7_traceroute_result['try'],
							'ip' => array(
									'value' => $m7_traceroute_result['ip'],
									'lat' => $m7_traceroute_result['ip_lat'],
									'lon' => $m7_traceroute_result['ip_lon'] 
							),
							'time' => $m7_traceroute_result['time'] 
					);
				}
				break;
			case 'mtr' :
				while ($m7_mtr_result = $m7_test_query->fetch_assoc() ) {
					$m7_mtr_hop = $m7_mtr_result['hop'];
					
					// Generate an array with all the IPs
					$m7_mtr_hop_ip_nested = array();
					$m7_mtr_hop_ips_array = explode( ',', $m7_mtr_result['ips']);
					$m7_mtr_hop_gps_array = explode( ',', $m7_mtr_result['ips_gps']);
					foreach ($m7_mtr_hop_ips_array as $m7_mtr_hop_ip_key => $m7_mtr_hop_ip_val ) {
						$m7_mtr_hop_ip_nested[$m7_mtr_hop_ip_val] = array(
								'lat' => preg_replace( "/(^[^:]*):[^:]*$/", "$1", $m7_mtr_hop_gps_array[$m7_mtr_hop_ip_key]),
								'lon' => preg_replace( "/^[^:]*:([^:]*$)/", "$1", $m7_mtr_hop_gps_array[$m7_mtr_hop_ip_key]) 
						);
					}
					
					// Define the hop entry
					$this->m7_plan[$plan_id][$shost][$cat][$destip][$type][$runtime][$m7_mtr_hop] = array(
							'ips' => $m7_mtr_hop_ip_nested,
							'pkt_loss' => $m7_mtr_result['pkt_loss'],
							'min_time' => $m7_mtr_result['min_time'],
							'avg_time' => $m7_mtr_result['avg_time'],
							'max_time' => $m7_mtr_result['max_time'],
							'avg_dev' => $m7_mtr_result['avg_dev'] 
					);
				}
				break;
		}
	}
	
	/**
	 * Load Destination IP Instance
	 */
	public function loadDestinationIP($params = array()) {
		$plan_id	= $params['id'];
		$shost		= $params['shost'];
		$cat		= $params['cat'];
		$destip		= $params['destip'];
		$type		= $params['type'];
		$start		= $params['start'];
		$stop		= $params['stop'];
		$table		= $this->m7_active['db_prefix'] . "_" . $cat . "_" . $type;
		
		// If loading the most recent test runtime
		if ($start == 'recent') {
			$m7_plan_runtime_query = $this->m7_db->query("SELECT DISTINCT run_time FROM " . $table . " ORDER BY run_time ASC");
			while ($m7_plan_runtime_result = $m7_plan_runtime_query->fetch_assoc() ) {
				$start = $m7_plan_runtime_result['run_time'];
				$this->m7_active['start'] = $m7_plan_runtime_result['run_time'];
				break;
			}
		} else {
			$this->m7_active['start'] = $start;
		}
		
		// Initialize the destination IP array entry
		$this->m7_plan[$plan_id][$shost][$cat][$destip] = array();
		
		// Get the destination IP properties
		$m7_plan_destip_query = $this->m7_db->query( "SELECT DISTINCT dest_lat,dest_lon,dest_region FROM " . $this->m7_active['db_prefix'] . "_" . $cat . "_" . $type . " WHERE dest_ip='" . $destip . "'" );
		$m7_plan_destip_result = $m7_plan_destip_query->fetch_assoc();
		$this->m7_plan[$plan_id][$shost][$cat][$destip]['lat'] = $m7_plan_destip_result['dest_lat'];
		$this->m7_plan[$plan_id][$shost][$cat][$destip]['lon'] = $m7_plan_destip_result['dest_lon'];
		$this->m7_plan[$plan_id][$shost][$cat][$destip]['region'] = $m7_plan_destip_result['dest_region'];
		
		// If loading a specific test type
		if (isset($type)) {
			$this->m7_plan[$plan_id][$shost][$cat][$destip][$type] = array();
			$this->m7_active['type'] = $type;
			
			// If loading a single test runtime
			if (isset($start) && isset($stop) && $stop == 'start') {
				$this->m7_active['stop'] = 'start';
				$this->loadTestSingle(array(
					'id'	  => $plan_id,
					'shost'   => $shost,
					'cat' 	  => $cat,
					'destip'  => $destip,
					'type'	  => $type,
					'runtime' => $start 
				));;
			}
			
			// If loading a range of test times
			if (isset($start) && isset($stop) && $stop != 'start') {
				$m7_runtimes = array();
				$this->m7_active['stop'] = $stop;
				
				// Query all run times between the start and stop time
				$m7_runtimes_query = $this->m7_db->query( "SELECT DISTINCT run_time FROM " . $this->m7_active['db_prefix'] . "_" . $cat . "_" . $type . " WHERE dest_ip='" . $destip . "' AND run_time BETWEEN '" . $start . "' AND '" . $stop . "' ORDER BY run_time ASC" );
				$m7_runtimes_result = $m7_runtimes_query->fetch_assoc();
				while ($m7_runtimes_row = $m7_runtimes_query->fetch_assoc() ) {
					array_push($m7_runtimes, $m7_runtimes_row['run_time']);
				}
				
				// Construct the arrays for each runtime
				foreach ($m7_runtimes as $m7_runtime) {
					$this->loadTestSingle(array(
						'id'	  => $plan_id,
						'shost'   => $shost,
						'cat' 	  => $cat,
						'destip'  => $destip,
						'type' 	  => $type,
						'runtime' => $m7_runtime 
					));
				}
			}
		}
	}
	
	// Check GET superglobal array
	public function checkGet() {
		
		// If no source host defined, use the first available one
		if (!isset($_GET['shost'])) {
			$m7_first_host = key($this->m7_hosts);
			$_GET['shost'] = $m7_first_host;
		}
			
		// If the test type isn't set, use the first available type
		if (!isset($_GET['type'])) {
			$m7_plan_cat_types = explode(',', $this->m7_plans[$this->m7_active['plan']]['types']);
			$_GET['type'] = current($m7_plan_cat_types);
		}
	}
	
	// Set source host properties
	public function setSHP() {
		
		// Get the source host properties
		$m7_plan_shost_query = $this->m7_db->query( "SELECT * FROM hosts WHERE name='" . $this->m7_active['host'] . "'" );
		$m7_plan_shost_result = $m7_plan_shost_query->fetch_assoc();
		
		// Set the active host properties
		$this->m7_active['host_ip'] = $m7_plan_shost_result['ipaddr'];
		$this->m7_active['host_lat'] = $m7_plan_shost_result['latitude'];
		$this->m7_active['host_lon'] = $m7_plan_shost_result['longitude'];
		$this->m7_active['host_reg'] = $m7_plan_shost_result['region'];
		
		// Set the array host properties
		$this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']]['ip'] = $m7_plan_shost_result['ipaddr'];
		$this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']]['lat'] = $m7_plan_shost_result['latitude'];
		$this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']]['lon'] = $m7_plan_shost_result['longitude'];
		$this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']]['region'] = $m7_plan_shost_result['region'];
	}
	
	// Set the plan category variables
	public function setCategory() {
		
		// Get the plan category
		$m7_plan_cat_query      = $this->m7_db->query("SELECT * FROM plans WHERE plan_id='" . $this->m7_active['plan'] . "'");
		$m7_plan_cat_info       = $m7_plan_cat_query->fetch_assoc();
		$m7_plan_cat            = $m7_plan_cat_info['category'];
		
		// Set the category in the active and plan arrays
		$this->m7_active['cat'] = $m7_plan_cat;
		$this->m7_plan[$this->m7_active['plan']][$this->m7_active['host']][$this->m7_active['cat']] = array();
		
		// Make sure that the destination IP, start, and stop times are set
		if ($this->m7_active['cat'] == 'net') {
			if (!isset($_GET['destip'])) { $_GET['destip'] = 'all';    }
			if (!isset($_GET['start']))  { $_GET['start']  = 'recent'; }
			if (!isset($_GET['stop']))   { $_GET['stop']   = 'start';  }
		}
	}
	
	// Build an array of all runtimes
	public function buildRuntimes() {
		$m7_runtimes_query = $this->m7_db->query("SELECT DISTINCT run_time FROM " . $this->m7_active['db_prefix'] . "_" . $this->m7_active['cat'] . "_" . $_GET['type'] . " ORDER BY run_time DESC");
		while ($m7_runtimes_row = $m7_runtimes_query->fetch_assoc() ) {
			array_push($this->m7_runtimes, $m7_runtimes_row['run_time']);
		}
	}
	
	// Initialize the M7 plan properties and results array
	public function planInit() {
		
		// If a plan ID is defined
		if (isset($_GET['id'])) {
			$this->m7_plan[$_GET['id']] = array();
			$this->m7_active['plan'] = $_GET['id'];
			
			// Get the plan description
			$m7_plan_desc_query = $this->m7_db->query( "SELECT `desc` FROM `plans` WHERE plan_id='" . $this->m7_active['plan'] . "'" );
			$m7_plan_desc_result = $m7_plan_desc_query->fetch_assoc();
			$this->m7_plan[$this->m7_active['plan']]['desc'] = $m7_plan_desc_result['desc'];
			
			// Check the GET superglobal array
			$this->checkGet();
			
			// Render for a specific source host
			if (isset($_GET['shost']) && $_GET['shost'] != 'all') {
				$this->m7_plan[$this->m7_active['plan']][$_GET['shost']] = array();
				$this->m7_active['host'] = $_GET['shost'];
				$this->m7_active['db_prefix'] = preg_replace( "/-/", "_", $_GET['shost']);
				
				// Set source host properties, plan category, and runtimes array
				$this->setSHP();
				$this->setCategory();
				$this->buildRuntimes();
				
				// Render network tests
				if ($this->m7_active['cat'] == 'net') {
					
					// Render all destination IPs
					if ($_GET['destip'] == 'all') {
							
						// Build an array of all destination IP addresses
						$m7_dest_ips_query = $this->m7_db->query( "SELECT DISTINCT dest_ip FROM " . $this->m7_active['db_prefix'] . "_" . $this->m7_active['cat'] . "_" . $_GET['type']);
							
						// Build the destination IP array for each entry
						while ($m7_dest_ips_result = $m7_dest_ips_query->fetch_assoc() ) {
					
							# Get the destination IP information and load the array
							$m7_destip_query     = $this->m7_db->query("SELECT * FROM net_destips WHERE ip='" . $m7_dest_ips_result['dest_ip'] . "'");
							$m7_destip_info      = $m7_destip_query->fetch_assoc();
							$m7_destip_alias     = $m7_destip_info['alias'];
							$m7_destip_hostname  = $m7_destip_info['hostname'];
							$this->m7_destips[$m7_destip_alias] = $m7_dest_ips_result['dest_ip'];
							
							// Load the destination IP into the plan array
							$this->loadDestinationIP(array(
								'id'	 => $this->m7_active['plan'],
								'shost'  => $this->m7_active['host'],
								'cat' 	 => $this->m7_active['cat'],
								'destip' => $m7_dest_ips_result['dest_ip'],
								'type' 	 => $_GET['type'],
								'start'  => $_GET['start'],
								'stop'   => $_GET['stop']
							));
						}
						
						// Set the active destination IP to 'all'
						$this->m7_active['destip'] = 'all';
					
					// Render a single destination IP
					} elseif (isset($_GET['destip'])) {
									
						# Get the destination IP information and load the array
						$m7_destip_query     = $this->m7_db->query("SELECT * FROM net_destips WHERE ip='" . $_GET['destip'] . "'");
						$m7_destip_info      = $m7_destip_query->fetch_assoc();
						$m7_destip_alias     = $m7_destip_info['alias'];
						$m7_destip_hostname  = $m7_destip_info['hostname'];
						$this->m7_destips[$m7_destip_alias] = $_GET['destip'];
						
						// Load the destination IP into the plan array
						$this->loadDestinationIP(array(
							'id'	 => $this->m7_active['plan'],
							'shost'  => $this->m7_active['host'],
							'cat' 	 => $this->m7_active['cat'],
							'destip' => $_GET['destip'],
							'type' 	 => $_GET['type'],
							'start'  => $_GET['start'],
							'stop'   => $_GET['stop']
						));
						
						// Set the active destination IP
						$this->m7_active['destip'] = $_GET['destip'];
					} else {
							
						// TODO: Right now I'm going to only support rendering either a single destination
						// IP or all destination IPs. I will add support for filtered sets in the future.
						return false;
					}	
				}
				
				// Render DNS tests
				if ($this->m7_active['cat'] == 'dns') {
					return false;
				}
				
				// Render web tests
				if ($this->m7_active['cat'] == 'web') {
					return false;
				}
			}
			
			// Render results for all source hosts
			if (isset($_GET['shost']) && $_GET['shost'] == 'all') {
				
				// TODO: For now I am only going to support the loading of single source hosts into memory.
				// For future reference, I should convert all the code in the first block of this statement
				// into a method. Here I should generate an array of all source hosts, loop through them, and
				// render the tests for each host.
				return false;
			}
		}
	}
	
	/**
	 * Render Check
	 *
	 * If enough variables are set to perform a test render, a true value is returned.
	 *
	 * @return boolean
	 */
	public function varCheck() {
		if (isset($this->m7_active['plan'])) {
			if (isset($this->m7_active['host'])) {
				if (isset($this->m7_active['destip'])) {
					$this->m7_ready = true;
				} else {
					if ($this->m7_active['cat'] == 'net') {
						$this->m7_ready = false;
					} else {
						$this->m7_ready = true;
					}
				}
			} else {
				$this->m7_ready = false;
			}
		} else {
			$this->m7_ready = false;
		}
	}
}

?>