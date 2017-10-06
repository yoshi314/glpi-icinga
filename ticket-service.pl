#!/usr/bin/perl

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

my @newtickets;
my @servers;

# login to service and obtain the session token
sub login_to_glpi() {
# perform initial login to get session token
$login_url = $server_endpoint . "/initSession";
$req = HTTP::Request->new(GET => $login_url);
$req->header('content-type' => 'application/json');
$req->header('Authorization' => "user_token $user_token");
$req->header('App-Token' => "$app_token");

my $resp = $ua->request($req);

if ($resp->is_success) {
    my $textresp = decode_json($resp->decoded_content);
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
	my $request_string = uri_escape("criteria[0][field]=1&criteria[0][searchtype]=contains&criteria[0][value]=[$ENV{'HOSTALIAS'}]","=[]");
	# and for given service
	$request_string .= uri_escape("&criteria[1][link]=AND&criteria[1][field]=1&criteria[1][searchtype]=contains&criteria[1][value]=$ENV{'SERVICEDESC'}","=[]");
	# and they have to be in "New" state
	$request_string .= uri_escape("&criteria[2][link]=AND&criteria[2][field]=12&criteria[2][searchtype]=equals&criteria[2][value]=notold","=[]");

	my $ticket_search_url = $server_endpoint . "/search/Ticket?" . $request_string;

	# print " url $ticket_search_url\n";
	$req = HTTP::Request->new(GET => $ticket_search_url);
	$req->header('content-type' => 'application/json');
	$req->header('Authorization' => "user_token $user_token");
	$req->header('App-Token' => "$app_token");
	$req->header('Session-Token' => "$session_token");

	my $resp = $ua->request($req);
	my $textresp = decode_json($resp->decoded_content);

	if ($resp->is_success) {
		my $message = $resp->decoded_content;
		print "Received reply: $message\n";
	}
	else {
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
	}

	my $dane = $textresp->{data};

# create a list of ticket ids

	foreach my $entry (@$dane) {
		print Dumper($entry);
		#print "i found a ticket with id: $entry->{2} , status $entry->{12}, name $entry->{1}\n";
		push(@tickety,$entry->{2});
	}
}

sub close_glpi_tickets() {
	# closing the tickets matching the search criteria
	my $post_data ;
	my $ticket_update_url;

	# go one by one through the tickets
	foreach my $ticketid (@tickety) {
		print "attempting to update ticket id: $ticketid\n";
		$ticket_update_url=$server_endpoint . "/Ticket/" . $ticketid;
		$req = HTTP::Request->new(PUT=> $ticket_update_url);
		$req->header('content-type' => 'application/json');
		$req->header('Authorization' => "user_token $user_token");
		$req->header('App-Token' => "$app_token");
		$req->header('Session-Token' => "$session_token");

		# this means status = closed
        # adjust as needed to reflect your needs and GLPI configuration
		$post_data = {
			'input' => {
				'status' => 6,
			}
		};

		$req->content(encode_json($post_data));

		my $resp = $ua->request($req);
		if ($resp->is_success) {
			my $message = $resp->decoded_content;
			print "Received reply: $message\n";
		}
		else {
			print "HTTP POST error code: ", $resp->code, "\n";
			print "HTTP POST error message: ", $resp->message, "\n";
		}
	}
}



sub insert_glpi_ticket() {
	my $ticket_insert_url=$server_endpoint . "/Ticket/";
	$req = HTTP::Request->new(POST=> $ticket_insert_url);
	$req->header('content-type' => 'application/json');
	$req->header('Authorization' => "user_token $user_token");
	$req->header('App-Token' => "$app_token");
	$req->header('Session-Token' => "$session_token");

    # the actual body of the ticket is in 'content' field
	my $ticket_data = { 
		"input" => {
			"name" => "[$ENV{'HOSTALIAS'}] $ENV{'SERVICEDESC'} na $ENV{'HOSTALIAS'} jest w stanie critical.",
			"content" => "$ENV{'SERVICEDESC'} na $ENV{'HOSTALIAS'} jest w stanie critical.\n\r
Host \t\t\t = $ENV{'HOSTALIAS'} \r
Service Check \t = $ENV{'SERVICEDESC'} \r
State \t\t\t = $ENV{'SERVICESTATE'} \r
Check Attempts \t = $ENV{'SERVICEATTEMPTS'}/$ENV{'MAXSERVICEATTEMPTS'} \r
Check Command \t = $ENV{'SERVICECHECKCOMMAND'} \r
Check Output \t = $ENV{'SERVICEOUTPUT'} \r
$ENV{'LONGSERVICEOUTPUT'}",
		}, 
	};

	$req->content(encode_json($ticket_data));

	my $resp = $ua->request($req);
	if ($resp->is_success) {
		my $message = $resp->decoded_content;
		print "Received reply: $message\n";
		my $textresp = decode_json($resp->decoded_content);
		print "Created ticket #$textresp->{'id'}\n";
        push(@newtickets,$textresp->{'id'});
		
	}	
	else {
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
	}
}

sub link_ticket_to_server() { 
    # bind ticket to server, given list of tickets and hosts matches them together
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

	} # foreach
	} # foreach
}

sub find_host_by_ip() { 
    # search where host address contains ^1.2.3.4$ , where 1.2.3.4 is host's IP
    # this is a workaround for GLPI's search by ip function
    # unfortunately GLPI does not support 'equals' for ip address and contains will return more results than necessary
    # e.g. for equals='192.168.1.1' it will also return 192.168.1.10 or 192.168.1.104 , etc.

	my $request_string = "criteria[0][field]=126&criteria[0][searchtype]=contains&criteria[0][value]=^$ENV{'HOSTADDRESS'}\$&forcedisplay[0]=2&forcedisplay[0]=2";


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
		print "Received reply: $message\n";
	}
	else {
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
	}

	my $dane = $textresp->{data};

# create a list of ticket ids

	foreach my $entry (@$dane) {
#		print "i found a computer with name: $entry->{1} , ip address $entry->{126}, id $entry->{2}\n";
		push(@servers,$entry->{2});
    }
}

#####


sub logout_from_glpi() {
	print "logout from GLPI\n";
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



if ($ENV{'HOSTSTATE'} eq 'DOWN') {
    # if the host is down, exit
    print " ------------------------- \n";
    exit 0
}


if ($ENV{'SERVICESTATETYPE'} eq 'SOFT') {
    # soft states are ignored
	print "Ignoring SOFT state\n";
	print " ------------------------- \n";
	exit 0
}

# get the service ticket
#
login_to_glpi();
collect_glpi_tickets();
find_host_by_ip();

# if service has recovered, close all the outstanding tickets
# we find all the tickets, just to make sure that there are no extra tickets left
# e.g. from test runs of the script

if ("$ENV{'SERVICESTATE'}" eq 'OK') { 
	print "service $ENV{'SERVICEDESC'} has recovered, closing the tickets\n";
	close_glpi_tickets()
}   # if service has recovered

# if service has gone into failed state
# insert a new ticket
if ("$ENV{'SERVICESTATE'}" eq 'CRITICAL') {
	my $ile = @tickety;
	
	if ($ile > 0) {
		print "service $ENV{'SERVICEDESC'} already has $ile open tickets, no point making another one\n";
	} else {
		print "service $ENV{'SERVICEDESC'} has no open tickets, making a new one\n";
		insert_glpi_ticket();
        link_ticket_to_server();

	}
}

logout_from_glpi();

print " ------------------------- \n";
