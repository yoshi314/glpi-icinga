#!/usr/bin/perl



# this script will
# open a ticket for a host issue if there is a DOWN event
# link ticket with host (matching by ip address)
# close a ticket for matching host issues if there is an UP event

use LWP::UserAgent;
use JSON;
use strict;
use warnings;
use URI::QueryParam;
use URI::Escape;
use Data::Dumper;

my $ua = LWP::UserAgent->new;

# --- configuration ---
# user token is configured on selected user account
# app_token is configured in glpi api configuration
# API url
my $server_endpoint = "http://glpi.server/glpi/apirest.php";
my $user_token = "sfs9rkd0v5a2e4botcp18fycr0vhrn3gkv9xuti3";
my $app_token = "ufkfgreaumq9yy0x83jpoak96kcc7grmm9uvzhv1";
# --- configuration ---

# session token used post login for further requests, this gets setup during login, so leave blank
my $session_token = "";

# this will be reused during the script, so declare it here
my $login_url;
my $req;
my @tickety;

# arrays for list of tickets and servers
my @newtickets;
my @servers;


# grab some env variables, might as well refer to them by $ENV{...}
my $lasthoststate = $ENV{'LASTHOSTSTATE'};
my $hoststate = $ENV{'HOSTSTATE'};
my $state = $ENV{'HOSTSTATETYPE'};
my $eventhost = $ENV{'HOSTALIAS'};
my $hostaddress = $ENV{'HOSTADDRESS'};
my $hostattempts = $ENV{'HOSTATTEMPT'};
my $maxhostattempts = $ENV{'MAXHOSTATTEMPTS'};
my $hostproblemid = $ENV{'HOSTPROBLEMID'};
my $lasthostproblemid = $ENV{'LASTHOSTPROBLEMID'};
my $hoststatetype = $ENV{'HOSTSTATETYPE'};
my $hostcommand = $ENV{'HOSTCOMMAND'};
my $hostoutput = $ENV{'HOSTOUTPUT'};
my $longhostoutput = $ENV{'LONGHOSTOUTPUT'};

# login to service and obtain the session token
sub login_to_glpi() {

  # perform initial login to get session token
  $login_url = $server_endpoint . "/initSession";
  $req = HTTP::Request->new(GET => $login_url);
  $req->header('content-type' => 'application/json');
  $req->header('Authorization' => "user_token $user_token");
  $req->header('App-Token' => "$app_token");

  my $resp = $ua->request($req);
  my $textresp = decode_json($resp->decoded_content);
  
  if ($resp->is_success) {
      $session_token = $textresp->{'session_token'};
  }
  else {
    print "HTTP GET error code: ", $resp->code, "\n";
    print "HTTP GET error message: ", $resp->message, "\n";
    exit 1;
  }
  
}


sub collect_glpi_tickets() {
	# find tickets for given host
	my $request_string = uri_escape("criteria[0][field]=1&criteria[0][searchtype]=contains&criteria[0][value]=[$eventhost]","=[]");
	# clarify that it's only about the host
	$request_string .= uri_escape("&criteria[1][link]=AND&criteria[1][field]=1&criteria[1][searchtype]=contains&criteria[1][value]=Host","=[]");
	# and they have to be in "New" state
	$request_string .= uri_escape("&criteria[2][link]=AND&criteria[2][field]=12&criteria[2][searchtype]=equals&criteria[2][value]=notold","=[]");

	my $ticket_search_url = $server_endpoint . "/search/Ticket?" . $request_string;

	#print " url $ticket_search_url\n";
	$req = HTTP::Request->new(GET => $ticket_search_url);
	$req->header('content-type' => 'application/json');
	$req->header('Authorization' => "user_token $user_token");
	$req->header('App-Token' => "$app_token");
	$req->header('Session-Token' => "$session_token");

	my $resp = $ua->request($req);
	my $textresp = decode_json($resp->decoded_content);

	if ($resp->is_success) {
		my $message = $resp->decoded_content;
#		print "Received reply: $message\n";
	}
	else {
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
	}

	my $dane = $textresp->{data};

# create a list of ticket ids

	foreach my $entry (@$dane) {
		print Dumper($entry);
		print "i found a ticket with id: $entry->{2} , status $entry->{12}, name $entry->{1}\n";
		push(@tickety,$entry->{2});
	}
}

sub close_glpi_tickets() {
	# closing the tickets matching the search criteria
	my $post_data ;
	my $ticket_update_url;

	# go one by one through the tickets
	foreach my $ticketid (@tickety) {

    #print "i am trying to update ticket id: $ticketid\n";

		$ticket_update_url=$server_endpoint . "/Ticket/" . $ticketid;
		$req = HTTP::Request->new(PUT=> $ticket_update_url);
		$req->header('content-type' => 'application/json');
		$req->header('Authorization' => "user_token $user_token");
		$req->header('App-Token' => "$app_token");
		$req->header('Session-Token' => "$session_token");

		# this means status = closed
    # this may vary depending on your GLPI configuration, or if you want to set a different status
		$post_data = {
			'input' => {
				'status' => 6,
			}
		};

		$req->content(encode_json($post_data));

		my $resp = $ua->request($req);
		if ($resp->is_success) {
			my $message = $resp->decoded_content;
#			print "Received reply: $message\n";
		}
		else {
			print "HTTP POST error code: ", $resp->code, "\n";
			print "HTTP POST error message: ", $resp->message, "\n";
		}
	}
}

