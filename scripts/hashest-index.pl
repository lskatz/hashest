#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use Bio::SeqIO;
use Storable qw/nstore_fd retrieve/;

# Quick hash implementation that is core-perl
use B qw/hash/;

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help k=i)) or die $!;
  usage() if($$settings{help} || !@ARGV);

  $$settings{k} ||= 16;

  my(%locusIndex, %alleleIndex);
  for my $f(@ARGV){
    my $indices = indexFasta($f, $$settings{k}, $settings);

    %locusIndex  = (%locusIndex, %{$$indices{locus}});
    %alleleIndex = (%alleleIndex, %{$$indices{allele}});

  }

  ...;
  
  # Save the indices
  #my $locusIndex  = "$f.idl";
  #my $alleleIndex = "$f.ida";
  #open (my $fh, '>:raw', $locusIndex) or die "ERROR: could not write to $locusIndex: $!";
  #nstore_fd $$indices{locus}, $fh;
  #close $fh;
  #open($fh, '>:raw', $alleleIndex) or die "ERROR: could not write to $alleleIndex: $!";
  #nstore_fd $$indices{allele}, $fh;
  #close $fh;

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
  --help    This useful help menu
  ";
  exit 0;
}
