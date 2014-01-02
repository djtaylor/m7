#!/usr/bin/perl

# Load the required Perl modules
use strict;
use XML::LibXML;
use XML::XPath;
use DBI;
use DBD::mysql;
use Data::Dumper;
use Geo::IP;
use Data::Validate::IP;
use File::Slurp;

# Create the XML and GeoIP parser
my $m7_xml_parser = XML::LibXML->new();
my $m7_geo_parser = Geo::IP->open('/usr/local/share/GeoIP/GeoLiteCity.dat', GEOIP_STANDARD);

# Database connection values
use constant {
	DB_NAME => "m7",
    DB_HOST => "localhost",
    DB_PORT => "3306",
    DB_USER => "root",
    DB_PASS => "password",
};

# Create a new database connection
my $m7_dsn = "dbi:mysql:" . DB_NAME . ":" . DB_HOST . ":" . DB_PORT;
my $m7_dbc = DBI->connect($m7_dsn, DB_USER, DB_PASS);

# Define the results directory based on test ID
my $m7_xml_dir = $ENV{"HOME"} . "/results/" . $ARGV[0] . "/";

# Grab all the output XML files and store in an array
opendir(DIR, $m7_xml_dir) or die $!;
my @m7_xml_files;
while (my $m7_xml_file = readdir(DIR)) {
	next if (substr($m7_xml_file,0,1) eq ".");
    push (@m7_xml_files, "$m7_xml_dir$m7_xml_file");
}

# Parse the XML test plan
my $m7_plan_xpath	= XML::XPath->new(filename => $ENV{"HOME"} . "/plans/" . $ARGV[0] . ".xml");
my $m7_plan_desc	= $m7_plan_xpath->findnodes('plan/desc');
my $m7_plan_cat		= $m7_plan_xpath->findnodes('plan/params/category');
my $m7_plan_runtime	= read_file($ENV{"HOME"} . "/lock/" . $ARGV[0] . "/runtime");

# If the test row doesn't exist create it, if so, update the last runtime
my $m7_plan_check	= $m7_dbc->selectcol_arrayref("SELECT * FROM tests WHERE test_id='" . $ARGV[0] . "'");
if (@$m7_plan_check) {
	my $m7_plan_update = "UPDATE `" . DB_NAME . "`.`tests` SET last_run='" . $m7_plan_runtime . "', run_count=run_count+1 WHERE test_id='" . $ARGV[0] . "'";
	$m7_dbc->do($m7_plan_update);
} else {
	my $m7_plan_create = "INSERT INTO `" . DB_NAME . "`.`tests`(" .
						 "`test_id`, `type`, `desc`, `first_run`, `last_run`, `run_count`) VALUES(" . 
						 "'" . $ARGV[0] . "','net','" . $m7_plan_desc . "','" . $m7_plan_runtime . "','" . $m7_plan_runtime . "', 1)";
	$m7_dbc->do($m7_plan_create);
}

