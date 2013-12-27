#!/usr/bin/perl

# Load the required Perl modules
use XML::LibXML;
use XML::XPath;
use DBI;
use DBD::mysql;
use Data::Dumper;

# Create the XML parser
my $m7_xml_parser = XML::LibXML->new();

# Database connection values
use constant {
	DB_NAME => "m7",
    DB_HOST => "localhost",
    DB_PORT => "3306",
    DB_USER => "root",
    DB_PASS => "KTr0xr0x",
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

# Process each XML results file
foreach (@m7_xml_files) {
    my $m7_xml_tree			= $m7_xml_parser->parse_file($_);
    my $m7_test_xpath		= XML::XPath->new(filename, $_);

    # Get the node information
    for my $m7_host_node ($m7_xml_tree->findnodes('plan/host/name')) {
    	my $m7_host			= $m7_host_node->textContent();
    	my $m7_host_ipaddr	= $m7_test_xpath->findvalue('plan/host/ip');
        $m7_host 			=~ s/-/_/g;

        # Create host ping statistics table
        $m7_dbc->do("
        	CREATE TABLE IF NOT EXISTS " . DB_NAME . "." . $m7_host . "_net_ping(
            	id              INT NOT NULL AUTO_INCREMENT,
            	test_id			INT NOT NULL,
                source_ip       VARCHAR(15) NOT NULL,
                dest_ip         VARCHAR(15) NOT NULL,
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
                
        # Create host traceroute statistics table
        $m7_dbc->do("
        	CREATE TABLE IF NOT EXISTS " . DB_NAME . "." . $m7_host . "_net_traceroute(
            	id              INT NOT NULL AUTO_INCREMENT,
            	test_id			INT NOT NULL,
            	source_ip       VARCHAR(15) NOT NULL,
           		dest_ip         VARCHAR(15) NOT NULL,
            	run_time        DATETIME NOT NULL,
            	hop             INT NOT NULL,
            	try             INT NOT NULL,
            	ip              VARCHAR(15) NOT NULL,
            	time            VARCHAR(10) NOT NULL,
            	modified        TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP,
            	PRIMARY KEY(id)
        	);
    	");

		# Create host mtr statistics table
		$m7_dbc->do("
			CREATE TABLE IF NOT EXISTS " . DB_NAME . "." . $m7_host . "_net_mtr(
            	id              INT NOT NULL AUTO_INCREMENT,
            	test_id			INT NOT NULL,
                source_ip       VARCHAR(15) NOT NULL,
                dest_ip         VARCHAR(15) NOT NULL,
                run_time        DATETIME NOT NULL,
                hop             INT NOT NULL,
                ips             VARCHAR(256) NOT NULL,
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

            	# Process the ping test for the host
                if ($m7_test_type eq "ping") {

					# Initialize the MySQL insert array
					my @m7_ping_sql;

                	# Process the host definitions
                    for my $m7_ping_host_name_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host/@name')) {
                    	$m7_ping_host = $m7_ping_host_name_tree->textContent();

                        # Get the ping statistics
                        my $m7_ping_ip       = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/ip');
                        my $m7_ping_pkt_loss = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/pktLoss');
                        my $m7_ping_min_time = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/minTime');
                        my $m7_ping_avg_time = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/avgTime');
                        my $m7_ping_max_time = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/maxTime');
                        my $m7_ping_avg_dev  = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_ping_host . '"]/avgDev');
                        
                        # Define the SQL insert string
                        my $m7_ping_sql_string = "('" . $ARGV[0] . "'",
                        	",'" . $m7_host_ipaddr . "'",
                        	",'" . $m7_ping_ip . "'",
                        	",'" . $m7_ping_pkt_loss . "'",
                        	",'" . $m7_ping_min_time . "'",
                        	",'" . $m7_ping_avg_time . "'",
                        	",'" . $m7_ping_max_time . "'",
                        	",'" . $m7_ping_avg_dev . "')";
                        
                        # Append the string to the array
                        push (@m7_ping_sql, $m7_ping_sql_string);      
                    }
                    
                    # Flatten the ping SQL array
                    $m7_ping_sql_values = join(", ", @m7_ping_sql);
                    
                    # Create the table rows for the ping test
                    $m7_dbc->do("
                    	INSERT INTO " . DB_NAME . "." . $m7_host . "_net_ping(test_id, source_ip, dest_ip, run_time, pkt_loss, min_time, avg_time, max_time, avg_dev)
                    	VALUES " . $m7_ping_sql_values . ";
                    ");
                    

                # Process the traceroute test for the host
                } elsif ($m7_test_type eq "traceroute") {

                	# Process the host definitions
                    for my $m7_test_host_name_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host/@name')) {
                    	$m7_target_host = $m7_test_host_name_tree->textContent();
                        for my $m7_test_host_troute_hops_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop/@number')) {
                        	
                        	# Get the statistics for the traceroute hop
                        	my $m7_host_troute_hop    = $m7_test_host_troute_hops_tree->textContent();
                            my $m7_host_troute_ip     = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop[@number="' . $m7_host_troute_hop . '"]/ip');
                            my $m7_host_troute_try    = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop[@number="' . $m7_host_troute_hop . '"]/try');
                            my $m7_host_troute_time   = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop[@number="' . $m7_host_troute_hop . '"]/time');
                        }
                    }

                # Process the mtr test for the host
                } elsif ($m7_test_type eq "mtr") {
                					
                	# Process the host definitions
                    for my $m7_test_host_name_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host/@name')) {
                    	$m7_target_host = $m7_test_host_name_tree->textContent();
                        for my $m7_test_host_mtr_hops_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop/@number')) {
                        	
                        	# Get the statistics for the mtr hop
                        	my $m7_host_mtr_hop     = $m7_test_host_mtr_hops_tree->textContent();
                            my $m7_host_mtr_ip_list = "";
                            for my $m7_host_mtr_ip_tree ($m7_xml_tree->findnodes('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop[@number="' . $m7_host_mtr_hop . '"]/ips/ip')) {
                            	if ($m7_host_mtr_ip_list eq "") {
                                	$m7_host_mtr_ip_list = $m7_host_mtr_ip_tree->textContent();
                                } else {
                                	$m7_host_mtr_ip_list .= "," . $m7_host_mtr_ip_tree->textContent();
                                }
                            }
                            my $m7_host_mtr_pkt_loss = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop[@number="' . $m7_host_mtr_hop . '"]/pktLoss');
                            my $m7_host_mtr_min_time = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop[@number="' . $m7_host_mtr_hop . '"]/minTime');
                            my $m7_host_mtr_avg_time = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop[@number="' . $m7_host_mtr_hop . '"]/avgTime');
                            my $m7_host_mtr_max_time = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop[@number="' . $m7_host_mtr_hop . '"]/maxTime');
                            my $m7_host_mtr_avg_dev  = $m7_test_xpath->findvalue('plan/test[@id="' . $m7_test_id . '"]/host[@name="' . $m7_target_host . '"]/hops/hop[@number="' . $m7_host_mtr_hop . '"]/avgDev');
                        }
                    }

                # Handle unknown test types
                } else {
                	# Nothing here yet
                }
            }
        }
    }
}           					