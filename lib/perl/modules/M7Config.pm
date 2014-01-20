#!/usr/bin/perl

# Package Name \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
package M7Config;

# Module Dependencies \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
BEGIN {
	use strict;
}

# Package Constructor \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub new {
	my $m7c = {
		_home			=> ( defined($ENV{HOME}) ? $ENV{HOME} : '/opt/vpls/m7' )
	};
	bless $m7c, M7Config;
	return $m7c;
}

# Configuration Subroutines \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #
sub home { return shift->{_home}; }
sub get  {
	my $m7c = shift;
	use feature 'switch';	
	my ($m7c_directive) = @_;
	
	# Retrieve the configuration parameter
	given ($m7c_directive) {
		
		# Database configuration
		when ('db_name')      { return 'm7'; }
		when ('db_host')      { return 'localhost'; }
		when ('db_port')      { return '3306'; }
		when ('db_user')      { return 'm7'; }
		when ('db_pass')      { return 'password'; }
		
		# Server configuration
		when ('pidfile')      { return $m7c->home . '/run/m7d.pid'; }
		when ('service')      { return 'm7d'; }
		when ('lock')         { return $m7c->home . '/lock/subsys/m7d'; }
		
		# GeoIP configuration
		when ('geo_db')       { return '/usr/local/share/GeoIP/GeoLiteCity.dat'; }
		
		# Logging configuration
		when ('log_conf_m7')  { return $m7c->home . '/lib/perl/log/m7.conf'; }
		when ('log_conf_m7p') { return $m7c->home . '/lib/perl/log/m7p.conf'; }
		when ('log_conf_m7d') { return $m7c->home . '/lib/perl/log/m7d.conf'; }
		when ('log_file_m7')  { return $m7c->home . '/log/client.log'; }
		when ('log_file_m7p') { return $m7c->home . '/log/parse.log'; }
		when ('log_file_m7d') { return $m7c->home . '/log/server.log'; }
		
		# Socket.IO Options
		when ('sio_name')	  { return 'm7-ws-server'; }
		when ('sio_pid')	  { return $m7c->home . '/run/m7-ws-server.pid'; }
		when ('sio_lock')	  { return $m7c->home . '/lock/subsys/m7-ws-server'; }
		when ('sio_log')	  { return $m7c->home . '/log/socket-io.log'; }
		when ('sio_ip')       { return 'localhost'; }
		when ('sio_port')     { return '1337'; }
		when ('sio_proto')    { return 'http'; }
		when ('sio_secret')   { return 'supersecret'; }
		
		# Socket.IO SSL Options
		when ('sio_ssl_cert') { return '/etc/pki/tls/certs/mycert.crt'; }
		when ('sio_ssl_key')  { return '/etc/pki/tls/private/mykey.key'; }
		when ('sio_ssl_ca')   { return '/etc/pki/tls/private/myca.ca'; }
		
		# Invalid configuration parameter
		default { return undef; }
	}
}

1;