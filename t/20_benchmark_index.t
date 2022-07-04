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

sub hashestIndex{
  my($hashing) = @_;
  my $exit_code = system("hashest-index.pl --hashing $hashing $dbDir/*.tfa --output $index.$hashing");
  return $exit_code;
}

subtest 'hashing index' => sub{
  plan tests => scalar(@hashing);
  for my $h(@hashing){
    my $exit_code = hashestIndex($h);
    is($exit_code, 0, "Run hashest-index $h");
  }
};

my $cmp = 
  cmpthese(10, { 
      'hashestIndexMd5'     => sub { hashestIndex("md5") },
      'hashestIndexMd5_hex' => sub { hashestIndex("md5_hex") },
      'hashestIndexSha1'    => sub { hashestIndex("sha1") },
      'hashestIndexSha1_hex'=> sub { hashestIndex("sha1_hex") },
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

