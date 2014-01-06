<?php 

class D3JS extends Core {
	
	public function __construct() {
		parent::__construct();
	}
	
	public function buildLineChart($params = array()) {
		$post = $params['post'];
		
		// Construct the X-axis data source
		$x_data_source	= implode(',', $params['x']['data']['values']);
		
		// Construct the Y-axis data source
		$y_data_source	= null;
		$y_data_keys	= array();
		$y_data_labels	= array();
		$y_line_count	= 0;
		foreach ($params['y']['data'] as $data_key => $data_set) {
			$y_line_count++;
			array_push($y_data_keys, $data_key);
			array_push($y_data_labels, $data_set['label']);
			$y_data_values = implode(',', $data_set['values']);
			if (!isset($y_data_source)) {
				$y_data_source = '[' . $y_data_values . ']';
			} else {
				$y_data_source .= ',[' . $y_data_values . ']';
			}
		}
		
		// Open the script and set the data source array
		$chart_js = '<script>' . "\n";
		$chart_js .= 'var dataX' . $post . ' = [' . $x_data_source . '];' . "\n";
		$chart_js .= 'var dataY' . $post . ' = [' . $y_data_source . '];' . "\n";
		
		// Set the margins
		$chart_js .= 'var margin' . $post . ' = {top: 20, right: 20, bottom: 40, left: 50},';
		$chart_js .= 'width' . $post . ' = 800 - margin' . $post . '.left - margin' . $post . '.right,';
		$chart_js .= 'height' . $post . ' = 300 - margin' . $post . '.top - margin' . $post . '.bottom;' . "\n";
		
		// Set the X and Y axis scales
		$chart_js .= 'var x' . $post . ' = d3.scale.linear()';
		$chart_js .= '.domain([1, ' . $params['x']['max'] . '])';
		$chart_js .= '.range([0, width' . $post . ']);' . "\n";
		$chart_js .= 'var y' . $post . ' = d3.scale.linear()';
		$chart_js .= '.domain([' . $params['y']['max'] . ', 0])';
		$chart_js .= '.range([0, height' . $post . ']);' . "\n";
		
		// Set the color scale
		$chart_js .= 'var color' . $post . ' = d3.scale.category10();';
		
		// Define the X and Y axis
		$chart_js .= 'var xAxis' . $post . ' = d3.svg.axis()';
		$chart_js .= '.scale(x' . $post . ')';
		$chart_js .= '.orient("bottom");' . "\n";
		$chart_js .= 'var yAxis' . $post . ' = d3.svg.axis()';
		$chart_js .= '.scale(y' . $post . ')';
		$chart_js .= '.orient("left");' . "\n";
		
		// Define the graph line
		$chart_js .= 'var line' . $post . ' = d3.svg.line()';
		$chart_js .= '.x(function(d, i) { return x' . $post . '(dataX' . $post . '[i]); })';
		$chart_js .= '.y(y' . $post . ');' . "\n";
		
		// Define the graph SVG
		$chart_js .= 'var svg' . $post . ' = d3.select("#chart' . $post . '").append("svg")';
		$chart_js .= '.attr("width", width' . $post . ' + margin' . $post . '.left + margin' . $post . '.right)';
		$chart_js .= '.attr("height", height' . $post . ' + margin' . $post . '.top + margin' . $post . '.bottom)';
		$chart_js .= '.append("g")';
		$chart_js .= '.attr("transform", "translate(" + margin' . $post . '.left + "," + margin' . $post . '.top + ")");' . "\n";
		
		// Parse the data and generate the graph
		$chart_js .= 'svg' . $post . '.append("g")';
		$chart_js .= '.attr("class", "x axis")';
		$chart_js .= '.attr("transform", "translate(0," + height' . $post . ' + ")")';
		$chart_js .= '.call(xAxis' . $post . ')';
		$chart_js .= '.append("text")';
		$chart_js .= '.attr("y", 23)';
		$chart_js .= '.attr("x", 358)';
		$chart_js .= '.attr("dy", ".71em")';
		$chart_js .= '.style("text-anchar", "middle")';
		$chart_js .= '.text("' . $params['x']['label'] . '");';
		$chart_js .= 'svg' . $post . '.append("g")';
		$chart_js .= '.attr("class", "y axis")';
		$chart_js .= '.call(yAxis' . $post . ')';
		$chart_js .= '.append("text")';
		$chart_js .= '.attr("transform", "rotate(-90)")';
		$chart_js .= '.attr("y", 6)';
		$chart_js .= '.attr("dy", ".71em")';
		$chart_js .= '.style("text-anchor", "end")';
		$chart_js .= '.text("' . $params['y']['label'] . '");';
		
		// Create the line group
		$chart_js .= 'svg' . $post . '.selectAll(".line").data(dataY' . $post . ')';
		$chart_js .= '.enter().append("path").style("stroke", function(d) { return color' . $post . '(d); }).style("fill", "none").style("stroke-width", "2px").attr("d", line' . $post . ');' . "\n";
		$chart_js .= '</script>' . "\n";
		return $chart_js;
	}
}

?>