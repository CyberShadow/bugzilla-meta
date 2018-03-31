#!/usr/bin/perl -w
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Initialize Bugzilla (in ways that are easier to do using Perl / Bugzilla code).
# Based on scripts/generate_bmo_data.pl

use 5.10.1;
use strict;
use warnings;
use lib qw(. lib local/lib/perl5);

use Bugzilla;
use Bugzilla::User;
use Bugzilla::Install;
use Bugzilla::Milestone;
use Bugzilla::Product;
use Bugzilla::Component;
use Bugzilla::Group;
use Bugzilla::Version;
use Bugzilla::Constants;
use Bugzilla::Keyword;
use Bugzilla::Config qw(:admin);
use Bugzilla::User::Setting;
use Bugzilla::Status;

##########################################################################
#  Set Default User Preferences
##########################################################################

my %user_prefs = (
    show_gravatars         => 'On',
    show_my_gravatar       => 'On',
);

foreach my $pref (keys %user_prefs) {
    my $value = $user_prefs{$pref};
    Bugzilla::User::Setting::set_default($pref, $value, 1);
}
