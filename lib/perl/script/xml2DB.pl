#!/usr/bin/perl

use strict;
use XML::LibXML;
use XML::XPath;
use DBI;
use DBD::mysql;
use Geo::IP;
use Data::Validate::IP;
use File::Slurp;
use lib $ENV{HOME} . '/lib/perl/modules';
use M7Config;

# Get the plan ID argument
my $m7p_plan_id = $ARGV[0];

# Create a new database connection
my $m7p_dsn = "dbi:mysql:" . %m7_db->{name} . ":" . %m7_db->{host} . ":" . %m7_db->{port};
my $m7p_db = DBI->connect($m7p_dsn, %m7_db->{user}, %m7_db->{pass});

# Create a LibXML instance
my $m7p_lib_xml = XML::LibXML->new();

# Define the geo IP parser
my $m7p_geoip = Geo::IP->open('/usr/local/share/GeoIP/GeoLiteCity.dat', GEOIP_STANDARD);

# Define the results directory based on test ID
my $m7p_xml_dir = $ENV{"HOME"} . "/results/" . $m7p_plan_id . "/";

# Grab all the output XML files and store in an array
opendir(DIR, $m7p_xml_dir) or die $!;
my @m7_xml_files;
while (my $m7p_xml_file = readdir(DIR)) {
	next if (substr($m7p_xml_file,0,1) eq ".");
    push (@m7_xml_files, "$m7p_xml_dir$m7p_xml_file");
}

# Parse the XML test plan
my $m7p_plan_xpath	= XML::XPath->new(filename => $ENV{"HOME"} . "/plans/" . $m7p_plan_id . ".xml");
my $m7p_plan_desc	= $m7p_plan_xpath->findnodes('plan/desc');
my $m7p_plan_cat		= $m7p_plan_xpath->findnodes('plan/params/category');
my $m7p_plan_runtime	= read_file($ENV{"HOME"} . "/lock/" . $m7p_plan_id . "/runtime");

# If the test row doesn't exist create it, if so, update the last runtime
my $m7p_plan_check	= $m7p_db->selectcol_arrayref("SELECT * FROM plans WHERE plan_id='" . $m7p_plan_id . "'");
if (@$m7p_plan_check) {
	my $m7p_plan_update = "UPDATE `" . %m7_db->{name} . "`.`plans` SET last_run='" . $m7p_plan_runtime . "', run_count=run_count+1 WHERE plan_id='" . $m7p_plan_id . "'";
	$m7p_db->do($m7p_plan_update);
} else {
	my $m7p_plan_create = "INSERT INTO `" . %m7_db->{name} . "`.`plans`(" .
						 "`plan_id`, `type`, `desc`, `first_run`, `last_run`, `run_count`) VALUES(" . 
						 "'" . $m7p_plan_id . "','net','" . $m7p_plan_desc . "','" . $m7p_plan_runtime . "','" . $m7p_plan_runtime . "', 1)";
	$m7p_db->do($m7p_plan_create);
}

