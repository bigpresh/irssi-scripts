#!/usr/bin/env perl
use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
use LWP::UserAgent;
use JSON;

$VERSION = "0.02";
%IRSSI = (
    authors     => 'David Precious',
    name        => 'nickserv_check_dea',
    description => 'Watch NickServ REGISTER messages, check for disposable email',
    license     => 'Public Domain',
    changed	=> '2016-10-21',
);

# API key to access cleanli.st with; if empty, we won't check them
Irssi::settings_add_str(
    'nickserv_check_dea', 'cleanlist_api_key', ''
);
# API key to access BDEA (block-disposable-email.com) with; if empty,
# we won't check them
Irssi::settings_add_str(
    'nickserv_check_dea', 'bdea_api_key', ''
);
# Channels in which we should look for NickServ REGISTER messages (where
# Atheme services are configured to log them to); comma-separated, and each 
# can optionally have a reporting destination channel after a colon if our
# reports should go to a different channel, e.g.:
# #snoop,#chan1:#chan1-reports
# ... would watch #snoop, and report results for those lookups to the same
# channel, and watch #chan1, reporting those results to #chan1-reports.
Irssi::settings_add_str(
    'nickserv_check_dea', 'nickserv_check_dea_channels', ''
);
# For cleanli.st, you can supply a whole email address to also check if the
# local-part looks suspicious - but you might not want to send your user's full
# email address to a third party, setting this to a true value will change the
# local-part to testing@ before sending.
Irssi::settings_add_bool(
    'nickserv_check_dea', 'cleanlist_check_domain_only', 1
);

my $ua = LWP::UserAgent->new(
    agent => "irssi/nickserv_check_dea $VERSION",
);


sub event_privmsg {
    my ($server, $data, $nick, $address) = @_;
    my ($target, $text) = split / :/, $data, 2;
    
    my $channel_list = Irssi::settings_get_str(
        'nickserv_check_dea_channels'
    );
    return unless $channel_list;
    my %channel_map;
    for my $channel_spec (split /,/, $channel_list) {
        my ($watch_channel, $report_channel) = split /:/, lc $channel_spec;
        $report_channel ||= $watch_channel;
        $channel_map{$watch_channel} = $report_channel;
    }
    return unless my $report_channel = $channel_map{lc $target};

    if (my($account, $email) = $text =~ /REGISTER: (\w+) to (\S+)/) {
        my $domain = (split /\@/, $email)[1];
        my $cleanlist_api_key = Irssi::settings_get_str('cleanlist_api_key');
        if ($cleanlist_api_key) {

            # By default, for user privacy, we send only the domain, replacing
            # the local-part
            my $pattern = Irssi::settings_get_bool('cleanlist_check_domain_only')
                ? "test\@$domain" : $email;
            
            Irssi::print(
                "Looking up $pattern against cleanlist with key "
                . $cleanlist_api_key
            );
            my $response = $ua->get(
                "http://app.cleanli.st/api/$cleanlist_api_key/pattern/check/"
                . $pattern
            );  
            if (!$response->is_success) {
                warn "Failed to look up test\@$email against cleanli.st - " 
                    . $response->status_line;
                return;
            }
            # Good response - code 1000, description valid, class 1
            my $data = JSON::decode_json($response->content);
            if ($data->{code} != 1000) {
                $server->command(
                    "MSG $report_channel $account email $email may be dodgy - "
                    . "cleanli.st code $data->{code} - $data->{detail}"
                );
                Irssi::print("Bitched about $email to '$report_channel'");
            } else {
                Irssi::print("Cleanlist reported no problems for $email");
            }
        }

        my $bdea_api_key = Irssi::settings_get_str('bdea_api_key');
        if ($bdea_api_key) {
            Irssi::print(
                "Looking up $domain against BDEA with key "
                . $bdea_api_key
            );
            my $response = $ua->get(
                "http://check.block-disposable-email.com/easyapi/json/"
                . "$bdea_api_key/$domain"
            );  
            if (!$response->is_success) {
                warn "Failed to look up $domain against BDEA - " 
                    . $response->status_line;
                return;
            }
            my $data = JSON::decode_json($response->content);
            if ($data->{request_status} eq 'success') {
                if ($data->{domain_status} ne 'ok') {
                    $server->command(
                        "MSG $report_channel $account email $email may be dodgy"
                        . " - BDEA report status $data->{domain_status}"
                    );
                } else {
                    Irssi::print("BDEA result ok for $domain");
                }

            } else {
                Irssi::print("BDEA lookup status " . $data->{request_status});
            }
        }
    }
}
Irssi::signal_add("event privmsg", "event_privmsg");
