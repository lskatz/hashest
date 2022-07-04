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

sub hashestIndexMd5{
  my $exit_code = system("hashest-index.pl --hashing md5_hex $dbDir/*.tfa --output $index");
  return $exit_code;
}

sub hashestIndexSha1{
  my $exit_code = system("hashest-index.pl --hashing sha1_hex $dbDir/*.tfa --output $sha1Index");
  return $exit_code;
}

my $hashestIndexMd5ExitCode = hashestIndexMd5();
is($hashestIndexMd5ExitCode, 0, "Run hashest-index MD5");
my $hashestIndexSha1ExitCode = hashestIndexSha1();
is($hashestIndexSha1ExitCode, 0, "Run hashest-index SHA1");

my $cmp = 
  cmpthese(10, { 
      'hashestIndexMd5'     => sub { hashestIndexMd5() },
      'hashestIndexSha1'    => sub { hashestIndexSha1() },
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

