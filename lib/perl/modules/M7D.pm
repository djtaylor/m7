#!/usr/bin/perl

# Package Name \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
package M7D;

# Module Dependencies \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
BEGIN {
	use strict;
	use warnings;
	use Log::Log4perl;
	use File::Slurp;
	use DBI;
	use DBD::mysql;
	use lib $ENV{HOME} . '/lib/perl/modules';
	use M7Config;
}

# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
# Module Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #

# Package Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub new {
	my $m7d = {
		_config		=> M7Config->new(),
		_log		=> undef,
		_db			=> undef,
		_plans		=> undef,
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
sub config  { return shift->{_config}; }
sub log		{ return shift->{_log};    }
sub db		{ return shift->{_db};     }
sub plans	{ return shift->{_plans};  }
sub forks	{ return shift->{_forks};  }

# Initialize Logger \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub logInit {
	my $m7d = shift;
	my $m7d_log_conf = read_file($m7->config->get('log_conf_m7d'));
	$m7d_log_conf =~ s/__LOGFILE__/$m7->config->get('log_file_m7d')/;
	Log::Log4perl::init(\$m7d_log_conf);
	$m7d->{_log} = Log::Log4perl->get_logger;
	return $m7d->{_log};
}

# Set PID File \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub setPID {
	my $m7d = shift;
	open(PIDFILE, '>' . $m7->config->get('pidfile'));
	print PIDFILE $$;
	close(PIDFILE);
}

# Initialze Database Object \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub dbInit {
	my $m7d = shift;
	my (%m7d_db_args) = @_;
	my $m7d_db_dsn = "dbi:mysql:" . $m7->config->get('db_name') . ":" . $m7->config->get('db_host') . ":" . $m7->config->get('db_port');
	$m7d->{_db} = shift;
	my $m7d_dbh = DBI->connect($m7d_db_dsn, $m7->config->get('db_user'), $m7->config->get('db_pass'), {
		PrintError => 0,
		RaiseError => 1
	}) or $m7d->log->logdie("Failed to connect to database: '" . DBI->errstr . "'");
	$m7d->{_db} = $m7d_dbh;
	return $m7d->{_db};
}

# Plan Configuration Parameters Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\ #
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
sub forkTest {
	
	# Retrieve arguments and set the run log variables
	my $m7d = shift;
	my ($m7d_id, $m7d_int, $m7d_plan) = @_;
	my $m7d_run_count = 1;
	my $m7d_run_type  = ($m7d_run_count == 1 ? 'first' : 'next');
	$m7d->log->info($$ . ': Fork parameters -> id=' . $m7d_id . ', interval=' . $m7d_int . 's, plan=' . $m7d_plan);

	# Define the command string
	my $m7d_cmd_string = '`~/bin/m7 run ' . $m7d_plan . '`';

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
			
			# Run the fork command
			$m7d->log->info($$ . ': Starting ' . $m7d_run_type . '[' . $m7d_run_count . '] test run interval for ID: ' . $m7d_id);
			$m7d->log->info($$ . ': Preparing to run test plan: ' . $m7d_plan);
			
			# Run the fork shell command
			system($m7d_cmd_string) != 1
				or $m7d->log->logdie($$ . ': Failed to execute shell command: ' . $m7d_cmd_string . ' - exit code: ' . $?);
			$m7d->log->info($$ . ': Successfully executed shell command: [' . $m7d_cmd_string . '] - exit code: ' . $?);
			
			# Execution complete
			$m7d->log->info($$ . ': Test plan execution complete - next run in ' . $m7d_int . ' seconds');
			$m7d_run_count ++;
			sleep($m7d_int);
		} while(1);	
	}
}

1;