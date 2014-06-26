#!/usr/bin/perl

#
#Produce reports for the patch events
#

use strict;
use Frontier::Client;
use Frontier::RPC2;
use POSIX qw(strftime);
use Date::Simple;

my $failedentries='';					#failed entries data file
my $compentries='';					#completed entries data file
my $spcwk_host = 'spacewalk.tealeafit.com';
my $spcwk_user = 'apiuser';
my $spcwk_pass = 'Api#Pas0420';
my $spcwk_client;
my $spcwk_session;
my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)=localtime(time);
($sec,$min,$hour,my $pday,my $pmonth,$year,$wday,$yday,$isdst)=localtime(time-60*60*24*7);
my $failnum;
my $failwknum;
my $compnum;
my $compwknum;
my $failsvrsnum;
my $failsvrswknum;
my $compsvrsnum;
my $compsvrswknum;
my $rtype='';						#report type - summary or failure
my $report='';						#report output
my %ecount;						#errata info holder
my %scount;						#errata server info holder
my %failures;
my %completed;
my %data;						#generic data file holder
my %failcount;						#holds failed patch count per server
my %compcount;						#holds completed patch count per server
my %fplist;						#failed packages string by svr
my %cplist;						#completed packages string by svr
my %fpkglistcount;					#failed pkg list count
my %cpkglistcount;					#completed pkg list count
my $grplist;						#ref to groupList array
my $grpfsvrcount=0;					#patch group failed svr count
my $grpcsvrcount=0;					#patch group completed svr count
my $svrcount=0;
my $svrl='';						#string list of svrs patched
my %svrlist;						#hold the unique svr list
my $grpfpkgcount=0;
my $grpcpkgcount=0;
$rtype=shift();
my $grpname=shift();
my @svrs;
my $svrstr='';
my $pdate01;
my $pdate02;
my $pdate03;
my $pdate04;
my $pdate05;
my $pdate06;
my $pdate07;
my %idmap;						#hash to hold id, svr name pairs

$year=$year+1900;
$pmonth = $month;
$pmonth=12 if $pmonth == 0;
$month = $month + 1;

$pmonth=addzero($pmonth);
$month=addzero($month);
$day=addzero($day);

my $date="$month\-$day\-$year";
my $sdate = Date::Simple->new($date);

#
##int to string date stamp
#
sub addzero()
{
  my $v = shift();
  if($v == 1 || $v == 2 || $v == 3 || $v == 4 || $v == 5 || $v == 6 || $v == 7 || $v == 8 || $v == 9)
  {
    my $t = "0" . $v;
    return $t;
  }
  else 
  { return $v }
}

#
##date range
#
sub daterange()
{
  my $pdate01 = $sdate -1;
  my $pdate02 = $sdate -2;
  my $pdate03 = $sdate -3;
  my $pdate04 = $sdate -4;
  my $pdate05 = $sdate -5;
  my $pdate06 = $sdate -6;
  my $pdate07 = $sdate -7;

  $pdate01 =~ s/....-..-//g;
  $pdate02 =~ s/....-..-//g;
  $pdate03 =~ s/....-..-//g;
  $pdate04 =~ s/....-..-//g;
  $pdate05 =~ s/....-..-//g;
  $pdate06 =~ s/....-..-//g;
  $pdate07 =~ s/....-..-//g;

  print "date range: $pdate01 $pdate02 $pdate03 $pdate04 $pdate05 $pdate06 $pdate07\n";
} #end dates

#
##email function
##
sub email($)
{
  my $mail_to;
  if($rtype =~ /[S|s]ummary/)
  { 
    $mail_to="xcxccarpenter\@tealeafit.com, curtis\@tealeafit.com, glowilliams\@tealeafit.com, mdobbertien\@tealeafit.com, rkelley\@tealeafit.com, DABucknor\@tealeafit.com";}
    #$mail_to="xcxccarpenter\@tealeafit.com";}
  else
  { 
    $mail_to="xcxccarpenter\@tealeafit.com, curtis\@tealeafit.com";
    #$mail_to="xcxccarpenter\@tealeafit.com";
  }
  my $mail_from="curtis\@tealeafit.com";
  my $subject="CentOS Patching Report";
  my $mail_body=shift();
  my $sendmail="/usr/lib/sendmail -t";

  open(SENDMAIL, "|sendmail -t ") or die "Cannot open sendmail: $!";
  print (SENDMAIL "To: " . $mail_to . "\nFrom: " . $mail_from . "\nMIME-version: 1.0" , "\nContent-type: text/html" . "\nSubject: " . $subject . "\n\n" . $mail_body);
  close(SENDMAIL);
} #end email

