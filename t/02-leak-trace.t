#!perl -w
use strict;
use constant HAS_LEAKTRACE => eval { require Test::LeakTrace };
use Test::More HAS_LEAKTRACE
    ? ( tests => 5 )
    : ( skip_all => 'require Test::LeakTrace' );
use Test::LeakTrace;
use Devel::LeakGuard::Object qw( GLOBAL_bless :at_end leakguard );

use_ok('SWISH::Prog');
use_ok('SWISH::Prog::KSx::InvIndex');
use_ok('SWISH::Prog::KSx::Searcher');

my $invindex;
my $leaks = 0;

leakguard {
    $invindex = SWISH::Prog::KSx::InvIndex->new(
        clobber => 0,                 # KS handles this
        path    => 't/index.swish',
    );

    my $program = SWISH::Prog->new(
        invindex   => $invindex,
        aggregator => 'fs',
        indexer    => 'ks',
        config     => 't/config.xml',

        #verbose    => 1,
        #debug      => 1,
    );

    # skip the index dir every time
    # the '1' arg indicates to append the value, not replace.
    $program->config->FileRules( 'dirname is index.swish', 1 );
    $program->config->FileRules( 'filename is config.xml', 1 );

    $program->index('t/test.html');

}
on_leak => \&report;
is( $leaks, 0, "no leaks" );

$leaks = 0;

leakguard {
    my $searcher = SWISH::Prog::KSx::Searcher->new(
        invindex => $invindex,
        config   => 't/test.conf',
    );
    my $results = $searcher->search('test');
    my $result  = $results->next;

}

on_leak => \&report;
is( $leaks, 0, "no leaks" );

sub report {
    my $report = shift;
    print "We got some memory leaks: \n";
    for my $pkg ( sort keys %$report ) {
        printf "%s %d %d\n", $pkg, @{ $report->{$pkg} };
    }
    $leaks++;
}

END {
    unless ( $ENV{PERL_DEBUG} ) {
        $invindex->path->rmtree;
    }
}
