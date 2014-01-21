# Package Name \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
package M7Parse;

# Module Dependencies \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
BEGIN {
	use strict;
	use Log::Log4perl;
	use File::Slurp;
	use XML::LibXML;
	use XML::XPath;
	use DBI;
	use DBD::mysql;
	use Geo::IP;
	use Data::Validate::IP;
	use Net::Nslookup;
	use Net::Whois::RIS;
	use lib $ENV{HOME} . '/lib/perl/modules';
	use M7Config;
}

# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
# Module Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #

# Package Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub new {
	my $m7p = {
		_config			=> M7Config->new(),
		_libxml			=> XML::LibXML->new(),
		_ris			=> Net::Whois::RIS->new(),
		_geoip			=> undef,
		_plan_id		=> undef,
		_plan_desc		=> undef,
		_plan_cat		=> undef,
		_plan_file		=> undef,
		_plan_xpath		=> undef,
		_plan_xtree		=> undef,
		_results_xpath  => undef,
		_results_xtree  => undef,
		_test_ids		=> undef,
		_test_types		=> undef,
		_test_host		=> {},
		_runtime		=> undef,
		_xml_dir		=> undef,
		_xml_files		=> undef,
		_db				=> undef,
		_log			=> undef
	};
	bless $m7p, M7Parse;
	$m7p->logInit();
	$m7p->dbInit();
	$m7p->geoIPInit();
	return $m7p;
}

# Subroutine Shortcuts \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub config        { return shift->{_config};        }
sub libxml        { return shift->{_libxml};        }
sub ris			  { return shift->{_ris};           }
sub plan_id       { return shift->{_plan_id};       }
sub plan_desc     { return shift->{_plan_desc};     }
sub plan_cat      { return shift->{_plan_cat};      }
sub plan_file     { return shift->{_plan_file};     }
sub plan_xpath    { return shift->{_plan_xpath};    }
sub plan_xtree	  { return shift->{_plan_xtree};	}
sub results_xpath { return shift->{_results_xpath}; }
sub results_xtree { return shift->{_results_xpath}; }
sub test_ids      { return shift->{_test_ids};      }
sub test_types    { return shift->{_test_types};    }
sub test_host	  { return shift->{_test_host};	    }
sub runtime       { return shift->{_runtime};       }
sub xml_dir       { return shift->{_xml_dir};       }
sub xml_files     { return shift->{_xml_files};     }
sub geoip         { return shift->{_geoip};         }
sub db 	          { return shift->{_db};            }
sub log		      { return shift->{_log};		    }

# Initialize Logger \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub logInit {
	my $m7p = shift;
	
	# Read the log configuration into memory
	my $m7p_log_file = $m7p->config->get('log_file_m7p');
	my $m7p_log_conf = read_file($m7p->config->get('log_conf_m7p'));
	$m7p_log_conf =~ s/__LOGFILE__/$m7p_log_file/;
	
	# Initialize the logger
	Log::Log4perl::init(\$m7p_log_conf)
		or die 'Failed to initialize logger!';
	
	# Build the logger object
	$m7p->{_log} = Log::Log4perl->get_logger;
	return $m7p->{_log};
}

# Initialize Database Connection \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub dbInit {
	my $m7p = shift;
		$m7p->log->info('Initializing database object');
	my $m7p_db_dsn = "dbi:mysql:" . $m7p->config->get('db_name') . ":" . $m7p->config->get('db_host') . ":" . $m7p->config->get('db_port');
	$m7p->{_db} = shift;
	my $m7p_dbh = DBI->connect($m7p_db_dsn, $m7p->config->get('db_user'), $m7p->config->get('db_pass'), {
		PrintError => 0,
		RaiseError => 1
	}) or $m7p->log->logdie("Failed to connect to database: '" . DBI->errstr . "'");
	$m7p->{_db} = $m7p_dbh;
	return $m7p->{_db};
}

# Initialize GeoIP Object \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub geoIPInit {
	my $m7p = shift;
	$m7p->log->info('Initializing GeoIP object');
	$m7p->{_geoip} = Geo::IP->open($m7p->config->get('geo_db'), GEOIP_STANDARD)
		or $m7p->log->logdie('Failed to initialize GeoIP object. Missing GeoIP database? : "' . $m7p_geo{db} . '"');
	return $m7->{_geoip};
}

