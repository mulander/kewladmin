#!/usr/bin/perl 

use warnings;
use strict;

use CGI qw(:standard);
use DBI;
use HTML::Template;
use Expect;

###
## global variables
my ($login,$ip,$uinfo,$type,$sth,$cookie);
my %max_dom = (
	www 		=> 1,
	premium 	=> 2,
	wwwplus		=> 3,
	full		=> 4,
);

my %type = (
	1 => 'example.tk',
	2 => 'example.lubin.pl',
	3 => 'example.int.pl',
);
###
## db info
my %kdb = (
		name	=> 'kewladmin',
		user	=> 'kewladmin',
		pass	=> 'DB_PASS',
		host	=> 'localhost'
	);


###
## db connect
my $dbh		= DBI->connect("dbi:mysql:$kdb{name}:$kdb{host}",$kdb{user},$kdb{pass})
			or die "Can't connect to the database $DBI::errstr\n";


###
## prepare and print the template
my $ciastko = cookie('key');
my $tmpl = HTML::Template->new(filename => 'login.tmpl');

clear_cookies(); #clear old cookies

$ip = $ENV{REMOTE_ADDR};
($login,$type) = check_cookie($ciastko) if defined $ciastko;
update_cookie($ciastko) if defined $ciastko;



if(param()) {#wprowadzone dane
	###
	## get username and pass
	my $passwd	= param('passwd');
	my $_login	= param('login');
	my $action	= param('action') || '';
	

	my %domain_err	= (
		100 	=> 'Musisz wype³niæ WSZYSTKIE pola',
		101	=> 'Niepoprawna nazwa domeny',
		102	=> 'Domena ju¿ zajêta - spróbuj inn± nazwê',
		103	=> 'Wykorzysta³e¶ ju¿ limit domen',
		104	=> 'Niepoprawna ¶cie¿ka'
	);

	if($action eq 'passwd' && defined $login && defined $type) {
		$tmpl = HTML::Template->new(filename => 'passwd.tmpl');
		acc_info($login,$type,$ip);			
	}
	elsif (defined $ciastko && $action eq 'logout') {
		$cookie = logout($ciastko);
		$tmpl = HTML::Template->new(filename => 'login.tmpl' );
		$tmpl->param({ LOGOUT => 1 });
	}
	elsif ($action eq 'change_pass' && defined $login) {
		my $ret = change_pass($ip,$login,param('current_pass'),param('new_pass'),param('new_pass2'));
		if($ret == 1) {
			$tmpl = HTML::Template->new(filename => 'admin.tmpl');
			$tmpl->param({ PASSOK => 1 });
		}
		elsif($ret == 0) {
			$tmpl = HTML::Template->new(filename => 'passwd.tmpl');
			$tmpl->param({ NOMATCH => 1});
			## passwords do not match
		}
		elsif($ret == -1) {
			$tmpl = HTML::Template->new(filename => 'passwd.tmpl');
			$tmpl->param({ WRONG => 1});
			## wrong pass
		}
		acc_info($login,$type,$ip);
	}
	elsif ($action eq 'domain' && defined $login && $type ne 'shell' && $type ne 'shellplus') {
		$tmpl = HTML::Template->new(filename => 'domain.tmpl');
		domain_info($login);
		acc_info($login,$type,$ip);
	}
	elsif ($action eq 'del_domain_c' && defined $login && $type ne 'shell' && $type ne 'shellplus')
	{
#		$tmpl = HTML::Template->new(filename => 'del_domain.tmpl');
		my $DOMAIN = get_domain_name(param('id'),$login);
		if(defined $DOMAIN) 
		{
			$tmpl = HTML::Template->new(filename => 'del_domain.tmpl');
			$tmpl->param({
					DOMAIN 	=> $DOMAIN,
					ID	=> param('id')
			});
		}
		else
		{	
			$tmpl = HTML::Template->new(filename => 'domain.tmpl');
			$tmpl->param({
					DELFAIL => 1
			});
			domain_info($login);
		}
		acc_info($login,$type,$ip);
	}
	elsif($action eq 'del_domain' && defined $login && $type ne 'shell' && $type ne 'shellplus')
	{
		$tmpl = HTML::Template->new(filename => 'domain.tmpl');

		my $DELETED = (del_domain(param('id'),$login)) ? 1 : 0;

		$tmpl->param({
			DELETED => $DELETED,
			DELFAIL => ($DELETED) ? 0 : 1,
		});
		domain_info($login);
		acc_info($login,$type,$ip);	
	}
	elsif ($action eq 'edit_domain' && $type ne 'shell' && $type ne 'shellplus')
	{
		$tmpl = HTML::Template->new(filename => 'domain_form.tmpl');
		edit_domain(param('id'),$login);
		acc_info($login,$type,$ip);
	}
	elsif ($action eq 'save_domain' && defined $login && $type ne 'shell' && $type ne 'shellplus')
	{
		# XXX save domain here
		$tmpl = HTML::Template->new(filename => 'domain_form.tmpl');
		edit_domain(param('id'),$login);
		my $ret = save_domain($login,param('domain'),param('path'),param('type'),param('id'));
		if($ret == 1)
		{
			$tmpl = HTML::Template->new(filename => 'domain.tmpl');
			$tmpl->param({ SAVED => 1 });
			domain_info($login);
		}
		else
		{
                       $tmpl->param({ INFO => 1,INFO_TXT => $domain_err{$ret} });
                }
		acc_info($login,$type,$ip);
	}
	elsif ($action eq 'add_domain_f' && defined $login && $type ne 'shell' && $type ne 'shellplus')
	{
		$tmpl = HTML::Template->new(filename => 'domain_form.tmpl');
		$tmpl->param({
			DOMAIN 	=> '',
			PATH	=> '/',
			T1	=> 1,
			ACTION  => 'add',
			BUTTON	=> 'Dodaj'
		});

		acc_info($login,$type,$ip);
	}
	elsif ($action eq 'add_domain' && defined $login && $type ne 'shell' && $type ne 'shellplus')
	{
		my $ret = add_domain($login,param('domain'),param('path'),param('type'));
		$tmpl = HTML::Template->new(filename => 'domain_form.tmpl');
		if( $ret == 1 )
		{
			$tmpl = HTML::Template->new(filename => 'domain.tmpl');
			$tmpl->param({ ADDED => 1 });
			domain_info($login);
		}
		else 
		{
			$tmpl->param({
				INFO 		=> 1,
				INFO_TXT 	=> $domain_err{$ret},
				DOMAIN		=> param('domain') || '',
				PATH 		=> param('path') || '/',
				T1		=> param('type') || 1,
				ACTION		=> 'add',
				BUTTON		=> 'Dodaj',
		
			});
		}
		acc_info($login,$type,$ip);
	}
	else {
		if ($_login =~ /^([A-Za-z][-_A-Za-z0-9]{0,29})$/) {
			$login = $1;
			$uinfo = finger($login);
			$type = check_type($uinfo); 
		}
		else {
			## the user has entered an invalid account name - no sens of giving him a hint on that
			$tmpl->param({ FAILED => 1 });
			undef $login;
		}
		unless(login($login,$passwd,$ip)){#zmeinic na 5 po testach
			## unable to login ?
			$sth = $dbh->prepare("UPDATE ka_users SET login_try = login_try +1, last_failed=? WHERE ip=? AND username=?");
			$sth->execute(time, $ip, $login);
			$tmpl->param({ FAILED => 1 });
			
		}
		else {			
			## logged in user
			$cookie = create_cookie($login,$ip);
			#quota count
			$tmpl = HTML::Template->new(filename => "admin.tmpl");
			acc_info($login,$type,$ip);
		}
	}

}
		

