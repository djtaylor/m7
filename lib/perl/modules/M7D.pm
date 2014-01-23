#!/usr/bin/perl

# Package Name \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
package M7D;

# Module Dependencies \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
BEGIN {
	use strict;
	use Log::Log4perl;
	use File::Slurp;
	use File::Path;
	use XML::LibXML;
	use DBI;
	use DBD::mysql;
	use DateTime;
	use DateTime::Duration;
	use Time::Piece;
	use lib $ENV{HOME} . '/lib/perl/modules';
	use M7Config;
	use M7Socket;
}

# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
# Module Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #

# Package Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub new {
	my $m7d = {
		_config		=> M7Config->new(),
		_libxml		=> XML::LibXML->new(),
		_socket		=> M7Socket->new(),
		_log		=> undef,
		_db			=> undef,
		_plans		=> undef,
		_plan_xtree => undef,
		_forks		=> undef
	};
	bless $m7d, M7D;
	$m7d->logInit();
	$m7d->setPID();
	$m7d->dbInit();
	$m7d->planConfig();
	return $m7d;
}

# Subroutine Shortcuts \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub config     { return shift->{_config};     }
sub libxml     { return shift->{_libxml};     }
sub socket	   { return shift->{_socket};     }
sub log		   { return shift->{_log};        }
sub db		   { return shift->{_db};         }
sub plans	   { return shift->{_plans};      }
sub plan_xtree { return shift->{_plan_xtree}; }
sub forks	   { return shift->{_forks};      }

# Initialize Logger \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub logInit {
	my $m7d = shift;
	
	# Read the log file into memory
	my $m7d_log_file = $m7d->config->get('log_file_m7d');
	my $m7d_log_conf = read_file($m7d->config->get('log_conf_m7d'));
	$m7d_log_conf =~ s/__LOGFILE__/$m7d_log_file/;
	
	# Initialize the logger
	Log::Log4perl::init(\$m7d_log_conf)
		or die 'Failed to initialize logger!';
	
	# Build the logger object
	$m7d->{_log} = Log::Log4perl->get_logger;
	return $m7d->{_log};
}

# Set PID File \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub setPID {
	my $m7d = shift;
	open(PIDFILE, '>' . $m7d->config->get('pidfile'));
	print PIDFILE $$;
	close(PIDFILE);
}

# Initialze Database Object \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub dbInit {
	my $m7d = shift;
	my (%m7d_db_args) = @_;
	my $m7d_db_dsn = "dbi:mysql:" . $m7d->config->get('db_name') . ":" . $m7d->config->get('db_host') . ":" . $m7d->config->get('db_port');
	$m7d->{_db} = shift;
	my $m7d_dbh = DBI->connect($m7d_db_dsn, $m7d->config->get('db_user'), $m7d->config->get('db_pass'), {
		PrintError => 0,
		RaiseError => 1
	}) or $m7d->log->logdie("Failed to connect to database: '" . DBI->errstr . "'");
	$m7d->{_db} = $m7d_dbh;
	return $m7d->{_db};
}

# Plan Configuration Parameters Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub planConfig {
	my $m7d = shift;
	my $m7d_plans_query = 'SELECT * FROM config_m7d';
	my $m7d_plans_qh 	= $m7d->db->prepare($m7d_plans_query)
		or $m7d->log->logdie("Failed to prepare MySQL statement: '" . DBI->errstr . "'");
	$m7d_plans_qh->execute()
		or $m7d->log->logdie("Failed to execute MySQL statement: '" . DBI->errstr . "'");
	while($m7d_plan_data = $m7d_plans_qh->fetchrow_hashref()) {
		push(@{$m7d->{_plans}}, $m7d_plan_data);
	}
	return $m7d->{_plans};
}

