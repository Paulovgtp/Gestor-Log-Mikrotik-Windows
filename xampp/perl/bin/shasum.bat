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
#!perl
#line 15
    eval 'exec \xampp\perl\bin\perl.exe -S $0 ${1+"$@"}'
	if $running_under_some_shell;
#!perl -w

	# shasum: filter for computing SHA digests (analogous to sha1sum)
	#
	# Copyright (C) 2003-2008 Mark Shelor, All Rights Reserved
	#
	# Version: 5.47
	# Wed Apr 30 04:00:54 MST 2008

=head1 NAME

shasum - Print or Check SHA Checksums

=head1 SYNOPSIS

 Usage: shasum [OPTION] [FILE]...
    or: shasum [OPTION] --check [FILE]
 Print or check SHA checksums.
 With no FILE, or when FILE is -, read standard input.

  -a, --algorithm    1 (default), 224, 256, 384, 512
  -b, --binary       read files in binary mode (default on DOS/Windows)
  -c, --check        check SHA sums against given list
  -p, --portable     read files in portable mode
                         produces same digest on Windows/Unix/Mac
  -t, --text         read files in text mode (default)

 The following two options are useful only when verifying checksums:

  -s, --status       don't output anything, status code shows success
  -w, --warn         warn about improperly formatted SHA checksum lines

  -h, --help         display this help and exit
  -v, --version      output version information and exit

 The sums are computed as described in FIPS PUB 180-2.  When checking,
 the input should be a former output of this program.  The default mode
 is to print a line with checksum, a character indicating type (`*'
 for binary, `?' for portable, ` ' for text), and name for each FILE.

=head1 DESCRIPTION

The I<shasum> script provides the easiest and most convenient way to
compute SHA message digests.  Rather than writing a program, the user
simply feeds data to the script via the command line, and waits for
the results to be printed on standard output.  Data can be fed to
I<shasum> through files, standard input, or both.

The following command shows how easy it is to compute digests for typical
inputs such as the NIST test vector "abc":

	perl -e "print qw(abc)" | shasum

Or, if you want to use SHA-256 instead of the default SHA-1, simply say:

	perl -e "print qw(abc)" | shasum -a 256

Since I<shasum> uses the same interface employed by the familiar
I<sha1sum> program (and its somewhat outmoded anscestor I<md5sum>),
you can install this script as a convenient drop-in replacement.

=head1 AUTHOR

Copyright (c) 2003-2008 Mark Shelor <mshelor@cpan.org>.

=head1 SEE ALSO

shasum is implemented using the Perl module L<Digest::SHA> or
L<Digest::SHA::PurePerl>.

=cut

use strict;
use FileHandle;
use Getopt::Long;

my $VERSION = "5.47";


	# Try to use Digest::SHA, since it's faster.  If not installed,
	# use Digest::SHA::PurePerl instead.

my $MOD_PREFER = "Digest::SHA";
my $MOD_SECOND = "Digest::SHA::PurePerl";

my $module = $MOD_PREFER;
eval "require $module";
if ($@) {
	$module = $MOD_SECOND;
	eval "require $module";
	die "Unable to find $MOD_PREFER or $MOD_SECOND\n" if $@;
}


	# Usage statement adapted from Ulrich Drepper's md5sum.
	# Include an "-a" option for algorithm selection,
	# and a "-p" option for portable digest computation.

sub usage {
	my($err, $msg) = @_;

	$msg = "" unless defined $msg;
	if ($err) {
		warn($msg . "Type shasum -h for help\n");
		exit($err);
	}
	print <<'END_OF_USAGE';
Usage: shasum [OPTION] [FILE]...
   or: shasum [OPTION] --check [FILE]
Print or check SHA checksums.
With no FILE, or when FILE is -, read standard input.

  -a, --algorithm    1 (default), 224, 256, 384, 512
  -b, --binary       read files in binary mode (default on DOS/Windows)
  -c, --check        check SHA sums against given list
  -p, --portable     read files in portable mode
                         produces same digest on Windows/Unix/Mac
  -t, --text         read files in text mode (default)

The following two options are useful only when verifying checksums:
  -s, --status       don't output anything, status code shows success
  -w, --warn         warn about improperly formatted SHA checksum lines

  -h, --help         display this help and exit
  -v, --version      output version information and exit

The sums are computed as described in FIPS PUB 180-2.  When checking, the
input should be a former output of this program.  The default mode is to
print a line with checksum, a character indicating type (`*' for binary,
`?' for portable, ` ' for text), and name for each FILE.

Report bugs to <mshelor@cpan.org>.
END_OF_USAGE
	exit($err);
}


	# Collect options from command line

