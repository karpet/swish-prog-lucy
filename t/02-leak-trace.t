#!perl -w
use strict;
use constant HAS_LEAKTRACE => eval { require Test::LeakTrace };
use Test::More HAS_LEAKTRACE
    ? ( tests => 4 )
    : ( skip_all => 'require Test::LeakTrace' );
use Test::LeakTrace;

#use Devel::LeakGuard::Object qw( GLOBAL_bless :at_end leakguard );

my $KNOWN_LEALucy = 105;    # Lucy, SWISH::Filter, et al

use_ok('SWISH::Prog');
use_ok('SWISH::Prog::Lucy::InvIndex');
use_ok('SWISH::Prog::Lucy::Searcher');

my $invindex = SWISH::Prog::Lucy::InvIndex->new(
    clobber => 0,                 # Lucy handles this
    path    => 't/index.swish',
);
SKIP: {

    unless ( $ENV{TEST_LEALucy} ) {
        skip "set TEST_LEALucy to test memory lealucy", 1;
    }

    lealucy_cmp_ok {

        #leakguard {

        my $program = SWISH::Prog->new(
            invindex   => "$invindex",  # force stringify to avoid lealucy
            aggregator => 'fs',
            indexer    => 'lucy',
            config     => 't/config.xml',

            #verbose    => 1,
            #debug      => 1,
        );
        
        #diag( $program->aggregator->{_swish3} );

        # skip the index dir every time
        # the '1' arg indicates to append the value, not replace.
        $program->config->FileRules( 'dirname is index.swish', 1 );
        $program->config->FileRules( 'filename is config.xml', 1 );

        $program->run('t/test.html');

    }
    '<=', $KNOWN_LEALucy, "SWISH::Prog leak test";

#    lealucy_cmp_ok {
#        my $indexer = SWISH::Prog::Lucy::Indexer->new(
#            invindex => "$invindex",  # force stringify to avoid lealucy
#            config   => 't/config.xml',
#        );
#
#        #$indexer->invindex->path->file( SWISH_HEADER_FILE() );
#
#    }
#    '<=', $KNOWN_LEALucy, "SWISH::Prog::Lucy::Indexer leak test";

    #    on_leak => sub {
    #        my $report = shift;
    #        for my $pkg ( sort keys %$report ) {
    #            printf "%s %d %d\n", $pkg, @{ $report->{$pkg} };
    #        }
    #    };

    #    lealucy_cmp_ok {
    #        my $searcher = SWISH::Prog::Lucy::Searcher->new(
    #            invindex => $invindex,
    #            config   => 't/test.conf',
    #        );
    #        my $results = $searcher->search('test');
    #        my $result  = $results->next;
    #
    #    }
    #    '<', 1;

}

END {
    unless ( $ENV{PERL_DEBUG} ) {
        $invindex->path->rmtree if $invindex;
    }
}
