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
package Apache2::PerlSections;

use strict;
use warnings FATAL => 'all';

our $VERSION = '2.00';

use Apache2::CmdParms ();
use Apache2::Directive ();
use APR::Table ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Const -compile => qw(OK);

use constant SPECIAL_NAME => 'PerlConfig';
use constant SPECIAL_PACKAGE => 'Apache2::ReadConfig';

sub new {
    my ($package, @args) = @_;
    return bless { @args }, ref($package) || $package;
}

sub parms      { return shift->{'parms'} }
sub directives { return shift->{'directives'} ||= [] }
sub package    { return shift->{'args'}->{'package'} }

my @saved;
sub save       { return $Apache2::PerlSections::Save }
sub server     { return $Apache2::PerlSections::Server }
sub saved      { return @saved }

sub handler : method {
    my ($self, $parms, $args) = @_;

    unless (ref $self) {
        $self = $self->new('parms' => $parms, 'args' => $args);
    }

    if ($self->save) {
        push @saved, $self->package;
    }

    my $special = $self->SPECIAL_NAME;

    for my $entry ($self->symdump()) {
        if ($entry->[0] !~ /$special/) {
            $self->dump_any(@$entry);
        }
    }

    {
        no strict 'refs';
        foreach my $package ($self->package) {
            my @config = map { split /\n/ }
                            grep { defined }
                                (@{"${package}::$special"},
                                 ${"${package}::$special"});
            $self->dump_special(@config);
        }
    }

    $self->post_config();

    Apache2::Const::OK;
}

my %directives_seen_hack;

sub symdump {
    my ($self) = @_;

    unless ($self->{symbols}) {
        no strict;

        $self->{symbols} = [];

        #XXX: Here would be a good place to warn about NOT using
        #     Apache2::ReadConfig:: directly in <Perl> sections
        foreach my $pack ($self->package, $self->SPECIAL_PACKAGE) {
            #XXX: Shamelessly borrowed from Devel::Symdump;
            while (my ($key, $val) = each(%{ *{"$pack\::"} })) {
                #We don't want to pick up stashes...
                next if ($key =~ /::$/);
                local (*ENTRY) = $val;
                if (defined $val && defined *ENTRY{SCALAR} && defined $ENTRY) {
                    push @{$self->{symbols}}, [$key, $ENTRY];
                }
                if (defined $val && defined *ENTRY{ARRAY}) {
                    unless (exists $directives_seen_hack{"$key$val"}) {
                        $directives_seen_hack{"$key$val"} = 1;
                        push @{$self->{symbols}}, [$key, \@ENTRY];
                    }
                }
                if (defined $val && defined *ENTRY{HASH} && $key !~ /::/) {
                    push @{$self->{symbols}}, [$key, \%ENTRY];
                }
            }
        }
    }

    return @{$self->{symbols}};
}

sub dump_special {
    my ($self, @data) = @_;
    $self->add_config(@data);
}

sub dump_any {
    my ($self, $name, $entry) = @_;
    my $type = ref $entry;

    if ($type eq 'ARRAY') {
        $self->dump_array($name, $entry);
    }
    elsif ($type eq 'HASH') {
        $self->dump_hash($name, $entry);
    }
    else {
        $self->dump_entry($name, $entry);
    }
}

sub dump_hash {
    my ($self, $name, $hash) = @_;

    for my $entry (keys %{ $hash || {} }) {
        my $item = $hash->{$entry};
        my $type = ref($item);

        if ($type eq 'HASH') {
            $self->dump_section($name, $entry, $item);
        }
        elsif ($type eq 'ARRAY') {
            for my $e (@$item) {
                $self->dump_section($name, $entry, $e);
            }
        }
    }
}

sub dump_section {
    my ($self, $name, $loc, $hash) = @_;

    $self->add_config("<$name $loc>\n");

    for my $entry (keys %{ $hash || {} }) {
        $self->dump_entry($entry, $hash->{$entry});
    }

    $self->add_config("</$name>\n");
}

sub dump_array {
    my ($self, $name, $entries) = @_;

    for my $entry (@$entries) {
        $self->dump_entry($name, $entry);
    }
}