# Fork Child Test Process \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub forkFail {
	my $m7d = shift;
	my ($m7d_msg) = @_;
	$m7d->socket->dashAlert('fatal', $m7d_msg);
	$m7d->log->logdie($msg);
}
sub forkTest {
	sub get_delay {
		my ($m7d_id, $m7d_int) = @_;
		sub set_next_run {
			my ($m7d_int, $m7d_next_run_marker) = @_;
			my $m7d_datetime = DateTime->now(time_zone => 'local');
			
			# Find the next runtime
			$m7d_datetime->add(seconds => $m7d_int);
			my $m7d_next_date     = $m7d_datetime->ymd;
			my $m7d_next_time     = $m7d_datetime->hms;
			my $m7d_next_run      = $m7d_next_date . ' ' . $m7d_next_time;
		
			# Initialize the runtime marker with the current time
			open(my $m7d_next_run_fh, '>', $m7d_next_run_marker);
			print $m7d_next_run_fh $m7d_next_run;
			close($m7d_next_run_fh);
		}
		
		# Generate the next runtime marker directory
		my $m7d_next_run_dir = $ENV{HOME} . '/run/plan';
		my $m7d_next_run_marker = $m7d_next_run_dir . '/' . $m7d_id;
		mkpath($m7d_next_run_dir, 0, 0755);
		
		# If clearing the runtime marker
		if ($m7d_int eq 'clear') {
			unlink($m7d_next_run_marker);
		} else {
			
			# Initialize the datetime object and delay variable
			my $m7d_datetime  = DateTime->now(time_zone => 'local');
			my $m7d_delay;
			
			# Get the current datetime
			my $m7d_this_date = $m7d_datetime->ymd;
			my $m7d_this_time = $m7d_datetime->hms;
			my $m7d_this_run  = $m7d_this_date . ' ' . $m7d_this_time;
			
			# If the runtime marker already exists
			if (-e $m7d_next_run_marker) {
				
				# Read the file into memory
				open(my $m7d_next_run_fh, '<', $m7d_next_run_marker);
				my $m7d_next_run = <$m7d_next_run_fh>;
				close($m7d_next_run_fh);
				
				# Calculate the delay in seconds until next run
				my $m7d_time_one = Time::Piece->strptime($m7d_this_run, '%Y-%m-%d %H:%M:%S');
				my $m7d_time_two = Time::Piece->strptime($m7d_next_run, '%Y-%m-%d %H:%M:%S');
				my $m7d_delay    = $m7d_time_two - $m7d_time_one;
				
				# If the delay is negative (next run date already passed)
				if ($m7d_delay != abs($m7d_delay)) {
					set_next_run($m7d_int, $m7d_next_run_marker);
					$m7d_delay = 0;
				}
			} else {
				set_next_run($m7d_int, $m7d_next_run_marker);
				$m7d_delay = 0;
			}
			return $m7d_delay;	
		}
	}
	
	# Retrieve arguments and set the run log variables
	my $m7d = shift;
	my ($m7d_id, $m7d_int, $m7d_plan) = @_;
	my $m7d_run_count = 1;
	my $m7d_run_type  = ($m7d_run_count == 1 ? 'first' : 'next');
	$m7d->log->info($$ . ': Fork parameters -> id=' . $m7d_id . ', interval=' . $m7d_int . 's, plan=' . $m7d_plan);

	# Define the command string
	my $m7d_cmd_string = "bash -c -l 'm7 run " . $m7d_plan . "' > /dev/null 2>&1 &";

	# If command is being run once
	if ($m7d_int == '0') {
		$m7d->log->info($$ . ': Starting single test run for ID: ' . $m7d_id);
		$m7d->log->info($$ . ': Preparing to run test plan: ' . $m7d_plan);
		$m7d->shellRun($m7d_cmd_str);
		$m7d->log->info($$ . ': Test plan execution complete');
	
	# If command is being run as a process
	} else {
		
		# Start the server process
		do {
			$m7d_delay = get_delay($m7d_id, $m7d_int);
			sleep($m7d_delay);
			
			# Run the fork command
			$m7d->log->info($$ . ': Starting ' . $m7d_run_type . '[' . $m7d_run_count . '] test run interval for ID: ' . $m7d_id);
			$m7d->log->info($$ . ': Preparing to run test plan: ' . $m7d_plan);
			
			# Run the fork shell command
			system($m7d_cmd_string) != 1
				or $m7d->forkFail($$ . ': Failed to execute shell command: ' . $m7d_cmd_string . ' - exit code: ' . $?);
			$m7d->log->info($$ . ': Successfully executed shell command: [' . $m7d_cmd_string . '] - exit code: ' . $?);
			$m7d->socket->dashAlert('info', 'Test plan ' . $m7d_id . ' successfully launched - next run in ' . $m7d_int . ' seconds.');
			
			# Execution complete
			$m7d->log->info($$ . ': Test plan execution complete - next run in ' . $m7d_int . ' seconds');
			$m7d_run_count ++;
			sleep($m7d_int);
			
			# Clear the next runtime marker
			get_delay($m7d_id, 'clear');
		} while(1);	
	}
}

1;