#
##errata stats
#
sub erratastats()
{
  open(efh,"/tmp/errata-outstanding.log") or die('cannot open file');
  while(<efh>)
  {
    my $entry=$_;
    chomp($entry);
    my @t;

    @t=split(/ /,$entry);
    push(@{$data{$t[0]}}, $t[1]);
  }

  foreach my $key ( keys %data )
  {
    my $str = '';
    my $count = 0;
    foreach(@{$data{$key}})
    {
      $str = $str . $_ . ", ";
      $count++;
    } #end foreach
    $str =~ s/, $//g;
    $ecount{$key}=$count;
    $scount{$key}=$str;
  } #end foreach
} #end erratastats

#
##generate data
#
sub gendata()
{
  print "gendata: month: $month previous month: $pmonth day: $day year: $year\n";
  `spacewalk-report system-history-packages | grep -e "\\-$pmonth\\-" | grep 'Completed' > /tmp/sw-completed.log`;
  `spacewalk-report system-history-packages | egrep -e "\\-\\($pdate01|$pdate02|$pdate03|$pdate04|$pdate05|$pdate06|$pdate07\\) " | grep 'Completed' > /tmp/sw-completed-weekly.log`;
  `spacewalk-report system-history-packages | grep -e "\\-$pmonth\\-" | grep 'Failed' > /tmp/sw-failed.log`;
  `spacewalk-report system-history-packages | egrep -e "\\-\\($pdate01|$pdate02|$pdate03|$pdate04|$pdate05|$pdate06|$pdate07\\) " | grep 'Failed' > /tmp/sw-failed-weekly.log`;
  `spacewalk-report errata-systems | awk -F ',' '{print \$3" "\$1}' | sort > /tmp/errata-outstanding.log`;
  `cat /tmp/sw-completed.log | awk '{ print \$1}' | sort | wc -l > /tmp/sw-completed-num.log`;
  `cat /tmp/sw-completed-weekly.log | awk '{ print \$1}' | sort | wc -l > /tmp/sw-completed-wk-num.log`;
  `cat /tmp/sw-failed.log | awk '{ print \$1}' | sort | wc -l > /tmp/sw-failed-num.log`;
  `cat /tmp/sw-failed-weekly.log | awk '{ print \$1}' | sort | wc -l > /tmp/sw-failed-wk-num.log`;
  `cat /tmp/sw-completed.log | awk -F ',' '{print \$1}' | sort | uniq | wc -l > /tmp/sw-completed-svrs-num.log`;
  `cat /tmp/sw-completed-weekly.log | awk -F ',' '{print \$1}' | sort | uniq | wc -l > /tmp/sw-completed-svrs-wk-num.log`;
  `cat /tmp/sw-failed.log | awk -F ',' '{print \$1}' | sort | uniq | wc -l > /tmp/sw-failed-svrs-num.log`;
  `cat /tmp/sw-failed-weekly.log | awk -F ',' '{print \$1}' | sort | uniq | wc -l > /tmp/sw-failed-svrs-wk-num.log`;

  $failnum=`cat /tmp/sw-failed-num.log`;
  $failwknum=`cat /tmp/sw-failed-wk-num.log`;
  $compnum=`cat /tmp/sw-completed-num.log`;
  $compwknum=`cat /tmp/sw-completed-wk-num.log`;
  $failsvrsnum=`cat /tmp/sw-failed-svrs-num.log`;
  $failsvrswknum=`cat /tmp/sw-failed-svrs-wk-num.log`;
  $compsvrsnum=`cat /tmp/sw-completed-svrs-num.log`;
  $compsvrswknum=`cat /tmp/sw-completed-svrs-wk-num.log`;
} #gendata

