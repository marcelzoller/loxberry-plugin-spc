#!/usr/bin/perl

# Einbinden von Module
use CGI;
use utf8;
use Encode;
use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use IO::Socket::INET;
use LWP::Simple;
use Net::Ping;


print "Content-type: text/html\n\n";

# Konfig auslesen
my %pcfg;
my %miniservers;
tie %pcfg, "Config::Simple", "$lbpconfigdir/pluginconfig.cfg";
my %spcstatus;
tie %spcstatus, "Config::Simple", "$lbpconfigdir/spc.cfg";
$UDP_Port = %pcfg{'MAIN.UDP_Port'};
#$UDP_Send_Enable = %pcfg{'MAIN.UDP_Send_Enable'};
$HTTP_Send_Enable = %pcfg{'MAIN.HTTP_Send_Enable'};
%miniservers = LoxBerry::System::get_miniservers();
$LOX_Name = $miniservers{1}{Name};
$LOX_IP = $miniservers{1}{IPAddress};
$LOX_User = $miniservers{1}{Admin};
$LOX_PW = $miniservers{1}{Pass};

# Create my logging object
my $log = LoxBerry::Log->new ( 
	name => 'MG Status abfrage',
	filename => "$lbplogdir/spc_http_send.log",
	append => 1
	);
LOGSTART "SPC Status Abfrage HTML/index.cgi start";

# Loxone HA-Miniserver by Marcel Zoller	
if($LOX_Name eq "lxZoller1"){
	# Loxone Minisever ping test
	LOGOK " Loxone Zoller HA-Miniserver";
	#$LOX_IP="172.16.200.7"; #Testvariable
	#$LOX_IP='172.16.200.6'; #Testvariable
	$p = Net::Ping->new();
	$p->port_number("80");
	if ($p->ping($LOX_IP,2)) {
				LOGOK "Ping Loxone: Miniserver1 is online.";
				LOGOK "Ping Loxone: $p->ping($LOX_IP)";
				$p->close();
			} else{ 
				LOGALERT "Ping Loxone: Miniserver1 not online!";
				LOGDEB "Ping Loxone: $p->ping($LOX_IP)";
				$p->close();
				
				$p = Net::Ping->new();
				$p->port_number("80");
				$LOX_IP = $miniservers{2}{IPAddress};
				$LOX_User = $miniservers{2}{Admin};
				$LOX_PW = $miniservers{2}{Pass};
				#$LOX_IP="172.16.200.6"; #Testvariable
				if ($p->ping($LOX_IP,2)) {
					LOGOK "Ping Loxone: Miniserver2 is online.";
					LOGOK "Ping Loxone: $p->ping($LOX_IP)";
				} else {
					LOGALERT "Ping Loxone: Miniserver2 not online!";
					LOGDEB "Ping Loxone: $p->ping($LOX_IP)";
					#Failback Variablen !!!
					$LOX_IP = $miniservers{1}{IPAddress};
					$LOX_User = $miniservers{1}{Admin};
					$LOX_PW = $miniservers{1}{Pass};	
				} 
			}
		$p->close();			
}	
$LoxHTTPGet_BASE = "http://$LOX_User:$LOX_PW\@$LOX_IP/dev/sps/io";



## 50 Bereiche weren aus dem CFG-file ausgelesen
print "<b>SPC Area Status</b><br>";
for (my $i=0; $i <= 50; $i++) {
	$MG_Status = %spcstatus{"BEREICH.$i"};
	if($MG_Status ne "") {
		print "SPC_AREA_$i\@$MG_Status<br>";
		LOGDEB "PRINT: SPC_AREA_$i\@$MG_Status";
		
		
		$LoxStatus = "SPC_AREA_$i";
		$LoxValue = $MG_Status;
		
		$LoxURL = "$LoxHTTPGet_BASE/$LoxStatus/$LoxValue";
		#print "$LoxURL<br>";
		LOGDEB "SEND: $LoxURL ";
		if ($HTTP_Send_Enable == 1) {
			# HTTP Send AREA to Loxone
			$contents = get("$LoxURL");
			}
		}
}
print "<br>";

## 50 Türen weren aus dem CFG-file ausgelesen
print "<b>SPC Door Status</b><br>";
for (my $i=0; $i <= 50; $i++) {
	$MG_Status = %spcstatus{"DOOR.$i"};
	if($MG_Status ne "") {
		print "SPC_DOOR_$i\@$MG_Status<br>";
		LOGDEB "PRINT: SPC_DOOR_$i\@$MG_Status";
		
		$LoxStatus = "SPC_DOOR_$i";
		$LoxValue = $MG_Status;
		
		$LoxURL = "$LoxHTTPGet_BASE/$LoxStatus/$LoxValue";
		# print "$LoxURL<br>";
		LOGDEB "SEND: $LoxURL ";
		if ($HTTP_Send_Enable == 1) {
			# HTTP Send Door to Loxone
			$contents = get("$LoxURL");
			}
		
		}
}
print "<br>";

## 500 MG (Melde Gruppe) weren aus dem CFG-file ausgelesen
print "<b>SPC MG Status</b><br>";
for (my $i=0; $i <= 500; $i++) {
	$MG_Status = %spcstatus{"MG.$i"};
	if($MG_Status ne "") {
		print "SPC_MG_$i\@$MG_Status<br>";
		$MG_Name = %spcstatus{"MG_NAME.$i"};
		$MG_Name  = decode('utf-8', $MG_Name );
		print "SPC_MG_Name_$i\@$MG_Name<br>";
		$MG_Zone = %spcstatus{"MG_ZONE.$i"};
		$MG_Zone  = decode('utf-8', $MG_Zone );
		print "SPC_MG_Zone_$i\@$MG_Zone<br><br>";
		
		$LoxStatus = "SPC_MG_$i";
		$LoxValue = $MG_Status;
		
		$LoxURL = "$LoxHTTPGet_BASE/$LoxStatus/$LoxValue";
		# print "$LoxURL<br>";
		LOGDEB "SEND: $LoxURL ";
		if ($HTTP_Send_Enable == 1) {
			# HTTP Send MG to Loxone
			$contents = get("$LoxURL");
			}
		
		}
}



# We start the log. It will print and store some metadata like time, version numbers
# LOGSTART "SPC Staus start";
  
# Now we really log, ascending from lowest to highest:
# LOGDEB "This is debugging";                 # Loglevel 7
# LOGINF "Infos in your log";                 # Loglevel 6
# LOGOK "Everything is OK";                   # Loglevel 5
# LOGWARN "Hmmm, seems to be a Warning";      # Loglevel 4
# LOGERR "Error, that's not good";            # Loglevel 3
# LOGCRIT "Critical, no fun";                 # Loglevel 2
# LOGALERT "Alert, ring ring!";               # Loglevel 1
# LOGEMERGE "Emergency, for really really hard issues";   # Loglevel 0
  
LOGEND "Operation finished sucessfully.";
