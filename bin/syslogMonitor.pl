#!/usr/bin/perl
#syslogMonitor.pl
# Source: http://www.thegeekstuff.com/2010/07/perl-tcp-udp-socket-programming/

# Marcel Zoller, 2018
# This is not used for normal operation.
# It simulates a simple UDP receiver like Loxone Miniserver is.
# For debugging, send UDP packages to this server instead of the Miniserver and see the UDP communication.
use IO::Socket::INET;
use utf8;
use Encode;
use Time::Piece;
use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use LWP::Simple;
use Net::Ping;



# flush after every write
$| = 1;


# Konfig Lox^Berry auslesen
my %pcfg;
my %miniservers;
tie %pcfg, "Config::Simple", "$lbpconfigdir/pluginconfig.cfg";
my %spcstatus;
tie %spcstatus, "Config::Simple", "$lbpconfigdir/spc.cfg";
$UDP_Port = %pcfg{'MAIN.UDP_Port'};
$EDP_Port = %pcfg{'MAIN.EDP_Port'};
$EDP_Port2 = $EDP_Port+1;
$EDPZentralenID =  %pcfg{'MAIN.EDPZentralenID'};
%miniservers = LoxBerry::System::get_miniservers();
$LOX_Name = $miniservers{1}{Name};
$LOX_IP = $miniservers{1}{IPAddress};
$LOX_User = $miniservers{1}{Admin};
$LOX_PW = $miniservers{1}{Pass};


# Loxone HA-Miniserver by Marcel Zoller	
if($LOX_Name eq "lxZoller1"){
	# Loxone Minisever ping test
	#LOGOK " Loxone Zoller HA-Miniserver";
	print "Loxone Zoller HA-Miniserver\n";
	#$LOX_IP="172.16.200.7"; #Testvariable
	#$LOX_IP='172.16.200.6'; #Testvariable
	$p = Net::Ping->new();
	$p->port_number("80");
	if ($p->ping($LOX_IP,2)) {
				#LOGOK "Ping Loxone: Miniserver1 is online.";
				print "Ping Loxone: Miniserver1 is online.\n";
				#LOGOK "Ping Loxone: $p->ping($LOX_IP)";
				print "Ping Loxone: $p->ping($LOX_IP)\n";
				$p->close();
			} else{ 
				#LOGALERT "Ping Loxone: Miniserver1 not online!";
				print "Ping Loxone: Miniserver1 not online!\n";
				#LOGDEB "Ping Loxone: $p->ping($LOX_IP)";
				print "Ping Loxone: $p->ping($LOX_IP\n)";
				$p->close();
				
				$p = Net::Ping->new();
				$p->port_number("80");
				$LOX_IP = $miniservers{2}{IPAddress};
				$LOX_User = $miniservers{2}{Admin};
				$LOX_PW = $miniservers{2}{Pass};
				#$LOX_IP="172.16.200.6"; #Testvariable
				if ($p->ping($LOX_IP,2)) {
					#LOGOK "Ping Loxone: Miniserver2 is online.";
					print "Ping Loxone: Miniserver2 is online.\n";
					#LOGOK "Ping Loxone: $p->ping($LOX_IP)";
					print "Ping Loxone: $p->ping($LOX_IP)\n";
				} else {
					#LOGALERT "Ping Loxone: Miniserver2 not online!";
					print "Ping Loxone: Miniserver2 not online!\n";
					#LOGDEB "Ping Loxone: $p->ping($LOX_IP)";
					print  "Ping Loxone: $p->ping($LOX_IP)\n";
					#Failback Variablen !!!
					$LOX_IP = $miniservers{1}{IPAddress};
					$LOX_User = $miniservers{1}{Admin};
					$LOX_PW = $miniservers{1}{Pass};	
				} 
			}
		$p->close();			
}	
$LoxHTTPGet_BASE = "http://$LOX_User:$LOX_PW\@$LOX_IP/dev/sps/io";

my ($socket,$received_data);
my ($peeraddress,$peerport);

#$EDP_Port ='6666';
$EDPZentralenID = "#$EDPZentralenID";

