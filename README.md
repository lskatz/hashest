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

1. Index the database
   * hash the first _k_ nucleotides of each allele in the database (`hash` => `locusname`)
   * hash the whole sequence of the alleles too (`hash` => `[locus, allele, sequence]`)
   * Save to index file
2. Search the database (TODO)
   * hash a sliding window of a genome assembly of _k_ length
   * Find the right locus: match hash to locus
   * Find the right allele of the locus: match sequence to alleles of locus