# Set Plan Parameters \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub setPlan {
	my $m7p = shift;
	my ($m7p_plan_id, $m7p_plan_runtime) = @_;
	
	# Make sure all arguments are defined
	unless( $m7p_plan_id and $m7p_plan_runtime) {
		$m7p->log->logdie('Must specify both plan ID and runtime to parse XML results');
	}
	
	# Begin setting module variables
	$m7p->{_plan_id}	= $m7p_plan_id;
	$m7p->{_plan_file}	= $m7p->config->home . "/plans/" . $m7p_plan_id . ".xml";
	$m7p->{_xml_dir}    = $m7p->config->home . "/results/" . $m7p_plan_id . "/";
	
	# Load all the result files into an array
	opendir(XML_DIR, $m7p->xml_dir)
		or $m7p->log->logdie('Could not open XML results directory: '. $m7p->xml_dir);
	while (my $m7p_xml_file = readdir(XML_DIR)) {
		next if (substr($m7p_xml_file,0,1) eq ".");
    	push (@{$m7p->{_xml_files}}, $m7p->xml_dir . $m7p_xml_file);
	}
	closedir(XML_DIR);
	
	# Get all the test IDs
	$m7p->{_plan_xtree}		= $m7p->libxml->parse_file($m7p->plan_file);
	for my $m7p_test_ids ($m7p->plan_xtree->findnodes('plan/params/test/@id')) {
		my $m7p_test_id = $m7p_test_ids->textContent();
		push(@{$m7p->{_test_ids}}, $m7p_test_id);
	}
	
	# Get all unique test types
	foreach(@{$m7p->test_ids}) {
		$m7p_test_type = $m7p->plan_xtree->findnodes('plan/params/test[@id="' . $_ . '"]/type');
		my %m7p_unique_tests = map { $_ => 1 } @{$m7p->test_types};
		if(not exists($m7p_unique_tests{$m7p_test_type})) {
			push(@{$m7p->{_test_types}}, $m7p_test_type);
		}
	}
	
	# Set the XPath, description, category, and runtime
	$m7p->{_plan_xpath}	= XML::XPath->new(filename => $m7p->plan_file);
	$m7p->{_plan_desc}	= $m7p->plan_xpath->findnodes('plan/desc');
	$m7p->{_plan_cat}	= $m7p->plan_xpath->findnodes('plan/params/category');
	$m7p->{_runtime}	= $m7p_plan_runtime;
}

