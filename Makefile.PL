use strict;
use warnings;
use ExtUtils::MakeMaker;

my $MM_Version = $ExtUtils::MakeMaker::VERSION;

if ( $MM_Version =~ /_/ )    # dev version
{
    $MM_Version = eval $MM_Version;
    die $@ if ($@);
}

WriteMakefile(
    NAME          => 'SWISH::Prog::Lucy',
    AUTHOR        => q{Peter Karman <karman at cpan dot org>},
    VERSION_FROM  => 'lib/SWISH/Prog/Lucy.pm',
    ABSTRACT_FROM => 'lib/SWISH/Prog/Lucy.pm',
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002
        ? ( 'LICENSE' => 'perl' )
        : () ),
    PL_FILES  => {},
    PREREQ_PM => {
        'Test::More'                   => 0,
        'Lucy'                         => '0.00100',
        'SWISH::Prog'                  => 0.49,
        'SWISH::3'                     => 0.11,
        'Sort::SQL'                    => 0.06,
        'Search::Query'                => 0.17,
        'Search::Query::Dialect::Lucy' => 0.03,
        'Path::Class::File::Lockable'  => 0,
        'Path::Class::File::Stat'      => 0.03,
    },
    dist => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'SWISH-Prog-Lucy-* t/index.swish' },
    ( $MM_Version >= 6.48 ? ( MIN_PERL_VERSION => '5.8.3' ) : () ),
    ( $MM_Version >= 6.31 ? ( LICENSE          => 'perl' )  : () ),
    (   $MM_Version <= 6.44 ? ()
        : ( META_MERGE => {
                resources => {
                    license  => 'http://dev.perl.org/licenses/',
                    homepage => 'http://dev.swish-e.org/wiki/perl',
                    bugtracker =>
                        'http://rt.cpan.org/NoAuth/Bugs.html?Dist=SWISH-Prog-Lucy',
                    repository =>
                        'http://svn.swish-e.org/perl/SWISH-Prog-Lucy/',
                },
            }
        )
    ),
);
