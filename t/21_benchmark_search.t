#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark ':all';
use Test::More 'no_plan';
use File::Basename qw/dirname/;

use FindBin qw/$RealBin/;
use Data::Dumper;
$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

my $asm = "$RealBin/SRR6881054.shovillSpades.fasta";
my $dbDir = "$RealBin/senterica";
my $index = "$RealBin/senterica.hashest";
my $res = "$RealBin/res.tsv";

my @hashing=qw(md5 md5_hex sha1 sha1_hex);

sub hashestSearch{
  my($hashing) = @_;
  my $exit_code = system("hashest-search.pl --db $index.$hashing $asm > $res 2> $res.log");
  return $exit_code;
}


subtest 'searching' => sub{
  plan tests => scalar(@hashing);
  for my $h(@hashing){
    my $hashestSearchExitCode = hashestSearch($h);
    is($hashestSearchExitCode, 0, "Run hashest-search $h");
  }
};

my $cmp = 
  cmpthese(10, { 
      'hashestSearchMd5'     => sub { hashestSearch("md5") },
      'hashestSearchMd5_hex' => sub { hashestSearch("md5_hex") },
      'hashestSearchSha1'    => sub { hashestSearch("sha1") },
      'hashestSearchSha1_hex'=> sub { hashestSearch("sha1_hex") },
  });

for(my $i=0;$i<@$cmp;$i++){
  #note join("\t", @{ $$cmp[$i] });
  my @a = @{ $$cmp[$i] };
  my $row = "";
  for(my $j=0;$j<@a;$j++){
    # 22 characters to help hold our longest string Path::Iterator::Rule2
    $row .= sprintf("%22s ", $a[$j]);
  }
  diag $row;
}