# Add IP Reference \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub addIPRef {
	my $m7p = shift;
	my (%m7p_ipref) = @_;
	
	# Only proceed if the IP address is valid
	if (is_ipv4($m7p_ipref{ip}) && !is_unroutable_ipv4($m7p_ipref{ip}) && !is_private_ipv4($m7p_ipref{ip})) {
	
		# Set the IP types
		my $m7p_ipref_types_sql;
		if (defined($m7p_ipref{is_src}))  { $m7p_ipref_types_sql .= "is_src='" . $m7p_ipref{is_src} . "', "; }
		if (defined($m7p_ipref{is_hop}))  { $m7p_ipref_types_sql .= "is_hop='" . $m7p_ipref{is_hop} . "', "; }
		if (defined($m7p_ipref{is_dest})) { $m7p_ipref_types_sql .= "is_dest='" . $m7p_ipref{is_dest} . "', "; }
		my $m7p_ipref_type = {
			'src'  => ( defined($m7p_ipref{is_src})  ? $m7p_ipref{is_src}  : 0 ),
			'hop'  => ( defined($m7p_ipref{is_hop})  ? $m7p_ipref{is_hop}  : 0 ),
			'dest' => ( defined($m7p_ipref{is_dest}) ? $m7p_ipref{is_dest} : 0 )
		};
	
		# Attempt to map the IP address to a hostname
		my $m7p_ipref_hostname = nslookup(host => $m7p_ipref{ip}, type => 'PTR', timeout => '5');
		if (defined $m7p_ipref_hostname) { $m7p_ipref_hostname = lc($m7p_ipref_hostname); }
	
		# Retrieve the geo information for the IP address
		my $m7p_ipref_geo		= $m7p->geoip->record_by_addr($m7p_ipref{ip});
		my $m7p_ipref_region	= $m7p_ipref_geo->country_code;
		my $m7p_ipref_lat		= $m7p_ipref_geo->latitude;
		my $m7p_ipref_lon		= $m7p_ipref_geo->longitude;
		
		# Get the IP routing information
		$m7p->ris->getIPInfo($m7p_ipref{ip});
		my $m7p_ipref_route = $m7p->ris->{get}->{route};
		my $m7p_ipref_desc  = $m7p->ris->{get}->{descr};
		my $m7p_ipref_asn   = $m7p->ris->{get}->{origin};
		$m7p_ipref_asn      =~ s/^AS(\d+)/$1/g;
	
		# Check if the IP exists in the database
		my $m7p_ipref_check	= $m7p->db->selectcol_arrayref("SELECT * FROM net_ipref WHERE ip='" . $m7p_ipref{ip} . "'");
		if (@$m7p_ipref_check) {
			$m7p->log->info('Updating entry in IP reference table for: ' . $m7p_ipref{ip});
			my $m7p_ipref_update = "UPDATE `" . $m7p->config->get('db_name') . "`.`net_ipref` SET " .
								   "asn='" . $m7p_ipref_asn . "', " .
								   "route='" . $m7p_ipref_route . "', " .
								   "desc='" . $m7p_ipref_desc . "', " .
								   "alias='" . $m7p_ipref{alias} . "', " .
								   "hostname='" . $m7p_ipref_hostname . "', " . 
								   "region='" . $m7p_ipref_region . "', " .
								   "latitude='" . $m7p_ipref_lat . "', " .
								   $m7p_ipref_types_sql .
								   "longitude='" . $m7p_ipref_lon . "', " .
								   "WHERE ip='" . $m7p_ipref{ip} . "'";
			$m7p->db->do($m7p_ipref_update) or $m7p->log->warn('Failed to update IP reference database entry for: ' . $m7p_ipref{ip});
		} else {
			$m7p->log->info('Creating entry in IP reference table for: ' . $m7p_ipref{ip});
			my $m7p_ipref_update = "INSERT INTO `" . $m7p->config->get('db_name') . "`.`net_ipref`(" .
								   "`ip`,`asn`,`route`,`desc`,`alias`,`hostname`,`region`,`latitude`,`longitude`,`is_src`,`is_hop`,`is_dest`) VALUES(" .
								   "'" . $m7p_ipref{ip} . "', " .
								   "'" . $m7p_ipref_asn . "', " .
								   "'" . $m7p_ipref_route . "', " .
								   "'" . $m7p_ipref_desc . "', " .
								   "'" . $m7p_ipref{alias} . "', " .
								   "'" . $m7p_ipref_hostname . "', " . 
								   "'" . $m7p_ipref_region . "', " .
								   "'" . $m7p_ipref_lat . "', " .
								   "'" . $m7p_ipref_lon . "', " .
								   "'" . $m7p_ipref_type->{src} . "', " .
								   "'" . $m7p_ipref_type->{hop} . "', " .
								   "'" . $m7p_ipref_type->{dest} . "')";
			$m7p->db->do($m7p_ipref_update) or $m7p->log->warn('Failed to create IP reference database entry for: ' . $m7p_ipref{ip});
		}
	} else {
		$m7p->log->warn('Invalid IP address - failed to add to reference table: ' . $m7p_ipref{ip});
	}
}

