#!/usr/bin/perl


##########################################################################
# LoxBerry-Module
##########################################################################
use CGI;
use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
  
# Die Version des Plugins wird direkt aus der Plugin-Datenbank gelesen.
my $version = LoxBerry::System::pluginversion();

# Loxone Miniserver Select Liste Variable
our $MSselectlist;

# Mit dieser Konstruktion lesen wir uns alle POST-Parameter in den Namespace R.
my $cgi = CGI->new;
$cgi->import_names('R');
# Ab jetzt kann beispielsweise ein POST-Parameter 'form' ausgelesen werden mit $R::form.

# Create my logging object
my $log = LoxBerry::Log->new ( 
	name => 'HTTP Settup',
	filename => "$lbplogdir/spc_setting.log",
	append => 1
	);
LOGSTART "SPC HTTP start";
 
 
# Wir Übergeben die Titelzeile (mit Versionsnummer), einen Link ins Wiki und das Hilfe-Template.
# Um die Sprache der Hilfe brauchen wir uns im Code nicht weiter zu kümmern.
LoxBerry::Web::lbheader("SPC Plugin $version", "https://www.loxwiki.eu/display/LOXBERRY/Vanderbilt+SPC+-+EDP-Protokoll", "help.html");
  
# Wir holen uns die Plugin-Config in den Hash %pcfg. Damit kannst du die Parameter mit $pcfg{'Section.Label'} direkt auslesen.
my %pcfg;
tie %pcfg, "Config::Simple", "$lbpconfigdir/pluginconfig.cfg";

# Alle Miniserver aus Loxberry config auslesen
%miniservers = LoxBerry::System::get_miniservers();

# Wir initialisieren unser Template. Der Pfad zum Templateverzeichnis steht in der globalen Variable $lbptemplatedir.

my $template = HTML::Template->new(
    filename => "$lbptemplatedir/index.html",
    global_vars => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
	associate => $cgi,
);
  
# Jetzt lassen wir uns die Sprachphrasen lesen. Ohne Pfadangabe wird im Ordner lang nach language_de.ini, language_en.ini usw. gesucht.
# Wir kümmern uns im Code nicht weiter darum, welche Sprache nun zu lesen wäre.
# Mit der Routine wird die Sprache direkt ins Template übernommen. Sollten wir trotzdem im Code eine brauchen, bekommen
# wir auch noch einen Hash zurück.
my %L = LoxBerry::Web::readlanguage($template, "language.ini");
  
# Checkboxen, Select-Lists sind mit HTML::Template kompliziert. Einfacher ist es, mit CGI das HTML-Element bauen zu lassen und dann
# das fertige Element ins Template einzufügen. Für die Labels und Auswahlen lesen wir aus der Config $pcfg und dem Sprachhash $L.
# Nicht mehr sicher, ob in der Config True, Yes, On, Enabled oder 1 steht? Die LoxBerry-Funktion is_enabled findet's heraus.
# my $activated = $cgi->checkbox(-name => 'activated',
#                                  -checked => is_enabled($pcfg{'MAIN.SOMEOTHEROPTION'}),
#                                    -value => 'True',
#                                    -label => $L{'BASIC.IS_ENABLED'},
#                                );
# Den so erzeugten HTML-Code schreiben wir ins Template.





##########################################################################
# Process form data
##########################################################################

if ($cgi->param("save")) {
	# Data were posted - save 
	&save;
}


$R::stop if 0; # Prevent errors
if ( $R::stop ) 
{
	&stop;
}
R::start if 0; # Prevent errors
if ( $R::start ) 
{
	&start;
}
R::restart if 0; # Prevent errors
if ( $R::restart ) 
{
	&restart;
}
R::reset if 0; # Prevent errors
if ( $R::reset ) 
{
	&reset;
}	
	

