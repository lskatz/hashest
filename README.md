# Hashest

Use hashes to estimate MLST

# Usage

```
hashest-index.pl: indexes a fasta file
  Fasta file have deflines in the format of >locus_allele
    where locus is a string and allele is an int
  Usage: hashest-index.pl [options] *.fasta [*.gbk...]
  --k       kmer length [default: 16]
  --hashing Hashing algorithm md5_hex, sha1_hex [default: md5_hex]
  --output  Output prefix for index files
  --version print version and exit
  --help    This useful help menu

hashest-search.pl: reports an MLST profile for a genome assembly
  Usage: hashest-search.pl [options] *.fasta [*.gbk...] > out.tsv
  --db         Database from hashest-index.pl
  --numcpus    Number of threads to use [default: 1]
  --dump       Dump the database instead of analyzing anything
  --novel-alleles  (optional) A filename to write novel alleles
               into a fasta format. Defline will be
               >locusname_hashsum
  --putatives  Print a '?' instead of an int when a locus
               has been detected but no exact allele was
               found
  --help       This useful help menu
```

* Step 1: get a fasta file or set of fasta files with alleles in the format of `>locus_allele`, e.g., `>abcZ_1`.
* Step 2: run `hashest-index.pl` on the set of fasta file(s) to create a new index. The database is described in its own section below.
* Step 3: analyze an assembly against the new index with `hashest-search.pl`.

`hashest-search` results in a tsv stdout output.
Columns are loci, rows are assemblies, and values are alleles.
Tildes (`~`) represent multiple allele matches and probably multiple copies/variations of a gene.
Question marks (`?`) indicate a match to a locus via a hash match, but no allele match was found.

## API

If you want to load the Hashest index, you can use `Storable` like so.
At this time, there is no direct Hashest API apart from loading the database.

```perl
use strict;
use warnings;
use Storable qw/retrieve/;

my $db = retrieve("file.hashest");

# and then do something with the database, e.g.,
use Data::Dumper qw/Dumper/;
print Dumper $db;
```

# Installation

Requires perl with threads and BioPerl

```
cd ~/bin
git clone git@github.com:lskatz/hashest.git
export PATH=$PATH:~/bin/hashest/scripts
```

# Algorithm

Inspired by [Gustle](https://github.com/supernifty/gustle)

Uses native perl md5 hashing.

1. Index the database
   * hash the first _k_ nucleotides of each allele in the database 
   * save whole sequence of the alleles too
   * Save to index file
2. Search the database 
   * hash a sliding window of a genome assembly of _k_ length
   * Find the right locus: match hash to locus
   * Find the right allele of the locus: match sequence to alleles of locus
   * If multiple cpus given, multiple assemblies will be analyzed at the same time, each single threaded.

# Database structure

Database is in a Perl storable object, similar to a Python pickle.
The data structure has these keys

* allele => associative array of `locus` => `[sequence]` => `[locus, allele]`
* alleleSeq => associative array of `locus` => `{allele => sequence}` (v0.6 and later)
* locus => associative array of `hash`=>`locusname`
* locusArray => [array of locus names], meant to hold a stable sort of the locus names
* settings => information about the database.  Stores `k`, `version`, `hashing` (hashing is `md5_hex` in v0.2 and later).
* stops => associative array of `{stopCodon => count}` where stopCodon is any last three nucleitides of any allele followed by the count of how many were found, e.g., `{CAG => 1997}` for the 7-gene senterica database.