sub dump_entry {
    my ($self, $name, $entry) = @_;
    my $type = ref $entry;

    if ($type eq 'SCALAR') {
        $self->add_config("$name $$entry\n");
    }
    elsif ($type eq 'ARRAY') {
        if (grep {ref} @$entry) {
            $self->dump_entry($name, $_) for @$entry;
        }
        else {
            $self->add_config("$name @$entry\n");
        }
    }
    elsif ($type eq 'HASH') {
        $self->dump_hash($name, $entry);
    }
    elsif ($type) {
        #XXX: Could do $type->can('httpd_config') here on objects ???
        die "Unknown type '$type' for directive $name";
    }
    elsif (defined $entry) {
        $self->add_config("$name $entry\n");
    }
}

sub add_config {
    my ($self, @config) = @_;
    foreach my $config (@config) {
        return unless defined $config;
        chomp($config);
        push @{ $self->directives }, $config;
    }
}

sub post_config {
    my ($self) = @_;
    my $errmsg = $self->parms->add_config($self->directives);
    die $errmsg if $errmsg;
}

sub dump {
    my $class = shift;
    require Apache2::PerlSections::Dump;
    return Apache2::PerlSections::Dump->dump(@_);
}

sub store {
    my $class = shift;
    require Apache2::PerlSections::Dump;
    return Apache2::PerlSections::Dump->store(@_);
}

1;
__END__

=head1 NAME

Apache2::PerlSections - write Apache configuration files in Perl





=head1 Synopsis

  <Perl>
  @PerlModule = qw(Mail::Send Devel::Peek);
  
  #run the server as whoever starts it
  $User  = getpwuid(>) || >;
  $Group = getgrgid()) || );
  
  $ServerAdmin = $User;
  
  </Perl>






=head1 Description

With C<E<lt>PerlE<gt>>...C<E<lt>/PerlE<gt>> sections, it is possible
to configure your server entirely in Perl.

C<E<lt>PerlE<gt>> sections can contain I<any> and as much Perl code as
you wish. These sections are compiled into a special package whose
symbol table mod_perl can then walk and grind the names and values of
Perl variables/structures through the Apache core configuration gears.

Block sections such as C<E<lt>LocationE<gt>>..C<E<lt>/LocationE<gt>>
are represented in a C<%Location> hash, e.g.:

  <Perl>
  $Location{"/~dougm/"} = {
    AuthUserFile   => '/tmp/htpasswd',
    AuthType       => 'Basic',
    AuthName       => 'test',
    DirectoryIndex => [qw(index.html index.htm)],
    Limit          => {
        "GET POST"    => {
            require => 'user dougm',
        }
    },
  };
  </Perl>

If an Apache directive can take two or three arguments you may push
strings (the lowest number of arguments will be shifted off the
C<@list>) or use an array reference to handle any number greater than
the minimum for that directive:

  push @Redirect, "/foo", "http://www.foo.com/";
  
  push @Redirect, "/imdb", "http://www.imdb.com/";
  
  push @Redirect, [qw(temp "/here" "http://www.there.com")];

Other section counterparts include C<%VirtualHost>, C<%Directory> and
C<%Files>.

To pass all environment variables to the children with a single
configuration directive, rather than listing each one via C<PassEnv>
or C<PerlPassEnv>, a C<E<lt>PerlE<gt>> section could read in a file and:

  push @PerlPassEnv, [$key => $val];

or

  Apache2->httpd_conf("PerlPassEnv $key $val");

These are somewhat simple examples, but they should give you the basic
idea. You can mix in any Perl code you desire. See I<eg/httpd.conf.pl>
and I<eg/perl_sections.txt> in the mod_perl distribution for more
examples.

Assume that you have a cluster of machines with similar configurations
and only small distinctions between them: ideally you would want to
maintain a single configuration file, but because the configurations
aren't I<exactly> the same (e.g. the C<ServerName> directive) it's not
quite that simple.

C<E<lt>PerlE<gt>> sections come to rescue. Now you have a single
configuration file and the full power of Perl to tweak the local
configuration. For example to solve the problem of the C<ServerName>
directive you might have this C<E<lt>PerlE<gt>> section:

  <Perl>
  $ServerName = `hostname`;
  </Perl>

For example if you want to allow personal directories on all machines
except the ones whose names start with I<secure>:

  <Perl>
  $ServerName = `hostname`;
  if ($ServerName !~ /^secure/) {
      $UserDir = "public.html";
  }
  else {
      $UserDir = "DISABLED";
  }
  </Perl>





=head1 API

C<Apache2::PerlSections> provides the following functions and/or methods:


