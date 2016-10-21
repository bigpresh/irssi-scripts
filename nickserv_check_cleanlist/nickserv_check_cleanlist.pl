#!/usr/bin/env perl
use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
use LWP::UserAgent;
use JSON;

$VERSION = "0.01";
%IRSSI = (
    authors     => 'David Precious',
    name        => 'nickserv_check_cleanlist',
    description => 'Watch NickServ REGISTER messages, check for disposable email',
    license     => 'Public Domain',
    changed	=> '2016-10-21',
);


Irssi::settings_add_str(
    'nickserv_check_cleanlist', 'cleanlist_api_key', ''
);
Irssi::settings_add_str(
    'nickserv_check_cleanlist', 'nickserv_check_cleanlist_channels', ''
);
Irssi::settings_add_bool(
    'nickserv_check_cleanlist', 'cleanlist_check_domain_only', 1
);

my $ua = LWP::UserAgent->new(
    agent => "irssi/nick-serv-check-dea $VERSION",
);


sub event_privmsg {
    my ($server, $data, $nick, $address) = @_;
    my ($target, $text) = split / :/, $data, 2;
    
    my $channel_list = Irssi::settings_get_str(
        'nickserv_check_cleanlist_channels'
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
        my $api_key = Irssi::settings_get_str('cleanlist_api_key');
        if (!$api_key) {
            Irssi::print("Set cleanlist API key with /set cleanlist_api_key");
            return;
        }

        # By default, for user privacy, we send only the domain, replacing the
        # local-part
        my $pattern = Irssi::settings_get_bool('cleanlist_check_domain_only')
            ? "test\@$domain" : $email;
        
        Irssi::print("Looking up $pattern against cleanlist with key $api_key");
        my $response = $ua->get(
            "http://app.cleanli.st/api/$api_key/pattern/check/$pattern"
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
                . "code $data->{code} - $data->{detail}"
            );
            Irssi::print("Bitched about $email to '$report_channel'");
        } else {
            Irssi::print("$email looked alright");
        }
    }
}
Irssi::signal_add("event privmsg", "event_privmsg");
