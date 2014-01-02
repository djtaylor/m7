<?php 

class Render {
	
	const DB_HOST = 'localhost';
	const DB_USER = 'root';
	const DB_PASS = 'KTr0xr0x';
	const DB_NAME = 'm7';
	
	public function testDetails($test_params = array()) {
		$db = new mysqli(self::DB_HOST, self::DB_USER, self::DB_PASS, self::DB_NAME);
		$test_details_html = null;
		
		if(isset($test_params['type']) && isset($test_params['id']) && isset($test_params['host']) && isset($test_params['cat'])) {
			$test_params['host'] = preg_replace("/-/", "_", $test_params['host']);
			$test_query = $db->query("SELECT * FROM " . $test_params['host'] . "_" . $test_params['type'] . "_" . $test_params['cat'] . " WHERE test_id='" . $test_params['id'] . "'");
			$test_details_html = '<div class="m7_test_details_info">';
			while($test_row = $test_query->fetch_assoc()) {
				$test_details_html .= '<div>';
				foreach($test_row as $test_row_index => $test_row_value) {
					$test_details_html .= $test_row_index . ' - ' . $test_row_value . ', ';
				}
				$test_details_html .= '</div>';
			}
			$test_details_html .= '</div>';
			return $test_details_html;
		}
	}
}

?>