# Process XML Result Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
foreach (@m7_xml_files) {
    my $m7p_xml_tree		= $m7p_lib_xml->parse_file($_);
    my $m7p_test_xpath		= XML::XPath->new(filename => $_);
	
    # Get the node information
    for my $m7p_host_node ($m7p_xml_tree->findnodes('plan/host/@name')) {
    	my $m7p_host			= $m7p_host_node->textContent();
    	my $m7p_host_ipaddr	= $m7p_test_xpath->findvalue('plan/host/@ip');
    	my $m7p_host_region  = $m7p_test_xpath->findvalue('plan/host/@region');
        $m7p_host 			=~ s/-/_/g;

		# Get the host's geolocation
		my $m7p_host_geo		= $m7p_geoip->record_by_addr($m7p_host_ipaddr);
		my $m7p_host_lat		= $m7p_host_geo->latitude;
		my $m7p_host_lon		= $m7p_host_geo->longitude;

		# Host Ping Statistics Table \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
        $m7p_db->do("
        	CREATE TABLE IF NOT EXISTS " . %m7_db->{name} . "." . $m7p_host . "_net_ping(
            	id              INT NOT NULL AUTO_INCREMENT,
            	plan_id			INT NOT NULL,
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
        $m7p_db->do("
        	CREATE TABLE IF NOT EXISTS " . %m7_db->{name} . "." . $m7p_host . "_net_traceroute(
            	id              INT NOT NULL AUTO_INCREMENT,
            	plan_id			INT NOT NULL,
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
		$m7p_db->do("
			CREATE TABLE IF NOT EXISTS " . %m7_db->{name} . "." . $m7p_host . "_net_mtr(
            	id              INT NOT NULL AUTO_INCREMENT,
            	plan_id			INT NOT NULL,
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
        for my $m7p_test_id_tree ($m7p_xml_tree->findnodes('plan/test/@id')) {
        	my $m7p_test_id = $m7p_test_id_tree->textContent();
            my $m7p_test_type = $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/@type');
            for my $m7p_test_tree ($m7p_xml_tree->findnodes('plan/test[@id="' . $m7p_test_id . '"]')) {

				# Ping Test Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
				#
				# Convert the test results for ping from XML to database format
				# and create entries in the database for the host.
                if ($m7p_test_type eq "ping") {

					# Initialize the MySQL insert array
					my @m7_ping_sql;

                	# Process the host definitions
                    for my $m7p_ping_host_name_tree ($m7p_xml_tree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host/@name')) {
                    	my $m7p_ping_host		= $m7p_ping_host_name_tree->textContent();

                        # Get the ping statistics
                        my $m7p_ping_ip			= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/@ip');
                        my $m7p_ping_region		= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/@region');
                        my $m7p_ping_pkt_loss 	= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/pktLoss');
                        my $m7p_ping_min_time 	= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/minTime');
                        my $m7p_ping_avg_time 	= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/avgTime');
                        my $m7p_ping_max_time 	= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/maxTime');
                        my $m7p_ping_avg_dev  	= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/avgDev');
                        
                        # Get the target node geolocation
                        my $m7p_ping_geo			= $m7p_geoip->record_by_addr($m7p_ping_ip);
                        my $m7p_ping_lat			= $m7p_ping_geo->latitude;
                        my $m7p_ping_lon			= $m7p_ping_geo->longitude;
                        
                        # Define the SQL insert string
                        my $m7p_ping_sql_string = "('" . $m7p_plan_id . "'" .
                        	",'" . $m7p_host_ipaddr . "'" .
                        	",'" . $m7p_host_region . "'" .
                        	",'" . $m7p_host_lat . "'" .
                        	",'" . $m7p_host_lon . "'" .
                        	",'" . $m7p_ping_ip . "'" .
                        	",'" . $m7p_ping_region . "'" .
                        	",'" . $m7p_ping_lat . "'" .
                        	",'" . $m7p_ping_lon . "'" .
                        	",'" . $m7p_plan_runtime . "'" .
                        	",'" . $m7p_ping_pkt_loss . "'" .
                        	",'" . $m7p_ping_min_time . "'" .
                        	",'" . $m7p_ping_avg_time . "'" .
                        	",'" . $m7p_ping_max_time . "'" .
                        	",'" . $m7p_ping_avg_dev . "')";
                        
                        # Append the string to the array
                        push (@m7_ping_sql, $m7p_ping_sql_string);      
                    }
                    
                    # Flatten the ping SQL array and prepare the query string
                    my $m7p_ping_sql_values		= join(", ", @m7_ping_sql);
                    my $m7p_ping_sql_query		= "INSERT INTO " . %m7_db->{name} . "." . $m7p_host . "_net_ping(" . 
                    				      		  "plan_id, source_ip, source_region, source_lat, source_lon, " . 
                    				      		  "dest_ip, dest_region, dest_lat, dest_lon, run_time, pkt_loss, min_time, avg_time, max_time, avg_dev) " .
                    					  		  "VALUES " . $m7p_ping_sql_values . ";";
                    
                    # Create the table rows for the ping test
                    $m7p_db->do($m7p_ping_sql_query);
                 
				# Traceroute Test Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ # 
				#
				# Convert the test results for traceroute from XML to database
				# format and create entries in the database for the host for
				# each hop.
                } elsif ($m7p_test_type eq "traceroute") {

					# Initialize the MySQL insert array
					my @m7_troute_sql;

                	# Process the host definitions
                    for my $m7p_troute_host_name_tree ($m7p_xml_tree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host/@name')) {
                    	my $m7p_troute_host 			= $m7p_troute_host_name_tree->textContent();
                    	my $m7p_troute_dest_ip		= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/@ip');
                    	my $m7p_troute_dest_region	= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/@region');
                    	
                    	# Get the target node geolocation
                        my $m7p_troute_dest_geo		= $m7p_geoip->record_by_addr($m7p_troute_dest_ip);
                        my $m7p_troute_dest_lat		= $m7p_troute_dest_geo->latitude;
                       	my $m7p_troute_dest_lon		= $m7p_troute_dest_geo->longitude;
                    	
                    	# Process the hop definitions
                        for my $m7p_troute_hops_tree ($m7p_xml_tree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/hops/hop/@number')) {
                        	
                        	# Get the statistics for the traceroute hop
                        	my $m7p_troute_hop    		= $m7p_troute_hops_tree->textContent();
                            my $m7p_troute_ip     		= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/hops/hop[@number="' . $m7p_troute_hop . '"]/ip');
                            my $m7p_troute_try    		= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/hops/hop[@number="' . $m7p_troute_hop . '"]/try');
                            my $m7p_troute_time   		= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/hops/hop[@number="' . $m7p_troute_hop . '"]/time');
                        	my $m7p_troute_ip_lat		= "";
                        	my $m7p_troute_ip_lon		= "";
                        	
                        	$m7p_troute_ip = $m7p_troute_ip . "";
                        	# Get the hop IP geolocation and make sure the IP address is valid
                        	if (is_ipv4($m7p_troute_ip) && !is_unroutable_ipv4($m7p_troute_ip) && !is_private_ipv4($m7p_troute_ip)) {
                        		my $m7p_troute_ip_geo	= $m7p_geoip->record_by_addr($m7p_troute_ip);
                        		$m7p_troute_ip_lat		= $m7p_troute_ip_geo->latitude;
                       			$m7p_troute_ip_lon		= $m7p_troute_ip_geo->longitude;
                        	} else {
                        		$m7p_troute_ip_lat		= "";
                        		$m7p_troute_ip_lon		= "";
                        	}
                        	
                        	# Define the SQL insert string
	                        my $m7p_troute_sql_string = "('" . $m7p_plan_id . "'" .
	                        	",'" . $m7p_host_ipaddr . "'" .
	                        	",'" . $m7p_host_region . "'" .
	                        	",'" . $m7p_host_lat . "'" .
	                        	",'" . $m7p_host_lon . "'" .
	                        	",'" . $m7p_troute_dest_ip . "'" .
	                        	",'" . $m7p_troute_dest_region . "'" .
	                        	",'" . $m7p_troute_dest_lat . "'" .
	                        	",'" . $m7p_troute_dest_lon . "'" .
	                        	",'" . $m7p_plan_runtime . "'" .
	                        	",'" . $m7p_troute_hop . "'" .
	                        	",'" . $m7p_troute_try . "'" .
	                        	",'" . $m7p_troute_ip . "'" .
	                        	",'" . $m7p_troute_ip_lat . "'" .
	                        	",'" . $m7p_troute_ip_lon . "'" .
	                        	",'" . $m7p_troute_time . "')";
	                        
	                        # Append the string to the array
	                        push (@m7_troute_sql, $m7p_troute_sql_string)
                        } 
                    }
                    
                    # Flatten the traceroute SQL array and prepare the query string
                    my $m7p_troute_sql_values		= join(", ", @m7_troute_sql);
                    my $m7p_troute_sql_query			= "INSERT INTO " . %m7_db->{name} . "." . $m7p_host . "_net_traceroute(" . 
                    						   		  "plan_id, source_ip, source_region, source_lat, source_lon, " . 
                    						   		  "dest_ip, dest_region, dest_lat, dest_lon, run_time, hop, try, ip, ip_lat, ip_lon, time) " .
                    						   		  "VALUES " . $m7p_troute_sql_values . ";";
                    
                    # Create the table rows for the traceroute test
                    $m7p_db->do($m7p_troute_sql_query);

				# MTR Test Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
				#
				# Convert the test results for MTR from XML to database format
				# and create an entry in the database for the host for each
				# hop.
                } elsif ($m7p_test_type eq "mtr") {
                				
                	# Initialize the MySQL insert array
                	my @m7_mtr_sql;			
                		
                	# Process the host definitions
                    for my $m7p_mtr_host_name_tree ($m7p_xml_tree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host/@name')) {
                    	my $m7p_mtr_host				= $m7p_mtr_host_name_tree->textContent();
                    	my $m7p_mtr_dest_ip			= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/@ip');
                    	my $m7p_mtr_dest_region		= $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/@region');
                    	
                    	# Get the target node geolocation
                        my $m7p_mtr_dest_geo			= $m7p_geoip->record_by_addr($m7p_mtr_dest_ip);
                        my $m7p_mtr_dest_lat			= $m7p_mtr_dest_geo->latitude;
                       	my $m7p_mtr_dest_lon			= $m7p_mtr_dest_geo->longitude;
                    	
                    	# Process the hop definitions
                        for my $m7p_mtr_hops_tree ($m7p_xml_tree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop/@number')) {
                        	
                        	# Get the statistics for the mtr hop
                        	my $m7p_mtr_hop			= $m7p_mtr_hops_tree->textContent();
                            my $m7p_mtr_ip_list		= "";
                            my $m7p_mtr_ip_geolist	= "";
                            my $m7p_mtr_ip_lat		= "";
                            my $m7p_mtr_ip_lon		= "";
                            for my $m7p_mtr_ip_tree ($m7p_xml_tree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/ips/ip')) {
                            	my $m7p_mtr_hop_ip =  $m7p_mtr_ip_tree->textContent();
                            	
                            	# Get the hop IP geolocation
	                        	if (is_ipv4($m7p_mtr_hop_ip) && !is_unroutable_ipv4($m7p_mtr_hop_ip) && !is_private_ipv4($m7p_mtr_hop_ip)) {
	                        		my $m7p_mtr_ip_geo	= $m7p_geoip->record_by_addr($m7p_mtr_hop_ip);
	                        		$m7p_mtr_ip_lat	    = $m7p_mtr_ip_geo->latitude;
	                       			$m7p_mtr_ip_lon	    = $m7p_mtr_ip_geo->longitude;
	                        	} else {
	                        		$m7p_mtr_hop_ip   	= "*";
	                        		$m7p_mtr_ip_lat		= "*";
	                        		$m7p_mtr_ip_lon		= "*";
	                        	}
                            	
                            	if ($m7p_mtr_ip_list eq "") {
                            		$m7p_mtr_ip_geolist	= $m7p_mtr_ip_lat . ":" . $m7p_mtr_ip_lon;
                                	$m7p_mtr_ip_list 	= $m7p_mtr_hop_ip;
                                } else {
                                	$m7p_mtr_ip_geolist 	.= "," . $m7p_mtr_ip_lat . ":" . $m7p_mtr_ip_lon;
                                	$m7p_mtr_ip_list 	.= "," . $m7p_mtr_hop_ip;
                                }
                            }
                            my $m7p_mtr_pkt_loss = $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/pktLoss');
                            my $m7p_mtr_min_time = $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/minTime');
                            my $m7p_mtr_avg_time = $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/avgTime');
                            my $m7p_mtr_max_time = $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/maxTime');
                            my $m7p_mtr_avg_dev  = $m7p_test_xpath->findvalue('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/avgDev');
                        
                        	# Define the SQL insert string
	                        my $m7p_mtr_sql_string = "('" . $m7p_plan_id . "'" .
	                        	",'" . $m7p_host_ipaddr . "'" .
	                        	",'" . $m7p_host_region . "'" .
	                        	",'" . $m7p_host_lat . "'" .
	                        	",'" . $m7p_host_lon . "'" .
	                        	",'" . $m7p_mtr_dest_ip . "'" .
	                        	",'" . $m7p_mtr_dest_region . "'" .
	                        	",'" . $m7p_mtr_dest_lat . "'" .
	                        	",'" . $m7p_mtr_dest_lon . "'" .
	                        	",'" . $m7p_plan_runtime . "'" .
	                        	",'" . $m7p_mtr_hop . "'" .
	                        	",'" . $m7p_mtr_ip_list . "'" .
	                        	",'" . $m7p_mtr_ip_geolist . "'" .
	                        	",'" . $m7p_mtr_pkt_loss . "'" .
	                        	",'" . $m7p_mtr_min_time . "'" .
	                        	",'" . $m7p_mtr_avg_time . "'" .
	                        	",'" . $m7p_mtr_max_time . "'" .
	                        	",'" . $m7p_mtr_avg_dev . "')";
	                        
	                        # Append the string to the array
	                        push (@m7_mtr_sql, $m7p_mtr_sql_string)
                        } 
                    }
                    
                    # Flatten the mtr SQL array and prepare the query
                    my $m7p_mtr_sql_values	= join(", ", @m7_mtr_sql);
                    my $m7p_mtr_sql_query	= "INSERT INTO " . %m7_db->{name} . "." . $m7p_host . "_net_mtr(" . 
                    					 	  "plan_id, source_ip, source_region, source_lat, source_lon, " . 
                    					 	  "dest_ip, dest_region, dest_lat, dest_lon, run_time, hop, ips, ips_gps, pkt_loss, min_time, avg_time, max_time, avg_dev) " .
                    					 	  "VALUES " . $m7p_mtr_sql_values . ";";
                    
                    # Create the table rows for the mtr test
                    $m7p_db->do($m7p_mtr_sql_query);

                # Handle unknown test types
                } else {
                	# Nothing here yet
                }
            }
        }
    }
}   