else {
	if( defined $login && defined $type ) {
		$tmpl = HTML::Template->new(filename => "admin.tmpl");
		acc_info( $login, $type, $ip );
	}
}
#prowadzone dane koniec
###
## send headers and start html
print header(-cookie=>$cookie, -type=>"text/html; charset=iso-8859-2"),
	start_html(-style=>{-src => ['../style.css'], -media=>'all'},-title=>'KewlAdmin');
###
## end html
print $tmpl->output,end_html;
###
## db disconnect
$sth->finish;
$dbh->disconnect;


sub change_pass {
	my ($ip,$login,$old_pass,$new_pass,$repeat_pass) = @_;

	return 0 if $new_pass ne $repeat_pass;

	my $ssh = login($login,$old_pass,$ip);
	
	unless(check_shell($login)) {
		$ssh->send("passwd\n");
	}
	
	$ssh->send("$old_pass\n")	if (scalar $ssh->expect(2,"Old password:"));
	$ssh->send("$new_pass\n") 	if (scalar $ssh->expect(2,"New password:"));
	$ssh->send("$repeat_pass\n") 	if (scalar $ssh->expect(2,"Re-enter new password:"));
	

	
	if($ssh->expect(2,"Password changed.")) {
		$ssh->close;
		return 1;
	}

	return -1;	
}