#
##failure data
#
sub faildata() {

  while(<fh1>)
  {
    my $r;
    my $sname;
    my $str=$_;
    my @svr=split(',',$str);
    my $id=$svr[0];

    chomp($svr[8]);
    if($idmap{$id})
    { 
      $r = checkgroup($idmap{$id});
      $failures{$idmap{$id}}{"$svr[1]"}=[$svr[0], $svr[2], $svr[3], $svr[4], $svr[5], $svr[6], $svr[7], $svr[8]] if $r == 0;
      $svrlist{$idmap{id}}=1;
#      print "faildata: hit cache: $idmap{$id} : $svr[1] : $svr[0], $svr[2], $svr[3], $svr[4], $svr[5], $svr[6], $svr[7], $svr[8]\n";
    }
    else
    {
      my $svrentry=$spcwk_client->call('system.getName',$spcwk_session,$id);
      $idmap{$id}=$svrentry->{'name'};
      $r = checkgroup($svrentry->{'name'});
      $failures{$svrentry->{'name'}}{"$svr[1]"}=[$svr[0], $svr[2], $svr[3], $svr[4], $svr[5], $svr[6], $svr[7], $svr[8]] if $r == 0;
      $svrlist{$svrentry->{'name'}}=1;
#      print "$svrentry->{'name'} : $svr[1] : $svr[0], $svr[2], $svr[3], $svr[4], $svr[5], $svr[6], $svr[7], $svr[8]\n";
    }
  } #end while
  
} #end faildata

#
##completed patching data
#
sub compdata {

  while(<fh2>)
  {
    my $r;
    my $sname;
    my $str=$_;
    my @svr=split(',',$str);
    my $id=$svr[0];
    if($idmap{$id})
    {
      chomp($svr[8]);
      $r = checkgroup($idmap{$id});
      $completed{$idmap{$id}}{"$svr[1]"}=[$svr[0], $svr[2], $svr[3], $svr[4], $svr[5], $svr[6], $svr[7], $svr[8]] if $r == 0;
      $svrlist{$idmap{id}}=1;
#      print "compdata: hit cache: $idmap{$id} : $svr[1] : $svr[0], $svr[2], $svr[3], $svr[4], $svr[5], $svr[6], $svr[7], $svr[8]\n";
    }
    else
    {
      my $svrentry=$spcwk_client->call('system.getName',$spcwk_session,$id);
      $idmap{$id}=$svrentry->{'name'};
      chomp($svr[8]);
      $r = checkgroup($svrentry->{'name'});
      $completed{$svrentry->{'name'}}{"$svr[1]"}=[$svr[0], $svr[2], $svr[3], $svr[4], $svr[5], $svr[6], $svr[7], $svr[8]] if $r == 0;
      $svrlist{$svrentry->{'name'}}=1;
    }
  } #end while
} #end compdata

#
##compile stats on success and failure entries
#
sub compilestats {

foreach my $key (keys %failures)
{
  my $pkgcount=0;			#number of pkgs in failure report
  my $pkgstr='';			#packages string for each server
  my $r;
#  print "compilestats: $key in group $grplist\n" if $rtype =~ /[w|W]eeklyreport/;
  $grpfsvrcount++;
  foreach my $k (keys %{$failures{$key}})
  {
    $pkgstr="$pkgstr $failures{$key}{$k}[7]";
    $pkgcount++;
    $grpfpkgcount++;
    pkgstats($failures{$key}{$k}[7],"failure");		#send to pkgstats for pkg stats
  }
  $failcount{$key}=$pkgcount;		#failure count svr
  $fplist{$key}=$pkgstr;		#package list by svr
} #end foreach
  
foreach my $key (keys %completed)
{
  my $pkgcount=0;
  my $pkgstr='';
  my $r;
#  print "compilestats: $key in group $grplist\n" if $rtype =~ /[w|W]eeklyreport/;
  $grpcsvrcount++;
  foreach my $k (keys %{$completed{$key}})
  {
    $pkgstr="$pkgstr $completed{$key}{$k}[7]";
    $pkgcount++;
    $grpcpkgcount++;
    pkgstats($completed{$key}{$k}[7],"completed");		#send to pkgstats for pkg stats
  }
  $compcount{$key}=$pkgcount;		#completed count by svr
  $cplist{$key}=$pkgstr;		#package list by svr
} #end foreach

foreach my $key (keys %svrlist)
{
  $svrcount++;
  $svrl=$svrl . " " . $key;
}
} #end compiledstats

