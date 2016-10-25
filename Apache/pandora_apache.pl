#!/usr/bin/perl
use strict;
use warnings;
# use XML::Simple;

# v1.1 - 25/10/16
#   david.tabernero@inclam.com
#		- Modify the script to let us use it without user/pass
#		- Fix "Apache B/request" regex

sub parseo_fichero($$){

my $config = $_[0];
my $fichero = $_[1];

my $ax=0;

	open (CFG, $fichero);	

	while (<CFG>){
		if ($_ =~ /Restart Time: ([aA-zZ]+\,\s[0-9]{2}\-[aA-zZ]{3}\-[0-9]{4}\s[0-9]{2}\:[0-9]{2}\:[0-9]{2}\s[aA-zZ]+)/ ) {
			
			$config->[$ax]->{"ApacheRestartTime"} = $1;
		}

		if ($_ =~ /Server uptime: ([aA-zZ 0-9]+)/) {
			
			$config->[$ax]->{"ApacheServerUptime"} = $1;
		}

		if ($_ =~ /Total accesses: ([0-9]+)/ ) {
			
			$config->[$ax]->{"ApacheTotalAccesses"} = $1;
		}

		if ($_ =~ /Total Traffic: ([0-9]+)/ ) {
			
			$config->[$ax]->{"ApacheTotalTraffic"} = $1;
		}

		if ($_ =~ /(\.[0-9]+)\%\sCPU\sload/) {

			print "<module>\n";
			print "<name>Apache CPU Load</name>\n";
			print "<type>generic_data</type>\n";
			print "<data>0$1</data>\n";
			print "</module>\n";

		}elsif ($_ =~ /([0-9]+\.[0-9]+)\%\sCPU\sload/ ) {

			print "<module>\n";
			print "<name>Apache CPU Load</name>\n";
			print "<type>generic_data</type>\n";
			print "<data>$1</data>\n";
			print "</module>\n";
		}

		if ($_ =~ /(\.[0-9]+)\srequests\/sec/) {
			
			print "<module>\n";
			print "<name>Apache requests/sec</name>\n";
			print "<type>generic_data</type>\n";
			print "<data>0$1</data>\n";
			print "</module>\n";

		}elsif ($_ =~ /([0-9]+\.[0-9]+)\srequests\/sec/ ) {

			print "<module>\n";
			print "<name>Apache requests/sec</name>\n";
			print "<type>generic_data</type>\n";
			print "<data>$1</data>\n";
			print "</module>\n";
		}

		if ($_ =~ /([0-9]+)\sB\/second/) {
			
			$config->[$ax]->{"Apache B/second"} = $1;
		}

		if ($_ =~ /([0-9]+)\skB\/request/) {
			
			$config->[$ax]->{"Apache B/request"} = $1;
		}

		if ($_ =~ /([0-9]+)\srequests\scurrently/) {
			
			$config->[$ax]->{"ApacheCurrentRequests"} = $1;
		}

		if ($_ =~ /([0-9]+)\sidle\sworkers/) {
			
			$config->[$ax]->{"ApacheIdleWorkers"} = $1;
		}

	}

}

my %datos;
my $dato;
my $numArgs = $#ARGV;
my $cont = 0;
my @arg;
my $user;
my $pass;
my $url;
my $file = "/tmp/pandora_apache.tmp";
my $command;
my @config;

# TODO: Introducir este script en el servidor JBoss junto con un agente Pandora para el correcto funcionamiento del mismo

	if ($numArgs == 3)
	{
		$user = $ARGV[0];
		$pass = $ARGV[1];
		$url = $ARGV[2];

		$command = `wget -o /dev/null $user $pass -O $file $url`;
	}
	else
	{
		$url = $ARGV[0];
		
		$command = `wget -o /dev/null  -O $file $url`;
	}


	parseo_fichero(\@config, $file);

foreach (@config) {

$datos{"ApacheRestartTime"} = "$_->{'ApacheRestartTime'}";
$datos{"ApacheServerUptime"} = "$_->{'ApacheServerUptime'}";
$datos{"ApacheTotalAccesses"} = "$_->{'ApacheTotalAccesses'}";
$datos{"ApacheTotalTraffic"} = "$_->{'ApacheTotalTraffic'}";
$datos{"Apache B/second"} = "$_->{'Apache B/second'}";
$datos{"Apache B/request"} = "$_->{'Apache B/request'}";
$datos{"ApacheCurrentRequests"} = "$_->{'ApacheCurrentRequests'}";
$datos{"ApacheIdleWorkers"} = "$_->{'ApacheIdleWorkers'}";

foreach $dato(keys %datos){

	if (defined($datos{$dato})){

		print "<module>\n";
		print "<name>$dato</name>\n";
	
		if ($datos{$dato} =~ /[aA-zZ]|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|[?]/){
			print "<type>generic_data_string</type>\n";
		}else{
			print "<type>generic_data</type>\n";
		}
		print "<data>$datos{$dato}</data>\n";
		print "</module>\n";
		}
	}
}