sub login {
	my ($login,$passwd,$ip) = @_;
	my $ssh;

	if(defined $passwd && defined $login){

		$sth = $dbh->prepare("SELECT ip, login_try, last_failed FROM ka_users WHERE ip=? AND username=? LIMIT 1");
		$sth->execute($ip, $login);

		if ($sth->rows == 0) {
			$sth = $dbh->prepare("INSERT INTO ka_users (ip, username) VALUES (?, ?)");
			$sth->execute($ip, $login);
			# tu dajemy redirect albo zmieniamy template ( sugeruje template )
		}
		my $row = $sth->fetchrow_hashref;
		if ($row->{"ip"} eq $ip && $row->{"login_try"} >= 5 && ($row->{"last_failed"} + 3600) > time) {
			#exit i komunikat o ilosci przekrroczonych prob
			$tmpl->param({ LIMIT => 1 });
			return 0;
		}
		else {
			if ( $row->{"ip"} eq $ip && $row->{"login_try"} >= 5 
							&& ($row->{"last_failed"} + 3600) <= time ) {
				$sth = $dbh->prepare("UPDATE ka_users set login_try = 0 WHERE username=?");
				$sth->execute($login);
			}

			## connect via ssh
			$Expect::Log_Stdout	= 0;

			$ssh = Expect->new("ssh $login\@localhost");
			#$ssh->debug(1);
			$ssh->expect(2,qq{$login\@localhost's password:});
			$ssh->send($passwd . "\n");
	
			unless(scalar $ssh->expect(2,'$') || $ssh->expect(2,"Changing password for")) {#$ssh->expect(2,"Old password:")) {
				return 0; #unable to login
			}
			else {
				return $ssh; # logged in
			}
		}
	}
}

sub finger {
	my $login = shift;
	my $uinfo	= `finger -mp $login`;
	
	if($uinfo =~ /^finger: $login: no such user\./) {
		undef $login;
	}
	undef $login if $login eq 'root';
	return $uinfo;
}

sub check_shell {
	my $login = shift;
	my $uinfo = finger($login);
	my $type;

	return 1 if $uinfo =~ m#Shell: /usr/bin/passwd#;
	return 0;
}

sub check_type {
	my $uinfo = shift;
	my $type;
	($type) = $uinfo =~ m#/home2?/(.+?)(?:/|\s)#;
	return $type;
}

sub acc_info {
	
	my ($login,$type,$ip) = @_;
	my %quota = (
		shell	 	=> 100,
		www 		=> 150,
		premium		=> 200,
		shellplus 	=> 250,
		wwwplus 	=> 400,
		full		=> 700,
	);

	my $space_used = `sudo du -sm ~$login | awk '{print \$1}'`;
	my $usage_percent = ($type eq $login) ? 0 : (($space_used * 100)/$quota{$type});
	my ($curr_dom,$max_dom);
	$sth = $dbh->prepare("UPDATE ka_users SET login_try = 0 WHERE ip=? AND username=?");
	$sth->execute($ip, $login);
	$sth = $dbh->prepare('SELECT id FROM ka_domains WHERE username = ?');
	$sth->execute($login);
		$tmpl->param({  
			USER => $login,
			TYPE => ($type eq $login) ? "unlimited" : $type,
			MAX     => ($type eq $login) ? "unlimited" : $quota{$type} . " MB",
			USED    => $space_used,
			PERCENT => ($type eq $login) ? '' : sprintf("%.1f%%",$usage_percent),
			WIDTH => ($type eq $login) ? 0 : sprintf("%.0f",$usage_percent),
			HAS_DOMAIN => ($type eq 'shell' || $type eq 'shellplus') ? 0 : 1, 
			CURR_DOM => ( $sth->rows ) ? $sth->rows : 0,
			MAX_DOM => ( exists $max_dom{$type} ) ? $max_dom{$type} : 5, 
			});
}

sub create_cookie {
	my ($username,$ip) = @_;
	my ($key);

	$sth = $dbh->prepare('DELETE FROM ka_keys WHERE ip = ?');
	$sth->execute($ip);

	$sth = $dbh->prepare("SELECT id FROM ka_keys WHERE cookie = ?");

	##
	# generate until unique key
	while (1) {
		$key = genkey();
		$sth->execute($key);
		last unless $sth->rows;
	}

	$sth = $dbh->prepare('INSERT INTO ka_keys(last_time,ip,username,cookie) VALUES (?, ?, ?, ?)') || error_log("prepare failed");
	$sth->execute(time,$ip,$username,$key) || error_log("create_cookie insert failed:$DBI::errstr");

	return cookie(-name => 'key', -value=> $key, -expires => '+1h');
}

sub check_cookie {
	my $cookie = shift;

	## db check if cookie is valid
	$sth = $dbh->prepare('SELECT * FROM ka_keys WHERE cookie=? AND last_time > ?') || error_log('prepare check cookie');
	$sth->execute($cookie, time-3600);

	if($sth->rows > 0) {
		#cookie ok
		my $row 	= $sth->fetchrow_hashref;
		return ($row->{"username"},check_type( finger( $row->{"username"} ) ));#,$row->{"ip"});
	}
	else {
		#cookie incorrect
		return (undef,undef);#,undef);
	} 
}

sub genkey {
	my $key ='';
	my @char = ('a' .. 'z','A' .. 'Z', 0 .. 9);
	$key  .= $char[rand@char] while length $key != 32;
	return $key;
}

sub logout {
	my $cookie = shift;
	$sth = $dbh->prepare('DELETE FROM ka_keys WHERE cookie = ?') || error_log('prepare delete cookie');
	return ($sth->execute($cookie)) ? cookie(-name => 'key',-value => $cookie, -expires => '-1d') : undef;
}

sub clear_cookies {
	$sth = $dbh->prepare('DELETE FROM ka_keys WHERE last_time < ?') || error_log('prepare clear cookies');
	$sth->execute(time-3600);
	
	return 1;
}

sub update_cookie {
	my $cookie = shift;

	$sth = $dbh->prepare('UPDATE ka_keys SET last_time = ? WHERE cookie = ?') || error_log('preprare update cookie');
	$sth->execute(time,$cookie);

	return 1;
}

sub error_log
{
	my $msg	 = shift;
	my @time = localtime(time);
	my $log_file = sprintf "%d%d%d.log",$time[5]+1900,$time[4]+1,$time[3];
	
	open LOG, ">>/var/www/htdocs/kewladmin/log/$log_file" or die "Can't create log file: $!";
		print LOG ( (scalar localtime) . ": $msg\n");
	close LOG;
}

sub list_domains
{
	my ($login) = @_;

	$sth = $dbh->prepare('SELECT * FROM ka_domains WHERE username = ?');
	$sth->execute($login);

	return 0 unless $sth->rows > 0;

	my @domains;
	while( my $row = $sth->fetchrow_hashref)
	{
		my $name = "$row->{domain}.$type{$row->{type}}";
		my $path = $row->{path};
		push @domains, { 	DOMAIN  	=> (length $name > 29) ? substr($name,0,25)."..." : $name,
					DOMAIN_LONG 	=> $name,
					ID		=> $row->{id},
					PATH		=> (length $path > 29) ? substr($path,0,25)."..." : $path,
					PATH_LONG	=> $path ,
		};
	}
	return @domains;
}

sub add_domain
{
	my ($user,$domain,$path,$dom_type) = @_;
	return 100 unless $user && $domain && $path && $dom_type;
	return 101 unless $domain =~ m/^[-.\w]+$/; 
	
	$sth = $dbh->prepare('SELECT id FROM ka_domains WHERE domain = ? AND type = ?');
	$sth->execute($domain,$dom_type);
	return 102 if $sth->rows > 0; # domain already exists

	$sth = $dbh->prepare('SELECT id FROM ka_domains WHERE username = ?');
	$sth->execute($user);
	return 103 if (($type eq $user && $sth->rows >= 5) || ($type ne $user && $sth->rows >= $max_dom{$type}));
	return 104 unless $path =~ m/^\/.*?$/;
	return 104 if $path =~ m/\.\.\//;


	$sth = $dbh->prepare('INSERT INTO ka_domains values(NULL, ?, ?, ?, ?)');
	$sth->execute($user,$domain,$path,$dom_type);
	mark_change();
	return 1;
}
sub domain_info
{
	my ($login) = @_;
	my $LIST    = 1;
	my @DOMAINS = list_domains($login);
	$LIST	    = 0 if ref($DOMAINS[0]) ne 'HASH';

	$tmpl->param({
			LIST => $LIST,
			DOMAINS => \@DOMAINS,
	});
}
sub get_domain_name
{
	my ($id,$login) = @_;

	$sth = $dbh->prepare('SELECT domain,type FROM ka_domains WHERE id = ? AND username = ?');
	$sth->execute($id,$login);
	my $row    = $sth->fetchrow_hashref;
	
	return ($sth->rows > 0 ) ? $row->{domain} . '.' . $type{$row->{type}} : undef;
}

sub get_domain_info
{
	my ($id,$login) = @_;
	
	$sth = $dbh->prepare('SELECT * FROM ka_domains WHERE id = ? AND username = ?');
	$sth->execute($id,$login);
	my $row	  = $sth->fetchrow_hashref;

	return ($sth->rows > 0) ? $row : undef;
}

sub del_domain
{
	my ($id,$login) = @_;
	$sth = $dbh->prepare('DELETE FROM ka_domains WHERE id = ? AND username = ?');
	$sth->execute($id,$login);
	mark_change();
	
	return ($sth->rows > 0 ) ? 1 : 0;
}
sub save_domain
{
	my ($user,$domain,$path,$dom_type,$id) = @_;
	return 100 unless $user && $domain && $path && $dom_type && $id;
	return 101 unless $domain =~ m/^[-.\w]+$/;
	return 104 unless $path =~ m/^\/.*?$/;
	return 104 if $path =~ m/\.\.\//;
	
	$sth = $dbh->prepare('UPDATE ka_domains SET domain=?, path=?, type=? WHERE id = ? AND username = ?');
	$sth->execute($domain,$path,$dom_type,$id,$user);
	mark_change();
	return 1;
}
sub edit_domain
{
	my ($id,$login) = @_;
	my $domain = get_domain_info($id,$login);
	
	if(defined $domain)
	{
		$tmpl->param({
			DOMAIN 	=> $domain->{domain},
			PATH	=> $domain->{path},
			T1	=> $domain->{type},
			ID	=> $domain->{id},
			ACTION  => 'save',
			BUTTON	=> 'Zapisz'
		});
	}
	else
	{
		$tmpl = HTML::Template->new(filename =>'domain.tmpl');
		$tmpl->param({ DELFAIL => 1 });
		domain_info($login);
	}
}
sub mark_change
{
	$sth = $dbh->prepare('UPDATE ka_config SET c_value = c_value+1 WHERE c_key = "changes"');
	$sth->execute();
}