# Initialize Plan Database Entries \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub initPlanDB {
	my $m7p = shift;
	my $m7p_plan_types  = join(',', @{$m7p->{_test_types}});
	my $m7p_plan_check	= $m7p->db->selectcol_arrayref("SELECT * FROM plans WHERE plan_id='" . $m7p->plan_id . "'");
	if (@$m7p_plan_check) {
		$m7p->log->info('Updating database entry for test plan: ID=' . $m7p->plan_id . ', Runtime=' . $m7p->runtime);
		my $m7p_plan_update = "UPDATE `" . $m7p->config->get('db_name') . "`.`plans` SET last_run='" . $m7p->runtime . "', run_count=run_count+1 WHERE plan_id='" . $m7p->plan_id . "'";
		$m7p->db->do($m7p_plan_update)
			or $m7p->log->logdie('Failed to update database entry');
	} else {
		$m7p->log->info('Creating database entry for test plan: ID=' . $m7p->plan_id . ', Runtime=' . $m7p->runtime);
		my $m7p_plan_create = "INSERT INTO `" . $m7p->config->get('db_name') . "`.`plans`(" .
							 "`plan_id`, `category`, `types`, `desc`, `first_run`, `last_run`, `run_count`) VALUES(" . 
						     "'" . $m7p->plan_id . "','net','" . $m7p_plan_types . "','" . $m7p->plan_desc . "','" . $m7p->runtime . "','" . $m7p->runtime . "', 1)";
		$m7p->db->do($m7p_plan_create)
			or $m7p->log->logdie('Failed to create database entry');
	}
	
	# Add network test destination IPs
	my $m7p_plan_cat = $m7p->plan_cat . "";
	if ($m7p_plan_cat eq 'net') {
		for my $m7p_host_tree ($m7p->plan_xtree->findnodes('plan/params/hosts/host')) {
			my $m7p_host_alias  = $m7p_host_tree->findvalue('@name');
			my $m7p_host_ip		= $m7p->plan_xtree->findvalue('plan/params/hosts/host[@name="' . $m7p_host_alias . '"]');
			
		}
	}
}

