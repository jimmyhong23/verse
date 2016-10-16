package Verse::Demo;

use strict;
use warnings;
use IO::Socket;
use base 'Exporter';
our @EXPORT = qw/ demo /;

my %MIME = (
	'image/svg+xml' => qr/\.svg$/i,
	'image/jpeg'    => qr/\.jpe?g$/i,
	'image/png'     => qr/\.png$/i,
);

sub status
{
	my ($c, $m, $s) = @_;
	print "HTTP/1.1 $c $m\r\n";
	$s = sprintf("%0.2f kB", ($s || 0) / 1024.0);
	print STDERR "<- HTTP/1.1 $c $m ($s)\n";
}

sub done
{
	close STDOUT;
	exit;
}

sub bail
{
	status(@_);
	print "\r\n";
	print "$_[0] $_[1]\r\n";
	done;
}

sub header
{
	while (@_) {
		my $h = shift;
		my $v = shift;
		print "$h: $v\r\n";
	}
}

sub demo
{
	my %opts = @_;
	$opts{listen} = "*:4000" unless $opts{listen};
	$opts{backlog} = 64      unless $opts{backlog};
	$opts{htdocs} = 'htdocs' unless $opts{htdocs};

	$opts{htdocs} = "$ENV{PWD}/$opts{htdocs}";

	die "bad 'listen' option: $opts{listen}\n"
		unless $opts{listen} =~ m/^(.+):(\d+)$/;
	my ($host, $port) = ($1, $2);

	chdir "/";
	my $socket = IO::Socket::INET->new(
		($host eq '*' ? () : (LocalHost => $host)),
		LocalPort => $port,
		ReuseAddr => 1,
		ReusePort => 1,
		Type      => SOCK_STREAM,
		Listen    => $opts{backlog},
	) or die "unable to bind $opts{listen}: $!\n";
	binmode $socket;

	print STDERR ">> \x1b[38;5;2mVerse\x1b[0m [demo] web server listening on \x1b[38;5;4mhttp://$opts{listen}\x1b[0m\n";

	local $SIG{CLD} = 'IGNORE';
	while (my $client = $socket->accept) {
		$client->autoflush(1);
		binmode $client;

		next if my $pid = fork;
		die "unable to fork: $!\n" unless defined $pid;

		my $req = <$client>;
		exit unless defined $req;
		select $client;

		print STDERR "+> \x1b[36m$req\x1b[0m";

		bail 400 => 'Bad Request'
			unless $req =~ m|^GET /(\S*) \S+\r\n$|;

		my $file = $1 || 'index.html';
		my $path = "$opts{htdocs}/$file";
		$path = "$path/index.html" if -d $path;
		bail 404 => 'Not Found' unless -e $path;

		status 200 => 'OK', -s $path;
		header 'Content-length' => -s $path;
		for (keys %MIME) {
			next unless $path =~ m/$MIME{$_}/;
			header 'Content-type' => $_;
			last;
		}
		print "\r\n";
		open my $res, "<", $path;
		print $_ for <$res>;
		done;
	}
}

1;

=head1 NAME

Verse::Demo - Simple Static HTTP Server

=head1 DESCRIPTION

This package defines the B<demo()> function, which runs a small, forking TCP
daemon that can render static sites generated by Verse with little overhead
or external dependencies.  This functionality is B<NOT> recommended for
anything more than verifying that the generated site is correct.
Specifically, it should B<NOT> be used to host production sites.

=head1 FUNCTIONS

=head2 demo(%options)

Run the demo HTTP server.  This will take over the thread of execution.

=head1 INTERNAL FUNCTIONS

The following functions are internal and should not be accessed from outside
the module:

=head2 status($code, $message)

Print the HTTP status response to the client.

=head2 done()

Close the connection and exit.

=head2 bail($code, $message)

Combine status() and done(), for use in 'or die' error handling.

=head2 header(%headers)

Render headers to the client.

=head1 AUTHOR

James Hunt, C<< <james at niftylogic.com> >>

=cut
