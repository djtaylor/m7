#!/usr/bin/perl

# Package Name \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
package M7;

# Module Dependencies \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
BEGIN {
	use strict;
	use Log::Log4perl;
	use File::Slurp;
	use File::Path;
	use File::Copy;
	use DBI;
	use DBD::mysql;
	use Sys::Hostname;
	use XML::LibXML;
	use XML::XPath;
	use XML::Simple;
	use XML::Merge;
	use JSON;
	use DateTime;
	use Net::OpenSSH;
	use Net::Nslookup;
	use File::Fetch;
	use Time::HiRes;
	use List::Util qw(sum);
	use lib $ENV{HOME} . '/lib/perl/modules';
	use M7Config;
	use M7Socket;
}

# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
# Module Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #

# Package Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub new {
	my $m7 = {
		_config			=> M7Config->new(),
		_lib_xml		=> XML::LibXML->new(),
		_socket			=> M7Socket->new(),
		_log			=> undef,
		_db				=> undef,
		_dir			=> undef,
		_is_dir			=> undef,
		_workers		=> undef,
		_nodes			=> undef,
		_node			=> undef,
		_local			=> undef,
		_wm_forks		=> undef,
		_tm_forks		=> undef,
		_plan_file		=> undef,
		_plan_xpath		=> undef,
		_plan_xtree		=> undef,
		_plan_id		=> undef,
		_plan_runtime	=> undef,
		_plan_cat		=> undef,
		_test_ids		=> undef,
		_test_threads   => undef,
		_test_id		=> undef,
		_test_thread    => undef,
		_test_samples   => undef,
		_test_proto		=> undef,
		_test_host		=> undef,
		_test_type		=> undef,
		_test_results	=> undef,
		_lock_dir		=> undef,
		_out_dir		=> undef,
	};
	bless $m7, M7;
	$m7->logInit();
	$m7->dbInit();
	$m7->checkDirector();
	return $m7;
}

# Subroutine Shortcuts \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub config		 { return shift->{_config};       }
sub lib_xml		 { return shift->{_lib_xml};      }
sub socket		 { return shift->{_socket};       }
sub log			 { return shift->{_log};		  }
sub db			 { return shift->{_db}; 		  }
sub dir			 { return shift->{_dir};	 	  }
sub is_dir	     { return shift->{_is_dir};       }
sub workers      { return shift->{_workers};      }
sub nodes		 { return shift->{_nodes};        }
sub node		 { return shift->{_node};         }
sub local		 { return shift->{_local}[0];	  }
sub wm_forks	 { return shift->{_wm_forks}; 	  }
sub tm_forks     { return shift->{_tm_forks};     }
sub plan_file	 { return shift->{_plan_file}; 	  }
sub plan_xpath	 { return shift->{_plan_xpath};   }
sub plan_xtree	 { return shift->{_plan_xtree};   }
sub plan_id		 { return shift->{_plan_id}; 	  }
sub plan_desc	 { return shift->{_plan_desc};    }
sub plan_runtime { return shift->{_plan_runtime}; }
sub plan_cat	 { return shift->{_plan_cat};     }
sub test_ids	 { return shift->{_test_ids};     }
sub test_threads { return shift->{_test_threads}; }
sub test_id		 { return shift->{_test_id};      }
sub test_thread  { return shift->{_test_thread};  }
sub test_samples { return shift->{_test_samples}; }
sub test_proto   { return shift->{_test_proto};   }
sub test_host    { return shift->{_test_host};    }
sub test_hosts   { return shift->{_test_hosts};   }
sub test_type	 { return shift->{_test_type};    }
sub test_results { return shift->{_test_results}; }
sub lock_dir	 { return shift->{_lock_dir};     }
sub out_dir		 { return shift->{_out_dir};      }

# Initialize Logger \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub logInit {
	my $m7 = shift;
	my ($m7_alt_log) = @_;
	
	# Read the log configuration into memory
	my $m7_log_file;
	if ($m7_alt_log) {
		$m7_log_file = $m7_alt_log;
	} else {
		$m7_log_file = $m7->config->get('log_file_m7');	
	}
	my $m7_log_conf = read_file($m7->config->get('log_conf_m7'));
	$m7_log_conf =~ s/__LOGFILE__/$m7_log_file/;
	
	# Initialize the logger
	Log::Log4perl::init(\$m7_log_conf)
		or die 'Failed to initialize logger!';
	
	# Build the logger object
	$m7->{_log} = Log::Log4perl->get_logger;
	return $m7->{_log};
}

# Initialze Database Object \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub dbInit {
	my $m7 = shift;
	$m7->log->info('Initializing director database connection');
	my $m7_db_dsn = "dbi:mysql:" . $m7->config->get('db_name') . ":" . $m7->config->get('db_host') . ":" . $m7->config->get('db_port');
	$m7->{_db} = shift;
	my $m7_dbh = DBI->connect($m7_db_dsn, $m7->config->get('db_user'), $m7->config->get('db_pass'), {
		PrintError => 0,
		RaiseError => 1
	}) or $m7->log->logdie("Failed to connect to database: '" . DBI->errstr . "'");
	$m7_dbh->{mysql_auto_reconnect} = 1;
	$m7->{_db} = $m7_dbh;
	return $m7->{_db};
}

# Get Node Properties \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub getNode {
	my $m7 = shift;
	my ($m7_node_name, $m7_node_property) = @_;
	for(@{$m7->nodes}) {
		my %m7_host	= %{$_};
		if ($m7_host{name} = $m7_node_name) {
			return $m7_host{$m7_node_property};
		}
	}
}
sub nodeExists {
	my $m7 = shift;
	my ($m7_node_name) = @_;
	for(@{$m7->nodes}) {
		my %m7_host	= %{$_};
		if ($m7_host{name} = $m7_node_name) {
			return 1;
		}
	}
	return undef;
}

# Director Check \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub checkDirector {
	my $m7 = shift;
	my $m7_host = hostname;
	
	# Prepare the director node query
	$m7->log->info('Constructing director node object');
	my $m7_dir_query = "SELECT * FROM nodes WHERE type='director'";
	my $m7_dir_qh 	 = $m7->db->prepare($m7_dir_query)
		or $m7->log->logdie("Failed to prepare MySQL statement: '" . DBI->errstr . "'");
	
	# Execute the director node query
	$m7_dir_qh->execute()
		or $m7->log->logdie("Failed to execute MySQL statement: '" . DBI->errstr . "'");
	$m7->{_dir} = $m7_dir_qh->fetchrow_hashref();
	
	# Prepare the worker nodes query
	$m7->log->info('Constructing worker nodes object');
	my $m7_wrk_query = "SELECT * FROM nodes WHERE type='worker'";
	my $m7_wrk_qh	 = $m7->db->prepare($m7_wrk_query)
		or $m7->log->logdie("Failed to prepare MySQL statement: '" . DBI->errstr . "'");
	
	# Execute the worker nodes query
	$m7_wrk_qh->execute()
		or $m7->log->logdie("failed to execute MySQL statement: '" . DBI->errstr . "'");
	while ($m7_wrk_row = $m7_wrk_qh->fetchrow_hashref()) {
		push(@{$m7->{_workers}}, $m7_wrk_row);
	}
	
	# Prepare the local node query
	$m7->log->info('Constructing local node object');
	my $m7_loc_query = "SELECT * FROM nodes WHERE name='" . $m7_host . "'";
	my $m7_loc_qh	 = $m7->db->prepare($m7_loc_query)
		or $m7->log->logdie("Failed to prepare MySQL statement: '" . DBI->errstr . "'");
	
	# Execute the local node query
	$m7_loc_qh->execute()
		or $m7->log->logdie("failed to execute MySQL statement: '" . DBI->errstr . "'");
	while ($m7_loc_row = $m7_loc_qh->fetchrow_hashref()) {
		push(@{$m7->{_local}}, $m7_loc_row);
	}
	
	# Prepare the all nodes query
	$m7->log->info('Constructing all nodes object');
	my $m7_nodes_query = "SELECT * FROM nodes";
	my $m7_nodes_qh	   = $m7->db->prepare($m7_nodes_query)
		or $m7->log->logdie("Failed to prepare MySQL statement: '" . DBI->errstr . "'");
		
	# Execute the all nodes query
	$m7_nodes_qh->execute()
		or $m7->log->logdie("failed to execute MySQL statement: '" . DBI->errstr . "'");
	while ($m7_nodes_row = $m7_nodes_qh->fetchrow_hashref()) {
		push(@{$m7->{_nodes}}, $m7_nodes_row);
	}
	
	# Set the global director object value
	if($m7->dir->{name} eq $m7_host) {
		$m7->log->info('Current node ' . $m7_host . ' is the director node');
		$m7->{_is_dir} = 1;
	} else {
		$m7->log->info('Current node ' . $m7_host . ' is NOT the director node');
		$m7->{_is_dir} = undef;
	}
	return $m7->{_is_dir};
}

