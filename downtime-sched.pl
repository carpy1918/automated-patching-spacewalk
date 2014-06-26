#!/usr/bin/perl -w

use strict;
use warnings;
use Frontier::Client;
use Frontier::RPC2;
use Convert::UU qw(uudecode uuencode);

my $spcwk_host = 'spacewalk.tealeafit.com';
my $spcwk_user = 'swuser';
my $spcwk_pass = 'password';
my @data;                       #db data array
my $spcwk_client;               #spacewalk call obj
my $spcwk_session;              #spacewalk session
my $sys_groups;                 #spacewalk array ref
my $pgroup='';                  #group holder for patchgrouplist
my @patchgrouplist;             #hold cmdb patch group list
my @patchgroupservers;          #hold cmdb patch server list
my $groupfound=0;               #cmdb group found in spacewalk or not
my $svrfound=0;                 #cmdb group found in spacewalk or not
my $result=0;
my @cmdbsvr;
my $email="curtis\@tealeafit.com";
my $group=shift();		#spacewalk group to process
my $date=shift();		#patching date
my $stime=shift();		#patching start time
my $etime=shift();		#patching end time
my $attach='';			#CSV file
my $battach;			#CSV file uuencoded

if($group eq '' || $date eq '' || $stime eq '' || $etime eq '')
{
  print "\nSyntax: perl downtime-sched.pl <group> <MM/DD/YYYY> <start_time> <end_time>\n";
  print "  Group is Spacewalk group - PB*\n";
  print "  MM/DD/YYYY - date of patching in exact form\n";
  print "  Maintenance window start time - 00:00\n";
  print "  Maintenance window end time - 00:00\n\n\n";
  exit;
}

#
#email function
#
sub email($)
{
  my $mail_from="curtis\@tealeafit.com";
  my $subject="CentOS Patching Window";
  my $mail_body=shift();
  my $sendmail="/usr/lib/sendmail -t";

  open(SENDMAIL, "|sendmail -t ") or die "Cannot open sendmail: $!";
  print (SENDMAIL "To: " . $email . "\nFrom: " . $mail_from . "\nSubject: " . $subject . "\n\n" . $mail_body);
#  print (SENDMAIL "To: " . $mail_to . "\nFrom: " . $mail_from . "\nContent-type: text/html\nSubject: " . $subject . "\n\n" . $mail_body);
  close(SENDMAIL);
} #end email

#
#processList
#
sub processList($)
{
  my $groupsvrlist = $spcwk_client->call('systemgroup.listSystems', $spcwk_session,shift());

  for my $a (@ {$groupsvrlist} )             #spacewalk servers
  {
    $attach = $attach . "$a->{hostname}.tribune,UTC,UTC,$date,$stime,$date,$etime\n";
  } #end spacewalk servers
  $battach=uuencode($attach,"svrdowntime-$group-$date.csv");
} #end processList

$spcwk_client=new Frontier::Client(url => "http://$spcwk_host/rpc/api");
$spcwk_session=$spcwk_client->call('auth.login', $spcwk_user, $spcwk_pass);
processList($group);				#get svrs in grp and create attachment
$spcwk_client->call('auth.logout', $spcwk_session);

email($battach);