#
##package stats
#
sub pkgstats($$) {
  my $pkg=shift();
  my $type=shift();

if($type eq "failure")
{
  my $flag=0;
  foreach my $key (keys %fpkglistcount)
  {
    if($pkg eq $key)
    { 
      $flag=1;
      $fpkglistcount{$key} = $fpkglistcount{$key} + 1; 		#pkg found add one to count
    }
  } #end foreach
  if($flag == 0)
  { $fpkglistcount{$pkg}=1; }		#not found, add to list
}
else
{
  my $flag=0;
  foreach my $key (keys %cpkglistcount)
  {
    if($pkg eq $key)
    {
      $flag=1;
      $cpkglistcount{$key} = $cpkglistcount{$key} + 1;
    }
  } #end foreach
  if($flag == 0)
  { $cpkglistcount{$pkg}=1; }

} 
} #end pkgstats

#
##summary report
#
sub summary() {

  my $tpatches = $failnum + $compnum;
  my $psucc = $compnum / $tpatches;
  my $psuccess = sprintf("%.2f",$psucc);
  $psuccess = $psuccess * 100;

  my $pfail = $failnum / $tpatches;
  my $pfailure = sprintf("%.2f",$pfail);
  $pfailure = $pfailure * 100;

  $report = $report . "<br>";
  $report = $report . "Monthly Patch Success Rate: $psuccess%<br>\n";
  $report = $report . "Monthly Patch Failure Rate: $pfailure%<br><br>\n";

  $report = $report . "Monthly Servers Patched: $svrcount<br>\n";
  $report = $report . "Monthly Server Count with Failed Patches: $grpfsvrcount<br>\n";
  $report = $report . "Monthly Server Count with Successful Patches: $grpcsvrcount<br><br>\n";

  $report = $report . "Monthly Patches Scheduled: $tpatches<br>\n";
  $report = $report . "Monthly Successful Patches: $compnum<br>\n";
  $report = $report . "Monthly Failed Patches: $failnum<br>\n";

  $report = $report . "<br>\n";

  my $etotal=0;
  my $stotal=0;
  foreach my $key (keys %ecount)
  {
    $etotal = $etotal + $ecount{$key};
    $stotal++ if $key ne '';
  } #end foreach
  $report = $report . "Monthly Outstanding Errata: $etotal<br>\n";
  $report = $report . "Monthly Servers with Errata Outstanding: $stotal<br><br>\n";
} #end summary

