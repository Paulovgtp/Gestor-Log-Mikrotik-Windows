# 
# /*
#  * *********** WARNING **************
#  * This file generated by ModPerl::WrapXS/0.01
#  * Any changes made here will be lost
#  * ***********************************
#  * 01: lib/ModPerl/Code.pm:709
#  * 02: \xampp\perl\bin\.cpanplus\5.10.1\build\mod_perl-2.0.4\blib\lib/ModPerl/WrapXS.pm:626
#  * 03: \xampp\perl\bin\.cpanplus\5.10.1\build\mod_perl-2.0.4\blib\lib/ModPerl/WrapXS.pm:1175
#  * 04: \xampp\perl\bin\.cpanplus\5.10.1\build\mod_perl-2.0.4\Makefile.PL:423
#  * 05: \xampp\perl\bin\.cpanplus\5.10.1\build\mod_perl-2.0.4\Makefile.PL:325
#  * 06: \xampp\perl\bin\.cpanplus\5.10.1\build\mod_perl-2.0.4\Makefile.PL:56
#  * 07: \xampp\perl\bin\cpanp-run-perl.bat:21
#  */
# 


package Apache2::Response;

use strict;
use warnings FATAL => 'all';



use Apache2::XSLoader ();
our $VERSION = '2.000004';
Apache2::XSLoader::load __PACKAGE__;



1;
__END__

=head1 NAME

Apache2::Response - Perl API for Apache HTTP request response methods




=head1 Synopsis

  use Apache2::Response ();
  
  $r->custom_response(Apache2::Const::FORBIDDEN, "No Entry today");
  
  $etag = $r->make_etag($force_weak);
  $r->set_etag();
  $status = $r->meets_conditions();
  
  $mtime_rat = $r->rationalize_mtime($mtime);
  $r->set_last_modified($mtime);
  $r->update_mtime($mtime);
  
  $r->send_cgi_header($buffer);
  
  $r->set_content_length($length);
  
  $ret = $r->set_keepalive();







=head1 Description

C<Apache2::Response> provides the L<Apache request
object|docs::2.0::api::Apache2::RequestRec> utilities API for dealing
with HTTP response generation process.





=head1 API

C<Apache2::Response> provides the following functions and/or methods:




=head2 C<custom_response>

Install a custom response handler for a given status

  $r->custom_response($status, $string);

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

The current request

=item arg1: C<$status> ( C<L<Apache2::Const
constant|docs::2.0::api::Apache2::Const>> )

The status for which the custom response should be used
(e.g. C<Apache2::Const::AUTH_REQUIRED>)

=item arg2: C<$string> (string)

The custom response to use.  This can be a static string, or a URL,
full or just the uri path (I</foo/bar.txt>).

=item ret: no return value

=item since: 2.0.00

=back

C<custom_response()> doesn't alter the response code, but is used to
replace the standard response body. For example, here is how to change
the response body for the access handler failure:

  package MyApache2::MyShop;
  use Apache2::Response ();
  use Apache2::Const -compile => qw(FORBIDDEN OK);
  sub access {
      my $r = shift;
   
      if (MyApache2::MyShop::tired_squirrels()) {
          $r->custom_response(Apache2::Const::FORBIDDEN,
              "It's siesta time, please try later");
          return Apache2::Const::FORBIDDEN;
      }
  
      return Apache2::Const::OK;
  }
  ...

  # httpd.conf
  PerlModule MyApache2::MyShop
  <Location /TestAPI__custom_response>
      AuthName dummy
      AuthType none
      PerlAccessHandler   MyApache2::MyShop::access
      PerlResponseHandler MyApache2::MyShop::response
  </Location>

When squirrels can't run any more, the handler will return 403, with
the custom message:

  It's siesta time, please try later








=head2 C<make_etag>

Construct an entity tag from the resource information.  If it's a real
file, build in some of the file characteristics.

  $etag = $r->make_etag($force_weak);

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

The current request

=item arg1: C<$force_weak> (number)

Force the entity tag to be weak - it could be modified
again in as short an interval.

=item ret: C<$etag> (string)

The entity tag

=item since: 2.0.00

=back







=head2 C<meets_conditions>

Implements condition C<GET> rules for HTTP/1.1 specification.  This
function inspects the client headers and determines if the response
fulfills the specified requirements.

  $status = $r->meets_conditions();

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

The current request

=item ret: C<$status> ( C<L<Apache2::Const
status constant|docs::2.0::api::Apache2::Const>> )

C<Apache2::Const::OK> if the response fulfills the condition GET
rules. Otherwise some other status code (which should be returned to
Apache).

=item since: 2.0.00

=back

Refer to the L<Generating Correct HTTP
Headers|docs::general::correct_headers::correct_headers/> document
for an indepth discussion of this method.







=head2 C<rationalize_mtime>