# Git Synchronization \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub gitSync {
	my $m7 = shift;
	my ($m7_git_branch) = @_;
	
	# Make sure a target branch is defined
	if (not defined($m7_git_branch)) {
		$m7->log->logdie('You must specify a target branch to run the Git sync command');
	}
	system('sh ' . $ENV{HOME} . '/lib/bash/gitsync.sh "' . $m7_git_branch . '"');
}

# Build Xpath Object \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub buildXpath {
	my $m7 = shift;
	my (%m7_xpath_args) = @_;
	$m7->{_plan_xpath} = XML::XPath->new(filename => $m7_xpath_args{file});
	return $m7->{_plan_xpath};
}

# Update Node Plan Run Status \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub updateNodeStatus {
	my $m7 = shift;
	my ($m7_status, $m7_node) = @_;
	my $m7_target_node;
	if (defined($m7_node)) {
		$m7_target_node = $m7_node;
	} else {
		$m7_target_node = $m7->local->{name};
	}
	
	# Check if the node status row exists
	my $m7_nsr_check = $m7->db->selectcol_arrayref("SELECT * FROM nodes_status WHERE name='" . $m7_target_node . "' AND plan_id='" . $m7->plan_id . "'");
	
	# Update the row if it exists
	if (@{$m7_nsr_check}) {
		
		# If setting to an active state
		if ($m7_status eq 'active') {
			$m7->log->info('Updating database entry node plan status: Node=' . $m7_target_node . ', ID=' . $m7->plan_id . ', Last Runtime=' . $m7->plan_runtime . ', Status=' . $m7_status);
			my $m7_nsr_update = "UPDATE `" . $m7->config->get('db_name') . "`.`nodes_status` SET last_run='" . $m7->plan_runtime . "', run_count=run_count+1, status='" . $m7_status . "' WHERE plan_id='" . $m7->plan_id . "' AND name='" . $m7_target_node . "'";
			$m7->db->do($m7_nsr_update)
				or $m7->log->logdie('Failed to update database entry');	
		} else {
			$m7->log->info('Updating database entry node plan status: Node=' . $m7_target_node . ', ID=' . $m7->plan_id . ', Status=' . $m7_status);
			my $m7_nsr_update = "UPDATE `" . $m7->config->get('db_name') . "`.`nodes_status` SET status='" . $m7_status . "' WHERE plan_id='" . $m7->plan_id . "' AND name='" . $m7_target_node . "'";
			$m7->db->do($m7_nsr_update)
				or $m7->log->logdie('Failed to update database entry');
		}
			
	# Create the row if it doesn't exist
	} else {
		$m7->log->info('Creating database entry node plan status: Node=' . $m7_target_node . ', ID=' . $m7->plan_id . ', Last Runtime=' . $m7->plan_runtime . ', Status=' . $m7_status);
		my $m7_nsr_create = "INSERT INTO `" . $m7->config->get('db_name') . "`.`nodes_status`(" .
							"`name`, `type`, `plan_id`, `status`, `last_run`, `run_count`) VALUES(" . 
						    "'" . $m7_target_node . "','" . $m7->local->{type} . "','" . $m7->plan_id . "','" . $m7_status . "','" . $m7->plan_runtime . "', 1)";
		$m7->db->do($m7_nsr_create)
			or $m7->log->logdie('Failed to create database entry');
	}
}

# Worker Lock \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub workerLock {
	my $m7 = shift;
	my $m7_worker_results = $ENV{HOME} . '/results/' . $m7->plan_id . '/' . $m7->node . '.xml';
	sleep 1 while not -e $m7_worker_results;
	$m7->log->info($$  . ': Worker results file received: ' . $m7_worker_results . ' - closing monitor');
	$m7->updateNodeStatus('idle');
	exit 1;
}

