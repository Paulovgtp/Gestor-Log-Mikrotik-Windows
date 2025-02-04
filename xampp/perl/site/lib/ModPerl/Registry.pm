# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package ModPerl::Registry;

use strict;
use warnings FATAL => 'all';

# we try to develop so we reload ourselves without die'ing on the warning
no warnings qw(redefine); # XXX, this should go away in production!

our $VERSION = '1.99';

use base qw(ModPerl::RegistryCooker);

sub handler : method {
    my $class = (@_ >= 2) ? shift : __PACKAGE__;
    my $r = shift;
    return $class->new($r)->default_handler();
}

my $parent = 'ModPerl::RegistryCooker';
# the following code:
# - specifies package's behavior different from default of $parent class
# - speeds things up by shortcutting @ISA search, so even if the
#   default is used we still use the alias
my %aliases = (
    new             => 'new',
    init            => 'init',
    default_handler => 'default_handler',
    run             => 'run',
    can_compile     => 'can_compile',
    make_namespace  => 'make_namespace',
    namespace_root  => 'namespace_root',
    namespace_from  => 'namespace_from_filename',
    is_cached       => 'is_cached',
    should_compile  => 'should_compile_if_modified',
    flush_namespace => 'NOP',
    cache_table     => 'cache_table_common',
    cache_it        => 'cache_it',
    read_script     => 'read_script',
    shebang_to_perl => 'shebang_to_perl',
    get_script_name => 'get_script_name',
    chdir_file      => 'NOP',
    get_mark_line   => 'get_mark_line',
    compile         => 'compile',
    error_check     => 'error_check',
    strip_end_data_segment             => 'strip_end_data_segment',
    convert_script_to_compiled_handler => 'convert_script_to_compiled_handler',
);

# in this module, all the methods are inherited from the same parent
# class, so we fixup aliases instead of using the source package in
# first place.
$aliases{$_} = $parent . "::" . $aliases{$_} for keys %aliases;

__PACKAGE__->install_aliases(\%aliases);

# Note that you don't have to do the aliases if you use defaults, it
# just speeds things up the first time the sub runs, after that
# methods are cached.
#
# But it's still handy, since you explicitly specify which subs from
# the parent package you are using
#

# META: if the ISA search results are cached on the first lookup, may
# be we need to alias only those methods that override the defaults?


1;
__END__

=head1 NAME

ModPerl::Registry - Run unaltered CGI scripts persistently under mod_perl

=head1 Synopsis

  # httpd.conf
  PerlModule ModPerl::Registry
  Alias /perl/ /home/httpd/perl/
  <Location /perl>
      SetHandler perl-script
      PerlResponseHandler ModPerl::Registry
      #PerlOptions +ParseHeaders
      #PerlOptions -GlobalRequest
      Options +ExecCGI
  </Location>

=head1 Description

URIs in the form of C<http://example.com/perl/test.pl> will be
compiled as the body of a Perl subroutine and executed.  Each child
process will compile the subroutine once and store it in memory. It
will recompile it whenever the file (e.g. I<test.pl> in our example)
is updated on disk.  Think of it as an object oriented server with
each script implementing a class loaded at runtime.

The file looks much like a "normal" script, but it is compiled into a
subroutine.

For example:

  my $r = Apache2::RequestUtil->request;
  $r->content_type("text/html");
  $r->send_http_header;
  $r->print("mod_perl rules!");

XXX: STOPPED here. Below is the old Apache::Registry document which I
haven't worked through yet.

META: document that for now we don't chdir() into the script's dir,
because it affects the whole process under
threads. C<L<ModPerl::RegistryPrefork|docs::2.0::api::ModPerl::RegistryPrefork>>
should be used by those who run only under prefork MPM.

This module emulates the CGI environment, allowing programmers to
write scripts that run under CGI or mod_perl without change.  Existing
CGI scripts may require some changes, simply because a CGI script has
a very short lifetime of one HTTP request, allowing you to get away
with "quick and dirty" scripting.  Using mod_perl and ModPerl::Registry
requires you to be more careful, but it also gives new meaning to the
word "quick"!

