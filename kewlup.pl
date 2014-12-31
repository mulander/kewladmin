#!/usr/bin/perl
use warnings;
use strict;

use DBI;

my ($dbh,$sth,$row);

###
## db info

my %settings = (
	name	=> 'kewladmin',
	user	=> 'kewladmin',
	pass	=> 'DB_PASS',
	host	=> 'localhost',
	file	=> 'vhosts',
);


$dbh	= DBI->connect("dbi:mysql:$settings{name}:$settings{host}",$settings{user},$settings{pass})
		or die "Can't connect to the database $DBI::errstr\n";

$sth = $dbh->prepare('SELECT * FROM ka_config WHERE c_key="changes"');
$sth->execute;

$row = $sth->fetchrow_hashref;

my $changes = $row->{c_value};

$sth = $dbh->prepare('SELECT username,domain,path,type FROM ka_domains');
$sth->execute;

if ( $changes > 0 )
{
	open (VHOSTS, ">$settings{file}") or die "Can't open vhosts file\n";

	while ( $row = $sth->fetchrow_hashref )
	{
		print VHOSTS vhost($row->{username}, $row->{domain}, $row->{path}, $row->{type});
	}

	close VHOSTS;

	$sth = $dbh->prepare('UPDATE ka_config SET c_value = c_value + 1 WHERE c_key = "updates"');
	$sth->execute;

	$sth = $dbh->prepare('UPDATE ka_config SET c_value = 0 WHERE c_key = "changes"');
	$sth->execute;

	system("apachectl restart");
	
}

sub vhost
{
        my ($username,$domain,$path,$type) = @_;

# 1 int.pl
# 2 .be
# 3 ipv-net.net
	my %sufix = (
	        1 => 'example.tk',
	        2 => 'example.lubin.pl',
        	3 => 'example.int.pl', 
	);

	my $dir = getdir($username);
	
        return "<VirtualHost $domain.$sufix{$type}>
        BandWidthModule On
        BandWidth 10.0 0
        BandWidth all 16384
        ServerAdmin abuse\@example.tk
        DocumentRoot \"${dir}/public_html$path\"
        ServerName \"$domain.$sufix{$type}\"
        ServerAlias \"*.$domain.$sufix{$type}\"
</VirtualHost>\n\n";
}

sub getdir
{
	my $username = $_[0];
	my $line = join "", getpwnam($username);

	if ( $line =~ /^.+?,,,(.+?\/$username)/ )
	{
		return $1;
	}
}
