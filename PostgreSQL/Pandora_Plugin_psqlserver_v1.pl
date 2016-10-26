#!/usr/bin/perl -w

###############################################################################
#                  Pandora FMS Plugin for PostgreSQL                          #
#                          (c) Artica ST 2013		                      #		
#                          v1.0, 13 Abril 2013                                #   
# 									      #
#                Carlos E. García  <carlos.garcia@artica.es>                  #
#                                                                             #
###############################################################################
# v1.0.1 - 25/10/16
#	david.tabernero@inclam.com
# 		- Fix for Ubuntu 14.04
# -----------------------------------------------------------------------------
# Default lib dir for RPM and DEB packages
use lib '/usr/lib/perl5';
use strict;
use warnings;
use DBI;

# -----------------------------------------------------------------------------
# 0. Global parameters
# -----------------------------------------------------------------------------
my $dbname="";
my $host="";
my $port="";
my $username="";
my $password="";
my %modules;		
my $file=$ARGV[0];	
my $dbh;				
my $servstat;		

###############################################################################
################################ FUNCTIONS ####################################
###############################################################################

# -----------------------------------------------------------------------------
# 1. Errase blank spaces before and after the string
# -----------------------------------------------------------------------------
sub trim($){
	my $string = $_[0];
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
# -----------------------------------------------------------------------------
# 2. Print modules
# -----------------------------------------------------------------------------
sub print_module{
	my $name = $_[0];
	my $data = $_[1];
	my $description = $_[2];
	my $datatype = $_[3];
	my $severity = $_[4];
	
	&trim($name);
	&trim($data);
	&trim($description);
	print "\t<module>\n";
	print "\t<name>$name</name>\n";

	if ($datatype eq "generic"){
		print "\t<type><![CDATA[generic_data]]></type>\n";
	} 
	
	elsif ($datatype eq "incremental"){
		print "\t<type><![CDATA[generic_data_inc]]></type>\n";
	}
	
	elsif ($datatype eq "string"){
		print "\t<type><![CDATA[generic_data_string]]></type>\n";
	} 
	elsif ($datatype eq "boolean"){
		print "\t<type><![CDATA[generic_proc]]></type>\n";
	}
	print "\t<data>$data</data>\n";
	print "\t<description>$description</description>\n";
		if (defined($severity)) {
			print "\t<status>$severity</status>\n";    
		} 
	
		else {
			print "\t<status>NORMAL</status>\n";  	
		}
	print "\t</module>\n";
}

# ----------------------------------------------------------------------------------------
#  3. Configuration settings for connecting to databases and load defined user modules
# ----------------------------------------------------------------------------------------
sub load_external_setup() {
	open (FILE,$file);
	my $line;
	my @data;
	my $numUser = 0;
	while($line=<FILE>){
		if ($line =~ /^\#/ || $line =~ /^\s/ ){
			next;
		}
           							
		elsif ($line =~ /dbname\s*=\s*/){
			@data=split('=',$line); #to take the values ​​of each line and insert in an array
			$dbname = &trim($data[1]);
		}
 
    		elsif ($line =~ /host\s*=\s*/){
			@data=split('=',$line);            				
			$host =  &trim($data[1]);
       		}		
	       	
		elsif ($line =~ /port\s*=\s*/){
			@data=split('=',$line);            				
			$port =  &trim($data[1]);
		}

		elsif ($line =~ /username\s*=\s*/){
			@data=split('=',$line);            				
			$username =  &trim($data[1]);
		}

		elsif ($line =~ /password\s*=\s*/){
			@data=split('=',$line);            				
			$password = &trim($data[1]);
		}

		elsif ($line =~ /usermod/ ){# user-defined modules
			while (($line = <FILE>)){
				trim($line);
				if ($line =~ /name\s*=\s*"{1}[a-zA-z0-9\s()-_]*"{1}/){
   					@data=split(/=\s*/, $line);
					$data[1] =~ s/"//g;
					$modules{$numUser."name"}=&trim($data[1]);
				}

				elsif ($line =~ /description\s*=\s*"{1}[a-zA-z0-9\sºª()-_]*"{1}/){
					@data = split(/=\s*/, $line);
					$data[1] =~ s/"//g;
					$modules{$numUser."description"}=&trim($data[1]);
				}

                elsif ($line =~ /query\s*:=\s*"[a-zA-z0-9\s\*();=\.ºª\/\+\>]*;{1}"{1}/){
					@data=split(/:=\s*/, $line);
				    	$data[1] =~ s/"//g;
				    	$modules{$numUser."query"}=&trim($data[1]);	
				}

				elsif ($line =~ /type\s*=\s*"[a-zA-Z_]*"{1}/){
				    	@data=split(/=\s*/, $line);
				    	$data[1] =~ s/"//g;
				    	$modules{$numUser."type"}=&trim($data[1]);
				}

				elsif ($line =~ /end\s*/){
					if (!defined($modules{$numUser."type"})){
						$modules{$numUser."type"}="generic";
					}
						$modules{$numUser}=1;
					        $numUser++;
					        last;
				}
				
				elsif ($line =~ /usermod/){
					next;
				}
				
				elsif ($line =~ /^\#/){# skip comment lines
					next;
				}

			        else{# skip what does not interest us
					next;
				}
			}
		}
	}
	close FILE;
}



# -----------------------------------------------------------------------------
#  4. To connect database
# -----------------------------------------------------------------------------
sub db_conection{
	my $conection_db = DBI->connect("dbi:Pg:dbname=$dbname;host=$host;port=$port",
                      $username,
                      $password,
                      {AutoCommit => 0, RaiseError => 0, PrintError => 0}
                     );

	return $conection_db;
}

#------------------------------------------------------------------------------
#  5. Performs monitoring defined by user 
#------------------------------------------------------------------------------
sub monitors_user{
	my $usermod = 0;

	# Modules defined in config file
	while(defined($modules{$usermod})){
		my @query_aux = $dbh->selectrow_array( $modules{$usermod."query"});
		print_module($modules{$usermod."name"},$query_aux[0], $modules{$usermod."description"},$modules{$usermod."type"});
		$usermod++;
	}
}

# -----------------------------------------------------------------------------
#  5. Run the basic modules 
# -----------------------------------------------------------------------------
sub load_modules{

	psql_server_status();
	
	psql_cpu();
	
	psql_memory();
}

# -----------------------------------------------------------------------------
# 6. Check state of Postgres server
# -----------------------------------------------------------------------------
sub psql_server_status(){
	my $name = "PSQL Server Status";
	my $type = "boolean";
	my $result = 0;
	my $psql_status = `ps aux | grep -v "grep" | grep "postgres" | awk '{print \$11}'`;
	

	if ($psql_status =~ m[postgres:] || $psql_status =~ m[/usr/bin/postmaster] || $psql_status =~ m[/usr/bin/postgres] || $psql_status =~ m[usr/lib/postgresql/8.4/bin/postgres] || $psql_status =~ m[/usr/lib/postgresql/9.1/bin/postgres]){
		$result=1;
		print_module($name,$result,"Information Sever Status",$type);
		$servstat = 1;
	} else {
		print_module($name,$result,"Information Sever Status",$type,"CRITICAL");
		$servstat = 0;
	}
}

# ----------------------------------------------------------------------
# 7. Check Postgre cpu usage
# ----------------------------------------------------------------------
sub psql_cpu {
	my @psql_cpu_result;
	my $name = "PSQL Cpu Usage";
	my $result = 0;
	my $element = 0;
	my $type = "generic";

	if ($servstat == 1){
	
		@psql_cpu_result = `ps aux | grep -v "grep" | grep "postgres" | awk '{print \$3}'`;
	
		foreach $element(@psql_cpu_result) {
			$result += $element;
		}

		if (($result > 50) && ($result<75)){
			print_module($name,$result,"Information about Cpu percent usage for Postgresql",$type,"WARNING");
		}
	
		elsif ($result >= 75) {
			print_module($name,$result,"Information about Cpu percent usage for Postgresql",$type,"CRITICAL");
		}
	
		else{
			print_module($name,$result,"Information about Cpu percent usage for Postgresql",$type);
		}
	} else {
			print_module($name,$result,"Information about Cpu percent usage for Postgresql",$type,"CRITICAL")		
	}
}

# ----------------------------------------------------------------------
# 8. Check Postgres memory usage
# ----------------------------------------------------------------------
sub psql_memory {
	my @psql_cpu_result;
	my $name = "PSQL Memory Usage";
	my $result = 0;
	my $element = 0;
	my $type = "generic";
	
	if ($servstat == 1){	
		@psql_cpu_result = `ps aux | grep -v "grep" | grep "postgres" | awk '{print \$4}'`;
		foreach $element(@psql_cpu_result) {
			$result += $element;
		}
		
		print_module($name,$result,"Information about Memory percent usage for Postgresql",$type);
	} else {
		print_module($name,$result,"Information about Memory percent usage for Postgresql",$type,"CRITICAL");	
	}
}

###############################################################################
############################ MAIN PROGRAM CODE ################################
###############################################################################
load_external_setup();

# -----------------------------------------------------------------------------
# Trhowing monitorings
# -----------------------------------------------------------------------------
$dbh = db_conection();
if (defined ($dbh)){	
	load_modules();
	monitors_user();
	my $rc = $dbh->disconnect();
	exit;
}
else{
	load_modules();	
	exit;
}



