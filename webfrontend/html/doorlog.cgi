#!/usr/bin/perl


##########################################################################
# LoxBerry-Module
##########################################################################
use CGI;
use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Log;
use Time::Piece;
  
# Die Version des Plugins wird direkt aus der Plugin-Datenbank gelesen.
my $version = LoxBerry::System::pluginversion();
 
# Mit dieser Konstruktion lesen wir uns alle POST-Parameter in den Namespace R.
my $cgi = CGI->new;


# Create my logging object
my $log = LoxBerry::Log->new ( 
	name => 'HTTP Settup',
	filename => "$lbplogdir/spc_door_html.log",
	append => 1
	);
LOGSTART "SPC HTTP start";
 
 # Local Time
 #my $dt = DateTime->now(time_zone=>'local');

# Datum und Uhrzeit zusammenbauen
my $t = my $t = localtime;
$mdy    = $t->dmy(".");
$hms    = $t->hms;
$datumtime = "$mdy $hms";
#print $datumtime;

 
# Wir Übergeben die Titelzeile (mit Versionsnummer), einen Link ins Wiki und das Hilfe-Template.
# Um die Sprache der Hilfe brauchen wir uns im Code nicht weiter zu kümmern.
# LoxBerry::Web::lbheader("SPC Plugin V$version", "http://www.loxwiki.eu/SPC/Zoller", "help.html");
  
# Wir holen uns die Plugin-Config in den Hash %pcfg. Damit kannst du die Parameter mit $pcfg{'Section.Label'} direkt auslesen.
my %pcfg;
tie %pcfg, "Config::Simple", "$lbpconfigdir/pluginconfig.cfg";
my %spcstatus;
tie %spcstatus, "Config::Simple", "$lbpconfigdir/spc.cfg";

# Wir initialisieren unser Template. Der Pfad zum Templateverzeichnis steht in der globalen Variable $lbptemplatedir.
my $template_head = HTML::Template->new(
    filename => "$lbptemplatedir/doorlog_head.html",
    global_vars => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
	associate => $cgi,
);
my $template_table = HTML::Template->new(
    filename => "$lbptemplatedir/doorlog_table.html",
    global_vars => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
	associate => $cgi,
);
my $template_footer = HTML::Template->new(
    filename => "$lbptemplatedir/doorlog_footer.html",
    global_vars => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
	associate => $cgi,
);
  

# Sprachen laden und anpassen
my %L = LoxBerry::Web::readlanguage($template_head, "language.ini");
my %L = LoxBerry::Web::readlanguage($template_table, "language.ini");
my %L = LoxBerry::Web::readlanguage($template_footer, "language.ini");
  


	


  
 
  
# Nun wird das Template ausgegeben.
$template_head->param( TIME => $datumtime);
print $template_head->output();

## Alle Doors auslesen MAX 50!
for (my $i=0; $i <= 50; $i++) {
	my $DNAME = %spcstatus{"DOOR.$i.Name"};
	if($DNAME ne "") {
		$template_table->param( DOORNAME => $DNAME);
		
		for (my $y=1; $y <= 10; $y++) {
			my $LOG = %spcstatus{"DOORLOG.$i.$y"};
			$template_table->param( "LOG$y" => $LOG);
		}
		print $template_table->output();
	}

}
print $template_footer->output();
  
# Schlussendlich lassen wir noch den Footer ausgeben.
LoxBerry::Web::lbfooter();

LOGEND "SPC Setting finish.";