=head2 C<server>

Get the current server's object for the E<lt>PerlE<gt> section

  <Perl>
    $s = Apache2::PerlSections->server();
  </Perl>

=over 4

=item obj: C<Apache2::PerlSections> (class name)

=item ret: C<$s>
( C<L<Apache2::ServerRec object|docs::2.0::api::Apache2::ServerRec>> )

=item since: 2.0.03

=back





=head1 C<@PerlConfig> and C<$PerlConfig>

This array and scalar can be used to introduce literal configuration
into the apache configuration. For example:

  push @PerlConfig, 'Alias /foo /bar';

Or:
  $PerlConfig .= "Alias /foo /bar\n";

See also
C<L<$r-E<gt>add_config|docs::2.0::api::Apache2::RequestUtil/C_add_config_>>





=head1 Configuration Variables

There are a few variables that can be set to change the default
behaviour of C<E<lt>PerlE<gt>> sections.





=head2 C<$Apache2::PerlSections::Save>

Each C<E<lt>PerlE<gt>> section is evaluated in its unique namespace,
by default residing in a sub-namespace of C<Apache2::ReadConfig::>,
therefore any local variables will end up in that namespace. For
example if a C<E<lt>PerlE<gt>> section happened to be in file
F</tmp/httpd.conf> starting on line 20, the namespace:
C<Apache2::ReadConfig::tmp::httpd_conf::line_20> will be used. Now if
it had:

  <Perl>
    $foo     = 5;
    my $bar  = 6;
    $My::tar = 7;
  </Perl>

The local global variable C<$foo> becomes
C<$Apache2::ReadConfig::tmp::httpd_conf::line_20::foo>, the other
variable remain where they are.

By default, the namespace in which C<E<lt>PerlE<gt>> sections are
evaluated is cleared after each block closes. In our example nuking
C<$Apache2::ReadConfig::tmp::httpd_conf::line_20::foo>, leaving the
rest untouched.

By setting C<$Apache2::PerlSections::Save> to a true value, the content
of those namespaces will be preserved and will be available for
inspection by C<L<Apache2::Status|docs::2.0::api::Apache2::Status>> and
C<L<Apache2::PerlSections-E<gt>dump|/C_Apache2__PerlSections_E_gt_dump_>>
In our example C<$Apache2::ReadConfig::tmp::httpd_conf::line_20::foo>
will still be accessible from other perl code, after the
C<E<lt>PerlE<gt>> section was parsed.





=head1 PerlSections Dumping



=head2 C<Apache2::PerlSections-E<gt>dump>

This method will dump out all the configuration variables mod_perl
will be feeding to the apache config gears. The output is suitable to
read back in via C<eval>.

  my $dump = Apache2::PerlSections->dump;

=over 4

=item ret: C<$dump> ( string / C<undef> )

A string dump of all the Perl code encountered in E<lt>PerlE<gt> blocks,
suitable to be read back via C<eval>

=back

For example:

  <Perl>
  
  $Apache2::PerlSections::Save = 1;
  
  $Listen = 8529;
  
  $Location{"/perl"} = {
     SetHandler => "perl-script",
     PerlHandler => "ModPerl::Registry",
     Options => "ExecCGI",
  };
  
  @DirectoryIndex = qw(index.htm index.html);
  
  $VirtualHost{"www.foo.com"} = {
     DocumentRoot => "/tmp/docs",
     ErrorLog => "/dev/null",
     Location => {
       "/" => {
         Allowoverride => 'All',
         Order => 'deny,allow',
         Deny  => 'from all',
         Allow => 'from foo.com',
       },
     },
  };
  </Perl>
  
  <Perl>
  print Apache2::PerlSections->dump;
  </Perl>

This will print something like this:

  $Listen = 8529;
  
  @DirectoryIndex = (
    'index.htm',
    'index.html'
  );
  
  $Location{'/perl'} = (
      PerlHandler => 'Apache2::Registry',
      SetHandler => 'perl-script',
      Options => 'ExecCGI'
  );
  
  $VirtualHost{'www.foo.com'} = (
      Location => {
        '/' => {
          Deny => 'from all',
          Order => 'deny,allow',
          Allow => 'from foo.com',
          Allowoverride => 'All'
        }
      },
      DocumentRoot => '/tmp/docs',
      ErrorLog => '/dev/null'
  );
  
  1;
  __END__


