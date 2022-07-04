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

subtest 'search' => sub{
  my $exit_code = system("hashest-search.pl --db $index $asm > $res 2> $res.log");
  is($exit_code, 0, "searching the senterica scheme with ".basename($asm));

  if($exit_code > 0){
    note `cat $res.log`;
    BAIL_OUT("profile was not correct");
  }

  my %profile;
  {
    open(my $fh, $res) or BAIL_OUT("ERROR: could not read $res: $!");
    my $header = <$fh>;
    chomp($header);
    my @header = sort split(/\t/, $header);
    my $values = <$fh>;
    chomp($values);
    my @value = split(/\t/, $values);
    close $fh;
    @profile{@header} = @value;
    # actually only check on the loci
    delete($profile{Assembly});
  }
  my %expectedProfile = (
    'aroC' => '10',
    'dnaN' => '7',
    'hemD' => '12',
    'hisD' => '9',
    'purE' => '5',
    'sucA' => '9',
    'thrA' => '2',
  );
  is_deeply(\%profile, \%expectedProfile, "7-gene MLST results");
  note `cut -f 2- $res | column -t`;

  $exit_code = system("hashest-search.pl --db $sha1Index $asm > $res 2> $res.log");
  is($exit_code, 0, "searching the senterica scheme with sha1 and ".basename($asm));
  note `cut -f 2- $res | column -t`;
};

