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
}

# Module Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #

# Package constructor
sub new {
	my $m7d = {
		_log		=> undef,
		_db			=> undef,
		_plans		=> undef
	};
	bless $m7d, M7D;
	return $m7d;
}

# Subroutine access to log and database objects
sub log		{ return shift->{_log}; }
sub db		{ return shift->{_db}; }
sub plans	{ return shift->{_plans}; }

# Initialize the logging object
sub logInit {
	my $m7d = shift;
	my (%m7d_log_args) = @_;
	my $m7d_log_conf = read_file($m7d_log_args{conf});
	$m7d_log_conf =~ s/__LOGFILE__/$m7d_log_args{file}/;
	Log::Log4perl::init(\$m7d_log_conf);
	$m7d->{_log} = Log::Log4perl->get_logger;
	return $m7d->{_log};
}

# Initialize the database object
sub dbInit {
	my $m7d = shift;
	my (%m7d_db_args) = @_;
	my $m7d_db_dsn = "dbi:mysql:" . $m7d_db_args{name} . ":" . $m7d_db_args{host} . ":" . $m7d_db_args{port};
	$m7d->{_db} = shift;
	my $m7d_dbh = DBI->connect($m7d_db_dsn, $m7d_db_args{user}, $m7d_db_args{pass}, {
		PrintError => 0,
		RaiseError => 1
	}) or $m7d->log->logdie("Failed to connect to database: '" . DBI->errstr . "'");
	$m7d->{_db} = $m7d_dbh;
	return $m7d->{_db};
}

# Return each plan config entry
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

# Run a shell command
sub shellRun {
	my $m7d = shift;
	my ($m7d_cmd_string) = @_;
	system($m7d_cmd_string) != 1 
		or $m7d->log->logdie("Failed to execute shell command: '" . $m7d_cmd_string . "' - exit code: '" . $? . "'");
	$m7d->log->info("Successfully exected shell command: '" . $m7d_cmd_string . "' - exit code: '" . $? . "'");
}

1;