sub link_ticket_to_server() { 

    # this will attempt to create a link between ticket and a server based on a list of tickets and a list of servers
    # there is a chance that there will be multiple server instances in glpi and multiple tickets.

	my $post_data;
	my $ticket_update_url;


	foreach my $ticketid (@newtickets) {

  	$ticket_update_url=$server_endpoint . "/Ticket/" . $ticketid . "/Item_Ticket/";
  	$req = HTTP::Request->new(POST=> $ticket_update_url);
  	$req->header('content-type' => 'application/json');
  	$req->header('Authorization' => "user_token $user_token");
  	$req->header('App-Token' => "$app_token");
  	$req->header('Session-Token' => "$session_token");
  	foreach my $serwer (@servers) {
  
  		print ("Linking ticket $ticketid with server $serwer\n");
  		$post_data = { 
  			'input' => { 
  				'items_id' => $serwer,
  				'itemtype' => 'Computer',
  				'tickets_id' => $ticketid,
  			}
  		};
  		$req->content(encode_json($post_data));
  
  		my $resp = $ua->request($req);
  		if ($resp->is_success) {
  			my $message = $resp->decoded_content;
  			print " [link ticket] Received reply: $message\n";
  		}
  		else {
  			print "HTTP POST error code: ", $resp->code, "\n";
  			print "HTTP POST error message: ", $resp->message, "\n";
  		}
  
  	} # foreach @tickets
	} # foreach @servers
}

sub insert_glpi_ticket() {
    # creates a ticket in GLPI
	my $ticket_insert_url=$server_endpoint . "/Ticket/";
	$req = HTTP::Request->new(POST=> $ticket_insert_url);
	$req->header('content-type' => 'application/json');
	$req->header('Authorization' => "user_token $user_token");
	$req->header('App-Token' => "$app_token");
	$req->header('Session-Token' => "$session_token");


  # the content of the ticket. adjust as necessary in the content field.

	my $ticket_data = { 
		"input" => {
			"name" => "[${eventhost}] Host ${eventhost} jest niedostepny.",
			"content" => "Host ${eventhost} jest niedostepny..\n\r
Host \t\t\t = ${eventhost} \r
Check Attempts \t = ${hostattempts}/${maxhostattempts} \r
Check Command \t = ${hostcommand} \r
Check Output \t = ${hostoutput} \r
${longhostoutput}",
		}, 
	};

	$req->content(encode_json($ticket_data));

	my $resp = $ua->request($req);
	if ($resp->is_success) {
		my $message = $resp->decoded_content;
#		print "Received reply: $message\n";
		my $textresp = decode_json($resp->decoded_content);
		print "Created ticket #$textresp->{'id'}\n";
		push(@newtickets,$textresp->{'id'});
	}	
	else {
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
	}
}


sub logout_from_glpi() {
  # log out of glpi to destroy the session ticket

	print "wylogowanie z GLPI\n";
	my $logout_url = $server_endpoint . "/killSession";
	$req = HTTP::Request->new(GET => $logout_url);
	$req->header('content-type' => 'application/json');
	$req->header('Authorization' => "user_token $user_token");
	$req->header('App-Token' => "$app_token");
	$req->header('Session-Token' => "$session_token");
	
	my $resp = $ua->request($req);
	
	if ($resp->is_success) {
		print "logout successful";
	}
	else {
		print "HTTP GET error code: ", $resp->code, "\n";
		print "HTTP GET error message: ", $resp->message, "\n";
		exit 1;
	}	
	
}

sub find_host_by_ip() { 
    # locate host in glpi based on its IP
    # hosts can have different names in glpi than in monitoring system

	my $request_string = "criteria[0][field]=126&criteria[0][searchtype]=contains&criteria[0][value]=^${hostaddress}\$&forcedisplay[0]=2&forcedisplay[0]=2";

	my $request_url = $server_endpoint . "/search/Computer?" . $request_string;

	$req = HTTP::Request->new(GET => $request_url);
	$req->header('content-type' => 'application/json');
	$req->header('Authorization' => "user_token $user_token");
	$req->header('App-Token' => "$app_token");
	$req->header('Session-Token' => "$session_token");

	my $resp = $ua->request($req);
	my $textresp = decode_json($resp->decoded_content);

	if ($resp->is_success) {
		my $message = $resp->decoded_content;
#		print "Received reply: $message\n";
	}
	else {
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
	}

	my $data = $textresp->{data};

  # grab a list of servers
	foreach my $entry (@$data) {
		print "i found a computer with name: $entry->{1} , ip address $entry->{126}, id $entry->{2}\n";
		push(@servers,$entry->{2});
	}
}

# main script starts here

if (${lasthoststate} eq ${hoststate}) { 
    # nothing to do, host state unchanged
    print " ------------------------- \n";
    exit 0
}

if (${hoststatetype} eq 'SOFT') {
	print "Ignoring SOFT state\n";
	# we only check for hard states
	print " ------------------------- \n";
	exit 0
}




# get the service ticket
login_to_glpi();
# collect tickets into @tickets
collect_glpi_tickets();

# look for matching hosts in glpi into @servers
find_host_by_ip();


# if service has recovered, close all the outstanding tickets
# we find all the tickets, just to make sure that there are no extra tickets left
# e.g. from test runs of the script

if ("${hoststate}" eq 'UP') { 
	print "Host ${eventhost} is up, closing host tickets\n";
	close_glpi_tickets():
}   # if service has recovered

# if service has gone into failed state
# insert a new ticket
if ("${hoststate}" eq 'DOWN') {
	my $ile = @tickety;
	
	if ($ile > 0) {
		print "host ${eventhost} has already $ile open tickets, i won't make any more\n";
	} else {
		print "host ${eventhost} has no tickets yet, i'll make a new one\n";
		if (${hostattempts} == ${maxhostattempts}) { 
			# just in case, check once more if max_check_attempts have been reached
			
			insert_glpi_ticket();
			link_ticket_to_server();
		}
	}
}

logout_from_glpi();

print " ------------------------- \n";
