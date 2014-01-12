#!/usr/bin/perl

# Package Name \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
package M7Parse;

# Module Dependencies \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
BEGIN {
	use strict;
	use warnings;
	use File::Find;
	use File::Slurp;
	use XML::LibXML;
	use XML::XPath;
	use Cwd;
}

# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
# Module Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #

# Package Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub new {
	my $m7p = {
		_lib_xml		=> XML::LibXML->new(),
		_xml_tree		=> undef
	};
	bless $m7p, M7Parse;
	return $m7p;
}

# Web Test Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub webSingleDL {
	my $m7p = shift;
	my ($m7p_test_base) = @_;
	
	# Parse each thread output log
	sub parse {
		
		# Get the thread directory
		my $m7p_output_dir = cwd();
		if (-f $_ && $_ == 'output.log') {
			my $m7p_file_path  = $m7p_output_dir . '/' . $_;
			
			# Read the summary lines into an array
			open my $m7p_file_hndl, $m7p_file_path;
			my @m7p_file_sum   = sort grep /Closing/, <$m7p_file_hndl>;
			
			# Extract the results
			foreach(@m7p_file_sum) {
				my $m7p_avg_speed = $_;
				$m7p_avg_speed =~ m/^[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*([^ ]*).*$/;
				my $m7p_dl_time   = $_;
				$m7p_dl_time   =~ m/^[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ]*[ ]*[^ ][ ]*([^ ]*).*$/;
				print "Avg Speed: " . $m7p_avg_speed . "\n";
				print "DL Time: " . $m7p_dl_time . "\n";
			}
		}
	}
	
	# Find and parse each thread output log
	find(\&parse, $m7p_test_base);
}
sub webMultiDL {
	my $m7p = shift;
	my ($m7p_test_base) = @_;
}

1;