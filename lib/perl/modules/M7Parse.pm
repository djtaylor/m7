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
	use lib $ENV{HOME} . '/lib/perl/modules';
	use M7Config;
}

# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
# Module Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #

# Package Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub new {
	my $m7p = {
		_libxml			=> XML::LibXML->new(),
		_xpath			=> undef,
		_geoip			=> undef,
		_plan_id		=> undef,
		_plan_desc		=> undef,
		_plan_cat		=> undef,
		_plan_file		=> undef,
		_runtime		=> undef,
		_xml_dir		=> undef,
		_xml_files		=> undef,
		_db_name		=> $m7_db{name},
		_db_host		=> $m7_db{host},
		_db_port		=> $m7_db{port},
		_db_user		=> $m7_db{user},
		_db_pass		=> $m7_db{pass},
		_db				=> undef,
		_log			=> undef
	};
	&logInit();
	&dbInit();
	&geoIPInit();
	bless $m7p, M7Parse;
	return $m7p;
}

# Subroutine Shortcuts \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub libxml     { return shift->{_libxml};     }
sub plan_xpath { return shift->{_plan_xpath}; }
sub plan_id    { return shift->{_plan_id};    }
sub plan_desc  { return shift->{_plan_desc};  }
sub plan_cat   { return shift->{_plan_cat};   }
sub plan_file  { return shift->{_plan_file};  }
sub runtime    { return shift->{_runtime};    }
sub xml_dir    { return shift->{_xml_dir};    }
sub xml_files  { return shift->{_xml_files};  }
sub geoip      { return shift->{_geoip};      }
sub db_name    { return shift->{_db_name};    }
sub db_host    { return shift->{_db_host};    }
sub db_port    { return shift->{_db_port};    }
sub db_user    { return shift->{_db_user};    }
sub db_pass    { return shift->{_db_pass};    }
sub db 	       { return shift->{_db};         }
sub log		   { return shift->{_log};		  }

# Initialize Logger \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub logInit {
	my $m7p = shift;
	
	# Read the log configuration into memory
	my $m7p_log_conf = read_file($m7p_log{conf});
	$m7p_log_conf =~ s/__LOGFILE__/$m7p_log{file}/;
	
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
	my (%m7_myslq_db_args) = @_;
	my $m7p_db_dsn = "dbi:mysql:" . $m7p->db_name . ":" . $m7p->db_host . ":" . $m7p->db_port;
	$m7p->{_db} = shift;
	my $m7p_dbh = DBI->connect($m7p_db_dsn, $m7p->db_user, $m7p->db_pass, {
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
	$m7p->{_geoip} = Geo::IP->open($m7_geo{db}, GEOIP_STANDARD)
		or $m7p->log->logdie('Failed to initialize GeoIP object. Missing GeoIP database? : "' . $m7_geo{db} . '"');
	return $m7->{_geoip};
}

# Set Plan Parameters \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub setPlan {
	my $m7p = shift;
	my ($m7p_plan_id, $m7p_plan_runtime) = @_;
	
	# Make sure all arguments are defined
	if (not defined $m7p_plan_id || not defined $m7p_plan_runtime) {
		$m7p->log->logdie('Must specify both plan ID and runtime to parse XML results');
	}
	
	# Begin setting module variables
	$m7p->{_plan_id}	= $m7p_plan_id;
	$m7p->{_plan_file}	= $ENV{"HOME"} . "/plans/" . $m7p_plan_id . ".xml"
	$m7p->{_xml_dir}    = $ENV{"HOME"} . "/results/" . $m7p_plan_id . "/";
	
	# Load all the result files into an array
	opendir(XML_DIR, $m7p->xml_dir)
		or $m7p->log->logdie('Could not open XML results directory: '. $m7p->xml_dir);
	while (my $m7p_xml_file = readdir(XML_DIR)) {
		next if (substr($m7p_xml_file,0,1) eq ".");
    	push (@{$m7p->{_xml_files}}, $m7p->xml_dir . $m7p_xml_file);
	}
	closedir(XML_DIR);
	
	# Set the XPath, description, category, and runtime
	$m7p->{_plan_xpath}	= XML::XPath->new(filename => $m7p->plan_file);
	$m7p->{_plan_desc}	= $m7p->plan_xpath->findnodes('plan/desc');
	$m7p->{_plan_cat}	= $m7p->plan_xpath->findnodes('plan/params/category');
	$m7p->{_runtime}	= $m7p_plan_runtime;
}

# Initialize Plan Database Entry \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub initPlanDB {
	my $m7p_plan_check	= $m7p->db->selectcol_arrayref("SELECT * FROM plans WHERE plan_id='" . $m7p->plan_id . "'");
	if (@$m7p_plan_check) {
		$m7p->log->info('Updating database entry for test plan: ID=' . $m7p->plan_id . ', Runtime=' . $m7p->runtime);
		my $m7p_plan_update = "UPDATE `" . $m7p->db_name . "`.`plans` SET last_run='" . $m7p->runtime . "', run_count=run_count+1 WHERE plan_id='" . $m7p->plan_id . "'";
		$m7p->db->do($m7_plan_update)
			or $m7p->log->logdie('Failed to update database entry');
	} else {
		$m7p->log->info('Creating database entry for test plan: ID=' . $m7p->plan_id . ', Runtime=' . $m7p->runtime);
		my $m7p_plan_create = "INSERT INTO `" . $m7p->db_name . "`.`plans`(" .
							 "`plan_id`, `type`, `desc`, `first_run`, `last_run`, `run_count`) VALUES(" . 
						     "'" . $m7p->plan_id . "','net','" . $m7p->plan_desc . "','" . $m7p->runtime . "','" . $m7p->runtime . "', 1)";
		$m7p->db->do($m7p_plan_create)
			or $m7p->log->logdie('Failed to create database entry');
	}
}

# Create Host Results Table \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub createHostTable {
	use feature 'switch';
	my $m7p = shift;
	my ($m7p_table_type, $m7p_table_host) = @_;
	$m7p->log->info('Creating host test results table: "' . $m7p_table_host . '_' . $m7p_table_type . '"');
	given ($m7p_table_type) {
		when ('net_ping') {
			$m7p->db->do("
        		CREATE TABLE IF NOT EXISTS " . $m7p->db_name . "." . $m7p_table_host . "_" . $m7p_table_type . "(
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
		} 
		when ('net_traceroute') {
			$m7p->db->do("
        		CREATE TABLE IF NOT EXISTS " . $m7p->db_name . "." . $m7p_table_host . "_" . $m7p_table_type . "(
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
		}
		when ('net-mtr') {
			$m7p->db->do("
				CREATE TABLE IF NOT EXISTS " . $m7p->db_name . "." . $m7p_table_host . "_" . $m7p_table_type . "(
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
		}
	}
}