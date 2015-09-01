#!/usr/bin/perl

use strict;
use warnings;

use Net::SNMP v5.1.0 qw(:snmp DEBUG_ALL);
use Getopt::Std;

my $snmp_community = $ARGV[0];
# ip
my $ip = $ARGV[1];
# mysql username
my $mysql_user = "MYSQL_USERNAME";
# mysql password 
my $mysql_password = "MYSQL_PASSWORD";


my $timeout = 5;
my $snmp_oid = "1.3.6.1.2.1.4.20.1.1";

if ( $#ARGV != 1 )
{
    print " Not enough parameters\n";
    print " Usage: snmp_mysql_status_discovery.pl <SNMP_COMMUNITY> <IP>\n";
    exit 2;
}

my ($s, $e) = Net::SNMP->session(
   -hostname => $ip,
   -version  => 1,
   -community    =>  $snmp_community,
#   -debug => DEBUG_ALL,
#   exists($OPTS{a}) ? (-authprotocol =>  $OPTS{a}) : (),
#   exists($OPTS{A}) ? (-authpassword =>  $OPTS{A}) : (),
#   exists($OPTS{D}) ? (-domain       =>  $OPTS{D}) : (),
#   exists($OPTS{d}) ? (-debug        => DEBUG_ALL) : (),
#   exists($OPTS{m}) ? (-maxmsgsize   =>  $OPTS{m}) : (),
#   exists($OPTS{r}) ? (-retries      =>  $OPTS{r}) : (),
#   exists($OPTS{t}) ? (-timeout      =>  $OPTS{t}) : (),
#   exists($OPTS{u}) ? (-username     =>  $OPTS{u}) : (),
#   exists($OPTS{v}) ? (-version      =>  $OPTS{v}) : (),
#   exists($OPTS{x}) ? (-privprotocol =>  $OPTS{x}) : (),
 #  exists($OPTS{X}) ? (-privpassword =>  $OPTS{X}) : ()
);

# Was the session created?
if (!defined($s)) {
   _exit($e);
}

#
# WALK
#
my @args = (-varbindlist    => [$snmp_oid] );

my $oid;

my %snmparr;


while (defined($s->get_next_request(@args)))
{
  $oid = ($s->var_bind_names())[0];

  if (!oid_base_match($snmp_oid, $oid)) { last; }

  # INDEX
  my $id1 = $s->var_bind_list()->{$oid};
  $snmparr{$id1}{"get_ip"} = $id1;

  # NAME
#  my $oid_name = $snmp_oid.$id1;
#  my $rs = $s->get_request(-varbindlist => [$oid_name],);

  #$snmparr{$id1}{"name"} = $rs->{$oid_name};

#  print "DEBUG:\n oid: ". $oid . " \n oid_name: " .$oid_name . "\n name: " . $rs->{$oid_name} . "\n";

  #OperStatus
  #my $oid_status = $snmp_oid.$id1;
  #my $rs2 = $s->get_request(-varbindlist => [$oid_status],);

  #$snmparr{$id1}{"status"} = $rs2->{$oid_status};

 # print "DEBUG:\n oid: ". $oid . " \n oid_status: " .$oid_name . "\n status: " . $rs2->{$oid_status} . "\n";


  @args = (-varbindlist => [$oid]);
}

#
# Use SNMP Values to query databases
#

use DBI;
use Try::Tiny;
my %mysqlarr = %snmparr;
my $dbserver;
for $dbserver ( keys %snmparr) {
#print "\nWorking On " . $dbserver .  "\n";
eval {

my $dbh = DBI->connect("DBI:mysql:database=mysql;host=$dbserver;mysql_connect_timeout=2",$mysql_user,$mysql_password,{RaiseError => 1,PrintWarn => 1});

#Collect mysql information (only works for single row queries or first row on multiple row queries)
%mysqlarr = AppendArray($dbh, $dbserver, "show slave status", %mysqlarr);
%mysqlarr = AppendArray($dbh, $dbserver, "select \@\@version as Version", %mysqlarr);

#clenaup the database handle
$dbh->disconnect();
};
};

## Needs Database Handle, database server, query to run,  source array
sub AppendArray{
 my ($dbh, $server, $query, %inarr) = @_;
 #print $server . "\n";
 #print $query . "\n";
 my $sth = $dbh->prepare("$query");
 $sth->execute();
 my $columns = $sth->{NAME};
 my $ref = $sth->fetchrow_arrayref;
 my $numColumns = $sth->{'NUM_OF_FIELDS'} -1;
 #print "query returned: " . $numColumns . " columns\n";
 #print "Query returned " . scalar($sth->rows) . " rows.\n";
 #for my $i ( 0..$numColumns ) {
 #   print $$columns[$i] . "=" . $$ref[$i] . "\n";
 #};

for my $i ( 0..$numColumns ) {
     if($ref) {
         $inarr{$server}{$$columns[$i]} = $$ref[$i];
     };
 };
 $sth->finish();
return %inarr;
};

#print "\n";
#
# PRINT RESULT
#
my %arr = %mysqlarr;
my $id;
my $role;

my $firstline = 1;
print "{\n";
print "\t\"data\":[\n";

for $id ( keys %arr) {

  print "\t,\n" if not $firstline;
  $firstline = 0;

  print "\t{\n";

  my $all = "";

  for $role ( keys %{ $arr{$id} } ) {
    print "\t\t\"{#".uc($role)."}\":\"" . $arr{$id}{$role} ."\",\n";
    $all .= "-".$arr{$id}{$role}."-";
  }
  print "\t\t\"{#".uc("all")."}\":\"" . $all ."\"\n";

  print "\t}\n";
}

print "\n\t]\n";
print "}\n";

#
# END
#
$s->close();

exit 0;

#
# [private functions]
#
sub _exit
{
   printf join('', sprintf("%s: ", "snmp_mysql_status_discovery.pl"), shift(@_), ".\n"), @_;
   exit 1;
}

