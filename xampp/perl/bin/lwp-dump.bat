@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!/xampp/perl/bin/perl.exe -w
#line 15

use strict;
use LWP::UserAgent ();
use Getopt::Long qw(GetOptions);

my $VERSION = "5.827";

GetOptions(\my %opt,
    'parse-head',
    'max-length=n',
    'keep-client-headers',
    'method=s',
    'agent=s',
) || usage();

my $url = shift || usage();
@ARGV && usage();

sub usage {
    (my $progname = $0) =~ s,.*/,,;
    die <<"EOT";
Usage: $progname [options] <url>

Recognized options are:
   --agent <str>
   --keep-client-headers
   --max-length <n>
   --method <str>
   --parse-head

EOT
}

my $ua = LWP::UserAgent->new(
    parse_head => $opt{'parse-head'} || 0,
    keep_alive => 1,
    env_proxy => 1,
    agent => $opt{agent} || "lwp-dump/$VERSION ",
);

my $req = HTTP::Request->new($opt{method} || 'GET' => $url);
my $res = $ua->simple_request($req);
$res->remove_header(grep /^Client-/, $res->header_field_names)
    unless $opt{'keep-client-headers'} or
        ($res->header("Client-Warning") || "") eq "Internal response";

$res->dump(maxlength => $opt{'max-length'});

__END__

=head1 NAME

lwp-dump - See what headers and content is returned for a URL

=head1 SYNOPSIS

B<lwp-dump> [ I<options> ] I<URL>

=head1 DESCRIPTION

The B<lwp-dump> program will get the resource indentified by the URL and then
dump the response object to STDOUT.  This will display the headers returned and
the initial part of the content, escaped so that it's safe to display even
binary content.  The escapes syntax used is the same as for Perl's double
quoted strings.  If there is no content the string "(no content)" is shown in
its place.

The following options are recognized:

=over

=item B<--agent> I<str>

Override the user agent string passed to the server.

=item B<--keep-client-headers>

LWP internally generate various C<Client-*> headers that are stripped by
B<lwp-dump> in order to show the headers exactly as the server provided them.
This option will suppress this.

=item B<--max-length> I<n>

How much of the content to show.  The default is 512.  Set this
to 0 for unlimited.

If the content is longer then the string is chopped at the
limit and the string "...\n(### more bytes not shown)"
appended.

=item B<--method> I<str>

Use the given method for the request instead of the default "GET".

=item B<--parse-head>

By default B<lwp-dump> will not try to initialize headers by looking at the
head section of HTML documents.  This option enables this.  This corresponds to
L<LWP::UserAgent/"parse_head">.

=back

=head1 SEE ALSO

L<lwp-request>, L<LWP>, L<HTTP::Message/"dump">


__END__
:endofperl
