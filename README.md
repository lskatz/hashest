# Hashest

Use hashes to estimate MLST

# Usage

```
hashest-index.pl: indexes a fasta file
  Fasta file have deflines in the format of >locus_allele
    where locus is a string and allele is an int
  Usage: hashest-index.pl [options] *.fasta [*.gbk...]
  --k       kmer length [default: 16]
  --help    This useful help menu

hashest-search.pl: reports an MLST profile for a genome assembly
  Usage: hashest-search.pl [options] *.fasta [*.gbk...] > out.tsv
    --db      Database from hashest-index.pl
    --dump    Dump the database instead of analyzing anything 
    --help    This useful help menu

```

# Installation

Requires perl and BioPerl

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
2. Search the database (TODO)
   * hash a sliding window of a genome assembly of _k_ length
   * Find the right locus: match hash to locus
   * Find the right allele of the locus: match sequence to alleles of locus

# Database structure

Database is in a Perl storable object, similar to a Python pickle.
The data structure has these keys

* locusArray => [array of locus names]
* locus => associative array of `hash`=>`locusname`
* allele => associative array of `locus` => `[sequence]` => `[locus, allele]`
* settings => information about the database.  Stores `k`.
