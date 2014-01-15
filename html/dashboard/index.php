<?php session_start(); ?>
<!DOCTYPE HTML>
<?php

// Load Class Libraries
require_once ('lib/core.php');
require_once ('lib/d3js.php');
require_once ('lib/render.php');
$render = new Render ();

// Make sure the required minimum test variables are set before attempting a render
$m7_render = $render->m7RenderCheck ();
?>
<html>
<head>
<title>M7 Dashboard</title>
<meta charset="utf-8">
<script><?php echo 'var test_details_render = ',($m7_render === true ? 'true' : 'false'); ?></script>
<script src="js/d3.v3.min.js"></script>
<script src="js/topojson.v1.min.js"></script>
<script src="js/jquery-1.10.2.min.js"></script>
<script src="js/dashboard.js"></script>
<link rel="stylesheet" type="text/css" href="css/dashboard.css">
</head>
<body>
	<div class="m7_dashboard_nav">
		<form id="test_params" action="index.php" action="post">
			<div class="m7_dashboard_content">
				<div class="m7_configure">Configure</div>
				<div class="m7_test_submit">Submit</div>
				<div class="m7_test_cat">
					<div class="m7_test_cat_title">Category</div>
					<div class="m7_test_cat_menu">
						<select name="cat">
							<option value="net">Network</option>
						</select>
					</div>
				</div>
				<div class="m7_plan_id">
					<div class="m7_plan_id_title">ID</div>
					<div class="m7_plan_id_menu">
						<select name="id">
	                        <?php
							foreach ( $render->m7_plans as $m7_plan_id => $m7_plan_params ) {
								echo '<option value="' . $m7_plan_id . '">' . $m7_plan_id . ' - ' . $m7_plan_params['desc'] . '</option>' . "\n";
							}
							?>
	                        </select>
					</div>
				</div>
				<div class="m7_test_host">
					<div class="m7_test_shost_title">Host</div>
					<div class="m7_test_shost_menu">
						<select name="shost">
	                        <?php
							foreach ( $render->m7_hosts as $m7_host => $m7_host_params ) {
								if (isset ( $render->m7_active['host'] ) && $m7_host == $render->m7_active['host']) {
									echo '<option selected="selected" value="' . $m7_host . '">' . $m7_host . ' - ' . $m7_host_params ['desc'] . '</option>' . "\n";
								} else {
									echo '<option value="' . $m7_host . '">' . $m7_host . ' - ' . $m7_host_params ['desc'] . '</option>' . "\n";
								}
							}
							?>
	                        </select>
					</div>
				</div>
				<div class="m7_test_type">
					<div class="m7_test_type_title">Type</div>
					<div class="m7_test_type_menu">
						<select name="type">
	                    		<?php
								foreach ( $render->m7_categories['net']['types'] as $m7_type_val => $m7_type_desc ) {
									if (isset ( $render->m7_active['type'] ) && $m7_type_val == $render->m7_active ['type']) {
										echo '<option selected="selected" value="' . $m7_type_val . '">' . $m7_type_desc . '</option>' . "\n";
									} else {
										echo '<option value="' . $m7_type_val . '">' . $m7_type_desc . '</option>' . "\n";
									}
								}
								?>
	                        </select>
					</div>
				</div>
				<div class="m7_test_destip_type">
					<div class="m7_test_destip_title">Destination IP</div>
					<div class="m7_test_destip_menu">
						<select name="destip">
							<option value="all">--All--</option>
	                        	<?php
								if (isset ( $render->m7_destips )) {
									foreach ( $render->m7_destips as $m7_destip_alias => $m7_destip_val ) {
										if ($m7_destip_val == $render->m7_active['destip']) {
											echo '<option selected="selected" value="' . $m7_destip_val . '">' . $m7_destip_val . ' - ' . $m7_destip_alias . '</option>' . "\n";
										} else {
											echo '<option value="' . $m7_destip_val . '">' . $m7_destip_val . ' - ' . $m7_destip_alias . '</option>' . "\n";
										}
									}
								}
								?>
	                        </select>
					</div>
				</div>
				<div class="m7_test_start">
					<div class="m7_test_start_title">Start Time</div>
					<div class="m7_test_start_menu">
						<select name="start">
							<option value="recent">--Most Recent--</option>
	                        	<?php
								if (isset ( $render->m7_runtimes )) {
									foreach ( $render->m7_runtimes as $m7_start_val ) {
										if (isset ( $render->m7_active['start'] ) && $m7_start_val == $render->m7_active['start']) {
											echo '<option selected="selected" value="' . $m7_start_val . '">' . $m7_start_val . '</option>';
										} else {
											echo '<option value="' . $m7_start_val . '">' . $m7_start_val . '</option>';
										}
									}
								}
								?>
	                        </select>
					</div>
				</div>
				<div class="m7_test_stop">
					<div class="m7_test_stop_title">Stop Time</div>
					<div class="m7_test_stop_menu">
						<select name="stop">
							<option value="start">--Start--</option>
	                        	<?php
								if (isset ( $render->m7_runtimes )) {
									foreach ( $render->m7_runtimes as $m7_stop_val ) {
										if (isset ( $render->m7_active ['stop'] ) && $m7_stop_val == $render->m7_active ['stop']) {
											echo '<option selected="selected" value="' . $m7_stop_val . '">' . $m7_stop_val . '</option>';
										} else {
											echo '<option value="' . $m7_stop_val . '">' . $m7_stop_val . '</option>';
										}
									}
								}
								?>
	                        </select>
					</div>
				</div>
	                <?php if ($m7_render) { echo $render->testDetails(); } ?>
	            </div>
		</form>
	</div>
    	<?php
		if ($m7_render) {
			if (! empty ( $render->m7_destips )) {
				echo '<div class="m7_map_key">' . "\n";
				echo '<div class="m7_map_key_title">Map Key</div>' . "\n";
				$m7_key_count = 1;
				foreach ( $render->m7_destips as $m7_destip_val ) {
					echo '<div class="m7_map_key_entry">' . "\n";
					echo '<div class="m7_map_key_color key' . $m7_key_count . '"></div>' . "\n";
					echo '<div class="m7_map_key_txt">Destination - ' . $m7_destip_val . '</div>' . "\n";
					echo '</div>' . "\n";
					$m7_key_count ++;
				}
				echo '</div>' . "\n";
			}
		}
		?>
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

<?php if ($m7_render) { echo $render->m7MapPaths(); } ?>

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