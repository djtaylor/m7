#!/usr/bin/perl
use strict;
use feature 'switch';

# Load the M7 client module
use lib $ENV{HOME} . '/lib/perl/modules';
use M7;

# Create the M7 server object
my $m7 = M7->new();

# Initialize the logger
$m7->logInit(
	'conf' => $ENV{HOME} . '/lib/perl/log/m7.conf',
	'file' => $ENV{HOME} . '/log/client.log'
);

# Initialize the database connection
$m7->dbInit(
	'name' => 'm7',
	'host' => '103.21.143.231',
	'port' => '3306',
	'user' => 'm7',
	'pass' => 'r3nDer'
);

# Check if the node is a director
$m7->checkDirector();

# Test arguments processor
given ($ARGV[0]) {
	
	# Run test plan
	when('run') {
		$m7->testInit(
			'plan' => $ARGV[1]
		);
		$m7->testDist();
		$m7->testExec();
		$m7->monitor();
	}
	
	# Git synchronization
	when('gitsync') {
		$m7->gitSync();
	}
	
	# Invalid argument
	default {
		$m7->log->logdie('Invalid argument supplied: ' . $ARGV[0]);
	}
}