# Process XML Result Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
foreach (@m7_xml_files) {
    my $m7_xml_tree			= $m7_xml_parser->parse_file($_);
    my $m7_test_xpath		= XML::XPath->new(filename => $_);
	
    # Get the node information
    for my $m7_host_node ($m7_xml_tree->findnodes('plan/host/name')) {
    	my $m7_host			= $m7_host_node->textContent();
    	my $m7_host_ipaddr	= $m7_test_xpath->findvalue('plan/host/ip');
    	my $m7_host_region  = $m7_test_xpath->findvalue('plan/host/region');
        $m7_host 			=~ s/-/_/g;

		# Get the host's geolocation
		my $m7_host_geo		= $m7_geo_parser->record_by_addr($m7_host_ipaddr);
		my $m7_host_lat		= $m7_host_geo->latitude;
		my $m7_host_lon		= $m7_host_geo->longitude;

		# Host Ping Statistics Table \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
        $m7_dbc->do("
        	CREATE TABLE IF NOT EXISTS " . DB_NAME . "." . $m7_host . "_net_ping(
            	id              INT NOT NULL AUTO_INCREMENT,
            	test_id			INT NOT NULL,
                source_ip       VARCHAR(15) NOT NULL,
                source_region   VARCHAR(25) NOT NULL,
                source_lat		VARCHAR(10),
                source_lon		VARCHAR(10),
                dest_ip         VARCHAR(15) NOT NULL,
                dest_region     VARCHAR(25),
               	dest_lat		VARCHAR(10),
                dest_lon		VARCHAR(10),
                run_time        DATETIME NOT NULL,
                pkt_loss        VARCHAR(5) NOT NULL,
                min_time        VARCHAR(10) NOT NULL,
                avg_time        VARCHAR(10) NOT NULL,
                max_time        VARCHAR(10) NOT NULL,
                avg_dev         VARCHAR(10) NOT NULL,
                modified        TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY(id)
            );
        ");
                
        # Host Traceroute Statistics Tables \\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
        $m7_dbc->do("
        	CREATE TABLE IF NOT EXISTS " . DB_NAME . "." . $m7_host . "_net_traceroute(
            	id              INT NOT NULL AUTO_INCREMENT,
            	test_id			INT NOT NULL,
            	source_ip       VARCHAR(15) NOT NULL,
            	source_region   VARCHAR(25) NOT NULL,
            	source_lat		VARCHAR(10),
                source_lon		VARCHAR(10),
           		dest_ip         VARCHAR(15) NOT NULL,
           		dest_region     VARCHAR(25),
           		dest_lat		VARCHAR(10),
                dest_lon		VARCHAR(10),
            	run_time        DATETIME NOT NULL,
            	hop             INT NOT NULL,
            	try             INT NOT NULL,
            	ip              VARCHAR(15) NOT NULL,
            	ip_lat			VARCHAR(10),
                ip_lon			VARCHAR(10),
            	time            VARCHAR(10) NOT NULL,
            	modified        TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP,
            	PRIMARY KEY(id)
        	);
    	");

		# Host MTR Statistics Table \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
		$m7_dbc->do("
			CREATE TABLE IF NOT EXISTS " . DB_NAME . "." . $m7_host . "_net_mtr(
            	id              INT NOT NULL AUTO_INCREMENT,
            	test_id			INT NOT NULL,
                source_ip       VARCHAR(15) NOT NULL,
                source_region   VARCHAR(25) NOT NULL,
                source_lat		VARCHAR(10),
                source_lon		VARCHAR(10),
                dest_ip         VARCHAR(15) NOT NULL,
                dest_region     VARCHAR(25),
                dest_lat		VARCHAR(10),
                dest_lon		VARCHAR(10),
                run_time        DATETIME NOT NULL,
                hop             INT NOT NULL,
                ips             VARCHAR(256) NOT NULL,
                ips_gps			VARCHAR(256),
                pkt_loss        VARCHAR(5) NOT NULL,
                min_time        VARCHAR(10) NOT NULL,
                avg_time        VARCHAR(10) NOT NULL,
                max_time        VARCHAR(10) NOT NULL,
                avg_dev         VARCHAR(10) NOT NULL,
                modified        TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY(id)
			);
		");
                
		# Process the test results
        for my $m7_test_id_tree ($m7_xml_tree->findnodes('plan/test/@id')) {
        	my $m7_test_id = $m7_test_id_tree->textContent();
            my $m7_test_type = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/type');
            for my $m7_test_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]')) {

				# Ping Test Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
				#
				# Convert the test results for ping from XML to database format
				# and create entries in the database for the host.
                if ($m7_test_type eq "ping") {

					# Initialize the MySQL insert array
					my @m7_ping_sql;

                	# Process the host definitions
                    for my $m7_ping_host_name_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host/@name')) {
                    	my $m7_ping_host		= $m7_ping_host_name_tree->textContent();

                        # Get the ping statistics
                        my $m7_ping_ip			= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/ip');
                        my $m7_ping_region		= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/region');
                        my $m7_ping_pkt_loss 	= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/pktLoss');
                        my $m7_ping_min_time 	= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/minTime');
                        my $m7_ping_avg_time 	= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/avgTime');
                        my $m7_ping_max_time 	= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/maxTime');
                        my $m7_ping_avg_dev  	= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/avgDev');
                        
                        # Get the target node geolocation
                        my $m7_ping_geo			= $m7_geo_parser->record_by_addr($m7_ping_ip);
                        my $m7_ping_lat			= $m7_ping_geo->latitude;
                        my $m7_ping_lon			= $m7_ping_geo->longitude;
                        
                        # Define the SQL insert string
                        my $m7_ping_sql_string = "('" . $ARGV[0] . "'" .
                        	",'" . $m7_host_ipaddr . "'" .
                        	",'" . $m7_host_region . "'" .
                        	",'" . $m7_host_lat . "'" .
                        	",'" . $m7_host_lon . "'" .
                        	",'" . $m7_ping_ip . "'" .
                        	",'" . $m7_ping_region . "'" .
                        	",'" . $m7_ping_lat . "'" .
                        	",'" . $m7_ping_lon . "'" .
                        	",'" . $m7_plan_runtime . "'" .
                        	",'" . $m7_ping_pkt_loss . "'" .
                        	",'" . $m7_ping_min_time . "'" .
                        	",'" . $m7_ping_avg_time . "'" .
                        	",'" . $m7_ping_max_time . "'" .
                        	",'" . $m7_ping_avg_dev . "')";
                        
                        # Append the string to the array
                        push (@m7_ping_sql, $m7_ping_sql_string);      
                    }
                    
                    # Flatten the ping SQL array and prepare the query string
                    my $m7_ping_sql_values		= join(", ", @m7_ping_sql);
                    my $m7_ping_sql_query		= "INSERT INTO " . DB_NAME . "." . $m7_host . "_net_ping(" . 
                    				      		  "test_id, source_ip, source_region, source_lat, source_lon, " . 
                    				      		  "dest_ip, dest_region, dest_lat, dest_lon, run_time, pkt_loss, min_time, avg_time, max_time, avg_dev) " .
                    					  		  "VALUES " . $m7_ping_sql_values . ";";
                    
                    # Create the table rows for the ping test
                    $m7_dbc->do($m7_ping_sql_query);
                 
				# Traceroute Test Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ # 
				#
				# Convert the test results for traceroute from XML to database
				# format and create entries in the database for the host for
				# each hop.
                } elsif ($m7_test_type eq "traceroute") {

					# Initialize the MySQL insert array
					my @m7_troute_sql;

                	# Process the host definitions
                    for my $m7_troute_host_name_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host/@name')) {
                    	my $m7_troute_host 			= $m7_troute_host_name_tree->textContent();
                    	my $m7_troute_dest_ip		= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_troute_host . '"]/ip');
                    	my $m7_troute_dest_region	= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_troute_host . '"]/region');
                    	
                    	# Get the target node geolocation
                        my $m7_troute_dest_geo		= $m7_geo_parser->record_by_addr($m7_troute_dest_ip);
                        my $m7_troute_dest_lat		= $m7_troute_dest_geo->latitude;
                       	my $m7_troute_dest_lon		= $m7_troute_dest_geo->longitude;
                    	
                    	# Process the hop definitions
                        for my $m7_troute_hops_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_troute_host . '"]/hops/hop/@number')) {
                        	
                        	# Get the statistics for the traceroute hop
                        	my $m7_troute_hop    		= $m7_troute_hops_tree->textContent();
                            my $m7_troute_ip     		= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_troute_host . '"]/hops/hop[@number="' . $m7_troute_hop . '"]/ip');
                            my $m7_troute_try    		= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_troute_host . '"]/hops/hop[@number="' . $m7_troute_hop . '"]/try');
                            my $m7_troute_time   		= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_troute_host . '"]/hops/hop[@number="' . $m7_troute_hop . '"]/time');
                        	my $m7_troute_ip_lat		= "";
                        	my $m7_troute_ip_lon		= "";
                        	
                        	$m7_troute_ip = $m7_troute_ip . "";
                        	# Get the hop IP geolocation and make sure the IP address is valid
                        	if (is_ipv4($m7_troute_ip) && !is_unroutable_ipv4($m7_troute_ip) && !is_private_ipv4($m7_troute_ip)) {
                        		my $m7_troute_ip_geo	= $m7_geo_parser->record_by_addr($m7_troute_ip);
                        		$m7_troute_ip_lat		= $m7_troute_ip_geo->latitude;
                       			$m7_troute_ip_lon		= $m7_troute_ip_geo->longitude;
                        	} else {
                        		$m7_troute_ip_lat		= "";
                        		$m7_troute_ip_lon		= "";
                        	}
                        	
                        	# Define the SQL insert string
	                        my $m7_troute_sql_string = "('" . $ARGV[0] . "'" .
	                        	",'" . $m7_host_ipaddr . "'" .
	                        	",'" . $m7_host_region . "'" .
	                        	",'" . $m7_host_lat . "'" .
	                        	",'" . $m7_host_lon . "'" .
	                        	",'" . $m7_troute_dest_ip . "'" .
	                        	",'" . $m7_troute_dest_region . "'" .
	                        	",'" . $m7_troute_dest_lat . "'" .
	                        	",'" . $m7_troute_dest_lon . "'" .
	                        	",'" . $m7_plan_runtime . "'" .
	                        	",'" . $m7_troute_hop . "'" .
	                        	",'" . $m7_troute_try . "'" .
	                        	",'" . $m7_troute_ip . "'" .
	                        	",'" . $m7_troute_ip_lat . "'" .
	                        	",'" . $m7_troute_ip_lon . "'" .
	                        	",'" . $m7_troute_time . "')";
	                        
	                        # Append the string to the array
	                        push (@m7_troute_sql, $m7_troute_sql_string)
                        } 
                    }
                    
                    # Flatten the traceroute SQL array and prepare the query string
                    my $m7_troute_sql_values		= join(", ", @m7_troute_sql);
                    my $m7_troute_sql_query			= "INSERT INTO " . DB_NAME . "." . $m7_host . "_net_traceroute(" . 
                    						   		  "test_id, source_ip, source_region, source_lat, source_lon, " . 
                    						   		  "dest_ip, dest_region, dest_lat, dest_lon, run_time, hop, try, ip, ip_lat, ip_lon, time) " .
                    						   		  "VALUES " . $m7_troute_sql_values . ";";
                    
                    # Create the table rows for the traceroute test
                    $m7_dbc->do($m7_troute_sql_query);

				# MTR Test Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
				#
				# Convert the test results for MTR from XML to database format
				# and create an entry in the database for the host for each
				# hop.
                } elsif ($m7_test_type eq "mtr") {
                				
                	# Initialize the MySQL insert array
                	my @m7_mtr_sql;			
                		
                	# Process the host definitions
                    for my $m7_mtr_host_name_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host/@name')) {
                    	my $m7_mtr_host				= $m7_mtr_host_name_tree->textContent();
                    	my $m7_mtr_dest_ip			= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_mtr_host . '"]/ip');
                    	my $m7_mtr_dest_region		= $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_mtr_host . '"]/region');
                    	
                    	# Get the target node geolocation
                        my $m7_mtr_dest_geo			= $m7_geo_parser->record_by_addr($m7_mtr_dest_ip);
                        my $m7_mtr_dest_lat			= $m7_mtr_dest_geo->latitude;
                       	my $m7_mtr_dest_lon			= $m7_mtr_dest_geo->longitude;
                    	
                    	# Process the hop definitions
                        for my $m7_mtr_hops_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_mtr_host . '"]/hops/hop/@number')) {
                        	
                        	# Get the statistics for the mtr hop
                        	my $m7_mtr_hop			= $m7_mtr_hops_tree->textContent();
                            my $m7_mtr_ip_list		= "";
                            my $m7_mtr_ip_geolist	= "";
                            my $m7_mtr_ip_lat		= "";
                            my $m7_mtr_ip_lon		= "";
                            for my $m7_mtr_ip_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_mtr_host . '"]/hops/hop[@number="' . $m7_mtr_hop . '"]/ips/ip')) {
                            	my $m7_mtr_hop_ip =  $m7_mtr_ip_tree->textContent();
                            	
                            	# Get the hop IP geolocation
	                        	if (is_ipv4($m7_mtr_hop_ip) && !is_unroutable_ipv4($m7_mtr_hop_ip) && !is_private_ipv4($m7_mtr_hop_ip)) {
	                        		my $m7_mtr_ip_geo	= $m7_geo_parser->record_by_addr($m7_mtr_hop_ip);
	                        		$m7_mtr_ip_lat	    = $m7_mtr_ip_geo->latitude;
	                       			$m7_mtr_ip_lon	    = $m7_mtr_ip_geo->longitude;
	                        	} else {
	                        		$m7_mtr_hop_ip   	= "*";
	                        		$m7_mtr_ip_lat		= "*";
	                        		$m7_mtr_ip_lon		= "*";
	                        	}
                            	
                            	if ($m7_mtr_ip_list eq "") {
                            		$m7_mtr_ip_geolist	= $m7_mtr_ip_lat . ":" . $m7_mtr_ip_lon;
                                	$m7_mtr_ip_list 	= $m7_mtr_hop_ip;
                                } else {
                                	$m7_mtr_ip_geolist 	.= "," . $m7_mtr_ip_lat . ":" . $m7_mtr_ip_lon;
                                	$m7_mtr_ip_list 	.= "," . $m7_mtr_hop_ip;
                                }
                            }
                            my $m7_mtr_pkt_loss = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_mtr_host . '"]/hops/hop[@number="' . $m7_mtr_hop . '"]/pktLoss');
                            my $m7_mtr_min_time = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_mtr_host . '"]/hops/hop[@number="' . $m7_mtr_hop . '"]/minTime');
                            my $m7_mtr_avg_time = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_mtr_host . '"]/hops/hop[@number="' . $m7_mtr_hop . '"]/avgTime');
                            my $m7_mtr_max_time = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_mtr_host . '"]/hops/hop[@number="' . $m7_mtr_hop . '"]/maxTime');
                            my $m7_mtr_avg_dev  = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_mtr_host . '"]/hops/hop[@number="' . $m7_mtr_hop . '"]/avgDev');
                        
                        	# Define the SQL insert string
	                        my $m7_mtr_sql_string = "('" . $ARGV[0] . "'" .
	                        	",'" . $m7_host_ipaddr . "'" .
	                        	",'" . $m7_host_region . "'" .
	                        	",'" . $m7_host_lat . "'" .
	                        	",'" . $m7_host_lon . "'" .
	                        	",'" . $m7_mtr_dest_ip . "'" .
	                        	",'" . $m7_mtr_dest_region . "'" .
	                        	",'" . $m7_mtr_dest_lat . "'" .
	                        	",'" . $m7_mtr_dest_lon . "'" .
	                        	",'" . $m7_plan_runtime . "'" .
	                        	",'" . $m7_mtr_hop . "'" .
	                        	",'" . $m7_mtr_ip_list . "'" .
	                        	",'" . $m7_mtr_ip_geolist . "'" .
	                        	",'" . $m7_mtr_min_time . "'" .
	                        	",'" . $m7_mtr_avg_time . "'" .
	                        	",'" . $m7_mtr_max_time . "'" .
	                        	",'" . $m7_mtr_avg_dev . "')";
	                        
	                        # Append the string to the array
	                        push (@m7_mtr_sql, $m7_mtr_sql_string)
                        } 
                    }
                    
                    # Flatten the mtr SQL array and prepare the query
                    my $m7_mtr_sql_values	= join(", ", @m7_mtr_sql);
                    my $m7_mtr_sql_query	= "INSERT INTO " . DB_NAME . "." . $m7_host . "_net_mtr(" . 
                    					 	  "test_id, source_ip, source_region, source_lat, source_lon, " . 
                    					 	  "dest_ip, dest_region, dest_lat, dest_lon, run_time, hop, ips, ips_gps, min_time, avg_time, max_time, avg_dev) " .
                    					 	  "VALUES " . $m7_mtr_sql_values . ";";
                    
                    # Create the table rows for the mtr test
                    $m7_dbc->do($m7_mtr_sql_query);

                # Handle unknown test types
                } else {
                	# Nothing here yet
                }
            }
        }
    }
}           					