my $UDPPORT = %pcfg{'MAIN.UDP_Port'};
my $UDPSEND = %pcfg{'MAIN.UDP_Send_Enable'};
my $UDPSENDINTER = %pcfg{'MAIN.UDP_SEND_Intervall'};
my $HTTPSEND = %pcfg{'MAIN.HTTP_Send_Enable'};
my $HTTPSENDINTER = %pcfg{'MAIN.HTTP_TEXT_SEND_Intervall'};
my $EDPPORT = %pcfg{'MAIN.EDP_Port'};
my $EDPZentralenID = %pcfg{'MAIN.EDPZentralenID'};
my $SERVICE = %pcfg{'MAIN.EDP_Server_runnig'};
my $miniserver = %pcfg{'MAIN.MINISERVER'};
my $AUTOSTART = %pcfg{'MAIN.autostart'};


%miniservers = LoxBerry::System::get_miniservers();
#print "Anzahl deiner Miniserver: " . keys(%miniservers);

##########################################################################
# Fill Miniserver selection dropdown
##########################################################################
for (my $i = 1; $i <=  keys(%miniservers);$i++) {
	if ("MINISERVER$i" eq $miniserver) {
		$MSselectlist .= '<option selected value="'.$i.'">'.$miniservers{$i}{Name}."</option>\n";
	} else {
		$MSselectlist .= '<option value="'.$i.'">'.$miniservers{$i}{Name}."</option>\n";
	}
}


$template->param( EDPZentralenID => $EDPZentralenID);
$template->param( EDPPORT => $EDPPORT);
$template->param(LOXLIST => $MSselectlist);
$template->param( UDPPORT => $UDPPORT);
$template->param( WEBSITE => "http://$ENV{HTTP_HOST}/plugins/$lbpplugindir/index.cgi");
$template->param( WEBSITELOG => "http://$ENV{HTTP_HOST}/plugins/$lbpplugindir/doorlog.cgi");
$template->param( LOGSYSMONITOR => "/admin/system/tools/logfile.cgi?logfile=plugins/$lbpplugindir/spc_syslogMonitor.log&header=html&format=template");
$template->param( LOGHTTP => "/admin/system/tools/logfile.cgi?logfile=plugins/$lbpplugindir/spc_http_send.log&header=html&format=template");
if ($SERVICE == 1) {
	$template->param( SERVER => '<span style="color:green">running</span>');
	} 
elsif ($SERVICE == 0) {
	$template->param( SERVER => '<span style="color:red">stop</span>');
	} 
else  {
	$template->param( SERVER => '<span style="color:red">stop</span>');
	} 

	
	
if ($AUTOSTART == 1) {
		$template->param( AUTOSTART => "checked");
		$template->param( AUTOSTARTYES => "selected");
		$template->param( AUTOSTARTNO => "");
	} else {
		$template->param( AUTOSTART => " ");
		$template->param( AUTOSTARTYES => "");
		$template->param( AUTOSTARTNO => "selected");
	} 	
if ($UDPSEND == 1) {
		$template->param( UDPSEND => "checked");
		$template->param( UDPSENDYES => "selected");
		$template->param( UDPSENDNO => "");
	} else {
		$template->param( UDPSEND => " ");
		$template->param( UDPSENDYES => "");
		$template->param( UDPSENDNO => "selected");
	} 
if ($HTTPSEND == 1) {
		$template->param( HTTPSEND => "checked");
		$template->param( HTTPSENDYES => "selected");
		$template->param( HTTPSENDNO => "");
	} else {
		$template->param( HTTPSEND => " ");
		$template->param( HTTPSENDYES => "");
		$template->param( HTTPSENDNO => "selected");
	} 

  
 
  
# Nun wird das Template ausgegeben.
print $template->output();
  
# Schlussendlich lassen wir noch den Footer ausgeben.
LoxBerry::Web::lbfooter();

LOGEND "SPC Setting finish.";

