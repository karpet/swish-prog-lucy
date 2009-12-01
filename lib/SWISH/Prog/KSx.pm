package SWISH::Prog::KSx;
use strict;
use warnings;

our $VERSION = '0.02';

=head1 NAME

SWISH::Prog::KSx - Swish3 KinoSearch backend

=head1 SYNOPSIS

 # create an index
 use SWISH::Prog;
 my $indexer = SWISH::Prog->new(
    invindex   => 'path/to/index.swish',
    aggregator => 'fs',
    indexer    => 'ks',
    config     => 'path/to/swish.conf',
 );
 
 $indexer->index('path/to/files');
 
 
 # then search the index
 my $searcher = SWISH::Prog::KSx::Searcher->new(
    invindex => 'path/to/index.swish',
    config   => 'path/to/swish.conf',
 );
 my $results = $searcher->search('my query')
 while ( my $result = $results->next ) {
    printf("%s : %s\n", $result->score, $result->uri);
 }


=head1 DESCRIPTION

B<STOP>: Read the L<SWISH::Prog> documentation before you use this
module.

SWISH::Prog::KSx is a KinoSearch-based implementation of Swish3,
using the SWISH::3 bindings for libswish3.

See the L<SWISH::Prog> docs for more information about the class
hierarchy and history.

See the Swish3 development site at L<http://dev.swish-e.org/wiki/swish3>.

=head1 Why Not Use KinoSearch Directly?

You can use KinoSearch directly. Using KinoSearch via SWISH::Prog::KSx
offers a few advantages:

=over

=item Aggregators and Filters

You get to use all of SWISH::Prog's Aggregators and SWISH::Filter support.
So you can easily index all kinds of file formats 
(email, .txt, .html, .xml, .pdf, .doc, .xls, etc) 
without writing your own parser.

=item SWISH::3

SWISH::3 offers fast and robust XML and HTML parsers 
with an extensible configuration system, build on top of libxml2.

=item Simple now, complex later

You can index your content with SWISH::Prog::KSx,
then build a more complex searching application directly
with KinoSearch.

=back

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

=head1 SEE ALSO

L<SWISH::Prog>, L<KinoSearch>

=cut

1;
