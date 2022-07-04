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
my $sha1Index = "$RealBin/senterica.sha1.hashest";
my $res = "$RealBin/res.tsv";

sub hashestSearchMd5{
  my $exit_code = system("hashest-search.pl --db $index $asm > $res 2> $res.log");
  return $exit_code;
}

sub hashestSearchSha1{
  my $exit_code = system("hashest-search.pl --db $index $asm > $res 2> $res.log");
  return $exit_code;
}

my $hashestSearchMd5ExitCode = hashestSearchMd5();
is($hashestSearchMd5ExitCode, 0, "Run hashest-search MD5");
my $hashestSearchSha1ExitCode = hashestSearchSha1();
is($hashestSearchSha1ExitCode, 0, "Run hashest-search SHA1");

my $cmp = 
  cmpthese(10, { 
      'hashestSearchMd5'     => sub { hashestSearchMd5() },
      'hashestSearchSha1'    => sub { hashestSearchSha1() },
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

