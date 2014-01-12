#!/usr/bin/perl

# Package Name \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
package M7;

# Module Dependencies \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
BEGIN {
	use strict;
	use warnings;
	use Log::Log4perl;
	use File::Slurp;
	use File::Path;
	use DBI;
	use DBD::mysql;
	use Sys::Hostname;
	use XML::LibXML;
	use XML::XPath;
	use XML::Simple;
	use XML::Merge;
	use DateTime;
	use Net::OpenSSH;
	use File::Fetch;
	use Time::HiRes;
	use List::Util qw(sum);
	use lib $ENV{HOME} . '/lib/perl/modules';
	use M7Parse;
}

# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
# Module Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #

# Package Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub new {
	my $m7 = {
		_log			=> undef,
		_db				=> undef,
		_dir			=> undef,
		_is_dir			=> undef,
		_workers		=> undef,
		_local			=> undef,
		_wm_forks		=> undef,
		_tm_forks		=> undef,
		_lib_xml		=> XML::LibXML->new(),
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
		_out_dir		=> undef
	};
	bless $m7, M7;
	return $m7;
}

# Subroutine Shortcuts \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub log			 { return shift->{_log};		  }
sub db			 { return shift->{_db}; 		  }
sub dir			 { return shift->{_dir}[0]; 	  }
sub is_dir	     { return shift->{_is_dir};       }
sub workers      { return shift->{_workers};      }
sub local		 { return shift->{_local}[0];	  }
sub wm_forks	 { return shift->{_wm_forks}; 	  }
sub tm_forks     { return shift->{_tm_forks};     }
sub lib_xml		 { return shift->{_lib_xml};      }
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
sub test_type	 { return shift->{_test_type};    }
sub test_results { return shift->{_test_results}; }
sub lock_dir	 { return shift->{_lock_dir};     }
sub out_dir		 { return shift->{_out_dir};      }

# Initialize Logger \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub logInit {
	my $m7 = shift;
	my (%m7_log_args) = @_;
	
	# Read the log configuration into memory
	my $m7_log_conf = read_file($m7_log_args{conf});
	$m7_log_conf =~ s/__LOGFILE__/$m7_log_args{file}/;
	
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
	my (%m7_db_args) = @_;
	$m7->log->info('Initializing director database connection');
	my $m7_db_dsn = "dbi:mysql:" . $m7_db_args{name} . ":" . $m7_db_args{host} . ":" . $m7_db_args{port};
	$m7->{_db} = shift;
	my $m7_dbh = DBI->connect($m7_db_dsn, $m7_db_args{user}, $m7_db_args{pass}, {
		PrintError => 0,
		RaiseError => 1
	}) or $m7->log->logdie("Failed to connect to database: '" . DBI->errstr . "'");
	$m7->{_db} = $m7_dbh;
	return $m7->{_db};
}

# Director Check \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub checkDirector {
	my $m7 = shift;
	my $m7_host = hostname;
	
	# Prepare the director node query
	$m7->log->info('Constructing director node object');
	my $m7_dir_query = "SELECT * FROM hosts WHERE type='director'";
	my $m7_dir_qh 	 = $m7->db->prepare($m7_dir_query)
		or $m7->log->logdie("Failed to prepare MySQL statement: '" . DBI->errstr . "'");
	
	# Execute the director node query
	$m7_dir_qh->execute()
		or $m7->log->logdie("Failed to execute MySQL statement: '" . DBI->errstr . "'");
	while ($m7_dir_row = $m7_dir_qh->fetchrow_hashref()) {
		push(@{m7->{_dir}}, $m7_dir_row);
	}
	
	# Prepare the worker nodes query
	$m7->log->info('Constructing worker nodes object');
	my $m7_wrk_query = "SELECT * FROM hosts WHERE type='worker'";
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
	my $m7_loc_query = "SELECT * FROM hosts WHERE name='" . $m7_host . "'";
	my $m7_loc_qh	 = $m7->db->prepare($m7_loc_query)
		or $m7->log->logdie("Failed to prepare MySQL statement: '" . DBI->errstr . "'");
	
	# Execute the local node query
	$m7_loc_qh->execute()
		or $m7->log->logdie("failed to execute MySQL statement: '" . DBI->errstr . "'");
	while ($m7_loc_row = $m7_loc_qh->fetchrow_hashref()) {
		push(@{$m7->{_local}}, $m7_loc_row);
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

# Build Xpath Object \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub buildXpath {
	my $m7 = shift;
	my (%m7_xpath_args) = @_;
	$m7->{_plan_xpath} = XML::XPath->new(filename => $m7_xpath_args{file});
	return $m7->{_plan_xpath};
}