# Datum und Uhrzeit zusammenbauen
my $t = my $t = localtime;
$mdy    = $t->dmy(".");
$hms    = $t->hms;
$datumtime = "$mdy $hms";
#print $datumtime;





#UDP Reciver PORT for EDP Port
$socket = new IO::Socket::INET (
	LocalPort => $EDP_Port,
	Proto => 'udp'
) or die "ERROR in Socket Creation EDP port : $!\n";

#UDP Sender PORT for Watchdog
$sock = IO::Socket::INET->new(
    Proto    => 'udp',
    PeerPort => $EDP_Port2,
    PeerAddr => '127.0.0.1',
) or die "Could not create socket watchdog prt: $!\n";

print "\nEDP-Moniter by Marcel Zoller 2018 - V3.3 / Listening on port $EDP_Port / $EDPZentralenID\n";
# Create my logging object
my $log = LoxBerry::Log->new ( 
	name => 'syslogMonitor',
	filename => "$lbplogdir/spc_syslogMonitor.log",
	append => 1
	);
LOGSTART "SPC demand SyslogMonitor start";

while(1)
{

# read operation on the socket
$socket->recv($recieved_data,10000);
$peer_address = $socket->peerhost();
$peer_port = $socket->peerport();
$recieved_data = decode('iso-8859-1',encode('utf-8', $recieved_data));

#print index($recieved_data,$EDPZentralenID);
#print "\n";

# Deamon Watchdog 
if(index($recieved_data,"WATCHDOG")!=-1){
	print "WATCHDOG REV: WATCHDOG\n";
	LOGINF "WATCHDOG REV: $recieved_data";
	$sock->send('WATCHDOG') or die "Send error: $!\n";
	print "WATCHDOG SEND: WATCHDOG\n";
	LOGDEB "WATCHDOG SEND: WATCHDOG";
}

#print "$recieved_data   $datumtime \n"; 
LOGINF "RECIVED DATE: $recieved_data   $datumtime"; 
	
if(index($recieved_data,$EDPZentralenID)!=-1){ #EDP Zentralen-ID identifizieren 

	# Ab hier wird das EDP Protokoll auseinander genommen	
	my @splitestate = split('\|', $recieved_data);
	$SPC_MG_ID = $splitestate[3];
	$SPC_MG_Bezeichnung = $splitestate[4];

	# Datum und Uhrzeit zusammenbauen
	my $t = my $t = localtime;
	$mdy    = $t->dmy(".");
	$hms    = $t->hms;
	$datumtime = "$mdy $hms";
	#print $datumtime;
	
	# Prüfen ob es eine MG ID ist (zwischen 1 - 255)
	if($SPC_MG_ID > 0){
		if($SPC_MG_ID < 255){
			#print "FOUND ID $SPC_MG_ID";
		
			if(index($recieved_data,"|ZO|")!=-1){  # MG ID OPEN
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_ZONE_ID = $splitbezeichung[2];
				$SPC_ZONE_Name = $splitbezeichung[3];
				chop($SPC_Bezeichnung);
				chop($SPC_ZONE_ID);
				$LoxStatus = "SPC_MG_$SPC_MG_ID";
				$LoxValue = "1";
				$spcstatus{"MG.$SPC_MG_ID"} = "1";
				$spcstatus{"MG_NAME.$SPC_MG_ID"} =  $SPC_Bezeichnung;
				$spcstatus{"MG_ZONE.$SPC_MG_ID"} =  $SPC_ZONE_ID;
				
				print "EDP1: MG ID $SPC_MG_ID OPEN / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name\n";
				LOGDEB "EDP1: MG ID $SPC_MG_ID OPEN / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name";
				
				}
			elsif(index($recieved_data,"|ZC|")!=-1){ ## MG ID CLOSE
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_ZONE_ID = $splitbezeichung[2];
				$SPC_ZONE_Name = $splitbezeichung[3];
				chop($SPC_Bezeichnung);
				chop($SPC_ZONE_ID);
				$LoxStatus = "SPC_MG_$SPC_MG_ID";
				$LoxValue = "0";
				$spcstatus{"MG.$SPC_MG_ID"} = "0";
				$spcstatus{"MG_NAME.$SPC_MG_ID"} =  $SPC_Bezeichnung;
				$spcstatus{"MG_ZONE.$SPC_MG_ID"} =  $SPC_ZONE_ID;
				
				print "EDP2: MG ID $SPC_MG_ID CLOSE / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name\n";
				LOGDEB "EDP2: MG ID $SPC_MG_ID CLOSE / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name";
				}
			elsif(index($recieved_data,"|ZI|")!=-1){ ## MG ID CLOSE mit INPUT (ausserhalb vom Ohm Widerstand, aber noch ok)
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_ZONE_ID = $splitbezeichung[2];
				$SPC_ZONE_Name = $splitbezeichung[3];
				chop($SPC_Bezeichnung);
				chop($SPC_ZONE_ID);
				$LoxStatus = "SPC_MG_$SPC_MG_ID";
				$LoxValue = "0";
				$spcstatus{"MG.$SPC_MG_ID"} = "0";
				$spcstatus{"MG_NAME.$SPC_MG_ID"} =  $SPC_Bezeichnung;
				$spcstatus{"MG_ZONE.$SPC_MG_ID"} =  $SPC_ZONE_ID;
				
				print "EDP3: MG ID $SPC_MG_ID CLOSE Input / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name\n";
				LOGDEB "EDP3: MG ID $SPC_MG_ID CLOSE Input / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name";
				}
			elsif(index($recieved_data,"|ZD|")!=-1){ ## MG ID SABOTAGE
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_ZONE_ID = $splitbezeichung[2];
				$SPC_ZONE_Name = $splitbezeichung[3];
				chop($SPC_Bezeichnung);
				chop($SPC_ZONE_ID);
				$LoxStatus = "SPC_MG_$SPC_MG_ID";
				$LoxValue = "2";
				$spcstatus{"MG.$SPC_MG_ID"} = "2";
				$spcstatus{"MG_NAME.$SPC_MG_ID"} =  $SPC_Bezeichnung;
				$spcstatus{"MG_ZONE.$SPC_MG_ID"} =  $SPC_ZONE_ID;
				
				print "EDP4: MG ID $SPC_MG_ID SABOTAGE / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name\n";
				LOGDEB "EDP4: MG ID $SPC_MG_ID SABOTAGE / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name";
				}
				
			elsif(index($recieved_data,"|TX|")!=-1){ ## ÜBERTRAGNGSFEHLER (Batterie Schwach)
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_ZONE_ID = $splitbezeichung[2];
				$SPC_ZONE_Name = $splitbezeichung[3];
				chop($SPC_Bezeichnung);
				chop($SPC_ZONE_ID);
				$LoxStatus = "SPC_MG_$SPC_MG_ID";
				$LoxValue = "3";
				$spcstatus{"MG.$SPC_MG_ID"} = "3";
				$spcstatus{"MG_NAME.$SPC_MG_ID"} =  $SPC_Bezeichnung;
				$spcstatus{"MG_ZONE.$SPC_MG_ID"} =  $SPC_ZONE_ID;
				
				print "EDP5: MG ID $SPC_MG_ID Übertragungsfehler /  / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name\n";
				LOGDEB "EDP5: MG ID $SPC_MG_ID Übertragungsfehler /  / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name";
				}	
				
			#elsif(index($recieved_data,"|DR|")!=-1){ ## DOOR OPEN
			#	@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
			#	$SPC_Bezeichnung = $splitbezeichung[0];
			#	$SPC_ZONE_ID = $splitbezeichung[2];
			#	$SPC_ZONE_Name = $splitbezeichung[3];
			#	chop($SPC_Bezeichnung);
			#	chop($SPC_ZONE_ID);
			#	$LoxStatus = "SPC_DOOR_$SPC_MG_ID";
			#	$LoxValue = "1";
			#	$spcstatus{"DOOR.$SPC_MG_ID"} = "1";
			#	$spcstatus{"DOOR.$SPC_MG_ID.Name"} =  $SPC_Bezeichnung;
			#	$spcstatus{"MG.$SPC_MG_ID.Zone"} =  $SPC_ZONE_ID;
			#	
			#	print "EDP6: DOOR ID $SPC_MG_ID OPEN / $SPC_Bezeichnung / Zone $SPC_ZONE_ID  / $SPC_ZONE_Name\n";
			#	}	
					
			elsif(index($recieved_data,"|DG|")!=-1){ ## DOOR Zutritt erlauben
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_Door = $splitbezeichung[0];
				$SPC_Token = $splitbezeichung[1];
				chop($SPC_Door);
				chop($SPC_Token);
				$LoxStatus = "SPC_DOOR_$SPC_MG_ID";
				$LoxValue = "$SPC_Token\/$datumtime";
				$spcstatus{"DOOR.$SPC_MG_ID"} = "$SPC_Token\/$datumtime";
				$spcstatus{"DOOR.$SPC_MG_ID.Name"} =  $SPC_Door;
				
				# DOOR -- Die letzten 10 Zutritte LOGGEN
				$spcstatus{"DOORLOG.$SPC_MG_ID.10"} = %spcstatus{"DOORLOG.$SPC_MG_ID.9"};
				$spcstatus{"DOORLOG.$SPC_MG_ID.9"} = %spcstatus{"DOORLOG.$SPC_MG_ID.8"};
				$spcstatus{"DOORLOG.$SPC_MG_ID.8"} = %spcstatus{"DOORLOG.$SPC_MG_ID.7"};
				$spcstatus{"DOORLOG.$SPC_MG_ID.7"} = %spcstatus{"DOORLOG.$SPC_MG_ID.6"};
				$spcstatus{"DOORLOG.$SPC_MG_ID.6"} = %spcstatus{"DOORLOG.$SPC_MG_ID.5"};
				$spcstatus{"DOORLOG.$SPC_MG_ID.5"} = %spcstatus{"DOORLOG.$SPC_MG_ID.4"};
				$spcstatus{"DOORLOG.$SPC_MG_ID.4"} = %spcstatus{"DOORLOG.$SPC_MG_ID.3"};
				$spcstatus{"DOORLOG.$SPC_MG_ID.3"} = %spcstatus{"DOORLOG.$SPC_MG_ID.2"};
				$spcstatus{"DOORLOG.$SPC_MG_ID.2"} = %spcstatus{"DOORLOG.$SPC_MG_ID.1"};
				$spcstatus{"DOORLOG.$SPC_MG_ID.1"} = "$SPC_Token\@$datumtime";

				
				print "EDP7: Zutritt $SPC_MG_ID erlaubt / $SPC_Door /  $SPC_Token\n";
				# print "$SPC_Token\@$datumtime";
				LOGDEB "EDP7: Zutritt $SPC_MG_ID erlaubt / $SPC_Door /  $SPC_Token";
				}	
			elsif(index($recieved_data,"|DD|")!=-1){ ## DOOR Zutritt verweigern
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_Door = $splitbezeichung[0];
				$SPC_Token = $splitbezeichung[1];
				chop($SPC_Door);
				chop($SPC_Token);
				#Extra falscher LoxStatus, damit es nicht überschrieben wird mit kein Zutritt
				$LoxStatus = "SPC_DOOR__$SPC_MG_ID";
				$LoxValue = "0";
				# $spcstatus{"DOOR.$SPC_MG_ID"} =  "0";
				# $spcstatus{"DOOR.$SPC_MG_ID.Name"} =  $SPC_Door;
				# $spcstatus{"DOOR.$SPC_MG_ID.Token"} =  $SPC_Token;
				
				print "EDP8: Zutritt $SPC_MG_ID verweigert / $SPC_Door /  $SPC_Token\n";
				LOGDEB "EDP8: Zutritt $SPC_MG_ID verweigert / $SPC_Door /  $SPC_Token";
				}	
				
			elsif(index($recieved_data,"|CG|")!=-1){ ## BEREICH EXTERN SCHARF
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_Door = $splitbezeichung[0];
				$SPC_Token = $splitbezeichung[1];
				chop($SPC_Door);
				chop($SPC_Token);
				$LoxStatus = "SPC_AREA_$SPC_MG_ID";
				$LoxValue = "1";
				$spcstatus{"BEREICH.$SPC_MG_ID"} =  "1";
				
				print "EDP9: BERIECH $SPC_MG_ID SCHARF / $SPC_Door /  $SPC_Token\n";
				LOGDEB "EDP9: BERIECH $SPC_MG_ID SCHARF / $SPC_Door /  $SPC_Token";
				}
				
			elsif(index($recieved_data,"|OG|")!=-1){ ## BEREICH UNSCAHRFF
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_Door = $splitbezeichung[0];
				$SPC_Token = $splitbezeichung[1];
				chop($SPC_Door);
				chop($SPC_Token);
				$LoxStatus = "SPC_AREA_$SPC_MG_ID";
				$LoxValue = "0";
				$spcstatus{"BEREICH.$SPC_MG_ID"} =  "0";
				
				print "EDP10: BERIECH $SPC_MG_ID UNSCHARF / $SPC_Door /  $SPC_Token\n";
				LOGDEB "EDP10: BERIECH $SPC_MG_ID UNSCHARF / $SPC_Door /  $SPC_Token";
				}
				
			elsif(index($recieved_data,"|BA|")!=-1){ ## ALARM 
						@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_ZONE_ID = $splitbezeichung[2];
				$SPC_ZONE_Name = $splitbezeichung[3];
				chop($SPC_Bezeichnung);
				chop($SPC_ZONE_ID);
				$LoxStatus = "SPC_MG_$SPC_MG_ID";
				$LoxValue = "99";
				$spcstatus{"MG.$SPC_MG_ID"} = "99";
				$spcstatus{"ALARM.SPC"} = "1";
				
				print "EDP11: MG $SPC_MG_ID ALARM / $SPC_Door /  $SPC_Token\n";
				LOGDEB "EDP11: MG $SPC_MG_ID ALARM / $SPC_Door /  $SPC_Token";
				}
				
			elsif(index($recieved_data,"|BR|")!=-1){ ## ALARM RESET
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_ZONE_ID = $splitbezeichung[2];
				$SPC_ZONE_Name = $splitbezeichung[3];
				chop($SPC_Bezeichnung);
				chop($SPC_ZONE_ID);
				$LoxStatus = "SPC_MG_$SPC_MG_ID";
				$LoxValue = "99";
				$spcstatus{"MG.$SPC_MG_ID"} = "99";
				$spcstatus{"ALARM.SPC"} = "0";
				
				print "EDP12: MG $SPC_MG_ID ALARM RESET / $SPC_Door /  $SPC_Token\n";
				LOGDEB "EDP12: MG $SPC_MG_ID ALARM RESET / $SPC_Door /  $SPC_Token";
				}	
				
			elsif(index($recieved_data,"|NL|")!=-1){ ## BEREICH INTERN SCHARF
				@splitbezeichung = split('\¦', $SPC_MG_Bezeichnung);
				$SPC_Bezeichnung = $splitbezeichung[0];
				$SPC_Door = $splitbezeichung[0];
				$SPC_Token = $splitbezeichung[1];
				#chop($SPC_Door);
				chop($SPC_Token);
				$LoxStatus = "SPC_AREA_$SPC_MG_ID";
				$LoxValue = "2";
				$spcstatus{"BEREICH.$SPC_MG_ID"} =  "2";
				
				print "EDP13: BERIECH $SPC_MG_ID INTERN SCHARF / $SPC_Door \n";
				LOGDEB "EDP13: BERIECH $SPC_MG_ID INTERN SCHARF / $SPC_Door";
				}	

				
			else {
				# print $recieved_data;
				LOGDEB "EMPFANG: $recieved_data ";
				}
				
			# SAVE SPC STATUS
			tied(%spcstatus)->write();
			
			$LoxURL = "$LoxHTTPGet_BASE/$LoxStatus/$LoxValue";
			#print "SEND: $LoxURL\n";
			LOGDEB "SEND: $LoxURL ";
			$contents = get("$LoxURL");
			
			}
		}
	}
# LOGEND "Operation finished sucessfully.";
}

$socket->close();