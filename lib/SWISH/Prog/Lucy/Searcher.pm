package SWISH::Prog::Lucy::Searcher;
use strict;
use warnings;

our $VERSION = '0.05';

use base qw( SWISH::Prog::Searcher );

use Carp;
use SWISH::3 qw( :constants );
use SWISH::Prog::Lucy::Results;
use Lucy::Search::IndexSearcher;
use Lucy::Search::PolySearcher;
use Lucy::Analysis::PolyAnalyzer;
use Lucy::Search::SortRule;
use Lucy::Search::SortSpec;
use Path::Class::File::Stat;
use Data::Dump qw( dump );
use Sort::SQL;
use Search::Query;
use Search::Query::Dialect::Lucy;

__PACKAGE__->mk_accessors(qw( find_relevant_fields ));

=head1 NAME

SWISH::Prog::Lucy::Searcher - search Swish3 Lucy backend

=head1 SYNOPSIS
 
 my $searcher = SWISH::Prog::Lucy::Searcher->new(
     invindex             => 'path/to/index',
     max_hits             => 1000,
     find_relevant_fields => 1,   # default: 0
 );
                
 my $results = $searcher->search( 'foo bar' );
 while (my $result = $results->next) {
     printf("%4d %s\n", $result->score, $result->uri);
 }

=head1 DESCRIPTION

SWISH::Prog::Lucy::Searcher is an Apache Lucy based Searcher
class for Swish3.

SWISH::Prog::Lucy::Searcher is not made to replace the more fully-featured
Lucy::Search::Searcher class and its friends. Instead, SWISH::Prog::Lucy::Searcher
provides a simple API similar to other SWISH::Prog::Searcher-based backends
so that you can experiment with alternate
storage engines without needing to change much code.
When your search application requirements become more complex, the author
recommends the switch to using Lucy::Search::Searcher directly.

=head1 METHODS

Only new and overridden methods are documented here. See
the L<SWISH::Prog::Searcher> documentation.

=head2 init

Called internally by new(). Additional parameters include:

=over

=item find_relevant_fields I<1|0>

Set to true to have the Results object locate the fields
that matched the query. Default is 0 (off).

=back

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    # load meta from the first invindex
    my $invindex = $self->invindex->[0];
    my $config   = $invindex->meta;

    # cache the meta file stat(), to test if it changes
    # while the searcher is open. See get_lucy()
    $self->{swish_xml}
        = Path::Class::File::Stat->new( $invindex->meta->file );
    $self->{swish_xml}->use_md5();    # slower but better
    $self->{_uuid} = $config->Index->{UUID} || "LUCY_NO_UUID";

    # this does 2 things:
    # 1: initializes the Lucy Searcher
    # 2: gives a copy of the Lucy Schema object for field defs
    my $schema = $self->get_lucy()->get_schema();

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

    my $props = $config->PropertyNames;

    # start with the built-in PropertyNames,
    # which cannot be aliases for anything.
    my %propnames = map { $_ => { alias_for => undef } }
        keys %{ SWISH_DOC_PROP_MAP() };
    $propnames{swishrank} = { alias_for => undef };
    $propnames{score}     = { alias_for => undef };
    for my $name ( keys %$props ) {
        $propnames{$name} = { alias_for => undef };
        if ( exists $props->{$name}->{alias_for} ) {
            $propnames{$name}->{alias_for} = $props->{$name}->{alias_for};
        }
    }
    $self->{_propnames} = \%propnames;

    # TODO could expose 'qp' as param to new().
    $self->{qp} ||= Search::Query::Parser->new(
        dialect          => 'Lucy',
        fields           => \%fieldtypes,
        query_class_opts => {
            default_field => $field_names,
            debug         => $self->debug,
        }
    );

    return $self;
}

sub _get_field_alias_for {
    my ( $self, $field ) = @_;
    if ( !exists $self->{_propnames}->{$field} ) {
        croak "unknown field name: $field";
    }
    if ( defined $self->{_propnames}->{$field}->{alias_for} ) {
        return $self->{_propnames}->{$field}->{alias_for};
    }
    return undef;
}

=head2 search( I<query> [, I<opts> ] )

Returns a SWISH::Prog::Lucy::Results object.

I<query> is assumed to be query string compatible
with Search::Query::Dialect::Lucy.

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
or a Lucy::Search::SortSpec object, which will determine
the sort order.

=item limit

Takes an arrayref of arrayrefs. Each child arrayref should
have three values: a field (PropertyName) value, a lower limit
and an upper limit.

=item default_boolop

The default boolean connector for parsing I<query>. Valid values
are B<AND> and B<OR>. The default is
B<AND> (which is different than Lucy::QueryParser, but the
same as Swish-e).

=back

=cut

my %boolops = (
    'AND' => '+',
    'OR'  => '',
);