# Worker Lock \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub workerLock {
	my $m7 = shift;
	my ($m7_worker) = @_;
	my $m7_worker_results = $ENV{HOME} . '/results/' . $m7->plan_id . '/' . $m7_worker . '.xml';
	while (not -e $m7_worker_results) {
		$m7->log->info($$  . ': Worker results file received: ' . $m7_worker_results . ' - closing monitor');
	}
}

# DNS Tests \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub dnsLookup {
	my $m7 = shift;
	exit 0;
}

# Network Tests \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub netPing {
	my $m7 = shift;
	my (%m7_net_args) = @_;
	exit 0;
}
sub netTraceroute {
	my $m7 = shift;
	exit 0;	
}
sub netMTR {
	my $m7 = shift;
	my (%m7_net_args) = @_;
	exit 0;
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
	
	# Initialize the results hash
	my $m7_results = {
		'category' => $m7->plan_cat,
		'test'     => {
			'type'     => $m7->test_type,
			'id'	   => $m7->test_id,
			'files'	   => {
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
	
	# Build an array of all files to download
	my $m7_file_key = 0;
	for my $m7_file_path ($m7->plan_xtree->findnodes('plan/params/test[@id="' . $m7->test_id . '"]/paths/path')) {
		push(@m7_target_files, $m7_file_path->textContent());
		$m7_results->{test}{files}{file}[$m7_file_key] = $m7_file_path->textContent();
		$m7_file_key ++;
	}
	
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
	
	# Conver the results hash to XML data and print to file
	my $m7_results_xml = XMLout($m7_results, RootName => 'plan');
	open(my $m7_xml_fh, '>', $m7_xml_file);
	print $m7_xml_fh $m7_results_xml;
	close($m7_xml_fh);
	
	# Test thread complete
	$m7->log->info($$ . ': Test run complete - ' . $m7_log_details);
	exit 0;
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
	$m7->logInit(
		'conf' => $ENV{HOME} . '/lib/perl/log/m7.conf',
		'file' => $m7_client_log
	);
	$m7->log->info('Initializing test run for plan ID: ' . $m7->plan_id);
	
	# Perform director tasks
	if($m7->is_dir) {
		
		# If the test is already running
		$m7->{_lock_dir} = $ENV{HOME} . '/lock/' . $m7->plan_id;
		if (-d $m7->lock_dir) {
			$m7->log->logdie('Plan ID lock directory exists: ' . $m7->lock_dir .  ' - plan already running?');
		}
		
		# Set the plan runtime
		my $m7_dt	= DateTime->now();
		my $m7_date = $m7_dt->ymd;
		my $m7_time = $m7_dt->hms;
		$m7->{_plan_runtime} = $m7_date . ' ' . $m7_time;
		$m7->log->info('Setting plan runtime: ' . $m7->plan_runtime);
	}
}

# Distribute Test Plan \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
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
				) or $m7->log->logdie('Failed to establish SSH connection with worker - ' . $m7_host{name} . ':' . $m7_host{user} . '@' . $m7_host{ipaddr});
				$m7->log->info('Successfully established SSH connection with worker - ' . $m7_host{name} . ':' . $m7_host{user} . '@' . $m7_host{ipaddr});
				
				# Copy the test plan to the worker nodes
				$m7_ssh->scp_put($m7->plan_file, "plans/" . $m7->plan_id . ".xml")
					or $m7->log->logdie('Failed to copy test plan to: ' . $m7_host{name});
				$m7->log->info('Copied test plan ' . $m7->plan_file . ' to: ' . $m7_host{name});
				
				# Run the test plan on the worker nodes
				$m7_ssh->pipe_out("bash -c -l 'm7.pl run ~/plans/" . $m7->plan_id . ".xml'")
					or $m7->log->logdie('Failed to execute command on worker node: ' . $m7_host{name});
					
				# Create a fork to monitor each worker node from the director
				my $m7_wm_pid = fork();
	
				# Parent process
				if ($m7_wm_pid) {
					$m7->log->info('Fork PID(' . $m7_wm_pid . ') for worker lock ' . $m7_host{name});
					push(@{$m7->{_wm_forks}}, $m7_wm_pid);
	
				# Child process
				} elsif ($m7_wm_pid == 0) {
					$m7->log->info('Launching fork process for worker lock ' . $m7_host{name});
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
	given ($m7->plan_cat) {
		
		# DNS testing
		when ('dns') {
			$m7->{_test_threads} = $m7->getXMLText('plan/params/threads');
			foreach(@{$m7->test_ids}) {
				my $m7_test_type	  = $m7->getXMLText('plan/params/test[@id="' . $_ . '"]/type');
				my $m7_samples		  = $m7->getXMLText('plan/params/test[@id="' . $_ . '"]/type[@="' . $m7_test_type . '"]/samples');
				my $m7_thread_count   = 0;
				
				# Fork based on the number of threads
				while ($m7_thread_count < $m7->test_threads) {
					$m7_thread_count ++;
					my $m7_thread_details = 'category=' . $m7->plan_cat . ', id=' . $_ . ', type=' . $m7_test_type . ', thread=' . $m7_thread_count;
					
					# Fork the process for the test ID and thread
					my $m7_tm_pid = fork();
		
					# Parent process
					if ($m7_tm_pid) {
						$m7->log->info('Fork PID(' . $m7_tm_pid . ') for test - ' . $m7_thread_details);
						push(@{$m7->{_tm_forks}}, $m7_tm_pid);
		
					# Child process
					} elsif ($m7_wm_pid == 0) {
						$m7->log->info($$ . ': Launching fork process for test - ' . $m7_thread_details);
						given ($m7_test_type) {
							when ('nslookup') {
								$m7->dnsLookup();
							}
							default {
								$m7->log->logdie($$ . ': Invalid type for test ID ' . $_ . ': ' . $m7_test_type);
							}
						}
					} else {
						$m7->log->logdie('Error forking test thread process: ' . $!);
					}
				}
			}
		}
		
		# Network testing
		when ('net') {
			foreach(@{$m7->test_ids}) {
				my $m7_test_type 	  = $m7->getXMLText('plan/params/test[@id="' . $_ . '"]/type');
				my $m7_test_details   = 'category=' . $m7->plan_cat . ', id=' . $_ . ', type=' . $m7_test_type;
				
				# Fork the process for the test ID and thread
				my $m7_tm_pid = fork();
	
				# Parent process
				if ($m7_tm_pid) {
					$m7->log->info('Fork PID(' . $m7_tm_pid . ') for test - ' . $m7_test_details);
					push(@{$m7->{_tm_forks}}, $m7_tm_pid);
	
				# Child process
				} elsif ($m7_wm_pid == 0) {
					$m7->log->info($$ . ': Launching fork process for test - ' . $m7_test_details);
					given ($m7_test_type) {
						when ('ping') {
							my $m7_ping_count = $m7->getXMLText('plan/params/test[@id="' . $_ . '"]/count');
							$m7->netPing(
								'id'	  => $_,
								'count'   => $m7_ping_count
							);
						}
						when ('traceroute') {
							$m7->netTraceroute(
								'id'	  => $_
							);
						}
						when ('mtr') {
							my $m7_mtr_count = $m7->getXMLText('plan/params/test[@id="' . $_ . '"]/count');
							$m7->netMTR(
								'id'	=> $_,
								'count'	=> $m7_mtr_count
							);
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
			'ip'		=> $m7->local->{ipaddr},
			'region'	=> $m7->local->{region}
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
		$m7_ssh->scp_put($m7->xml_file, "results/" . $m7->plan_id . "/" . $m7->local->{name} . ".xml")
			or $m7->log->logdie('Failed to copy results to: ' . $m7->dir->{name} . ':' . $m7->dir->{user} . '@' . $m7->dir->{ipaddr});
		$m7->log->info('Copied results ' . $m7_xml_file . ' to: ' . $m7->dir->{name} . ':' . $m7->dir->{user} . '@' . $m7->dir->{ipaddr});
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
			foreach(@{$m7->wm_forks}) {
				waitpid ($_, 0);
				$m7->log->info('Worker monitor PID ' . $_ . ' complete');
			}
			$m7->log->info('All worker monitor processes complete');	
		} else {
			$m7->log->info('No worker monitor PIDs found - skipping');
		}
	}
}

1;