Be sure to read all mod_perl related documentation for more details,
including instructions for setting up an environment that looks
exactly like CGI:

 print "Content-type: text/html\n\n";
 print "Hi There!";

Note that each httpd process or "child" must compile each script once,
so the first request to one server may seem slow, but each request
there after will be faster.  If your scripts are large and/or make use
of many Perl modules, this difference should be noticeable to the
human eye.

=head1 DirectoryIndex

If you are trying setup a DirectoryIndex under a Location
covered by ModPerl::Registry* you might run into some trouble.

META: if this gets added to core, replace with real documenation.
See http://marc.theaimsgroup.com/?l=apache-modperl&m=112805393100758&w=2


=head1 Special Blocks


=head2 C<BEGIN> Blocks

C<BEGIN> blocks defined in scripts running under the
C<ModPerl::Registry> handler behave similarly to the normal L<mod_perl
handlers|docs::2.0::user::coding::coding/C_BEGIN__Blocks> plus:

=over

=item *

Only once, if pulled in by the parent process via
C<Apache2::RegistryLoader>.

=item *

An additional time, once per child process or Perl interpreter, each
time the script file changes on disk.

=back

C<BEGIN> blocks defined in modules loaded from C<ModPerl::Registry>
scripts behave identically to the normal L<mod_perl
handlers|docs::2.0::user::coding::coding/C_BEGIN__Blocks>, regardless
of whether they define a package or not.



=head2 C<CHECK> and C<INIT> Blocks

Same as normal L<mod_perl
handlers|docs::2.0::user::coding::coding/C_CHECK__and_C_INIT__Blocks>.



=head2 C<END> Blocks

C<END> blocks encountered during compilation of a script, are called
after the script has completed its run, including subsequent
invocations when the script is cached in memory. This is assuming that
the script itself doesn't define a package on its own. If the script
defines its own package, the C<END> blocks in the scope of that
package will be executed at the end of the interpretor's life.

C<END> blocks residing in modules loaded by registry script will be
executed only once, when the interpreter exits.



=head1 Security

C<ModPerl::Registry::handler> performs the same sanity checks as
mod_cgi does, before running the script.



=head1 Environment

The Apache function `exit' overrides the Perl core built-in function.

=head1 Commandline Switches In First Line

Normally when a Perl script is run from the command line or under CGI,
arguments on the `#!' line are passed to the perl interpreter for processing.

C<ModPerl::Registry> currently only honors the B<-w> switch and will
enable the C<warnings> pragma in such case.

Another common switch used with CGI scripts is B<-T> to turn on taint
checking.  This can only be enabled when the server starts with the
configuration directive:

 PerlSwitches -T

However, if taint checking is not enabled, but the B<-T> switch is
seen, C<ModPerl::Registry> will write a warning to the I<error_log>
file.

=head1 Debugging

You may set the debug level with the $ModPerl::Registry::Debug bitmask

 1 => log recompile in errorlog
 2 => ModPerl::Debug::dump in case of $@
 4 => trace pedantically

=head1 Caveats

ModPerl::Registry makes things look just the CGI environment, however, you
must understand that this *is not CGI*.  Each httpd child will compile
your script into memory and keep it there, whereas CGI will run it once,
cleaning out the entire process space.  Many times you have heard
"always use C<-w>, always use C<-w> and 'use strict'".
This is more important here than anywhere else!



=head1 Authors

Andreas J. Koenig, Doug MacEachern and Stas Bekman.

=head1 See Also

C<L<ModPerl::RegistryCooker|docs::2.0::api::ModPerl::RegistryCooker>>,
C<L<ModPerl::RegistryBB|docs::2.0::api::ModPerl::RegistryBB>> and
C<L<ModPerl::PerlRun|docs::2.0::api::ModPerl::PerlRun>>.

=cut
