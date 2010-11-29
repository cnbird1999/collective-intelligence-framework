#!/usr/bin/perl -w

use strict;

use Data::Dumper;
use Getopt::Std;
use CIF::Client;
use JSON;

my %opts;
getopts('dhs:f:c:l:t:', \%opts);
die(usage()) if($opts{'h'});

my $feed = $opts{'f'} || 'domains';
my $debug = ($opts{'d'}) ? 1 : 0;
my $sid = ($opts{'s'}) || '10000000';
my $c = $opts{'c'} || $ENV{'HOME'}.'/.cif';
my $timeout = $opts{'t'} || 60;
my $ref_url = 'https://example.com/Lookup.html?q=';

sub usage {
    return <<EOF;
Usage: perl $0 -s 1 -f domains/malware 
        -h  --help:     this message
        -d  --debug:    debug output
        -f  --feed:     type of feed
        
        configuration file ~/.cif should be readable and look something like:

    url=https://example.com:443/api
    apikey=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Examples:
    \$> perl snort.pl -f infrastructure
    \$> perl snort.pl -f infrastructure/networks > snort_networks.rules

EOF
}

open(F,$c) || die('could not read configuration file: '.$c.' '.$!);

my ($apikey,$url);
while(<F>){
    my ($o,$v) = split(/=/,$_);
    $url = $v if(lc($o) eq 'url');
    $apikey = $v if(lc($o) eq 'apikey');
}
$url =~ s/\n//;
$apikey =~ s/\n//;
close(F);

my $client = CIF::Client->new({ 
    host        => $url,
    timeout     => $timeout,
    apikey      => $apikey,
});

$client->GET('/'.$feed.'?apikey='.$client->apikey());
die('request failed with code: '.$client->responseCode()) unless($client->responseCode == 200);

my $text = $client->responseContent();

my $hash = from_json($text);
my @a = @{$hash->{'data'}->{'result'}};
exit 1 unless($#a);

$text = '; generated by: '.$0." at ".time()."\n";
foreach (@a){
    $text .= 'zone "'.$_->{'address'}.'" {type master; file "/etc/namedb/blockeddomain.hosts";};'."\n";
}
print $text;
