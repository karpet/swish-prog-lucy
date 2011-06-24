package SWISH::Prog::Lucy::Results;
use strict;
use warnings;

our $VERSION = '0.02';

use base qw( SWISH::Prog::Results );
use SWISH::Prog::Lucy::Result;

__PACKAGE__->mk_ro_accessors(qw( lucy_hits ));

=head1 NAME

SWISH::Prog::Lucy::Results - search results for Swish3 Lucy backend

=head1 SYNOPSIS

 # see SWISH::Prog::Results

=head1 DESCRIPTION

SWISH::Prog::Lucy::Results is an Apache Lucy based Results
class for Swish3.

=head1 METHODS

Only new and overridden methods are documented here. See
the L<SWISH::Prog::Results> documentation.

=head2 next

Returns the next SWISH::Prog::Lucy::Result object from the result set.

=cut

sub next {
    my $hit = $_[0]->lucy_hits->next or return;
    return SWISH::Prog::Lucy::Result->new(
        doc   => $hit,
        score => int( $hit->get_score * 1000 ),  # scale like xapian, swish-e
    );
}

=head2 lucy_hits

Get the internal Lucy::Search::Hits object.

=cut

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

