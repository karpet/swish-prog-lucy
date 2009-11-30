use Test::More tests => 11;
use strict;

use_ok('SWISH::Prog');

#use_ok('SWISH::Prog::Xapian::Searcher');

ok( my $program = SWISH::Prog->new(
        invindex   => 't/index.swish',
        aggregator => 'fs',
        indexer    => 'ks',
        config     => 't/test.conf',

        #filter     => sub { diag( "doc filter on " . $_[0]->url ) },
    ),
    "new program"
);

ok( $program->index('t/'), "run program" );

is( $program->count, 2, "indexed test docs" );

#ok( my $searcher = SWISH::Prog::Xapian::Searcher->new(
#        invindex => 't/index.swish',
#        config   => 't/test.conf',
#    ),
#    "new searcher"
#);
#
#ok( my $results = $searcher->search('test'), "search()" );
#
#is( $results->hits, 1, "1 hit" );
#
#ok( my $result = $results->next, "next result" );
#
#is( $result->uri, 't/test.html', 'get uri' );
#
#is( $result->title, "test html doc", "get title" );
#
#diag( $result->score );
