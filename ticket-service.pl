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
my $server_endpoint = "http://172.17.2.14/glpi/apirest.php";
my $user_token = "0fcmmzahfzz4g8fu9myx2k8cg5t724nbvuhq6jmo";
my $app_token = "qfaqlz2cpiapxd0nqr1kl6lchlkoohpa4n516lax";
# --- configuration ---

# session token used post login for further requests, this gets setup during login, so leave blank
my $session_token = "";

# this will be reused during the script, so declare it here
my $login_url;
my $req;
my @tickety;

# arguments are passed in form name=value name2=value2 ....
# let's extract them
my %arguments;

foreach my $entry (@ARGV) {
    my ($arg, $value) = split /=/, $entry;
    print "$arg :: $value \n";
    $arguments{$arg}=$value;
}


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
	my $request_string = uri_escape("criteria[0][field]=1&criteria[0][searchtype]=contains&criteria[0][value]=$arguments{'eventhost'}","=[]");
	# and for given service
	$request_string .= uri_escape("&criteria[1][link]=AND&criteria[1][field]=1&criteria[1][searchtype]=contains&criteria[1][value]=$arguments{'service'}","=[]");
	# and they have to be in "New" state
	$request_string .= uri_escape("&criteria[2][link]=AND&criteria[2][field]=12&criteria[2][searchtype]=equals&criteria[2][value]=1","=[]");

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
		print "proba aktualizacji ticketu $ticketid\n";
		$ticket_update_url=$server_endpoint . "/Ticket/" . $ticketid;
		$req = HTTP::Request->new(PUT=> $ticket_update_url);
		$req->header('content-type' => 'application/json');
		$req->header('Authorization' => "user_token $user_token");
		$req->header('App-Token' => "$app_token");
		$req->header('Session-Token' => "$session_token");

		# this means status = closed
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

	my $ticket_data = { 
		"input" => {
			"name" => "$arguments{'service'} na $arguments{'eventhost'} jest w stanie critical.",
			"content" => "$arguments{'service'} na $arguments{'eventhost'} jest w stanie critical.\n\r
Host \t\t\t = $arguments{'eventhost'} \r
Service Check \t = $arguments{'service'} \r
State \t\t\t = $arguments{'event'} \r
Check Attempts \t = $arguments{'serviceattempts'}/$arguments{'maxserviceattempts'} \r
Check Command \t = $arguments{'servicecheckcommand'} \r
Check Output \t = $arguments{'serviceoutput'} \r
$arguments{'longserviceoutput'}",
		}, 
	};

	#print Dumper($ticket_data);


	$req->content(encode_json($ticket_data));

	my $resp = $ua->request($req);
	if ($resp->is_success) {
		my $message = $resp->decoded_content;
		print "Received reply: $message\n";
		my $textresp = decode_json($resp->decoded_content);
		print "Created ticket #$textresp->{'id'}\n";
		
	}	
	else {
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
	}
}




if ($arguments{"hoststate"} eq 'DOWN') {
    # if the host is down, exit. there is already a ticket for the host.
    exit 0
}


if ($arguments{"servicestatetype"} eq 'SOFT') {
	# don't do anything until monitoring system gets certain that the problem persists after max_retries
	exit 0
}

# get the service ticket
login_to_glpi();
collect_glpi_tickets();


# if service has recovered, close all the outstanding tickets
# we find all the tickets, just to make sure that there are no extra tickets left
# e.g. from test runs of the script

if ("$arguments{'servicestate'}" eq 'OK') { 
	print "service $arguments{'service'} has recovered, closing the tickets\n";
	close_glpi_tickets()
}   # if service has recovered

# if service has gone into failed state
# insert a new ticket
if ("$arguments{'servicestate'}" eq 'CRITICAL') {
	my $ile = @tickety;
	
	if ($ile > 0) {
		print "$arguments{'service'} already has $ile open tickets, skipping\n";
	} else {
		print "$arguments{'service'} has no open tickets, creating one\n";
		insert_glpi_ticket();

	}
}