sub search {
    my $self  = shift;
    my $query = shift;
    croak "query required" unless defined $query;
    my $opts = shift || {};

    my $start  = $opts->{start}          || 0;
    my $max    = $opts->{max}            || $self->max_hits;
    my $order  = $opts->{order};
    my $limits = $opts->{limit}          || [];
    my $boolop = $opts->{default_boolop} || 'AND';
    if ( !exists $boolops{ uc($boolop) } ) {
        croak "Unsupported default_boolop: $boolop (should be AND or OR)";
    }
    $self->{qp}->default_boolop( $boolops{$boolop} );

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

            my $has_sort_by_score  = 0;
            my $has_sort_by_doc_id = 0;

            # turn it into a SortSpec
            my $sort_array = Sort::SQL->parse($order);
            my @rules;
            for my $pair (@$sort_array) {
                my ( $field, $dir ) = @$pair;
                if ( $self->_get_field_alias_for($field) ) {
                    $field = $self->_get_field_alias_for($field);
                }
                my $type;
                if ( $field eq 'score' or $field =~ m/^(swish)?rank$/ ) {
                    $type = 'score';
                }
                else {
                    $type = 'field';
                }

                if ( $type eq 'score' ) {

                    $has_sort_by_score++;

                    if ( uc($dir) eq 'DESC' ) {
                        push @rules,
                            Lucy::Search::SortRule->new( type => $type );
                    }
                    else {
                        push @rules,
                            Lucy::Search::SortRule->new(
                            type    => $type,
                            reverse => 1
                            );
                    }
                }
                else {
                    if ( $field eq 'doc_id' ) {
                        $has_sort_by_doc_id++;
                    }
                    if ( uc($dir) eq 'DESC' ) {
                        push @rules,
                            Lucy::Search::SortRule->new(
                            field   => $field,
                            reverse => 1,
                            );
                    }
                    else {
                        push @rules,
                            Lucy::Search::SortRule->new( field => $field, );
                    }
                }
            }

            # always include a sort by score so that we calculate a score.
            if ( !$has_sort_by_score ) {
                push @rules, Lucy::Search::SortRule->new( type => 'score' );
            }

            # always have doc_id last
            # http://rectangular.com/pipermail/kinosearch/2010-May/007392.html
            if ( !$has_sort_by_doc_id ) {
                push @rules, Lucy::Search::SortRule->new( type => 'doc_id' );
            }

            $hits_args{sort_spec}
                = Lucy::Search::SortSpec->new( rules => \@rules, );
        }
    }

    # turn the Search::Query object into a Lucy object
    $hits_args{query} = $parsed_query->as_lucy_query;
    my $lucy = $self->get_lucy();
    $self->debug
        and carp "search in $lucy for '$parsed_query' : "
        . dump( \%hits_args );
    my $compiler = $hits_args{query}->make_compiler( searcher => $lucy );
    my $hits     = $lucy->hits(%hits_args);
    my $results  = SWISH::Prog::Lucy::Results->new(
        hits                 => $hits->total_hits,
        lucy_hits            => $hits,
        query                => $parsed_query,
        find_relevant_fields => $self->find_relevant_fields,
    );
    $results->{_compiler} = $compiler;
    $results->{_searcher} = $lucy;
    $results->{_args}     = \%hits_args;
    return $results;
}

=head2 get_lucy

Returns the internal Lucy::Search::PolySearcher object.

=cut

sub get_lucy {
    my $self = shift;
    my $uuid = $self->invindex->[0]->meta->Index->{UUID} || $self->{_uuid};
    if ( !$self->{lucy} ) {

        $self->debug and carp "init lucy";
        $self->_open_lucy;

    }
    elsif ( $self->{_uuid} && $self->{_uuid} ne $uuid ) {

        $self->debug and carp "UUID has changed from $self->{_uuid} to $uuid";
        $self->_open_lucy;

        # recache
        $self->{_uuid} = $self->invindex->[0]->meta->Index->{UUID};

    }
    elsif ( $self->{swish_xml}->changed ) {

        $self->debug and carp "MD5 sig has changed";
        $self->_open_lucy;

    }
    else {

        $self->debug and carp "re-using cached Lucy Searcher";

    }
    return $self->{lucy};
}

sub _open_lucy {
    my $self = shift;
    my @searchers;
    for my $idx ( @{ $self->invindex } ) {
        my $searcher = Lucy::Search::IndexSearcher->new( index => "$idx" );
        push @searchers, $searcher;
    }

    # assume all the schemas are identical.
    my $schema = $searchers[0]->get_schema();

    $self->{lucy} = Lucy::Search::PolySearcher->new(
        schema    => $schema,
        searchers => \@searchers,
    );

    $self->debug and carp "opened new PolySearcher: " . $self->{lucy};
}

1;

__END__

=head1 AUTHOR

Peter Karman, C<< <karman at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-swish-prog-lucy at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SWISH-Prog-Lucy>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SWISH::Prog::Lucy


You can also look for information at:

=over 4

=item * Mailing list

L<http://lists.swish-e.org/listinfo/users>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SWISH-Prog-Lucy>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SWISH-Prog-Lucy>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SWISH-Prog-Lucy>

=item * Search CPAN

L<http://search.cpan.org/dist/SWISH-Prog-Lucy/>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Peter Karman.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
