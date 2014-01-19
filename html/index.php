<?php session_start(); ?>
<!DOCTYPE HTML>
<?php

// Load Class Libraries
require_once('lib/config.php');
require_once('lib/core.php');
require_once('lib/d3js.php');
require_once('lib/render.php');
$m7 = new Render();

// Make sure enough variables are set before rendering
$m7->varCheck();

?>
<html>
	<head>
		<title>M7 Dashboard</title>
		<meta charset="utf-8">
		<?php echo $m7->loadClusterState(); ?>
		<script><?php echo 'var test_details_render = ',($m7->m7_ready === true ? 'true;' : 'false;'); ?></script>
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
					<?php echo $m7->planMenu(); ?>	
	        	</div>
			</form>
		</div>
		<?php echo $m7->renderWorldMap('/json/world-50m.json'); ?>
    	<div style="display:none;" id="m7_auto_script"></div>
    	<script src="js/m7.listener.js"></script>
	</body>
</html>