my ($alg, $binary, $check, $text, $status, $warn, $help, $version);
my ($portable);

eval { Getopt::Long::Configure ("bundling") };
GetOptions(
	'b|binary' => \$binary, 'c|check' => \$check,
	't|text' => \$text, 'a|algorithm=i' => \$alg,
	's|status' => \$status, 'w|warn' => \$warn,
	'h|help' => \$help, 'v|version' => \$version,
	'p|portable' => \$portable
) or usage(1, "");


	# Deal with help requests and incorrect uses

usage(0)
	if $help;
usage(1, "shasum: Ambiguous file mode\n")
	if scalar(grep { defined $_ } ($binary, $portable, $text)) > 1;
usage(1, "shasum: --warn option used only when verifying checksums\n")
	if $warn && !$check;
usage(1, "shasum: --status option used only when verifying checksums\n")
	if $status && !$check;


	# Default to SHA-1 unless overriden by command line option

$alg = 1 unless $alg;
grep { $_ == $alg } (1, 224, 256, 384, 512)
	or usage(1, "shasum: Unrecognized algorithm\n");


	# Display version information if requested

if ($version) {
	print "$VERSION\n";
	exit(0);
}


	# Try to figure out if the OS is DOS-like.  If it is,
	# default to binary mode when reading files, unless
	# explicitly overriden by command line "--text" or
	# "--portable" options.

my $isDOSish = ($^O =~ /^(MSWin\d\d|os2|dos|mint|cygwin)$/);
if ($isDOSish) { $binary = 1 unless $text || $portable }

my $modesym = $binary ? '*' : ($portable ? '?' : ' ');


	# Read from STDIN (-) if no files listed on command line

@ARGV = ("-") unless @ARGV;


	# sumfile($file): computes SHA digest of $file

sub sumfile {
	my $file = shift;

	my $mode = $portable ? 'p' : ($binary ? 'b' : '');
	my $digest = eval { $module->new($alg)->addfile($file, $mode) };
	if ($@) {
		warn "shasum: $file: $!\n";
		return;
	}

	$digest->hexdigest;
}


	# %len2alg: maps hex digest length to SHA algorithm

my %len2alg = (40 => 1, 56 => 224, 64 => 256, 96 => 384, 128 => 512);


	# Verify checksums if requested

if ($check) {
	my $checkfile = shift(@ARGV);
	my ($err, $read_errs, $match_errs) = (0, 0, 0);
	my ($num_files, $num_checksums) = (0, 0);
	my ($fh, $sum, $fname, $rsp, $digest);

	die "shasum: $checkfile: $!\n"
		unless $fh = FileHandle->new($checkfile, "r");
	while (<$fh>) {
		s/\s+$//;
		($sum, $modesym, $fname) = /^(\S+) (.)(.*)$/;
		($binary, $portable, $text) =
			map { $_ eq $modesym } ('*', '?', ' ');
		unless ($alg = $len2alg{length($sum)}) {
			warn("shasum: $checkfile: $.: improperly " .
				"formatted SHA checksum line\n") if $warn;
			next;
		}
		$rsp = "$fname: "; $num_files++;
		unless ($digest = sumfile($fname)) {
			$rsp .= "FAILED open or read\n";
			$err = 1; $read_errs++;
		}
		else {
			$num_checksums++;
			if (lc($sum) eq $digest) { $rsp .= "OK\n" }
			else { $rsp .= "FAILED\n"; $err = 1; $match_errs++ }
		}
		print $rsp unless $status;
	}
	$fh->close;
	unless ($status) {
		warn("shasum: WARNING: $read_errs of $num_files listed " .
			"files could not be read\n") if $read_errs;
		warn("shasum: WARNING: $match_errs of $num_checksums " .
			"computed checksums did NOT match\n") if $match_errs;
	}
	exit($err);
}


	# Compute and display SHA checksums of requested files

my($file, $digest);

for $file (@ARGV) {
	if ($digest = sumfile($file)) {
		print "$digest $modesym", "$file\n";
	}
}

__END__
:endofperl
