#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use Bio::SeqIO;
use Storable qw/retrieve/;

use threads;
use Thread::Queue;

# Quick hash implementation that is core-perl
use Digest::MD5 qw/md5_hex md5/;
use Digest::SHA qw/sha1_hex sha1/;

local $0 = basename $0;
sub logmsg{my $TID=threads->tid; local $0=basename $0; print STDERR "$0 (TID $TID): @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help outseqs=s putatives numcpus=i version k dump db|database=s)) or die $!;

  usage() if($$settings{help});

  $$settings{db} ||= die("ERROR: need --db");
  # TODO might be smart to get the actual locus max length in the database
  $$settings{maxGeneLength}=10000;
  $$settings{version} && die "ERROR: you can only use --version with hashest-index.pl";
  $$settings{k} && die "ERROR: you can only use --k with hashest-index.pl";
  $$settings{numcpus} ||= 1;

  logmsg "START: loading index $$settings{db}";
  my $index = retrieve($$settings{db});
  if($$settings{dump}){
    print Dumper $index; 
    logmsg "Dumped database to stdout";
    return 0;
  }
  logmsg "DONE: loading index $$settings{db}";
  usage() if(!@ARGV);

  # Form a regex to capture stop codons
  my $stopsRegexStr = '(?:' . join("|", sort{$a cmp $b} keys(%{ $$index{stops} })) . ')$';
  $$settings{stopsRegex} = qr/$stopsRegexStr/i;

  my @thr;
  my $asmQ = Thread::Queue->new(@ARGV);
  # Kick off the printer queue and give it the header to print first
  my $printQ = Thread::Queue->new;
  $printQ->enqueue(
    [
      'stdout',
      # The header is the assembly and then all the loci
      join("\t", "Assembly", @{ $$index{locusArray} })
    ]
  );
  # Kick off threads
  for(my $i=0;$i<$$settings{numcpus};$i++){
    $thr[$i] = threads->new(\&searchAsmWorker, $index, $asmQ, $printQ, $settings);
  }

  # Start off printer thread
  my $printer = threads->new(\&printer, $printQ, $settings);

  # Send termination signal to threads
  for(@thr){
    $asmQ->enqueue(undef);
  }
  # Wait for threads to finish
  for(@thr){
    $_->join;
  }

  # Wait for the printer to finish
  $printQ->enqueue(undef);
  $printer->join;

  return 0;
}

# Separate printer thread to make sure there is no stdout collisions.
sub printer{
  my($Q, $settings) = @_;

  my $seqsFh;
  if($$settings{outseqs}){
    my $novelAlleles = $$settings{outseqs};
    logmsg "Opening $novelAlleles for writing...";
    open($seqsFh, '>', $novelAlleles) or die "ERROR: could not write to novel alleles file $novelAlleles: $!";
  }

  while(defined(my $toPrint = $Q->dequeue)){
    my ($fhStr, $str) = @$toPrint;
    if($fhStr eq 'stdout'){
      print $str . "\n";
    }
    elsif($fhStr eq 'seqs'){
      print $seqsFh $str . "\n";
    }
    else {
      die "ERROR: did not understand filehandle nickname $fhStr to write the string $str";
    }

  }
}

sub searchAsmWorker{
  my($index, $asmQ, $printQ, $settings) = @_;
  my $k = $$index{settings}{k} || die "ERROR: could not find k in database $$settings{db}";
  my $hashing_sub = \&{$$index{settings}{hashing}};
  my @locusName = @{ $$index{locusArray} };

  my $numSearched = 0;
  while(defined(my $asm = $asmQ->dequeue)){
    logmsg "Typing for $asm";
    my $loci = searchAsm($asm, $k, $hashing_sub, $index, $settings);
    printTsvRow($asm, \@locusName, $loci, $printQ, $settings);
    if($$settings{outseqs}){
      printSeqs($asm, \@locusName, $loci, $index, $hashing_sub, $printQ, $settings);
    }

    $numSearched++;
  }

  return $numSearched;
}

