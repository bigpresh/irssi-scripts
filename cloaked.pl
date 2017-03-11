#!/usr/bin/perl

# Irssi plugin to generate random more interesting "OK, cloaked" messages when
# give cloaks to users on freenode.
# I entirely blame Fuchs for inspiring me to do this.

use strict;
use Irssi ();

our $VERSION = '0.1';
our %IRSSI = (
    authors     => 'David Precious',
    contact     => 'davidp@preshweb.co.uk',
    url         => 'http://www.preshweb.co.uk/',
    name        => 'cloaked',
    description => 'Adds a /cloaked user command',
    license     => q(GNU GPLv2 or later),
);

Irssi::command_bind('cloaked', 'cmd_cloaked');

sub cmd_cloaked {
    my ($params, $server, $witem) = @_;

    my $user = $params;
    
    my @colours = (
        # This set of esoteric colours courtesy of raccoon on #freenode
        qw(  
            sarcoline coquelicot smaragdine mikado glaucous wenge fulvous
            xanadu falu eburnean
        ),
        # more esoteric ones of my own
        qw(
            sepia  ochre  fawn   khaki  taupe  gold  silver
            copper ruby   coral  orange olive  magenta
            sapphire
        ),
        # a bit more normal
        qw(
            turqouise   aquamarine  purple   red
        ),
        # lovely
        (
            'snot green', 'baby-poo yellow', 'lapis blue',
        ),
    );
    my @materials = (
        'silk', 'angora wool', 'bison hair', 'dogs hair', 'kitten fur',
        'badger hair', 'luxury wool', 'locks of orphans',
        'badger fur', 'weasel fur', 'meerkat fur', 'cat hair',
        'puppy fur', 'bison hair',
        'belly-button fluff', 'pubic hair',
    );
    my @methods = (
        'hand made', 'crafted', 'woven', 'thrown together',
    );
    my @method_descriptions = (
        'artisinally', 'carefully', 'with love', 'exquisitely',
        'expertly', 'most skillfully', 'efficiently',
        'beautifully', 'in a most artful fashion',
        '(a bit haphazardly, truth be told)',
        'as a labour of love', 'whilst crying tears of pride',
    );
    my @creators = (
        'elderly monks', 'orphans', 'artisinal craftmen',
        'expert craftmen', 'sweatshop labourers', 'prison inmates',
        'a small Liverpudlian child', 'Barbary apes',
        'network trolls doing community service as penance',
    );

    my $message = join ' ',
        "All done - one cloak,",
        pick(@methods),
        pick(@method_descriptions),
        "by",
        pick(@creators),
        "using the finest",
        pick(@materials),
        "in a beautiful shade of",
        pick(@colours);


    if ($witem->{type} eq 'CHANNEL') {
        my $channel = $witem->{name};
        if (!$user) {
            Irssi::print("Pass a nick to address the cloaked message to");
            return;
        }
        $server->command("MSG $channel $user: $message. Enjoy!");
    } elsif ($witem->{type} eq 'QUERY') {
        $server->command("MSG $witem->{name} $message. Enjoy!");
    } else {
        warn "Called from unrecognised witem type " . $witem->{type};
    }
    return;
}


sub pick {
    return @_[ int rand scalar @_ ];
}
