#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;
use Try::Tiny;
use DBI;

# ip
my $ip = $ARGV[0];
# mysql username
my $mysql_user = "MYSQL_USERNAME";
# mysql password 
my $mysql_password = "MYSQL_PASSWORD";
# return value requesteed (optional)
my $requested_return = $ARGV[1];

my $timeout = 5;
my $snmp_oid = "1.3.6.1.2.1.4.20.1.1";

if ( $#ARGV != 0 and $#ARGV != 1 )
{
    print " Not enough parameters\n";
    print " Usage: mysql_status_check.pl <IP> [<Return Value Requested>]\n";
    exit 2;
}

#
# Define the initial array
#

my %mysqlarr;

  # INDEX
  my $id1 = $ip;
  $mysqlarr{$id1}{uc("get_ip")} = $id1;


#
# Use array Values to query databases
#

my $dbserver;
my $dbh;
for $dbserver ( keys %mysqlarr) {
eval {
 $dbh = DBI->connect("DBI:mysql:database=mysql;host=$dbserver;mysql_connect_timeout=2",$mysql_user,$mysql_password,{RaiseError => 1,PrintWarn => 1});
};
#Collect mysql information (only works for single row queries or first row on multiple row queries)
%mysqlarr = AppendArray($dbh, $dbserver, "show slave status", %mysqlarr);
%mysqlarr = AppendArray($dbh, $dbserver, "select \@\@version as Version", %mysqlarr);
%mysqlarr = AppendArrayiMultiKeyValue($dbh, $dbserver, "show global status", %mysqlarr);

#Generate calculated values from populated data
%mysqlarr = MysqlStatus($dbh, $dbserver, %mysqlarr);
%mysqlarr = pretty_uptime($dbserver, %mysqlarr); 
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "com_begin", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "com_insert", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "com_commit", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "bytes_received", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "bytes_sent", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "questions", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "com_rollback", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "com_update", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "com_select", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "com_delete", %mysqlarr);
%mysqlarr = CalculateStatsAgainstUptime($dbserver, "queries", %mysqlarr);
eval{
#clenaup the database handle
$dbh->disconnect();
};
};

#
# PRINT RESULT withtout requested return
#
if (!$requested_return) {
my $id;
my $role;

my $firstline = 1;
print "{\n";
print "\t\"data\":[\n";

for $id ( keys %mysqlarr) {

  print "\t,\n" if not $firstline;
  $firstline = 0;

  print "\t{\n";

  my $all = "";

  for $role ( keys %{ $mysqlarr{$id} } ) {
    print "\t\t\"{#".$role."}\":\"" . $mysqlarr{$id}{$role} ."\",\n";
    $all .= "-".$mysqlarr{$id}{$role}."-";
  }
  print "\t\t\"{#".uc("all")."}\":\"" . $all ."\"\n";

  print "\t}\n";
}

print "\n\t]\n";
print "}\n";

#
# END PRINT RESULT
#
};


#
# PRINT RESULT with requested return 
#
if ($requested_return) {
 if (length $mysqlarr{$ip}{uc($requested_return)}) {
  print $mysqlarr{$ip}{uc($requested_return)};
 } else {
  print "Requested Value is not defined or is empty";
 }; 
};
#
# END PRINT RESULT
#


exit 0;

#
# [private functions]
#
sub _exit
{
   printf join('', sprintf("%s: ", "mysql_status_check.pl"), shift(@_), ".\n"), @_;
   exit 1;
}

## Needs Database Handle, database server, query to run,  source array
sub AppendArray{
 my ($dbh, $server, $query, %inarr) = @_;
 if ($dbh) {
 my $sth = $dbh->prepare("$query");
 $sth->execute();
 my $columns = $sth->{NAME};
 my $ref = $sth->fetchrow_arrayref;
 my $numColumns = $sth->{'NUM_OF_FIELDS'} -1;
 for my $i ( 0..$numColumns ) {
     if($ref) {
         $inarr{$server}{uc($$columns[$i])} = $$ref[$i];
     };
 };
 $sth->finish();
};
 return %inarr;
};



## Needs Database Handle, database server, query to run,  source array
## appends a query which returns two columns of key value pairs
sub AppendArrayiMultiKeyValue{
 my ($dbh, $server, $query, %inarr) = @_;
 if($dbh) {
 my $sth = $dbh->prepare("$query");
 $sth->execute();
 my $columns = $sth->{NAME};
 my $numColumns = $sth->{'NUM_OF_FIELDS'} -1;
 while (my $ref = $sth->fetchrow_arrayref){
     if($ref) {
         $inarr{$server}{uc($$ref[0])} = $$ref[1];
     };
 };
 $sth->finish();
 };
 return %inarr;
};

sub MysqlStatus{
    my ($dbh, $server, %inarr) = @_;
    my $isUp = 0;
    if ($dbh) {
	$isUp = 1;    
    };	
   $inarr{$server}{uc("dbstatus")} = $isUp;
return %inarr;
};


# Average Statistics since server was started, not current as of this minute stats
sub CalculateStatsAgainstUptime {
    my ($server, $stat_to_calc, %inarr) = @_;
eval {
    if (length $inarr{$server}{uc($stat_to_calc)}) { 
        my $var = ($inarr{$server}{uc($stat_to_calc)} / $inarr{$server}{uc("uptime")});
        $inarr{$server}{uc($stat_to_calc . "_per_second")} = $var; 
    };
};
    return %inarr;
};



sub pretty_uptime {
    my ($server, %inarr) = @_;
    my $uptime = $inarr{$server}{uc("uptime")};
    if ($uptime) {
        my $seconds = $uptime % 60;
	my $minutes = int(($uptime % 3600) / 60);
	my $hours = int(($uptime % 86400) / (3600));
	my $days = int($uptime / (86400));
	my $uptimestring;
        if ($days > 0) {
            $uptimestring = "${days}d ${hours}h ${minutes}m ${seconds}s";
        } elsif ($hours > 0) {
            $uptimestring = "${hours}h ${minutes}m ${seconds}s";
        } elsif ($minutes > 0) {
            $uptimestring = "${minutes}m ${seconds}s";
        } else {
            $uptimestring = "${seconds}s";
        };
        $inarr{$server}{uc("prettyuptime")} = $uptimestring;
    };
    return %inarr;
};

