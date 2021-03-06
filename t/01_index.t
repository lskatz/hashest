#!/usr/bin/env perl

use strict;
use warnings;
use lib './lib';
use File::Basename qw/dirname/;
use FindBin qw/$RealBin/;
use Storable qw/retrieve/;
use Data::Dumper;

use Test::More tests => 1;

$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

my $asm = "$RealBin/SRR6881054.shovillSpades.fasta";
my $dbDir = "$RealBin/senterica";
my $index = "$RealBin/senterica.hashest";
my $sha1Index = "$RealBin/senterica.sha1.hashest";

subtest 'index' => sub{
  my $exit_code = system("hashest-index.pl $dbDir/*.tfa --hashing md5_hex --output $index");
  is($exit_code, 0, "indexing the senterica scheme");

  # Read the database and look for expected keys
  my $retrieved = retrieve($index);
  my @expectedKeys = sort qw(settings locusArray locus allele stops alleleSeq);
  my @obsKeys = sort keys(%$retrieved);
  is_deeply(\@obsKeys, \@expectedKeys, "Reading the database back");
  
  my @expectedLoci = sort ('aroC', 'dnaN', 'hemD', 'hisD', 'purE', 'sucA', 'thrA');
  my @obsLoci = sort (@{ $$retrieved{locusArray} });
  is_deeply(\@obsLoci, \@expectedLoci, "Checking expected loci @expectedLoci");

  $exit_code = system("hashest-index.pl $dbDir/*.tfa --hashing sha1_hex --output $sha1Index");
  is($exit_code, 0, "indexing the senterica scheme with sha1");
};

