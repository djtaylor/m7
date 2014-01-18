<?php session_start(); ?>
<!DOCTYPE HTML>
<?php

/**
 * M7 Dashboard - In order for this portal to work you need to make sure
 * you install and run Composer in the 'html/lib' directory to pull any
 * required PHP dependencies.
 */

// Load Class Libraries
require_once('lib/m7/config.php');
require_once('lib/m7/core.php');
require_once('lib/m7/d3js.php');
require_once('lib/m7/render.php');
require_once('lib/vendor/autoload.php');
$render = new Render();

// Make sure enough variables are set before rendering
$render->varCheck();

?>
<html>
	<head>
		<title>M7 Dashboard</title>
		<meta charset="utf-8">
		<?php echo $render->loadClusterState(); ?>
		<script><?php echo 'var test_details_render = ',($render->m7_ready === true ? 'true;' : 'false;'); ?></script>
		<script src="js/d3.v3.min.js"></script>
		<script src="js/topojson.v1.min.js"></script>
		<script src="js/jquery-1.10.2.min.js"></script>
		<script src="js/jquery-ui-1.10.3.min.js"></script>
		<script src="js/socket.io.min.js"></script>
		<script src="js/dashboard.js"></script>
		<link rel="stylesheet" type="text/css" href="css/dashboard.css">
	</head>
	<body>
		<div class="m7_dashboard_nav">
			<form id="test_params" action="index.php" action="post">
				<div class="m7_dashboard_content">
					<div class="m7_configure">Configure</div>
					<div class="m7_test_submit">Submit</div>
					<?php echo $render->planMenu(); ?>	
	        	</div>
			</form>
		</div>
    	<?php echo $render->mapKey(); ?>
    	<?php echo $render->mapHostDetails(); ?>
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

var color = d3.scale.category20();
    
var graticule = d3.geo.graticule();

var svg = d3.select("#map_container").append("svg")
    .attr("width", width)
    .attr("height", height);

svg.append("path")
    .datum(graticule)
    .attr("class", "graticule")
    .attr("d", path);


<?php 
echo $render->mapHosts();
if ($render->m7_ready) { echo $render->mapPaths(); } 
?>

d3.json("/json/world-50m.json", function(error, world) {
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
    	<div style="display:none;" id="m7_auto_script"></div>
    	<script src="js/m7.listener.js"></script>
	</body>
</html>