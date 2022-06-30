#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use Bio::SeqIO;
use Storable qw/retrieve/;

# Quick hash implementation that is core-perl
#use B qw/hash/;
use Digest::MD5 qw/md5_hex/;

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help dump db|database=s)) or die $!;
  usage() if($$settings{help} || !@ARGV);

  $$settings{db} ||= die("ERROR: need --db");
  $$settings{maxGeneLength}=10000;

  logmsg "START: loading index $$settings{db}";
  my $index = retrieve($$settings{db});
  if($$settings{dump}){
    print Dumper $index; 
    logmsg "Dumped database to stdout";
    return 0;
  }
  logmsg "DONE: loading index $$settings{db}";
  my $k = $$index{settings}{k} || die "ERROR: could not find k in database $$settings{db}";

  # Print header
  print join("\t", "Assembly", @{ $$index{locusArray} })."\n";
  for my $asm(@ARGV){
    logmsg "Typing for $asm";
    my $loci = searchAsm($asm, $k, $index, $settings);

    # Print a line of results
    print $asm;
    for my $locus(@{ $$index{locusArray} }){
      my $allele = $$loci{$locus} // 0;
      print "\t$allele";
    }
    print "\n";
  }

  return 0;
}

sub searchAsm{
  my($asm, $k, $index, $settings) = @_;

  my %locus;

  my $in=Bio::SeqIO->new(-file=>$asm);
  while(my $seqOrig = $in->next_seq){
    my $revcom   = $seqOrig->revcom;

    for my $seq($seqOrig, $revcom){
      my $sequence = $seq->seq;
      my $seqLength = length($sequence);

      # sliding window to get hashes and match against db
      for(my $i=0; $i<$seqLength-$k; $i++){
        my $subseq = substr($sequence, $i, $k);
        my $locusHash = md5_hex($subseq);

        #logmsg "Compare $locusHash";
        # Test if we found the locus hash which would indicate we found the locus
        if($$index{locus}{$locusHash}){
          # Get the name of the putative locus
          my $locus = $$index{locus}{$locusHash};
          #logmsg "Testing locus $locus from ".$seq->id." pos $i";
          # Get downstream sequence to see if it matches an allele
          for(my $j=$k;$j<$$settings{maxGeneLength};$j++){
            my $candidateSequence = substr($sequence, $i, $j);
            if($$index{allele}{$locus}{$candidateSequence}){
              #logmsg "Found $candidateSequence";
              #push(@locus, $$index{allele}{$locus}{$candidateSequence});
              my $allele = $$index{allele}{$locus}{$candidateSequence}[1];
              if(defined $locus{$locus}){
                logmsg "WARNING: locus $locus is defined more than once. Appending allele $locus{$locus} with ~$allele";
                $allele = "~$allele";
              }
              $locus{$locus} .= $allele;

              # push ahead the search to wherever $j is but back it up the kmer length
              $i += $j-$k;
              last;
            }
          }
        }
      }
    }

  }
  $in->close;
  #print Dumper \@locus, "Num loci: ".scalar(@locus);die;
  #print "Found ". scalar(@locus)." loci with k=$k\n"; die;
  return \%locus;
}


sub usage{
  print "$0: reports an MLST profile for a genome assembly
  Usage: $0 [options] *.fasta [*.gbk...] > out.tsv
  --db      Database from hashest-index.pl
  --help    This useful help menu
  ";
  exit 0;
}
