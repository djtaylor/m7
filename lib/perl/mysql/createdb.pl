#!/usr/bin/perl
use strict;
use Getopt::Std;
use DBI;
use DBD::mysql;
use Term::ReadKey;

# Command Line Arguments
#
# -a	The MySQL administrator account, defaults to root if not specified
# -P	The MySQL administrator password, used to create databases and users
# -p	The M7 database user password
my %opts=();
getopts('a:P:p:', \%opts);

# Option variable containers
my $db_admin;
my $db_pass;
my $db_upass;

# Get the MySQL administrator account
sub db_admin_user {
	if (not defined $opts{a}) {
		print "Please enter the MySQL administrator account (root): ";
		chomp($db_admin = <STDIN>);
		if ($db_admin eq '') { $db_admin = 'root'; }
	} else {
		$db_admin = $opts{a};
	}
}

# Get the MySQL administrator password
sub db_admin_pass {
	if (not defined $opts{P}) {
		print "Please enter the MySQL administrator password: ";
		ReadMode('noecho');
		chomp($db_pass = <STDIN>);
		ReadMode(0);
		print "\n";
		if ($db_pass eq '') { 
			print "Sorry, you need to enter the administrator password...\n";
			&db_admin_pass;
		}
	} else {
		$db_pass = $opts{P};
	}
}

# Get the M7 database user password
sub db_user_pass {
	if (not defined $opts{p}) {
		print "Please enter the MySQL M7 user password: ";
		ReadMode('noecho');
		chomp($db_upass = <STDIN>);
		ReadMode(0);
		print "\n";
		if ($db_upass eq '') { 
			print "Sorry, you need to enter the M7 user password...\n";
			&db_admin_pass;
		}
	} else {
		$db_upass = $opts{p};
	}
}

# Database error handler
sub db_handle_error {
	my $db_err_msg = shift;
	print "MySQL database error: $db_err_msg\n";
	exit;
}

# Test the database connection
sub db_connect_test {

	# Try to open a database connection
	my $db_con = DBI->connect(
		'dbi:mysql:', 
		$db_admin, 
		$db_pass,
		{
			PrintError	=> 0,
			HandleError => \&db_handle_error,
		}
	) or db_handle_error(DBI->errstr);
	
	# Database connection succeeded
	print "Database connection success!\n"
}

# Create the M7 database, user account, and base tables
sub db_m7_create {
	sub db_exec {
		my $db_con = DBI->connect(
			'dbi:mysql:', 
			$db_admin, 
			$db_pass,
			{
				PrintError	=> 0,
				HandleError => \&db_handle_error,
			}
		) or db_handle_error(DBI->errstr);
		$db_con->do(
			$_[0]
		) or db_handle_error(DBI->errstr);
	}
	my $dbq_create_db	= 'CREATE DATABASE IF NOT EXISTS m7';
	my $dbq_create_user	= 'GRANT ALL PRIVILEGES ON m7.* TO \'m7\'@\'%\' IDENTIFIED BY \'' . $db_upass . '\' WITH GRANT OPTION';
	my $dbq_flush_user  = 'FLUSH PRIVILEGES';
	my $dbq_hosts_table = '
		CREATE TABLE IF NOT EXISTS `m7`.`hosts` (
	  		`id` int(11) NOT NULL AUTO_INCREMENT,
	  		`name` varchar(25) NOT NULL,
	  		`type` varchar(10) NOT NULL,
	  		`desc` varchar(128) DEFAULT NULL,
	  		`ipaddr` varchar(15) NOT NULL,
	  		`sshport` varchar(10) NOT NULL,
	  		`user` varchar(15) NOT NULL,
	  		`hostname` varchar(128) NOT NULL,
	  		`region` varchar(45) NOT NULL,
	  		`modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	  		PRIMARY KEY (`id`)
		);';
	my $dbq_tests_table = '
		CREATE TABLE IF NOT EXISTS `m7`.`tests` (
	  		`id` int(11) NOT NULL AUTO_INCREMENT,
		  	`test_id` int(11) NOT NULL,
		  	`type` varchar(10) NOT NULL,
		  	`desc` varchar(128) DEFAULT NULL,
		  	`first_run` datetime DEFAULT NULL,
		  	`last_run` datetime DEFAULT NULL,
		  	`created` datetime DEFAULT NULL,
		  	PRIMARY KEY (`id`)
		);';
	
	# Execute the statements
	&db_exec($dbq_create_db);
	print "M7 database created...\n";
	&db_exec($dbq_create_user);
	print "M7 database user created...\n";
	&db_exec($dbq_flush_user);
	print "Flushing user privileges...\n";
	&db_exec($dbq_hosts_table);
	print "M7 hosts table created...\n";
	&db_exec($dbq_tests_table);
	print "M7 tests table created...\n";
	
	# Database creation complete
	print "M7 database initialization complete!\n"
}

&db_admin_user;
&db_admin_pass;
&db_user_pass;
&db_connect_test;
&db_m7_create;