##########################################################################
# Save data
##########################################################################
sub save 
{

	# We import all variables to the R (=result) namespace
	$cgi->import_names('R');
	
	# print "DEV1:$R::Dev1<br>\n";
	# print "UDP_Port:$R::UDP_Port<br>\n";
	# print "UDP_Send:$R::UDP_Send<br>\n";
	# print "HTTP_Send:$R::HTTP_Send<br>\n";
	# print "UDP_Sendddd:$R::UDP_Send<br>\n";
	LOGDEB "UDP Port: $R::UDP_Port";
	LOGDEB "EDP Port: $R::EDP_Port";
	LOGDEB "EDP Zentralen ID: $R::EDPZentralenID";
	

	if ($R::Dev1 != "") {
			#print "DEV1:$R::Dev1<br>\n";
			$pcfg{'Device1.IP'} = $R::Dev1;
		} 
	if ($R::UDP_Port != "") {
			#print "UDP_Port:$R::UDP_Port<br>\n";
			$pcfg{'MAIN.UDP_Port'} = $R::UDP_Port;
		}
	if ($R::miniserver != "") {
			#print "miniserver:$R::miniserver<br>\n";
			$pcfg{'MAIN.MINISERVER'} = "MINISERVER".$R::miniserver;
			# tied(%pcfg)->write();
		} 
	if ($R::UDP_Send == "1") {
			LOGDEB "UDP Send: $R::UDP_Send";
			$pcfg{'MAIN.UDP_Send_Enable'} = "1";
		} else{
			LOGDEB "UDP Send: $R::UDP_Send";
			$pcfg{'MAIN.UDP_Send_Enable'} = "0";
		}
	if ($R::AUTOSTART == "1") {
			LOGDEB "Autostart: $R::AUTOSTART";
			$pcfg{'MAIN.autostart'} = "1";
		} else{
			LOGDEB "Autostart: $R::AUTOSTART";
			$pcfg{'MAIN.autostart'} = "0";
		}	
	if ($R::HTTP_Send == "1") {
			LOGDEB "HTTP Send: $R::HTTP_Send";
			$pcfg{'MAIN.HTTP_Send_Enable'} = "1";
		} else{
			LOGDEB "HTTP Send: $R::HTTP_Send";
			$pcfg{'MAIN.HTTP_Send_Enable'} = "0";
		}
		
	if ($R::EDP_Port != "") {
			LOGDEB "EDP_Port:$R::EDP_Port<br>\n";
			$pcfg{'MAIN.EDP_Port'} = $R::EDP_Port;
		} 
	if ($R::EDPZentralenID != "") {
			LOGDEB "EDP Zentralen ID:$R::EDPZentralenID<br>\n";
			$pcfg{'MAIN.EDPZentralenID'} = $R::EDPZentralenID;
		} 
	
	tied(%pcfg)->write();
	LOGDEB "Setting: SAVE!!!!";
	#	print "SAVE!!!!";	
	return;
	
}

##########################################################################
# Start Deamen
##########################################################################
sub start 
{
	#print "Start\n";
	LOGDEB "UDP-Server start";
	$pcfg{'MAIN.EDP_Server_runnig'} = 1;
	
	tied(%pcfg)->write();
	#LOGDEB "Setting: SAVE!!!!";
	#	print "SAVE!!!!";	
	
	system ("perl '$lbpbindir/spc-control.pl' start &");
	
	return;	
}

##########################################################################
# Stop Deamen
##########################################################################
sub stop
{
	#print "Stop\n";
	LOGDEB "UDP-Server stop";
	$pcfg{'MAIN.EDP_Server_runnig'} = 0;
	
	tied(%pcfg)->write();
	#LOGDEB "Setting: SAVE!!!!";
	#	print "SAVE!!!!";	
	
	system ("perl '$lbpbindir/spc-control.pl' stop &");
	
	return;	
}	

##########################################################################
# RESTART Deamen
##########################################################################
sub restart
{
	#print "Stop\n";
	LOGDEB "UDP-Server restart";
	
	system ("perl '$lbpbindir/spc-control.pl' restart &");
	
	return;	
}

##########################################################################
# Reset MG Status
##########################################################################
sub reset
{
	#print "Reset\n";
	LOGDEB "RESET: Alle MG Status";
	
	system ("cp '$lbpconfigdir/spc.master' '$lbpconfigdir/spc.cfg' &");

	return;	
}	