package Catalyst::Engine::CGI;

use strict;
use base 'Catalyst::Engine';
use URI;

require CGI::Simple;

$CGI::Simple::POST_MAX        = 1048576;
$CGI::Simple::DISABLE_UPLOADS = 0;

__PACKAGE__->mk_accessors('cgi');

=head1 NAME

Catalyst::Engine::CGI - The CGI Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::CGI module might look like:

    #!/usr/bin/perl -w

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

The application module (C<MyApp>) would use C<Catalyst>, which loads the
appropriate engine module.

=head1 DESCRIPTION

This is the Catalyst engine specialized for the CGI environment (using the
C<CGI::Simple> and C<CGI::Cookie> modules).  Normally Catalyst will select the
appropriate engine according to the environment that it detects, however you
can force Catalyst to use the CGI engine by specifying the following in your
application module:

    use Catalyst qw(-Engine=CGI);

The performance of this way of using Catalyst is not expected to be
useful in production applications, but it may be helpful for development.

=head1 METHODS

=over 4

=item $c->cgi

This config parameter contains the C<CGI::Simple> object.

=back

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine>.

=over 4

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;
    my %headers;

    $headers{-status} = $c->response->status if $c->response->status;

    for my $name ( $c->response->headers->header_field_names ) {
        $headers{"-$name"} = $c->response->header($name);
    }

    print $c->cgi->header(%headers);
}

=item $c->finalize_output

Prints the response output to STDOUT.

=cut

sub finalize_output {
    my $c = shift;
    print $c->response->output;
}

=item $c->prepare_connection

=cut

sub prepare_connection {
    my $c = shift;
    $c->req->hostname( $c->cgi->remote_host );
    $c->req->address( $c->cgi->remote_addr );
}

=item $c->prepare_headers

=cut

sub prepare_headers {
    my $c = shift;
    $c->req->method( $c->cgi->request_method );
    for my $header ( $c->cgi->http ) {
        ( my $field = $header ) =~ s/^HTTPS?_//;
        $c->req->headers->header( $field => $c->cgi->http($header) );
    }
    $c->req->headers->header( 'Content-Type'   => $c->cgi->content_type );
    $c->req->headers->header( 'Content-Length' => $c->cgi->content_length );
}

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c    = shift;

    $c->cgi->parse_query_string;
 
    my %vars = $c->cgi->Vars;
    while ( my ( $key, $value ) = each %vars ) {
        my @values = split "\0", $value;
        $vars{$key} = @values <= 1 ? $values[0] : \@values;
    }
    $c->req->parameters( {%vars} );
}

=item $c->prepare_path

=cut

sub prepare_path {
    my $c = shift;

    my $base;
    {
        my $scheme = $ENV{HTTPS} ? 'https' : 'http';
        my $host   = $ENV{HTTP_HOST} || $ENV{SERVER_NAME};
        my $port   = $ENV{SERVER_PORT} || 80;
        my $path   = $ENV{SCRIPT_NAME} || '/';

        $base = URI->new;
        $base->scheme($scheme);
        $base->host($host);
        $base->port($port);
        $base->path($path);

        $base = $base->canonical->as_string;
    }

    my $path = $ENV{PATH_INFO} || '/';
    $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    $path =~  s/^\///;

    $c->req->base($base);
    $c->req->path($path);
}

=item $c->prepare_request

=cut

sub prepare_request { shift->cgi( CGI::Simple->new ) }

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;
    for my $name ( $c->cgi->upload ) {
        next unless defined $name;
        $c->req->uploads->{$name} = {
            fh   => $c->cgi->upload($name),
            size => $c->cgi->upload_info( $name, 'size' ),
            type => $c->cgi->upload_info( $name, 'mime' )
        };
    }
}

=item $c->run

=cut

sub run { shift->handler }

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