Return the latest rational time from a request/mtime pair.

  $mtime_rat = $r->rationalize_mtime($mtime);

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

The current request

=item arg1: C<$mtime> ( time in seconds )

The last modified time

=item ret: C<$mtime_rat> ( time in seconds )

the latest rational time from a request/mtime pair.  Mtime is
returned unless it's in the future, in which case we return the
current time.

=item since: 2.0.00

=back







=head2 C<send_cgi_header>

Parse the header

  $r->send_cgi_header($buffer);

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

=item arg1: C<$buffer> (string)

headers and optionally a response body

=item ret: no return value

=item since: 2.0.00

=back

This method is really for back-compatibility with mod_perl 1.0. It's
very inefficient to send headers this way, because of the parsing
overhead.

If there is a response body following the headers it'll be handled too
(as if it was sent via
C<L<print()|docs::2.0::api::Apache2::RequestIO/C_print_>>).

Notice that if only HTTP headers are included they won't be sent until
some body is sent (again the "send" part is retained from the mod_perl
1.0 method).







=head2 C<set_content_length>

Set the content length for this request.

  $r->set_content_length($length);

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

The current request

=item arg1: C<$length> (integer)

The new content length

=item ret: no return value

=item since: 2.0.00

=back







=head2 C<set_etag>

Set the E-tag outgoing header

  $r->set_etag();

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

=item ret: no return value

=item since: 2.0.00

=back







=head2 C<set_keepalive>

Set the keepalive status for this request

  $ret = $r->set_keepalive();

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

The current request

=item ret: C<$ret> ( boolean )

true if keepalive can be set, false otherwise

=item since: 2.0.00

=back

It's called by C<ap_http_header_filter()>. For the complete
complicated logic implemented by this method see
F<httpd-2.0/server/http_protocol.c>.





=head2 C<set_last_modified>

sets the C<Last-Modified> response header field to the value of the
mtime field in the request structure -- rationalized to keep it from
being in the future.

  $r->set_last_modified($mtime);

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

=item opt arg1: C<$mtime> ( time in seconds )

if the C<$mtime> argument is passed,
L<$r-E<gt>update_mtime|/C_update_mtime_> will be first run with that
argument.

=item ret: no return value

=item since: 2.0.00

=back





=head2 C<update_mtime>

Set the
C<L<$r-E<gt>mtime|docs::2.0::api::Apache2::RequestRec/C_mtime_>> field
to the specified value if it's later than what's already there.

  $r->update_mtime($mtime);

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

The current request

=item arg1: C<$mtime> ( time in seconds )

=item ret: no return value

=item since: 2.0.00

=back

See also: L<$r-E<gt>set_last_modified|/C_set_last_modified_>.





=head1 Unsupported API

C<Apache2::Response> also provides auto-generated Perl interface for a
few other methods which aren't tested at the moment and therefore
their API is a subject to change. These methods will be finalized
later as a need arises. If you want to rely on any of the following
methods please contact the L<the mod_perl development mailing
list|maillist::dev> so we can help each other take the steps necessary
to shift the method to an officially supported API.




=head2 C<send_error_response>

Send an "error" response back to client. It is used for any response
that can be generated by the server from the request record.  This
includes all 204 (no content), 3xx (redirect), 4xx (client error), and
5xx (server error) messages that have not been redirected to another
handler via the ErrorDocument feature.

  $r->send_error_response($recursive_error);

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

The current request

=item arg1: C<$recursive_error> ( boolean )

the error status in case we get an error in the process of trying to
deal with an C<ErrorDocument> to handle some other error.  In that
case, we print the default report for the first thing that went wrong,
and more briefly report on the problem with the C<ErrorDocument>.

=item ret: no return value

=item since: 2.0.00

=back

META: it's really an internal Apache method, I'm not quite sure how
can it be used externally.




=head2 C<send_mmap>

META: Autogenerated - needs to be reviewed/completed

Send an MMAP'ed file to the client

  $ret = $r->send_mmap($mm, $offset, $length);

=over 4

=item obj: C<$r>
( C<L<Apache2::RequestRec object|docs::2.0::api::Apache2::RequestRec>> )

The current request

=item arg1: C<$mm> (C<L<APR::Mmap|docs::2.0::api::APR::Mmap>>)

The MMAP'ed file to send

=item arg2: C<$offset> (number)

The offset into the MMAP to start sending

=item arg3: C<$length> (integer)

The amount of data to send

=item ret: C<$ret> (integer)

The number of bytes sent

=item since: 2.0.00

=back

META: requires a working APR::Mmap, which is not supported at the
moment.







=head1 See Also

L<mod_perl 2.0 documentation|docs::2.0::index>.




=head1 Copyright

mod_perl 2.0 and its core modules are copyrighted under
The Apache Software License, Version 2.0.




=head1 Authors

L<The mod_perl development team and numerous
contributors|about::contributors::people>.

=cut