# DNS Tests \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub dnsStress {
	my $m7 = shift;
	
	# Set the log details and set the test base
	my $m7_log_details = 'category=' . $m7->plan_cat . ', id=' . $m7->test_id . ', type=' . $m7->test_type . ', thread=' . $m7->test_thread . ', samples=' . $m7->test_samples;
	my $m7_test_base   = $m7->out_dir . '/test-' . $m7->test_id . '/thread-' . $m7->test_thread;
	my $m7_host_count  = @{$m7->{_test_hosts}};
	mkpath($m7_test_base, 0, 0755);
	
	# Initialize the results hash
	my $m7_results = {
		'category' => $m7->plan_cat,
		'test'     => {
			'type'       => $m7->test_type,
			'id'	     => $m7->test_id,
			'nameserver' => $m7->test_host,
			'samples'	 => $m7->test_samples,
			'hosts'	     => {
				'count'	   => $m7_host_count,
				'host'	   => []
			},
			'threads'  => {
				'thread' => [{
					'number'  => $m7->test_thread,
					'samples' => {
						'sample' => []
					},
					'average' => {
						'time'	=> undef,
						'fails'	=> undef
					}
				}]
			}
		}
	};
	
	# Construct the list of lookup hostnames
	my $m7_host_key = 0;
	foreach(@{$m7->{_test_hosts}}) {
		$m7_results->{test}{hosts}{host}[$m7_host_key] = $_;
		$m7_host_key ++;
	}	
	
	# Initialize the samples averages array
	my @m7_time_avgs;
	my @m7_fail_avgs;
	
	# Run based on the number of samples
	my $m7_samples_count = 0;
	my $m7_key_count     = 0;
	while ($m7_samples_count < $m7->test_samples) {
		$m7_samples_count ++;
		my $m7_fail_count = 0;
		
		# Start the thread timer
		my $m7_nsl_start = [Time::HiRes::gettimeofday];
		foreach(@{$m7->{_test_hosts}}) {
			$m7_nslookup = nslookup(host => $_, server => $m7->test_host);
			if (not defined($m7_nslookup)) { $m7_fail_count ++; }
		}	
		
		# Calculcate the total lookup time
		my $m7_nsl_time_raw  = Time::HiRes::tv_interval($m7_nsl_start);
		my $m7_nsl_time		 = sprintf("%.2f", $m7_nsl_time_raw);
	
		# Append to averages array
		push(@m7_time_avgs, $m7_nsl_time);
		push(@m7_fail_avgs, $m7_fail_count);
	
		# Define the sample results hash block
		my $m7_sample_results = {
			'number' => $m7_samples_count,
			'time'	 => $m7_nsl_time,
			'fails'	 => $m7_fail_count
		};
		
		# Append to the hash
		$m7_results->{test}{threads}{thread}[0]{samples}{sample}[$m7_key_count] = $m7_sample_results;
		$m7_key_count ++;
	}
	
	# Calculate the averages
	$m7_time_avg_raw  = sum(@m7_time_avgs)/@m7_time_avgs;
	$m7_fail_avg_raw  = sum(@m7_fail_avgs)/@m7_fail_avgs;
	
	# Create the sample averages entries
	$m7_results->{test}{threads}{thread}[0]{average}{time}	= sprintf("%.2f", $m7_time_avg_raw);
	$m7_results->{test}{threads}{thread}[0]{average}{fails} = sprintf("%.2f", $m7_fail_avg_raw);
	
	# Dump the results hash to an XML file
	my $m7_xml_file    = $m7_test_base . '/results.xml';
	$m7->log->info($$ . ': Dumping results to XML file - ' . $m7_xml_file);
	
	# Convert the results hash to XML data and print to file
	my $m7_results_xml = XMLout($m7_results, RootName => 'plan');
	open(my $m7_xml_fh, '>', $m7_xml_file);
	print $m7_xml_fh $m7_results_xml;
	close($m7_xml_fh);
	
	# Test thread complete
	$m7->log->info($$ . ': Test run complete - ' . $m7_log_details);
	exit 1;
}
sub dnsQuery {
	my $m7 = shift;
	
	# Set the log details and set the test base
	my $m7_log_details = 'category=' . $m7->plan_cat . ', id=' . $m7->test_id . ', type=' . $m7->test_type;
	my $m7_test_base   = $m7->out_dir . '/test-' . $m7->test_id;
	mkpath($m7_test_base, 0, 0755);
	
	# Initialize the results hash
	my $m7_results = {
		'category' => $m7->plan_cat,
		'test'     => {
			'type'       => $m7->test_type,
			'id'	     => $m7->test_id,
			'nameserver' => $m7->test_host,
			'hosts'	     => {
				'host'	   => []
			}
		}
	};
	
	# Perform the DNS tests for each hostname
	my $m7_host_key = 0;
	foreach(@{$m7->{_test_hosts}}) {
		
		# Test 1: Forward lookup
		my $m7_nslookup_fwd;
		if ($m7->test_host eq 'auto') {
			$m7_nslookup_fwd = nslookup(host => $_);
		} else {
			$m7_nslookup_fwd = nslookup(host => $_, server => $m7->test_host);
		}
		$m7_nslookup_fwd = (defined($m7_nslookup_fwd) ? $m7_nslookup_fwd : '0.0.0.0');
		
		# Test 2: SOA lookup
		my $m7_nslookup_soa;
		if ($m7->test_host eq 'auto') {
			$m7_nslookup_soa = nslookup(host => $_, type => 'SOA');
			$m7_nslookup_soa =~ s/(^[\w\d\.]+)\s.*$/$1/g;
		} else {
			$m7_nslookup_soa = nslookup(host => $_, server => $m7->test_host, type => 'SOA');
			$m7_nslookup_soa =~ s/(^[\w\d\.]+)\s.*$/$1/g;
		}
		$m7_nslookup_soa = (defined($m7_nslookup_soa) ? $m7_nslookup_soa : 'unknown');
		
		# Test 3: Reverse lookup
		my $m7_nslookup_rev;
		if ($m7_nslookup_fwd ne '0.0.0.0') {
			if ($m7->test_host eq 'auto') {
				$m7_nslookup_rev = nslookup(host => $m7_nslookup_fwd, type => 'PTR');
			} else {
				$m7_nslookup_rev = nslookup(host => $m7_nslookup_fwd, server => $m7->test_host, type => 'PTR');
			}
			$m7_nslookup_rev = (defined($m7_nslookup_rev) ? $m7_nslookup_rev : 'unknown');
		} else {
			$m7_nslookup_rev = "unknown";
		}
		
		# Test 4: MX lookup
		my $m7_nslookup_mx;
		if ($m7_nslookup_fwd ne '0.0.0.0') {
			if ($m7->test_host eq 'auto') {
				$m7_nslookup_mx = nslookup(host => $_, type => 'MX');
			} else {
				$m7_nslookup_mx = nslookup(host => $_, server => $m7->test_host, type => 'MX');
			}
			$m7_nslookup_mx = (defined($m7_nslookup_mx) ? $m7_nslookup_mx : 'unknown');
		} else {
			$m7_nslookup_mx = "unknown";
		}
		
		# Test 5: NS lookup
		my $m7_nslookup_ns;
		if ($m7_nslookup_fwd ne '0.0.0.0') {
			if ($m7->test_host eq 'auto') {
				$m7_nslookup_ns = nslookup(host => $_, type => 'NS');
			} else {
				$m7_nslookup_ns = nslookup(host => $_, server => $m7->test_host, type => 'NS');
			}
			$m7_nslookup_ns = (defined($m7_nslookup_ns) ? $m7_nslookup_ns : 'unknown');
		} else {
			$m7_nslookup_ns = "unknown";
		}
		
		# Define the host results hash and append
		my $m7_host_results = {
			'name' => $_,
			'fwd'  => [$m7_nslookup_fwd],
			'rev'  => [$m7_nslookup_rev],
			'soa'  => [$m7_nslookup_soa],
			'mx'   => [$m7_nslookup_mx],
			'ns'   => [$m7_nslookup_ns]
		};
		$m7_results->{test}{hosts}{host}[$m7_host_key] = $m7_host_results;
		$m7_host_key ++;
	};
	
	# Dump the results hash to an XML file
	my $m7_xml_file    = $m7_test_base . '/results.xml';
	$m7->log->info($$ . ': Dumping results to XML file - ' . $m7_xml_file);
	
	# Convert the results hash to XML data and print to file
	my $m7_results_xml = XMLout($m7_results, RootName => 'plan');
	open(my $m7_xml_fh, '>', $m7_xml_file);
	print $m7_xml_fh $m7_results_xml;
	close($m7_xml_fh);
	
	# Test thread complete
	$m7->log->info($$ . ': Test run complete - ' . $m7_log_details);
	exit 1;
}

