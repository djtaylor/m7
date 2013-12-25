#!/usr/bin/perl -T

use utf8;
use strict;

my $lasthop = 0;
my @traceroute;

while(<>){
        if(/(\d+)\.\|\-\-\s+(\d+\.\d+\.\d+\.\d+)\s+([\d\.]+)%\s+(\d+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)/) {
                my ($hop, $ip, $loss, $sent, $last, $avg, $best, $wrst, $stdev) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
                my %trace = (
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
                push(@traceroute, \%trace);
                $lasthop = $hop;
        }
        if(/\|\s+`?\|--\s+(\d+\.\d+\.\d+\.\d+)/) {
                push(@{$traceroute[-1]->{ip}}, $1);
        }
        if(/(\d+)\.\|--\s\?\?\?/){
                my $hop = $1;
                my %trace = ('hop' => $hop, 'ip' => ['0.0.0.0'], 'loss' => 100, 'avg' => 0, 'best' => 0, 'wrst' => 0, 'stdev' => 0);
                push(@traceroute, \%trace);
                $lasthop = $hop;
        }
}

print "\t\t\t<hops>\n";
foreach my $hop (@traceroute){
        print "\t\t\t\t<hop number=\"$hop->{hop}\">\n";
        print "\t\t\t\t\t<ips>\n";
        print "\t\t\t\t\t\t<ip>$_</ip>\n" foreach (@{$hop->{ip}});
        print "\t\t\t\t\t</ips>\n";
        print "\t\t\t\t\t<pktLoss unit=\"%\">$hop->{loss}</pktLoss>\n";
        print "\t\t\t\t\t<minTime unit=\"ms\">$hop->{best}</minTime>\n";
        print "\t\t\t\t\t<avgTime unit=\"ms\">$hop->{avg}</avgTime>\n";
        print "\t\t\t\t\t<maxTime unit=\"ms\">$hop->{wrst}</maxTime>\n";
        print "\t\t\t\t\t<avgDev unit=\"ms\">$hop->{stdev}</avgDev>\n";
        print "\t\t\t\t</hop>\n";
}
print "\t\t\t<\hops>\n";