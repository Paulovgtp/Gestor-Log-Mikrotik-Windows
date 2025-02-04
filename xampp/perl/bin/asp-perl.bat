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
#!/usr/bin/perl
#line 15

# for more accurate per request time accounting
BEGIN {
    eval "use Time::HiRes";
    $Apache::ASP::QuickStartTime = eval { &Time::HiRes::time(); } || time();
}

# help section
use File::Basename;
use Getopt::Std;
use Cwd;
use Carp qw(confess);
use Apache::ASP::CGI;

=pod

=head1 NAME

asp-perl - Apache::ASP CGI and command line script processor

=head1 SYNOPSIS

asp-perl [-hsdb] [-f asp.conf] [-o directory] file1 @arguments file2 @arguments ...

    -h  Help you are getting now!
    -f  Specify an alternate configuration file other than ./asp.conf
    -s  Setup $Session and $Application state for script.
    -d  Set to debug code upon errors.
    -b  Only return body of document, no headers.
    -o  Output directory, writes to files there instead of STDOUT
    -p  GlobalPackage config, what perl package are the scripts compiled in.

=head1 DESCRIPTION

This program will run Apache::ASP scripts from the command line.
Each file that is specified will be run, and the 
$Request->QueryString() and $Request->Form() data will be 
initialized by the @arguments following the script file name.  

The @arguments will be written as space separated 
words, and will be initialized as an associate array where
%arguments = @arguments.  As an example:

 asp-perl file.asp key1 value1 key2 value2

would be similar to calling the file.asp in a web environment like

 /file.asp?key1=value1&key2=value2

The asp.conf script will be read from the current directory
for parameters that would be set with PerlSetVar normally under
mod_perl.  For more information on how to configure the asp.conf
file, please see < http://www.apache-asp.org/cgi.html > 

=head1 SEE ALSO

perldoc Apache::ASP, and also http://www.apache-asp.org

=head1 COPYRIGHT

Copyright 1998-2004 Joshua Chamas, Chamas Enterprises Inc.

This program is distributed under the GPL.  Please see the LICENSE
file in the Apache::ASP distribution for more information.

=cut

$SIG{__DIE__} = \&confess;
getopts('hsdbo:p:f:');

if($opt_h || ! @ARGV) {
    open(SCRIPT, $0) || die("can't open $0 for reading: $!");
    my $script = join('', <SCRIPT>);
    close SCRIPT;
    $script =~ /=pod\s(.*?)=cut/s;
    my $pod = $1;
    $pod =~ s/\=head1 (\w+)/$1/isg;
    $pod =~ s/DESCRIPTION.*//isg;
    print $pod;
    print "\"perldoc asp-perl\" or \"man asp-perl\" for more information\n\n";

    exit;
}

if($opt_o && ! -e $opt_o) {
    mkdir($opt_o, 0750) || die("can't mkdir $opt_o");    
}

$Config = '';
my $config_file = $opt_f || 'asp.conf';
if(-e $config_file) {
    # read in .asp to load %Config
    open(CONFIG, $config_file) || die("can't open $config_file: $!");
    $Config = join('', <CONFIG>);
    close CONFIG;
} else {
    if($opt_f) {
	die("Configuration file $opt_f does not exist!");
    }
}

my $cwd = cwd();
while(@ARGV) {
    $cwd && (chdir($cwd) || die("can't chdir to $cwd"));
    my $file = shift @ARGV;
    my @script_args;

    unless(-e $file) {
	print "file $file does not exist\n";
	next;
    }

    while(@ARGV) {
	last if(-e $ARGV[0]);
	push(@script_args, shift @ARGV);
    }
	
    if($opt_o) {
	my $basename = basename($file);
	open(STDOUT, ">$opt_o/$basename") || die("can't open $opt_o/$basename for writing");
    }

    $r = Apache::ASP::CGI->init($file, @script_args);
    $0 = $file; # might need real $0 in $Config
    eval $Config;
    $@ && die("can't eval config error: $@");

    $r->dir_config->set('NoState', 0) if $opt_s;
    if($opt_d) {
	$r->dir_config->set('Debug', -3);
	$r->dir_config->set('CommandLine', 1);
    }
    if($opt_b) {
	$r->dir_config->set('NoHeaders', 1);
    }
    if($opt_p) {
	$r->dir_config->set('GlobalPackage', $opt_p);
    }

    for(keys %Config) {
	$r->dir_config->set($_, $Config{$_});
    }

    &Apache::ASP::handler($r);

    if($opt_o) {
	close STDOUT;
    }
    
}



__END__
:endofperl
