#!/usr/bin/env perl

use strict;
use warnings;
use lib './lib';
use File::Basename qw/dirname basename/;
use FindBin qw/$RealBin/;
use Storable qw/retrieve/;
use Data::Dumper;

use Test::More tests => 1;

$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

my $asm = "$RealBin/SRR6881054.shovillSpades.fasta";
my $dbDir = "$RealBin/senterica";
my $index = "$RealBin/senterica.hashest";
my $sha1Index = "$RealBin/senterica.sha1.hashest";
my $res = "$RealBin/res.tsv";
my $dump = "$index.dmp";

subtest 'dump' => sub{
  my $exit_code = system("hashest-search.pl --db $index --dump > $dump 2> $dump.log");
  is($exit_code, 0, "dumping the senterica scheme with ".basename($index)." to ".$dump);
  if($exit_code > 1){
    note `cat $dump.log`;
  }

};