#
##weekly report
#
sub weeklyreport {
  $report = $report . "<b>Total Weekly Failed Patches:</b> $failwknum<br>\n";
  $report = $report . "<b>Total Weekly Completed Patches:</b> $compwknum<br>\n";
  $report = $report . "<b>Total Weekly Server count with Failed Patches:</b> $failsvrswknum<br>\n";
  $report = $report . "<b>Total Weekly Server count with Successful Patches:</b> $compsvrswknum<br>\n";
  $report = $report . "<br>\n";
  $report = $report . "<b>$grpname Weekly Failed Patches:</b> $grpfpkgcount<br>\n";
  $report = $report . "<b>$grpname Weekly Completed Patches:</b> $grpcpkgcount<br>\n";
  $report = $report . "<b>$grpname Weekly Server count with Failed Patches:</b> $grpfsvrcount<br>\n";
  $report = $report . "<b>$grpname Weekly Server count with Successful Patches:</b> $grpcsvrcount<br>\n";
  $report = $report . "<br><br>\n";

  $report = $report . "<b>Failed Count by Server:</b><br>\n";
  foreach my $key (keys %failcount)
  {
    $report = $report . "$key: $failcount{$key}<br>\n";		#pkg upgrade failure count by svr
  }
  $report = $report . "<br><b>Completed Count by Server:</b><br>\n";
  foreach my $key (keys %compcount)
  {
    $report = $report . "$key: $compcount{$key}<br>\n";		#pkg upgrade completed count by svr
  }
  $report = $report . "<br><b>Failed Packages Count by Package:</b><br>\n";
  foreach my $key (keys %fpkglistcount)
  {
    $report = $report . "$key: $fpkglistcount{$key}<br>\n";         #pkg upgrade completed count by svr
  }
  $report = $report . "<br><b>Completed Packages Count by Package:</b><br>\n";
  foreach my $key (keys %cpkglistcount)
  {
    $report = $report . "$key: $cpkglistcount{$key}<br>\n";         #pkg upgrade completed count by svr
  } 
  $report = $report . "<br><b>Failed Package Upgrade List:</b><br>\n";
  foreach my $key (keys %fplist)
  {
    $report = $report . "<b>$key:</b> $fplist{$key}<br>\n";		#pkg upgrade failure list
  }
  $report = $report . "<br><b>Completed Package Upgrade List:</b><br>\n";
  foreach my $key (keys %cplist)
  {
    $report = $report . "<b>$key:</b> $cplist{$key}<br>\n";		#pkg upgrade completed list
  }
} #end weekly report

#
##check to see if svr is in group
##
sub checkgroup($)
{
  my $svr=shift();

  return 0 if $rtype =~ /[s|S]ummary/;

  foreach(@svrs)
  {
    if($_ =~ /$svr/)
    { 
      return 0; 
    }
  }#end foreach
  return 1;
} #end checkgroup

#
##header
#
sub header() {
$report = "<html><body><p>\n";

if($rtype =~ /[s|S]ummary/)
{ $report = $report . "<b><center>CentOS Monthly Summary Patching Report : $date</center></b><br>\n"; }
else
{ $report = $report . "<b><center>CentOS Weekly Patching Report : $date : Patch Group: $grpname</center></b><br>\n"; }
} #end header

#
##footer
#
sub footer() {
$report = $report . "</p></body></html>\n";
} #end footer

#
##grouplist - get list of svrs from Spacewalk for group report
#
sub grouplist()
{
  my $grplist=$spcwk_client->call('systemgroup.listSystems',$spcwk_session,$grpname); 
  foreach( @{$grplist} ) 
  {
    push(@svrs,$_->{hostname});
    $svrstr=$svrstr . "|" . $_->{hostname};
  }
} #end grouplist

if($rtype =~ /[s|S]ummary/)
{ print "Generating summary patching report\n"; }
elsif($rtype =~ /[w|W]eeklyreport/)
{ print "Generating weekly activity patching report\n"; }
else
{ print "Syntax: spacewalk-report-wrapper.pl <[summary|weeklyreport]> [<patch_group>]\n"; exit; }

$spcwk_client=new Frontier::Client(url => "http://$spcwk_host/rpc/api");
$spcwk_session=$spcwk_client->call('auth.login', $spcwk_user, $spcwk_pass);
&grouplist() if $rtype =~ /[w|W]eeklyreport/;
&gendata();

if($rtype =~ /[w|W]eeklyreport/)
{
  $failedentries = "/tmp/sw-failed-weekly.log";
  $compentries = "/tmp/sw-completed-weekly.log";
}
else
{
  $failedentries = "/tmp/sw-failed.log";
  $compentries = "/tmp/sw-completed.log";
}

open(fh1,$failedentries) or die "Could not open $failedentries";
open(fh2,$compentries) or die "Could not open $compentries";

&faildata();
&compdata();
&compilestats();
&erratastats();

print "failnum: $failnum\n";
chomp($failnum);
print "failnum after: $failnum\n";
chomp($failwknum);
chomp($compwknum);
chomp($failsvrswknum);
chomp($compsvrswknum);
chomp($date);
chomp($month);
chomp($compnum);
chomp($failsvrsnum);
chomp($compsvrsnum);

&header();
if($rtype =~ /[S|s]ummary/)
{ &summary(); }
else
{ &weeklyreport(); }
&footer();
&email("$report");