It is important to put the call to C<dump> in it's own C<E<lt>PerlE<gt>>
section, otherwise the content of the current C<E<lt>PerlE<gt>> section
will not be dumped.





=head2 C<Apache2::PerlSections-E<gt>store>

This method will call the C<dump> method, writing the output
to a file, suitable to be pulled in via C<require> or C<do>.

  Apache2::PerlSections->store($filename);

=over 4

=item arg1: C<$filename> (string)

The filename to save the dump output to

=item ret: no return value

=back





=head1 Advanced API

mod_perl 2.0 now introduces the same general concept of handlers to
C<E<lt>PerlE<gt>> sections.  Apache2::PerlSections simply being the
default handler for them.

To specify a different handler for a given perl section, an extra
handler argument must be given to the section:

  <Perl handler="My::PerlSection::Handler" somearg="test1">
    $foo = 1;
    $bar = 2;
  </Perl>

And in My/PerlSection/Handler.pm:

  sub My::Handler::handler : handler {
      my ($self, $parms, $args) = @_;
      #do your thing!
  }

So, when that given C<E<lt>PerlE<gt>> block in encountered, the code
within will first be evaluated, then the handler routine will be
invoked with 3 arguments:

=over

=item arg1: C<$self>

self-explanatory

=item arg2: C<$parms>
( C<L<Apache2::CmdParms|docs::2.0::api::Apache2::CmdParms>> )

C<$parms> is specific for the current Container, for example, you
might want to call C<$parms-E<gt>server()> to get the current server.

=item arg3: C<$args>
( C<L<APR::Table object|docs::2.0::api::APR::Table>>)

the table object of the section arguments. The 2 guaranteed ones will
be:

  $args->{'handler'} = 'My::PerlSection::Handler';
  $args->{'package'} = 'Apache2::ReadConfig';

Other C<name="value"> pairs given on the C<E<lt>PerlE<gt>> line will
also be included.

=back

At this point, it's up to the handler routing to inspect the namespace
of the C<$args>-E<gt>{'package'} and chooses what to do.

The most likely thing to do is to feed configuration data back into
apache. To do that, use Apache2::Server-E<gt>add_config("directive"),
for example:

  $parms->server->add_config("Alias /foo /bar");

Would create a new alias. The source code of C<Apache2::PerlSections>
is a good place to look for a practical example.



=head1 Verifying C<E<lt>PerlE<gt>> Sections

If the C<E<lt>PerlE<gt>> sections include no code requiring a running
mod_perl, it is possible to check those from the command line. But the
following trick should be used:

  # file: httpd.conf
  <Perl>
  #!perl
  
  # ... code here ...
  
  __END__
  </Perl>

Now you can run:

  % perl -c httpd.conf





=head1 Bugs




=head2 E<lt>PerlE<gt> directive missing closing 'E<gt>'

httpd-2.0.47 had a bug in the configuration parser which caused the
startup failure with the following error:

  Starting httpd:
  Syntax error on line ... of /etc/httpd/conf/httpd.conf:
  <Perl> directive missing closing '>'     [FAILED]

This has been fixed in httpd-2.0.48. If you can't upgrade to this or a
higher version, please add a space before the closing 'E<gt>' of the
opening tag as a workaround. So if you had:

  <Perl>
  # some code
  </Perl>

change it to be:

  <Perl >
  # some code
  </Perl>





=head2 E<lt>PerlE<gt>[...]E<gt> was not closed.

On encountering a one-line E<lt>PerlE<gt> block, 
httpd's configuration parser will cause a startup
failure with an error similar to this one:

  Starting httpd:
  Syntax error on line ... of /etc/httpd/conf/httpd.conf:
  <Perl>use> was not closed.

If you have written a simple one-line E<lt>PerlE<gt>
section like this one :

  <Perl>use Apache::DBI;</Perl>

change it to be:

   <Perl>
   use Apache::DBI;
   </Perl>

This is caused by a limitation of httpd's configuration
parser and is not likely to be changed to allow one-line
block like the example above. Use multi-line blocks instead.




=head1 See Also

L<mod_perl 2.0 documentation|docs::2.0::index>.






=head1 Copyright

mod_perl 2.0 and its core modules are copyrighted under
The Apache Software License, Version 2.0.




=head1 Authors

L<The mod_perl development team and numerous
contributors|about::contributors::people>.

=cut

