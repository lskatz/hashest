#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use Bio::SeqIO;
use Storable qw/nstore_fd/;

# Quick hash implementation that is core-perl
use B qw/hash/;

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help output=s k=i)) or die $!;
  usage() if($$settings{help} || !@ARGV);

  $$settings{k} ||= 16;
  $$settings{output} ||= die("ERROR: need --output");

  my %index = (
    settings => {
      k => $$settings{k},
    }
  );

  for my $f(@ARGV){
    my $indices = indexFasta($f, $$settings{k}, $settings);

    # Combine the associative arrays into the larger associative array
    for my $key(qw(locus allele)){
      while(my($hash, $values) = each(%{ $$indices{$key} })){
        $index{$key}{$hash} = $values;
      }
    }


  }

  # Save the indices
  my $indexfile = $$settings{output};
  open (my $fh, '>:raw', $indexfile) or die "ERROR: could not write to $indexfile: $!";
  nstore_fd \%index, $fh;
  close $fh;

  return 0;
}

sub indexFasta{
  my($file, $k, $settings) = @_;
  
  my %indexLocus;
  my %indexAllele;

  my $in = Bio::SeqIO->new(-file=>$file);
  while(my $seq = $in->next_seq){
    my $sequence = $seq->seq;
    my $id = $seq->id;
    my(@F) = split(/_/, $id);
    my $allele = pop(@F);
    my $locus = join("_", @F);

    my $locusHash  = hash(substr($sequence, 0, $k));
    my $alleleHash = hash($sequence);
    $indexLocus{$locusHash} = $locus;
    $indexAllele{$alleleHash} = [$locus, $allele, $sequence];
  }
  return {locus=>\%indexLocus, allele=>\%indexAllele};
}


sub usage{
  print "$0: indexes a fasta file
  Fasta file have deflines in the format of >locus_allele
    where locus is a string and allele is an int
  Usage: $0 [options] *.fasta [*.gbk...]
  --k       kmer length [default: 16]
  --output  Output prefix for index files
  --help    This useful help menu
  ";
  exit 0;
}