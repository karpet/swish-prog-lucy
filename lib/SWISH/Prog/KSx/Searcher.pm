package SWISH::Prog::KSx::Searcher;
use strict;
use warnings;

our $VERSION = '0.11';

use base qw( SWISH::Prog::Searcher );

use Carp;
use SWISH::3;
use SWISH::Prog::KSx::Results;
use KinoSearch::Searcher;
use KinoSearch::Search::PolySearcher;
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::Search::SortRule;
use KinoSearch::Search::SortSpec;
use Data::Dump qw( dump );
use Sort::SQL;
use Search::Query;
use Search::Query::Dialect::KSx;

=head1 NAME

SWISH::Prog::KSx::Searcher - search Swish3 KinoSearch backend

=head1 SYNOPSIS

 # see SWISH::Prog::Searcher

=head1 DESCRIPTION

SWISH::Prog::KSx::Searcher is a KinoSearch-based Searcher
class for Swish3.

SWISH::Prog::KSx::Searcher is not made to replace the more fully-featured
KinoSearch::Searcher class and its friends. Instead, SWISH::Prog::KSx::Searcher
provides a simple API similar to other SWISH::Prog::Searcher-based backends
so that you can experiment with alternate
storage engines without needing to change much code.
When your search application requirements become more complex, the author
recommends the switch to using KinoSearch::Searcher directly.

=head1 METHODS

Only new and overridden methods are documented here. See
the L<SWISH::Prog::Searcher> documentation.

=head2 init

Called internally by new().

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    # load meta from the first invindex
    my $invindex = $self->invindex->[0];
    my $config   = $invindex->meta;

    my @searchables;
    for my $idx ( @{ $self->invindex } ) {
        my $searcher = KinoSearch::Searcher->new( index => "$idx" );
        push @searchables, $searcher;
    }
    my $schema = $searchables[0]->get_schema;

    $self->{ks} = KinoSearch::Search::PolySearcher->new(
        schema    => $schema,
        searchers => \@searchables,
    );

    my $metanames   = $config->MetaNames;
    my $field_names = [ keys %$metanames ];
    my %fieldtypes;
    for my $name (@$field_names) {
        $fieldtypes{$name} = {
            type     => $schema->fetch_type($name),
            analyzer => $schema->fetch_analyzer($name)
        };
        if ( exists $metanames->{$name}->{alias_for} ) {
            $fieldtypes{$name}->{alias_for}
                = $metanames->{$name}->{alias_for};
        }
    }

    # TODO could expose 'qp' as param to new().
    $self->{qp} ||= Search::Query::Parser->new(
        dialect          => 'KSx',
        fields           => \%fieldtypes,
        query_class_opts => {
            default_field => $field_names,
            debug         => $self->debug,
        }
    );

    return $self;
}

=head2 search( I<query> [, I<opts> ] )

Returns a SWISH::Prog::KSx::Results object.

I<query> is assumed to be query string compatible
with Search::Query::Dialect::KSx.

I<opts> is an optional hashref with the following supported
key/values:

=over

=item start

The starting position. Default is 0.

=item max

The ending position. Default is max_hits() as documented
in SWISH::Prog::Searcher.

=item order

Takes a SQL-like text string (like SWISH::Prog::Native::Searcher)
or a KinoSearch::Search::SortSpec object, which will determine
the sort order.

=item limit

Takes an arrayref of arrayrefs. Each child arrayref should
have three values: a field (PropertyName) value, a lower limit
and an upper limit.

=back

=cut

sub search {
    my $self  = shift;
    my $query = shift;
    croak "query required" unless defined $query;
    my $opts = shift || {};

    my $start  = $opts->{start} || 0;
    my $max    = $opts->{max}   || $self->max_hits;
    my $order  = $opts->{order};
    my $limits = $opts->{limit} || [];

    #warn "query=$query";

    my $parsed_query = $self->{qp}->parse($query)
        or croak "Query syntax error: " . $self->{qp}->error;
    my %hits_args = (
        offset     => $start,
        num_wanted => $max,
    );

    for my $limit (@$limits) {
        if ( !ref $limit or ref($limit) ne 'ARRAY' or @$limit != 3 ) {
            croak "poorly-formed limit. should be an array ref of 3 values.";
        }
        $parsed_query->add_and_clause(
            Search::Query::Clause->new(
                field => $limit->[0],
                op    => '..',
                value => [ $limit->[1], $limit->[2] ]
            )
        );
    }

    #carp dump $hits_args{query}->dump;

    if ($order) {
        if ( ref $order ) {

            # assume it is a SortSpec object
            $hits_args{sort_spec} = $order;
        }
        else {

            # turn it into a SortSpec
            my $sort_array = Sort::SQL->parse($order);
            my @rules;
            for my $pair (@$sort_array) {
                my $type
                    = $pair->[0] =~ m/^(swish)?rank$/ ? 'score' : 'field';

                if ( $type eq 'score' and uc( $pair->[1] ) eq 'DESC' ) {
                    push @rules,
                        KinoSearch::Search::SortRule->new( type => $type );
                }
                elsif ( $type eq 'score' ) {
                    push @rules,
                        KinoSearch::Search::SortRule->new( type => $type, reverse => 1 );
                }
                elsif ( uc( $pair->[1] ) eq 'DESC' ) {
                    push @rules,
                        KinoSearch::Search::SortRule->new(
                        field   => $pair->[0],
                        reverse => 1,
                        );
                }
                else {
                    push @rules,
                        KinoSearch::Search::SortRule->new(
                        field => $pair->[0], );
                }
            }
            $hits_args{sort_spec}
                = KinoSearch::Search::SortSpec->new( rules => \@rules, );
        }
    }

    # turn the Search::Query object into a KS object
    $hits_args{query} = $parsed_query->as_ks_query;
    my $hits    = $self->{ks}->hits(%hits_args);
    my $results = SWISH::Prog::KSx::Results->new(
        hits    => $hits->total_hits,
        ks_hits => $hits,
        query   => $parsed_query,
    );
    $results->{_args} = \%hits_args;
    return $results;
}

1;

__END__

=head1 AUTHOR

Peter Karman, C<< <karman at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-swish-prog-ksx at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SWISH-Prog-KSx>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SWISH::Prog::KSx


You can also look for information at:

=over 4

=item * Mailing list

L<http://lists.swish-e.org/listinfo/users>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SWISH-Prog-KSx>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SWISH-Prog-KSx>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SWISH-Prog-KSx>

=item * Search CPAN

L<http://search.cpan.org/dist/SWISH-Prog-KSx/>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Peter Karman.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