# Network Tests \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub netPing {
	my $m7 = shift;
	my $m7_ping_count = $m7->getXMLText('plan/params/test[@id="' . $m7->test_id . '"]/count');
	
	# Set the log details, test base, and output log
	my $m7_log_details = 'category=' . $m7->plan_cat . ', id=' . $m7->test_id . ', type=' . $m7->test_type . ', count=' . $m7_mtr_count;
	my $m7_test_base = $m7->out_dir . '/test-' . $m7->test_id;
	mkpath($m7_test_base, 0, 0755);
	
	# Initialize the results hash
	my $m7_results = {
		'category' => $m7->plan_cat,
		'test' => {
			'id'	=> $m7->test_id,
			'type'	=> $m7->test_type,
			'host'	=> []
		}
	};
	
	# Process all the network test hosts
	my $m7_ping_host_count = 0;
	foreach my $m7_net_host (keys %{$m7->{_test_hosts}}) {
		my $m7_net_ipaddr = $m7->test_hosts->{$m7_net_host};
		my $m7_test_log  = $m7_test_base . '/' . $m7_net_host . '.output.log';
		
		# Run the MTR test
		system('ping -c ' . $m7_ping_count . ' ' . $m7_net_ipaddr . ' >> ' . $m7_test_log);
		
		# Parse the log file
		open(PING_LOG, $m7_test_log);
		my ($pkt_loss, $min_time, $avg_time, $max_time, $avg_dev);
		while(<PING_LOG>) {
			if(/(\d+)%/) { ($pkt_loss) = ($1); }
        	if(/(\d+\.\d+)\/(\d+\.\d+)\/(\d+\.\d+)\/(\d+\.\d+)/) {
                ($min_time, $avg_time, $max_time, $avg_dev) = ($1, $2, $3, $4);
        	}
		}
		close(PING_LOG);
		
		# Set the type
		if (defined $m7->nodeExists($m7_net_host)) {
			$m7_ping_type   = 'cluster';
		} else {
			$m7_ping_type   = 'satellite';
		}
		
		# Define the results hash
		my $m7_ping_results = {
			'name'	 => $m7_net_host,
			'ip'	 => $m7_net_ipaddr,
			'type'   => $m7_ping_type,
			'pktLoss'	=> [$pkt_loss],
			'minTime'	=> [$min_time],
			'avgTime'	=> [$avg_time],
			'maxTime'	=> [$max_time],
			'avgDev'	=> [$avg_dev]
		};
		
		$m7_results->{test}{host}[$m7_ping_host_count] = $m7_ping_results;
		$m7_ping_host_count ++;
	}
	
	# Dump the results hash to an XML file
	my $m7_xml_file    = $m7_test_base . '/results.xml';
	$m7->log->info($$ . ': Dumping results to XML file - ' . $m7_xml_file);
	
	# Convert the results hash to XML data and print to file
	my $m7_results_xml = XMLout($m7_results, RootName => 'plan');
	open(my $m7_xml_fh, '>', $m7_xml_file);
	print $m7_xml_fh $m7_results_xml;
	close($m7_xml_fh);
	
	# Test thread complete
	$m7->log->info($$ . ': Test run complete - ' . $m7_log_details);
	exit 1;
}
sub netTraceroute {
	my $m7 = shift;
	my $m7_mtr_count = $m7->getXMLText('plan/params/test[@id="' . $m7->test_id . '"]/count');
	
	# Set the log details, test base, and output log
	my $m7_log_details = 'category=' . $m7->plan_cat . ', id=' . $m7->test_id . ', type=' . $m7->test_type . ', count=' . $m7_mtr_count;
	my $m7_test_base = $m7->out_dir . '/test-' . $m7->test_id;
	mkpath($m7_test_base, 0, 0755);
	
	# Initialize the results hash
	my $m7_results = {
		'category' => $m7->plan_cat,
		'test' => {
			'id'	=> $m7->test_id,
			'type'	=> $m7->test_type,
			'host'	=> []
		}
	};
	
	# Process all the network test hosts
	my $m7_troute_host_count = 0;
	foreach my $m7_net_host (keys %{$m7->{_test_hosts}}) {
		my $m7_net_ipaddr = $m7->test_hosts->{$m7_net_host};
		my $m7_test_log  = $m7_test_base . '/' . $m7_net_host . '.output.log';
		
		# Run the MTR test
		system('traceroute -n ' . $m7_net_ipaddr . ' >> ' . $m7_test_log);
		
		# Parse the log file
		my $m7_lasthop = 0;
		my @m7_troute_hops;
		open(TROUTE_LOG, $m7_test_log);
		while(<TROUTE_LOG>) {
			my $hop;
			my $try;
			my $ip;
			my $time;
			if(/(\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+)\sms/) {
                ($hop, $ip, $time) = ($1, $2, $3);
                $try = 1;
        	}
        	if(/(\d+)\s+\*\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+)\sms/) {
                ($hop, $ip, $time) = ($1, $2, $3);
                $try = 2;
        	}
        	if(/(\d+)\s+\*\s+\*\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+)\sms/) {
                ($hop, $ip, $time) = ($1, $2, $3);
                $try = 3;
        	}
        	if(/(\d+)\s+\*\s\*\s\*\s/) {
                ($hop) = ($1);
                $try = 0;
                $ip = '0.0.0.0';
                $time = 0;
        	}
        	if ($hop) {
        		my %m7_troute = (
					'hop' => $hop,
					'try' => $try,
					'ip' => $ip,
					'time' => $time
				);
				push(@m7_troute_hops, \%m7_troute);
				$m7_lasthop = $hop;	
        	}
		}
		close(TROUTE_LOG);
		
		# Set the host type
		if (defined $m7->nodeExists($m7_net_host)) {
			$m7_troute_type   = 'cluster';
		} else {
			$m7_troute_type   = 'satellite';
		}
		
		# Define the results hash
		my $m7_troute_results = {
			'name'	 => $m7_net_host,
			'ip'	 => $m7_net_ipaddr,
			'type'   => $m7_troute_type,
			'hops'	 => {
				'hop'	=> []
			}
		};
		
		# Generate the hop hash
		my $m7_troute_key_count = 0;
		foreach my $hop (@m7_troute_hops) {
			my $m7_troute_hop_hash = {
				'number' => $hop->{hop},
				'try'	 => [$hop->{try}],
				'time'	 => [$hop->{time}],
				'ip'	 => [$hop->{ip}]
			};
			$m7_troute_results->{hops}{hop}[$m7_troute_key_count] = $m7_troute_hop_hash;
			$m7_troute_key_count ++;
		}
		
		$m7_results->{test}{host}[$m7_troute_host_count] = $m7_troute_results;
		$m7_troute_host_count ++;
	}
	
	# Dump the results hash to an XML file
	my $m7_xml_file    = $m7_test_base . '/results.xml';
	$m7->log->info($$ . ': Dumping results to XML file - ' . $m7_xml_file);
	
	# Convert the results hash to XML data and print to file
	my $m7_results_xml = XMLout($m7_results, RootName => 'plan');
	open(my $m7_xml_fh, '>', $m7_xml_file);
	print $m7_xml_fh $m7_results_xml;
	close($m7_xml_fh);
	
	# Test thread complete
	$m7->log->info($$ . ': Test run complete - ' . $m7_log_details);
	exit 1;
}
sub netMTR {
	my $m7 = shift;
	my $m7_mtr_count = $m7->getXMLText('plan/params/test[@id="' . $m7->test_id . '"]/count');
	
	# Set the log details, test base, and output log
	my $m7_log_details = 'category=' . $m7->plan_cat . ', id=' . $m7->test_id . ', type=' . $m7->test_type . ', count=' . $m7_mtr_count;
	my $m7_test_base = $m7->out_dir . '/test-' . $m7->test_id;
	mkpath($m7_test_base, 0, 0755);
	
	# Initialize the results hash
	my $m7_results = {
		'category' => $m7->plan_cat,
		'test' => {
			'id'	=> $m7->test_id,
			'type'	=> $m7->test_type,
			'host'	=> []
		}
	};
	
	# Process all the network test hosts
	my $m7_mtr_host_count = 0;
	foreach my $m7_net_host (keys %{$m7->{_test_hosts}}) {
		my $m7_net_ipaddr = $m7->test_hosts->{$m7_net_host};
		my $m7_test_log  = $m7_test_base . '/' . $m7_net_host . '.output.log';
		
		# Run the MTR test
		system('/usr/bin/sudo /usr/sbin/mtr -n --report --report-wide --report-cycles ' . $m7_mtr_count . ' ' . $m7_net_ipaddr . ' >> ' . $m7_test_log);
		
		# Parse the log file
		my $m7_lasthop = 0;
		my @m7_mtr_hops;
		open(MTR_LOG, $m7_test_log);
		while(<MTR_LOG>){
			if(/(\d+)\.\|\-\-\s+(\d+\.\d+\.\d+\.\d+)\s+([\d\.]+)%\s+(\d+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)/) {
				my ($hop, $ip, $loss, $sent, $last, $avg, $best, $wrst, $stdev) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
				my %m7_mtr = (
					'hop' => $hop,
					'ip' => [$ip],
					'loss' => $loss,
					'sent' => $sent,
					'last' => $last,
					'avg' => $avg,
					'best' => $best,
					'wrst' => $wrst,
					'stdev' => $stdev,
				);
				push(@m7_mtr_hops, \%m7_mtr);
				$m7_lasthop = $hop;
			}
			if(/\|\s+`?\|--\s+(\d+\.\d+\.\d+\.\d+)/) {
				push(@{$m7_mtr_hops[-1]->{ip}}, $1);
		    }
		    if(/(\d+)\.\|--\s\?\?\?/){
				my $hop = $1;
				my %m7_mtr = ('hop' => $hop, 'ip' => ['0.0.0.0'], 'loss' => 100, 'avg' => 0, 'best' => 0, 'wrst' => 0, 'stdev' => 0);
				push(@m7_mtr_hops, \%m7_mtr);
				$m7_lasthop = $hop;
		    }
		}
		close(MTR_LOG);
		
		# Set the and type
		if (defined $m7->nodeExists($m7_net_host)) {
			$m7_mtr_type   = 'cluster';
		} else {
			$m7_mtr_type   = 'satellite';
		}
		
		# Define the results hash
		my $m7_mtr_results = {
			'name'	 => $m7_net_host,
			'ip'	 => $m7_net_ipaddr,
			'type'   => $m7_mtr_type,
			'hops'	 => {
				'hop'	=> []
			}
		};
		
		# Generate the hop hash
		my $m7_mtr_key_count = 0;
		foreach my $hop (@m7_mtr_hops) {
			my $m7_mtr_hop_hash = {
				'number'	=> $hop->{hop},
				'minTime'	=> [$hop->{best}],
				'avgTime'	=> [$hop->{avg}],
				'maxTime'	=> [$hop->{wrst}],
				'pktLoss'	=> [$hop->{loss}],
				'avgDev'	=> [$hop->{stdev}],
				'ips'		=> {
					'ip'	=> [@{$hop->{ip}}]
				}
			};
			$m7_mtr_results->{hops}{hop}[$m7_mtr_key_count] = $m7_mtr_hop_hash;
			$m7_mtr_key_count ++;
		}
		
		$m7_results->{test}{host}[$m7_mtr_host_count] = $m7_mtr_results;
		$m7_mtr_host_count ++;
	}
	
	# Dump the results hash to an XML file
	my $m7_xml_file    = $m7_test_base . '/results.xml';
	$m7->log->info($$ . ': Dumping results to XML file - ' . $m7_xml_file);
	
	# Convert the results hash to XML data and print to file
	my $m7_results_xml = XMLout($m7_results, RootName => 'plan');
	open(my $m7_xml_fh, '>', $m7_xml_file);
	print $m7_xml_fh $m7_results_xml;
	close($m7_xml_fh);
	
	# Test thread complete
	$m7->log->info($$ . ': Test run complete - ' . $m7_log_details);
	exit 1;
}

# Web Tests \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub webDownload {
	my $m7 = shift;
	
	# Set the log details and base URL
	my $m7_log_details = 'category=' . $m7->plan_cat . ', id=' . $m7->test_id . ', type=' . $m7->test_type . ', thread=' . $m7->test_thread . ', samples=' . $m7->test_samples;
	my $m7_base_url    = $m7->test_proto . '://' . $m7->test_host . '/';
	my @m7_target_files;
	
	# Create the test base and set the output log
	my $m7_test_base = $m7->out_dir . '/test-' . $m7->test_id . '/thread-' . $m7->test_thread;
	my $m7_test_log  = $m7_test_base . '/output.log';
	mkpath($m7_test_base . '/tmp', 0, 0755);
	my $m7_fetch_path = $m7_test_base . '/tmp/';
	
	# Build an array of all files to download
	my $m7_file_count = 0;
	for my $m7_file_path ($m7->plan_xtree->findnodes('plan/params/test[@id="' . $m7->test_id . '"]/paths/path')) {
		push(@m7_target_files, $m7_file_path->textContent());
		$m7_results->{test}{files}{file}[$m7_file_count] = $m7_file_path->textContent();
		$m7_file_count ++;
	}
	
	# Initialize the results hash
	my $m7_results = {
		'category' => $m7->plan_cat,
		'test'     => {
			'type'     => $m7->test_type,
			'id'	   => $m7->test_id,
			'files'	   => {
				'count' => $m7_file_count,
				'file'	=> []
			},
			'threads'  => {
				'thread' => [{
					'number'  => $m7->test_thread,
					'samples' => {
						'sample'	=> []
					},
					'average' => {
						'time'	=> undef,
						'speed'	=> undef
					}
				}]
			}
		}
	};
	
	# Initialize the transfer/file property variables
	my $m7_fetch_size_bytes;
	my @m7_multi_fsize;
	
	# Initialize the averages arrays
	my @m7_speed_avgs;
	my @m7_time_avgs;
	
	# Run based on the number of samples
	my $m7_samples_count = 0;
	my $m7_key_count     = 0;
	while ($m7_samples_count < $m7->test_samples) {
		$m7_samples_count ++;
		$m7->log->info($$ . ': Running test ID ' . $m7->test_id . ', sample ' . $m7_samples_count);
	
		# Start the download timer and fetch the files
		my $m7_fetch_start = [Time::HiRes::gettimeofday];
		foreach(@m7_target_files) {
			
			# Get the target file
			my $m7_target_uri  = $m7_base_url . $_;
			my $m7_file_name   = $m7_target_uri;
			$m7_file_name	   =~ s/^.*\/([^\/]*$)/$1/g;
			
			# Fetch the file
			my $m7_fetch = File::Fetch->new(uri => $m7_target_uri);
			my $m7_fetch_local = $m7_fetch->fetch( to => $m7_fetch_path)
				or $m7->log->logdie($$ . ': Failed to retrieve file - ' . $m7_fetch_uri);
			my $m7_fetch_size_single  = -s $m7_fetch_local;
			push(@m7_multi_fsize, $m7_fetch_size_single);
			unlink($m7_fetch_path . $m7_file_name);
		}
		$m7_fetch_size_bytes  = sum(@m7_multi_fsize);

		# Calculcate the transfer time and speed
		my $m7_fetch_time_raw    = Time::HiRes::tv_interval($m7_fetch_start);
		my $m7_fetch_size_kb_raw = $m7_fetch_size_bytes / 1024;
		my $m7_fetch_speed_raw   = $m7_fetch_size_kb_raw / $m7_fetch_time_raw;
		my $m7_fetch_time		 = sprintf("%.2f", $m7_fetch_time_raw);
		my $m7_fetch_speed		 = sprintf("%.2f", $m7_fetch_speed_raw); 
	
		# Append to averages array
		push(@m7_speed_avgs, $m7_fetch_speed);
		push(@m7_time_avgs, $m7_fetch_time);
	
		# Define the sample results hash block
		my $m7_sample_results = {
			'number' => $m7_samples_count,
			'speed'	 => $m7_fetch_speed,
			'time'	 => $m7_fetch_time
		};
		
		# Append to the hash
		$m7_results->{test}{threads}{thread}[0]{samples}{sample}[$m7_key_count] = $m7_sample_results;
		$m7_key_count ++;
	}
	
	# Calculate the averages
	$m7_speed_avg_raw  = sum(@m7_speed_avgs)/@m7_speed_avgs;
	$m7_time_avg_raw   = sum(@m7_time_avgs)/@m7_time_avgs;
	
	# Create the sample averages entries
	$m7_results->{test}{threads}{thread}[0]{average}{time}	 = sprintf("%.2f", $m7_time_avg_raw);
	$m7_results->{test}{threads}{thread}[0]{average}{speed} = sprintf("%.2f", $m7_speed_avg_raw);
	
	# Dump the results hash to an XML file
	my $m7_xml_file    = $m7_test_base . '/results.xml';
	$m7->log->info($$ . ': Dumping results to XML file - ' . $m7_xml_file);
	
	# Convert the results hash to XML data and print to file
	my $m7_results_xml = XMLout($m7_results, RootName => 'plan');
	open(my $m7_xml_fh, '>', $m7_xml_file);
	print $m7_xml_fh $m7_results_xml;
	close($m7_xml_fh);
	
	# Test thread complete
	$m7->log->info($$ . ': Test run complete - ' . $m7_log_details);
	exit 1;
}

# Get XML Element Text \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub getXMLText {
	my $m7 = shift;
	my ($m7_xpath) = @_;
	my $m7_xml_str = ${$m7->plan_xpath->getNodeText($m7_xpath)};
	return $m7_xml_str;
}

# Initialize Test Plan \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub testInit {
	my $m7 = shift;
	my (%m7_init_args) = @_;
	
	# Make sure the XML file is well formed
	if (eval {$m7->lib_xml->parse_file($m7_init_args{plan})}) {
		$m7->log->info('Plan file XML validation success: ' . $m7_init_args{plan});
		$m7->{_plan_file}	= $m7_init_args{plan};
		$m7->{_plan_xtree} 	= $m7->lib_xml->parse_file($m7_init_args{plan});
	} else {
		$m7->log->logdie('Plan file XML validation failed: ' . $m7_init_args{plan});
	}
		
	# Build the plan xpath object and grab the test plan ID / description / category
	$m7->buildXpath('file' => $m7->plan_file);
	$m7->{_plan_id}		= $m7->getXMLText('plan/id');
	$m7->{_plan_desc}	= $m7->getXMLText('plan/desc');
	$m7->{_plan_cat}	= $m7->getXMLText('plan/params/category');
	$m7->{_out_dir}  = $ENV{HOME} . '/output/' . $m7->plan_id;
	
	# Switch log files
	$m7_client_log = $ENV{HOME} . '/log/client.' . $m7->plan_id . '.log';
	$m7->log->info('Plan ID found - switching log files: ' . $m7_client_log);
	$m7->logInit($m7_client_log);
	$m7->log->info('Initializing test run for plan ID: ' . $m7->plan_id);
	
	# If being passed the runtime from the director node
	if($m7_init_args{runtime}) { $m7->{_plan_runtime} = $m7_init_args{runtime}; }
	
	# Perform director tasks
	if($m7->is_dir) {
		
		# If the test is already running
		$m7->{_lock_dir} = $ENV{HOME} . '/lock/' . $m7->plan_id;
		if (-d $m7->lock_dir) {
			$m7->log->logdie('Plan ID lock directory exists: ' . $m7->lock_dir .  ' - plan already running?');
		}
		
		# Set the plan runtime
		my $m7_dt	= DateTime->now(time_zone => 'local');
		my $m7_date = $m7_dt->ymd;
		my $m7_time = $m7_dt->hms;
		$m7->{_plan_runtime} = $m7_date . ' ' . $m7_time;
		$m7->log->info('Setting plan runtime: ' . $m7->plan_runtime);
	}
}

# Distribute Test Plan \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub testDistFail {
	my $m7 = shift;
	my ($m7_dist_fail_node, $m7_dist_fail_msg) = @_;
	$m7->updateNodeStatus('error', $m7_dist_fail_node);
	$m7->log->error($m7_dist_fail_msg);
}
sub testDist {
	my $m7 = shift;
	if($m7->is_dir) {
		
		# If any worker nodes present
		if($m7->workers) {
			for(@{$m7->workers}) {
				my %m7_host	= %{$_};
				my $m7_ssh  = Net::OpenSSH->new(
					$m7_host{ipaddr},
					%m7_opts = (
						'user'	=> $m7_host{user},
						'port'	=> $m7_host{sshport},
						'master_opts' => [ 
							-o => 'StrictHostKeyChecking=no', 
							-i => $ENV{HOME} . '/.ssh/m7.key'
						],
					)
				) or $m7->testDistFail($m7_host{name}, 'Failed to establish SSH connection with worker - ' . $m7_host{name} . ':' . $m7_host{user} . '@' . $m7_host{ipaddr});
				$m7->log->info('Successfully established SSH connection with worker - ' . $m7_host{name} . ':' . $m7_host{user} . '@' . $m7_host{ipaddr});
				
				# Copy the test plan to the worker nodes
				$m7_ssh->scp_put($m7->plan_file, "plans/" . $m7->plan_id . ".xml")
					or $m7->testDistFail($m7_host{name}, 'Failed to copy test plan to: ' . $m7_host{name});
				$m7->log->info('Copied test plan ' . $m7->plan_file . ' to: ' . $m7_host{name});
				
				# Run the test plan on the worker nodes
				$m7_ssh->pipe_out("bash -c -l 'm7 run ~/plans/" . $m7->plan_id . ".xml \"" . $m7->plan_runtime . "\"' > /dev/null 2>&1 &")
					or $m7->testDistFail($m7_host{name}, 'Failed to execute command on worker node: ' . $m7_host{name});
					
				# Create a fork to monitor each worker node from the director
				my $m7_wm_pid = fork();
	
				# Parent process
				if ($m7_wm_pid) {
					$m7->log->info('Fork PID(' . $m7_wm_pid . ') for worker lock ' . $m7_host{name});
					push(@{$m7->{_wm_forks}}, $m7_wm_pid);
	
				# Child process
				} elsif ($m7_wm_pid == 0) {
					$m7->log->info('Launching fork process for worker lock ' . $m7_host{name});
					$m7->{_node} = $m7_host{name};
					$m7->workerLock();
		
				# Fork error
				} else {
					$m7->log->logdie('Error forking worker lock process: ' . $!);
				}	
			}
		}
	}
}

# Execute Test Plan \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub testExec {
	my $m7 = shift;
	use feature 'switch';
	if($m7->is_dir) {
		mkpath($ENV{HOME} . '/results/' . $m7->plan_id, 0, 0755);
	}
	
	# Get all the test IDs
	for my $m7_test_ids ($m7->plan_xtree->findnodes('plan/params/test/@id')) {
		my $m7_test_id = $m7_test_ids->textContent();
		push(@{$m7->{_test_ids}}, $m7_test_id);
	}
	
	# Run the test based on category
	$m7->updateNodeStatus('active');
	$m7->socket->dashAlert('info', 'Running test plan ' . $m7->plan_id . ' on node ' . $m7->local->{name});
	given ($m7->plan_cat) {
		
		# DNS testing
		when ('dns') {
			my $m7_test_host  = $m7->getXMLText('plan/params/nameserver');
			$m7->{_test_host} = $m7_test_host;
			
			# Build an array of all hosts to lookup
			for my $m7_nsl_host ($m7->plan_xtree->findnodes('plan/params/hosts/host')) {
				$m7_nsl_name = $m7_nsl_host->textContent();
				push(@{$m7->{_test_hosts}}, $m7_nsl_name);
			}
	
			# Process each test ID
			foreach(@{$m7->test_ids}) {
				my $m7_test_id	  = $_;
				my $m7_test_type  = $m7->getXMLText('plan/params/test[@id="' . $_ . '"]/type');
				$m7->{_test_id}   = $m7_test_id;
				$m7->{_test_type} = $m7_test_type;
				
				# Stress test uses threads, query test does not
				given ($m7_test_type) {
					when ('stress') {
						$m7->{_test_threads} = $m7->getXMLText('plan/params/threads');
						my $m7_samples		 = $m7->getXMLText('plan/params/test[@id="' . $m7_test_id . '"]/samples');
						my $m7_thread_count  = 0;
						
						# Fork based on the number of threads
						while ($m7_thread_count < $m7->test_threads) {
							$m7_thread_count ++;
							my $m7_thread_details = 'category=' . $m7->plan_cat . ', id=' . $m7_test_id . ', type=' . $m7_test_type . ', thread=' . $m7_thread_count;
							
							# Fork the process for the test ID and thread
							my $m7_tm_pid = fork();
				
							# Parent process
							if ($m7_tm_pid) {
								$m7->log->info('Fork PID(' . $m7_tm_pid . ') for test - ' . $m7_thread_details);
								push(@{$m7->{_test_results}}, $m7->out_dir . '/test-' . $m7_test_id . '/thread-' . $m7_thread_count . '/results.xml');
								push(@{$m7->{_tm_forks}}, $m7_tm_pid);
				
							# Child process
							} elsif ($m7_tm_pid == 0) {
								$m7->{_test_thread}  = $m7_thread_count;
								$m7->{_test_samples} = $m7_samples;
								$m7->log->info($$ . ': Launching fork process for test - ' . $m7_thread_details);
								$m7->dnsStress();
							} else {
								$m7->log->logdie('Error forking test thread process: ' . $!);
							}
						}
					}
					when ('query') {
						my $m7_test_details = 'category=' . $m7->plan_cat . ', id=' . $m7_test_id . ', type=' . $m7_test_type . ', thread=' . $m7_thread_count;
						
						# Fork the process for the test ID
						my $m7_tm_pid = fork();
				
						# Parent process
						if ($m7_tm_pid) {
							$m7->log->info('Fork PID(' . $m7_tm_pid . ') for test - ' . $m7_test_details);
							push(@{$m7->{_test_results}}, $m7->out_dir . '/test-' . $m7_test_id . '/results.xml');
							push(@{$m7->{_tm_forks}}, $m7_tm_pid);
						
						# Child process
						} elsif ($m7_tm_pid == 0) {
							$m7->log->info($$ . ': Launching fork process for test - ' . $m7_test_details);
							$m7->dnsQuery();
						}
					}
					default {
						$m7->log->logdie($$ . ': Invalid type for test ID ' . $_ . ': ' . $m7_test_type);
					}
				}
			}
		}
		
		# Network testing
		when ('net') {
			
			# Build a hash of all target hosts and IPs
			for my $m7_net_host ($m7->plan_xtree->findnodes('plan/params/hosts/host/@name')) {
				$m7_host_name = $m7_net_host->textContent();
				$m7_host_ip = $m7->getXMLText('plan/params/hosts/host[@name="' . $m7_host_name . '"]');
				$m7->{_test_hosts}->{$m7_host_name} = $m7_host_ip;
			}
			
			# Check if targeting cluster nodes
			my $m7_net_cluster = $m7->getXMLText('plan/params/skipcluster');
			if ($m7_net_cluster eq 'no') {
				$m7->log->info('Test parameter: "skip_cluster" = "' . $m7_net_cluster . '" - including cluster nodes in network tests');
				for(@{$m7->nodes}) {
					my %m7_host	= %{$_};
					
					# Exclude the local node in tests
					if ($m7_host{name} ne $m7->local->{name}) {
						$m7->{_test_hosts}->{$m7_host{name}} =  $m7_host{ipaddr};
					}
				}
			} else {
				$m7->log->info('Test parameter: "skip_cluster" = "' . $m7_net_cluster . '" - ignoring cluster nodes in network tests');
			}
			
			foreach(@{$m7->test_ids}) {
				my $m7_test_id		  = $_;
				my $m7_test_type 	  = $m7->getXMLText('plan/params/test[@id="' . $_ . '"]/type');
				my $m7_test_details   = 'category=' . $m7->plan_cat . ', id=' . $_ . ', type=' . $m7_test_type;
				
				# Fork the process for the test ID and thread
				my $m7_tm_pid = fork();
	
				# Parent process
				if ($m7_tm_pid) {
					$m7->log->info('Fork PID(' . $m7_tm_pid . ') for test - ' . $m7_test_details);
					push(@{$m7->{_test_results}}, $m7->out_dir . '/test-' . $m7_test_id . '/results.xml');
					push(@{$m7->{_tm_forks}}, $m7_tm_pid);
	
				# Child process
				} elsif ($m7_wm_pid == 0) {
					$m7->{_test_id}		 = $m7_test_id;
					$m7->{_test_type}	 = $m7_test_type;
					$m7->log->info($$ . ': Launching fork process for test - ' . $m7_test_details);
					given ($m7_test_type) {
						when ('ping') {
							$m7->netPing();
						}
						when ('traceroute') {
							$m7->netTraceroute();
						}
						when ('mtr') {
							$m7->netMTR();
						}
						default {
							$m7->log->logdie($$ . ': Invalid type for test ID ' . $_ . ': ' . $m7_test_type);
						}
					}
				} else {
					$m7->log->logdie('Error forking test process: ' . $!);
				}	
			}
		}
		
		# Web testing
		when ('web') {
			$m7->{_test_threads} = $m7->getXMLText('plan/params/threads');
			my $m7_test_proto	 = $m7->getXMLText('plan/params/proto');
			my $m7_test_host	 = $m7->getXMLText('plan/params/host');
			foreach(@{$m7->test_ids}) {
				my $m7_test_id		  = $_;
				my $m7_test_type	  = $m7->getXMLText('plan/params/test[@id="' . $m7_test_id . '"]/type');
				my $m7_samples		  = $m7->getXMLText('plan/params/test[@id="' . $m7_test_id . '"]/samples');
				my $m7_thread_count   = 0;
				
				# Fork based on the number of threads
				while ($m7_thread_count < $m7->test_threads) {
					$m7_thread_count ++;
					my $m7_thread_details = 'category=' . $m7->plan_cat . ', id=' . $m7_test_id . ', type=' . $m7_test_type . ', thread=' . $m7_thread_count;
					
					# Fork the process for the test ID and thread
					my $m7_tm_pid = fork();
		
					# Parent process
					if ($m7_tm_pid) {
						$m7->log->info('Fork PID(' . $m7_tm_pid . ') for test - ' . $m7_thread_details);
						push(@{$m7->{_test_results}}, $m7->out_dir . '/test-' . $m7_test_id . '/thread-' . $m7_thread_count . '/results.xml');
						push(@{$m7->{_tm_forks}}, $m7_tm_pid);
		
					# Child process
					} elsif ($m7_tm_pid == 0) {
						$m7->{_test_id}		 = $m7_test_id;
						$m7->{_test_thread}  = $m7_thread_count;
						$m7->{_test_samples} = $m7_samples;
						$m7->{_test_proto}	 = $m7_test_proto;
						$m7->{_test_host}	 = $m7_test_host;
						$m7->{_test_type}	 = $m7_test_type;
						$m7->log->info($$ . ': Launching fork process for test - ' . $m7_thread_details);
						given ($m7_test_type) {
							when ('download') {
								$m7->webDownload();
							}
							default {
								$m7->log->logdie($$ . ': Invalid type for test ID ' . $m7_test_id . ': ' . $m7_test_type);
							}
						}
					} else {
						$m7->log->logdie('Error forking test thread process: ' . $!);
					}
				}
			}
		}
		default {
			$m7->log->logdie('Invalid plan category in ' . $m7->plan_file . ': ' . $m7->plan_cat);
		}
	}
}

# Merge Local Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub mergeLocal {
	my $m7 = shift;
	
	# Initialize the results hash
	my $m7_res_base = {
		'category'	=> $m7->plan_cat,
		'host'		=> {
			'name'		=> $m7->local->{name},
			'ip'		=> $m7->local->{ipaddr}
		}
	};	
	
	# Create the aggregate results file
	my $m7_xml_file    = $m7->out_dir . '/results.xml';
	$m7->log->info('Initializing aggregate results XML file: ' . $m7_xml_file);
	my $m7_results_xml = XMLout($m7_res_base, RootName => 'plan');
	open(my $m7_xml_fh, '>', $m7_xml_file);
	print $m7_xml_fh $m7_results_xml;
	close($m7_xml_fh);
	
	# Merge the XML result files
	$m7->log->info('Preparing to merge all XML result files to: ' . $m7_xml_file);
	my $m7_xml_merge = XML::Merge->new('filename' => $m7_xml_file, 'conflict_resolution_method' => 'main');
	$m7_xml_merge->set_id_xpath_list('@id', '@number');
	foreach(@{$m7->test_results}) {
		$m7_xml_merge->merge('filename' => $_)
			or $m7->log->logdie('Failed to merge thread result file: ' . $_);
		$m7->log->info('Finished merging thread result file: ' . $_);
	}
	
	# Tidy up and write the merged XML file
	$m7_xml_merge->tidy();
	$m7_xml_merge->write()
		or $m7->log->logdie('Failed to merge XML result files to: ' . $m7_xml_file);
	$m7->log->info('Successfully merged XML result files to: ' . $m7_xml_file);
	
	# Submit results to test director if a worker node
	if (not defined $m7->is_dir) {
		$m7->log->info('Submitting test results to director - ' . $m7->dir->{name} . ':' . $m7->dir->{user} . '@' . $m7->dir->{ipaddr});
		my $m7_ssh  = Net::OpenSSH->new(
			$m7->dir->{ipaddr},
			%m7_opts = (
				'user'	=> $m7->dir->{user},
				'port'	=> $m7->dir->{sshport},
				'master_opts' => [ 
					-o => 'StrictHostKeyChecking=no', 
					-i => $ENV{HOME} . '/.ssh/m7.key'
				],
			)
		) or $m7->log->logdie('Failed to establish SSH connection with director - ' . $m7->dir->{name} . ':' . $m7->dir->{user} . '@' . $m7->dir->{ipaddr});
		$m7->log->info('Successfully established SSH connection with director - ' . $m7->dir->{name} . ':' . $m7->dir->{user} . '@' . $m7->dir->{ipaddr});
		
		# Copy the results to the director node
		$m7_ssh->scp_put($m7_xml_file, "results/" . $m7->plan_id . "/" . $m7->local->{name} . ".xml")
			or $m7->log->logdie('Failed to copy results to: ' . $m7->dir->{name} . ':' . $m7->dir->{user} . '@' . $m7->dir->{ipaddr});
		$m7->log->info('Copied results ' . $m7_xml_file . ' to: ' . $m7->dir->{name} . ':' . $m7->dir->{user} . '@' . $m7->dir->{ipaddr});
		
		# Delete the output directory
		rmtree($m7->out_dir);
		$m7->updateNodeStatus('idle');
		$m7->socket->dashAlert('info', 'Test plan ' . $m7->plan_id . ' execution complete on node ' . $m7->local->{name});
	} else {
		
		# Copy the results file to the final directory and delete the output path
		copy($m7_xml_file, $ENV{HOME} . "/results/" . $m7->plan_id . "/" . $m7->local->{name} . ".xml");
		rmtree($m7->out_dir);
	}
}

# Monitor Test Plan \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub monitor {
	my $m7 = shift;
	
	# Wait for local tests to complete and merge
	$m7->log->info('Waiting for local result files');
	foreach(@{$m7->tm_forks}) {
		waitpid ($_, 0);
		$m7->log->info('Test monitor PID ' . $_ . ' complete');
	}
	$m7->log->info('All test monitor processes complete - parsing results');
	
	# Load the local results
	$m7->mergeLocal();
	
	# Wait for worker results if a director node
	if ($m7->is_dir) {
		
		# Wait for worker result files
		if ($m7->wm_forks) {
			$m7->log->info('Waiting for worker result files');
			$m7->updateNodeStatus('waiting');
			foreach(@{$m7->wm_forks}) {
				waitpid ($_, 0);
				$m7->log->info('Worker monitor PID ' . $_ . ' complete');
			}
			$m7->log->info('All worker monitor processes complete');	
		} else {
			$m7->log->info('No worker monitor PIDs found - skipping');
		}
		
		# Parse the XML results into the database
		$m7->log->info('Parsing XML results into M7 database');
		$m7->socket->dashAlert('info', 'Parsing test results to database for plan ' . $m7->plan_id);
		$m7->updateNodeStatus('parsing');
		system('m7p "' . $m7->plan_id . '" "' . $m7->plan_runtime . '"');
		
		# Flush the results directory after parsing
		my $m7_results_dir = $m7->config->home . '/results/' . $m7->plan_id;
		rmtree($m7_results_dir)
			or $m7->log->warn('Failed to clear XML results directory: ' . $m7_results_dir);
		$m7->updateNodeStatus('idle');
		$m7->socket->dashAlert('info', 'All test results parsed for plan ' . $m7->plan_id . ' - test run complete.');
	}
}

# Get Status JSON Response \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub getStatusJSON {
	my $m7 = shift;
	$m7->log->info('Constructing cluster status JSON object');
	
	# Initialize the status hash
	$m7_cluster_status = {
		'cluster' => {
			'scheduler' => {},
			'socketio' => {},
			'nodes' => {}
		}
	};
	
	# If the node is the director
	if ($m7->is_dir) {
		
		# Check if the schediler is running
		system('service m7d status &> /dev/null');
		my $m7_scheduler_code = $? >> 8;
		
		# If the server is running
		my $m7_scheduler_status;
		if ($m7_scheduler_code == 0) {
			$m7_scheduler_status = {
				'host'   => $m7->local->{name},
				'status' => 'running'
			};
		} else {
			$m7_scheduler_status = {
				'host'   => $m7->local->{name},
				'status' => 'stopped'
			};
		}
		
		# Check if the socket server is running
		system('service m7socket status &> /dev/null');
		my $m7_socketio_code = $? >> 8;
		
		# If the socket server is running
		my $m7_socketio_status;
		if ($m7_socketio_code == 0) {
			$m7_socketio_status = {
				'host'	 => $m7->local->{name},
				'status' => 'running'
			};
		} else {
			$m7_sockiet_status = {
				'host'	 => $m7->local->{name},
				'status' => 'stopped'
			};
		}
		
		# Append the hashes
		$m7_cluster_status->{cluster}->{scheduler} = $m7_scheduler_status;
		$m7_cluster_status->{cluster}->{socketio} = $m7_socketio_status;
	}
	
	# Process each cluster node
	for(@{$m7->nodes}) {
		my %m7_host	= %{$_};
					
		# Construct the cluster node hash
		my $m7_cluster_node_hash = { 'plans' => {} };
					
		# Prepare the nodes status query
		my $m7_node_status_query = "SELECT * FROM nodes_status WHERE name='" . $m7_host{name} . "'";
		my $m7_node_status_qh	 = $m7->db->prepare($m7_node_status_query)
			or $m7->log->logdie("Failed to prepare MySQL statement: '" . DBI->errstr . "'");
	
		# Execute the worker nodes query
		$m7_node_status_qh->execute()
			or $m7->log->logdie("failed to execute MySQL statement: '" . DBI->errstr . "'");
		while (my $m7_node_status_row = $m7_node_status_qh->fetchrow_hashref()) {
		
			# Construct the nested hash
			my $m7_plan_status_hash = {
				$m7_node_status_row->{plan_id} => {
					'status'   => $m7_node_status_row->{status},
					'last_run' => $m7_node_status_row->{last_run}
				}
			};

			# Append to the cluster node hash
			$m7_cluster_node_hash->{plans} = $m7_plan_status_hash;
		}
		
		# Append to the main status hash
		$m7_cluster_status->{cluster}->{nodes}->{$m7_host{name}} = $m7_cluster_node_hash;
	}
	
	# Dump the JSON object
	my $m7_status_json = encode_json $m7_cluster_status;
	print $m7_status_json;
}

1;