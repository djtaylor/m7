#!/usr/bin/perl

# Package Name \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
package M7Socket;

# Module Dependencies \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
BEGIN {
	use strict;
	use Sys::Hostname;
	use lib $ENV{HOME} . '/lib/perl/modules';
	use M7Config;
}

# \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
# Module Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #

# Package Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub new {
	my $m7s = {
		_config		=> M7Config->new()
	};
	bless $m7s, M7Socket;
	return $m7s;
}

# Subroutine Shortcuts \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub config { return shift->{_config}; }

# Transmit Dashboard Alert Message \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub dashAlert {
	my $m7s = shift;
	my ($m7s_type, $m7s_msg) = @_;
	my $m7s_host = hostname;
	
	# Make sure the alert type is valid
	if ($m7s_type eq 'fatal' or $m7s_type eq 'error' or $m7s_type eq 'warn' or $m7s_type eq 'info') {
		
		# Construct the JSON string
		my $m7s_json = '{ "event": "alert", "host":"' . $m7s_host . '", "type":"' . $m7s_type . '", "msg":"' . $m7s_msg . '"}';
		
		# Construct the command string
		my $m7s_node_cmd = 'node ~/bin/m7-ws-client ' . $m7s->config->get('sio_ip') .
						   ' ' . $m7s->config->get('sio_port') . ' ' . $m7s->config->get('sio_proto') .
						   ' web_transmit \'' . $m7s_json . '\' ' . $m7s->config->get('sio_secret');
		
		# Transmit the message
		system($m7s_node_cmd);
		
	} else {
		return undef;	
	}
}