# Create Host Results Table \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub createHostTable {
	use feature 'switch';
	my $m7p = shift;
	my ($m7p_test_type) = @_;
	$m7p->log->info('Creating host test results table: "' . $m7p->test_host->{name} . '_' . $m7p->plan_cat . '_' . $m7p_test_type . '"');
	$m7p_test_type .= "";
	given ($m7p_test_type) {
		when ('stress') {
			$m7p->db->do("
        		CREATE TABLE IF NOT EXISTS " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . '_' . $m7p->plan_cat . '_' . $m7p_test_type . "(
            		id              INT NOT NULL AUTO_INCREMENT,
            		plan_id			INT NOT NULL,
                	source_ip       VARCHAR(15) NOT NULL,
                	run_time        DATETIME NOT NULL,
                	nameserver		VARCHAR(35) NOT NULL,
                	hosts			INT NOT NULL,
                	thread			INT NOT NULL,
                	samples			INT NOT NULL,
                	avg_time		VARCHAR(5) NOT NULL,
                	avg_fails		INT NOT NULL,
                	modified        TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP,
                	PRIMARY KEY(id)
            	);
        	");
		}
		when ('query') {
			$m7p->db->do("
        		CREATE TABLE IF NOT EXISTS " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . '_' . $m7p->plan_cat . '_' . $m7p_test_type . "(
            		id              INT NOT NULL AUTO_INCREMENT,
            		plan_id			INT NOT NULL,
                	source_ip       VARCHAR(15) NOT NULL,
                	run_time        DATETIME NOT NULL,
                	nameserver		VARCHAR(35) NOT NULL,
                	hostname		VARCHAR(35) NOT NULL,
                	fwd				VARCHAR(15) NOT NULL,
                	rev				VARCHAR(35) NOT NULL,
                	soa				VARCHAR(35) NOT NULL,
                	ns				VARCHAR(35) NOT NULL,
                	mx				VARCHAR(35) NOT NULL,
                	modified        TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP,
                	PRIMARY KEY(id)
            	);
        	");
		}
		when ('ping') {
			$m7p->db->do("
        		CREATE TABLE IF NOT EXISTS " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . '_' . $m7p->plan_cat . '_' . $m7p_test_type . "(
            		id              INT NOT NULL AUTO_INCREMENT,
            		plan_id			INT NOT NULL,
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
		} 
		when ('traceroute') {
			$m7p->db->do("
        		CREATE TABLE IF NOT EXISTS " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . '_' . $m7p->plan_cat . '_' . $m7p_test_type . "(
            		id              INT NOT NULL AUTO_INCREMENT,
            		plan_id			INT NOT NULL,
            		source_ip       VARCHAR(15) NOT NULL,
           			dest_ip         VARCHAR(15) NOT NULL,
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
		}
		when ('mtr') {
			$m7p->db->do("
				CREATE TABLE IF NOT EXISTS " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . '_' . $m7p->plan_cat . '_' . $m7p_test_type . "(
            		id              INT NOT NULL AUTO_INCREMENT,
            		plan_id			INT NOT NULL,
                	source_ip       VARCHAR(15) NOT NULL,
                	dest_ip         VARCHAR(15) NOT NULL,
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
		}
	}
}

# Get XML Element Text \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub getXMLText {
	my $m7p = shift;
	my ($m7p_xpath) = @_;
	my $m7p_xml_str = ${$m7p->results_xpath->getNodeText($m7p_xpath)};
	return $m7p_xml_str;
}

# Set XML Source \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub setXMLResults {
	my $m7p = shift;
	my ($m7p_results_file) = @_;
	$m7p->{_results_xtree}	= $m7p->libxml->parse_file($m7p_results_file);
    $m7p->{_results_xpath}	= XML::XPath->new(filename => $m7p_results_file);
}

# Set Test Host Properties \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub setTestHost {
	my $m7p = shift;
	my ($m7p_test_host) = @_;
	$m7p->test_host->{name}   = $m7p_test_host ;
    $m7p->test_host->{ip}     = $m7p->getXMLText('plan/host/@ip');
    
    # Add the IP reference
    $m7p->addIPRef(
		'ip'     => $m7p->test_host->{ip},
		'alias'	 => $m7p->test_host->{name},
		'is_src' => 1
	); 
    
    # Set the database friendly host name
    $m7p->test_host->{name} =~ s/-/_/g;
}

# Load XML Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub loadXMLResults {
	use feature 'switch';
	my $m7p = shift;
	my ($m7p_test_id, $m7p_test_type) = @_;
	$m7p->log->info('Loading XML test results: ID=' . $m7p_test_id . ', Type=' . $m7p_test_type);
	$m7p_test_type .= "";
	given ($m7p_test_type) {
		when ('stress') {
			my $m7p_nsstress_ns			= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/@nameserver');
			my $m7p_nsstress_samples	= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/@samples');
			my $m7p_nsstress_host_count = $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/hosts/@count');
			
			# Initialize the MySQL insert array
			my @m7p_nsstress_sql;
			
			# Process the thread definitions
            for my $m7p_nsstress_thread_tree ($m7p->results_xtree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/threads/thread')) {
            	my $m7p_nsstress_thread	= $m7p_nsstress_thread_tree->findvalue('@number');
            	my $m7p_nsstress_thread_avg_fails	= $m7p_nsstress_thread_tree->findvalue('average/@fails');
            	my $m7p_nsstress_thread_avg_time	= $m7p_nsstress_thread_tree->findvalue('average/@time');
            	
            	 # Define the SQL insert string
                my $m7p_nsstress_sql_string = "('" . $m7p->plan_id . "'" .
                	",'" . $m7p->test_host->{ip} . "'" .
                    ",'" . $m7p->runtime . "'" .
                    ",'" . $m7p_nsstress_ns . "'" .
                    ",'" . $m7p_nsstress_host_count . "'" .
                    ",'" . $m7p_nsstress_thread . "'" .
                    ",'" . $m7p_nsstress_samples . "'" .
                    ",'" . $m7p_nsstress_thread_avg_time . "'" .
                    ",'" . $m7p_nsstress_thread_avg_fails . "')";
                        
				# Append the string to the array
                push (@m7p_nsstress_sql, $m7p_nsstress_sql_string);  
            }
            
            # Flatten the nsstress SQL array and prepare the query string
            my $m7p_nsstress_sql_values	= join(", ", @m7p_nsstress_sql);
            my $m7p_nsstress_sql_query	= "INSERT INTO " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . "_dns_stress(" . 
                    				      "plan_id, source_ip, " . 
                    				      "run_time, nameserver, hosts, thread, samples, avg_time, avg_fails) " .
                    					  "VALUES " . $m7p_nsstress_sql_values . ";";
                    
            # Create the table rows for the nsstress test
            $m7p->db->do($m7p_nsstress_sql_query);
			
		}
		when ('query') {
			my $m7p_nsquery_ns		= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/@nameserver');
			
			# Initialize the MySQL insert array
			my @m7p_nsquery_sql;
			
			# Process the host definitions
            for my $m7p_nsquery_host_tree ($m7p->results_xtree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/hosts/host')) {
            	my $m7p_nsquery_host	= $m7p_nsquery_host_tree->findvalue('@name');
            	
            	# Get the DNS resolutions
            	my $m7p_nsquery_host_fwd	= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/hosts/host[@name="' . $m7p_nsquery_host . '"]/fwd');
            	my $m7p_nsquery_host_rev	= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/hosts/host[@name="' . $m7p_nsquery_host . '"]/rev');
            	my $m7p_nsquery_host_soa	= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/hosts/host[@name="' . $m7p_nsquery_host . '"]/soa');
            	my $m7p_nsquery_host_mx		= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/hosts/host[@name="' . $m7p_nsquery_host . '"]/mx');
            	my $m7p_nsquery_host_ns		= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/hosts/host[@name="' . $m7p_nsquery_host . '"]/ns');
            	
            	 # Define the SQL insert string
                my $m7p_nsquery_sql_string = "('" . $m7p->plan_id . "'" .
                	",'" . $m7p->test_host->{ip} . "'" .
                    ",'" . $m7p->runtime . "'" .
                    ",'" . $m7p_nsquery_ns . "'" .
                    ",'" . $m7p_nsquery_host . "'" .
                    ",'" . $m7p_nsquery_host_fwd . "'" .
                    ",'" . $m7p_nsquery_host_rev . "'" .
                    ",'" . $m7p_nsquery_host_soa . "'" .
                    ",'" . $m7p_nsquery_host_ns . "'" .
                    ",'" . $m7p_nsquery_host_mx . "')";
                        
				# Append the string to the array
                push (@m7p_nsquery_sql, $m7p_nsquery_sql_string);   
            }
            
            # Flatten the nsquery SQL array and prepare the query string
            my $m7p_nsquery_sql_values	= join(", ", @m7p_nsquery_sql);
            my $m7p_nsquery_sql_query	= "INSERT INTO " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . "_dns_query(" . 
                    				      "plan_id, source_ip, " . 
                    				      "run_time, nameserver, hostname, fwd, rev, soa, ns, mx) " .
                    					  "VALUES " . $m7p_nsquery_sql_values . ";";
                    
            # Create the table rows for the nsquery test
            $m7p->db->do($m7p_nsquery_sql_query);
			
		}
		when ('ping') {
			
			# Initialize the MySQL insert array
			my @m7p_ping_sql;

            # Process the host definitions
            for my $m7p_ping_host_name_tree ($m7p->results_xtree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host')) {
            	my $m7p_ping_host		= $m7p_ping_host_name_tree->findvalue('@name');

                # Get the ping statistics
                my $m7p_ping_ip			= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/@ip');
                my $m7p_ping_pkt_loss 	= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/pktLoss');
                my $m7p_ping_min_time 	= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/minTime');
                my $m7p_ping_avg_time 	= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/avgTime');
                my $m7p_ping_max_time 	= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/maxTime');
                my $m7p_ping_avg_dev  	= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_ping_host . '"]/avgDev');
                        
                # Add the IP reference
                $m7p->addIPRef(
					'ip'      => $m7p_ping_ip,
					'alias'   => $m7p_ping_host,
					'is_dest' => 1
				); 
                       
                # Define the SQL insert string
                my $m7p_ping_sql_string = "('" . $m7p->plan_id . "'" .
                	",'" . $m7p->test_host->{ip} . "'" .
                    ",'" . $m7p_ping_ip . "'" .
                    ",'" . $m7p->runtime . "'" .
                    ",'" . $m7p_ping_pkt_loss . "'" .
                    ",'" . $m7p_ping_min_time . "'" .
                    ",'" . $m7p_ping_avg_time . "'" .
                    ",'" . $m7p_ping_max_time . "'" .
                    ",'" . $m7p_ping_avg_dev . "')";
                        
				# Append the string to the array
                push (@m7p_ping_sql, $m7p_ping_sql_string);      
            }
                    
            # Flatten the ping SQL array and prepare the query string
            my $m7p_ping_sql_values		= join(", ", @m7p_ping_sql);
            my $m7p_ping_sql_query		= "INSERT INTO " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . "_net_ping(" . 
                    				      "plan_id, source_ip, " . 
                    				      "dest_ip, run_time, pkt_loss, min_time, avg_time, max_time, avg_dev) " .
                    					  "VALUES " . $m7p_ping_sql_values . ";";
                    
            # Create the table rows for the ping test
            $m7p->db->do($m7p_ping_sql_query);
		}
		when ('traceroute') {
			
			# Initialize the MySQL insert array
			my @m7p_troute_sql;

            # Process the host definitions
            for my $m7p_troute_host_name_tree ($m7p->results_xtree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host')) {
            	my $m7p_troute_host			= $m7p_troute_host_name_tree->findvalue('@name');
                my $m7p_troute_dest_ip		= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/@ip');
                    
                # Add the IP reference
                $m7p->addIPRef(
					'ip'      => $m7p_troute_dest_ip,
					'alias'   => $m7p_troute_host,
					'is_dest' => 1
				); 
                    	
                # Process the hop definitions
                for my $m7p_troute_hops_tree ($m7p->results_xtree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/hops/hop')) {
                        	
                	# Get the statistics for the traceroute hop
                    my $m7p_troute_hop    		= $m7p_troute_hops_tree->findvalue('@number');
                    my $m7p_troute_ip     		= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/hops/hop[@number="' . $m7p_troute_hop . '"]/ip');
                    my $m7p_troute_try    		= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/hops/hop[@number="' . $m7p_troute_hop . '"]/try');
                    my $m7p_troute_time   		= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_troute_host . '"]/hops/hop[@number="' . $m7p_troute_hop . '"]/time');
                    my $m7p_troute_ip_lat		= "";
                    my $m7p_troute_ip_lon		= "";
                        	
                    $m7p_troute_ip = $m7p_troute_ip . "";
                    # Get the hop IP geolocation and make sure the IP address is valid
                    if (is_ipv4($m7p_troute_ip) && !is_unroutable_ipv4($m7p_troute_ip) && !is_private_ipv4($m7p_troute_ip)) {
                    	my $m7p_troute_ip_geo	= $m7p->geoip->record_by_addr($m7p_troute_ip);
                    	$m7p_troute_ip_lat		= $m7p_troute_ip_geo->latitude;
                       	$m7p_troute_ip_lon		= $m7p_troute_ip_geo->longitude;
                    } else {
                    	$m7p_troute_ip_lat		= "";
                    	$m7p_troute_ip_lon		= "";
                    }
                        
                    # Add the IP reference
                	$m7p->addIPRef(
						'ip'     => $m7p_troute_ip,
						'is_hop' => 1
					); 
                        	
                    # Define the SQL insert string
	                my $m7p_troute_sql_string = "('" . $m7p->plan_id . "'" .
	                	",'" . $m7p->test_host->{ip} . "'" .
	                    ",'" . $m7p_troute_dest_ip . "'" .
	                    ",'" . $m7p->runtime . "'" .
	                    ",'" . $m7p_troute_hop . "'" .
	                    ",'" . $m7p_troute_try . "'" .
	                    ",'" . $m7p_troute_ip . "'" .
	                    ",'" . $m7p_troute_ip_lat . "'" .
	                    ",'" . $m7p_troute_ip_lon . "'" .
	                    ",'" . $m7p_troute_time . "')";
	                        
	                # Append the string to the array
	                push (@m7p_troute_sql, $m7p_troute_sql_string)
                } 
            }
                    
            # Flatten the traceroute SQL array and prepare the query string
            my $m7p_troute_sql_values		= join(", ", @m7p_troute_sql);
            my $m7p_troute_sql_query		= "INSERT INTO " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . "_net_traceroute(" . 
                    						  "plan_id, source_ip, " . 
                    						  "dest_ip, run_time, hop, try, ip, ip_lat, ip_lon, time) " .
                    						  "VALUES " . $m7p_troute_sql_values . ";";
                    
            # Create the table rows for the traceroute test
        	$m7p->db->do($m7p_troute_sql_query);
		}
		when ('mtr') {
			
			# Initialize the MySQL insert array
            my @m7p_mtr_sql;			
                		
            # Process the host definitions
            for my $m7p_mtr_host_name_tree ($m7p->results_xtree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host')) {
            	my $m7p_mtr_host			= $m7p_mtr_host_name_tree->findvalue('@name');
                my $m7p_mtr_dest_ip			= $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/@ip');
                    
                # Add the IP reference
                $m7p->addIPRef(
					'ip'      => $m7p_mtr_dest_ip,
					'alias'   => $m7p_mtr_host,
					'is_dest' => 1
				); 
                    	
                # Process the hop definitions
                for my $m7p_mtr_hops_tree ($m7p->results_xtree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop')) {
                        	
                	# Get the statistics for the mtr hop
                    my $m7p_mtr_hop			= $m7p_mtr_hops_tree->findvalue('@number');
                    my $m7p_mtr_ip_list		= "";
                    my $m7p_mtr_ip_geolist	= "";
                    my $m7p_mtr_ip_lat		= "";
                    my $m7p_mtr_ip_lon		= "";
                    for my $m7p_mtr_ip_tree ($m7p->results_xtree->findnodes('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/ips')) {
                    	my $m7p_mtr_hop_ip =  $m7p_mtr_ip_tree->findvalue('ip');
                    	$m7p_mtr_hop_ip .= "";
                            
                        # Add the IP reference
                		$m7p->addIPRef(
							'ip'     => $m7p_mtr_hop_ip,
							'is_hop' => 1
						); 
                            	
                        # Get the hop IP geolocation
	                    if (is_ipv4($m7p_mtr_hop_ip) && !is_unroutable_ipv4($m7p_mtr_hop_ip) && !is_private_ipv4($m7p_mtr_hop_ip)) {
	                    	my $m7p_mtr_ip_geo	= $m7p->geoip->record_by_addr($m7p_mtr_hop_ip);
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
                    my $m7p_mtr_pkt_loss = $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/pktLoss');
                    my $m7p_mtr_min_time = $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/minTime');
                    my $m7p_mtr_avg_time = $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/avgTime');
                    my $m7p_mtr_max_time = $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/maxTime');
                    my $m7p_mtr_avg_dev  = $m7p->getXMLText('plan/test[@id="' . $m7p_test_id . '"]/host[@name="' . $m7p_mtr_host . '"]/hops/hop[@number="' . $m7p_mtr_hop . '"]/avgDev');
                        
                    # Define the SQL insert string
	                my $m7p_mtr_sql_string = "('" . $m7p->plan_id . "'" .
	                	",'" . $m7p->test_host->{ip} . "'" .
	                    ",'" . $m7p_mtr_dest_ip . "'" .
	                    ",'" . $m7p->runtime . "'" .
	                    ",'" . $m7p_mtr_hop . "'" .
	                    ",'" . $m7p_mtr_ip_list . "'" .
	                    ",'" . $m7p_mtr_ip_geolist . "'" .
	                    ",'" . $m7p_mtr_pkt_loss . "'" .
	                    ",'" . $m7p_mtr_min_time . "'" .
	                    ",'" . $m7p_mtr_avg_time . "'" .
	                    ",'" . $m7p_mtr_max_time . "'" .
	                    ",'" . $m7p_mtr_avg_dev . "')";
	                        
	                # Append the string to the array
	                push (@m7p_mtr_sql, $m7p_mtr_sql_string)
                } 
            }
                    
            # Flatten the mtr SQL array and prepare the query
            my $m7p_mtr_sql_values	= join(", ", @m7p_mtr_sql);
            my $m7p_mtr_sql_query	= "INSERT INTO " . $m7p->config->get('db_name') . "." . $m7p->test_host->{name} . "_net_mtr(" . 
                    				  "plan_id, source_ip, " . 
                    				  "dest_ip, run_time, hop, ips, ips_gps, pkt_loss, min_time, avg_time, max_time, avg_dev) " .
                    				  "VALUES " . $m7p_mtr_sql_values . ";"; 
                    
            # Create the table rows for the mtr test
            $m7p->db->do($m7p_mtr_sql_query);
		}
	}
}

1;