sub printSeqs{
  my($asm, $locusName, $loci, $index, $hashing_sub, $printQ, $settings) = @_;

  my $fasta = "";
  for my $locus(@$locusName){
    my($sequence, $allele);

    if(defined($$loci{$locus})){
      $allele   = $$loci{$locus};
      $sequence = $$index{alleleSeq}{$locus}{$allele};
    }
    else{
      next;
    }
    if(!$sequence){
      logmsg "WARNING: sequence was not defined for ${locus}_$allele";
      next;
    }
    $fasta .= ">${locus}_$allele $asm\n$sequence\n";
  }

  # Print novel alleles too
  for my $locus(@$locusName){
    if(defined($$loci{_novel}{$locus})){

      for my $sequence(@{ $$loci{_novel}{$locus} }){
        my $allele   = &$hashing_sub($sequence);
        $fasta .= ">${locus}_$allele $asm\n$sequence\n";
      }

    }
  }

  $printQ->enqueue(['seqs', $fasta]);
}

sub printTsvRow{
  my($asm, $locusName, $loci, $printQ, $settings) = @_;

  my $printLine = $asm;
  for my $locus(@$locusName){
    my $allele = $$loci{$locus} // 0;
    $printLine .= "\t$allele";
  }
  $printQ->enqueue(['stdout', $printLine]);
}

sub searchAsm{
  my($asm, $k, $hashing_sub, $index, $settings) = @_;

  my %locus;
  my $stopsRegex = $$settings{stopsRegex};

  my $in=Bio::SeqIO->new(-file=>$asm);
  while(my $seqOrig = $in->next_seq){
    my $revcom   = $seqOrig->revcom;

    for my $seq($seqOrig, $revcom){
      my $sequence = $seq->seq;
      my $seqLength = length($sequence);

      # sliding window to get hashes and match against db
      for(my $i=0; $i<$seqLength-$k; $i++){
        my $subseq = substr($sequence, $i, $k);
        my $locusHash = &$hashing_sub($subseq);
        my $alleleSeq = "";

        # Test if we found the locus hash which would indicate we found the locus
        if($$index{locus}{$locusHash}){
          # Get the name of the putative locus
          my $locus = $$index{locus}{$locusHash};
          # Get downstream sequence to see if it matches an allele
          my $candidateSequence = "";
          for(my $j=$k;$j<$$settings{maxGeneLength};$j++){
            $candidateSequence = substr($sequence, $i, $j);
            if($candidateSequence !~ $stopsRegex){
              next;
            }

            if($$index{allele}{$locus}{$candidateSequence}){
              #logmsg "Found $candidateSequence";
              #push(@locus, $$index{allele}{$locus}{$candidateSequence});
              my $allele = $$index{allele}{$locus}{$candidateSequence}[1];
              if(defined $locus{$locus}){
                logmsg "WARNING: locus $locus has been defined more than once. Applying '?' for $locus.";
                $locus{$locus} = '?';
                $alleleSeq = 'N' x 60;
              } else {
                $locus{$locus} .= $allele;
                $alleleSeq = $candidateSequence;
              }

              # push ahead the search to wherever $j is but back it up the kmer length
              $i += $j-$k;
            }
          }

          # If the allele sequence hasn't been determined yet,
          # get it by detecting the first ORF.
          if(!$alleleSeq){
            # Figure out the ORF but it should be at least 20aa or 60nt.
            for(my $pos=60; $pos < length($candidateSequence); $pos+=3){
              my $candidateOrf = substr($candidateSequence, 0, $pos);
              my $candidateStop = substr($candidateOrf, -3, 3);
              #logmsg $pos;
              if($$index{stops}{$candidateStop}){
                push(@{ $locus{_novel}{$locus} }, $candidateOrf);
                $alleleSeq = $candidateOrf;
                last;
              }
            }
          }

          # The next part of this loop is only when we care about putative alleles
          # for a locus we might have detected.
          next if(!$$settings{putatives});
          # If we get to this point, then `next SLIDING_WINDOW` was not run,
          # but a locus was identified.
          # Mark that we think we know the locus but not the allele.
          my $allele = "?";
          if(defined $locus{$locus}){
            logmsg "WARNING: locus $locus is defined more than once. Appending allele $locus{$locus} with ~$allele";
            $allele = "~$allele";
          }
          $locus{$locus} .= $allele;
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
  --db         Database from hashest-index.pl
  --numcpus    Number of threads to use [default: 1]
  --dump       Dump the database instead of analyzing anything 
  --outseqs    (optional) A filename to write alleles
               into a fasta format. Defline will be
               >locusname_alleleInt or for novel alleles,
               >locusname_hashsum
               The assembly filename will also appear on the defline.
  --putatives  Print a '?' instead of an int when a locus
               has been detected but no exact allele was
               found
  --help       This useful help menu
  ";
  exit 0;
}
