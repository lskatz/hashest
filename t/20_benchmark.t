#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark ':all';
use Test::More 'no_plan';
use File::Basename qw/dirname/;

use FindBin qw/$RealBin/;
use Data::Dumper;
... ;

my $thisDir = dirname($0);
my $filesDir = "$thisDir/files";

my $OS = "nix";
if($^O =~ /mswin32/i){
  $OS = "win";
}
my $fd = which("fd") || which("fdfind") || "";
diag "fd was found at: '$fd'";

# Vanilla GNU find program
sub gnuFind{
  my @files;
  if($OS eq 'win'){
    my $f = pirFresh();
    @files = @$f;
  } else {
    @files = `find $filesDir`;
  }
  chomp(@files);
  return \@files;
}
# This package's program
sub fileFindFast{
  my $files = File::Find::Fast::find($filesDir);
  return $files;
}
# Default perl File::Find
sub fileFind{
  my @files = ();
  File::Find::find({wanted=>sub{
    push(@files,$File::Find::name);
  }, no_chdir=>1}, $filesDir);
  return \@files;
}

# PIR options for fastest possible finding, see:
#   https://metacpan.org/pod/Path::Iterator::Rule#PERFORMANCE
my $pirOptions = {loop_safe=>0, sorted=>0, depthfirst=>-1, error_handler=>undef};
# PIR finding function but it recreates the rule object each time
sub pirFresh{
  my $rule = Path::Iterator::Rule->new;
  my @file = $rule->all($filesDir,$pirOptions);
  return \@file;
}
# PIR finding function again but not recreating the rule object
my $globalRule = Path::Iterator::Rule->new;
sub pirReused{
  my @file = $globalRule->all($filesDir, $pirOptions);
  return \@file;
}

sub fd{
  my @file;
  if(!$fd){
    my $f = pirFresh();
    @file = @$f;
  }
  else {
    @file = `$fd . $filesDir`;
    chomp(@file);
    unshift(@file, $filesDir); # fd doesn't have the root dir for some reason
  }
  return \@file;
}

# initial check
my $gnuFind = [sort @{ gnuFind() } ];
my $fileFindFast = [sort @{ fileFindFast() } ];
my $fileFind = [sort @{fileFind() } ];
my $pirFresh = [sort @{pirFresh() } ];
my $pirReused= [sort @{pirReused() } ];
my $fdFind = [sort @{fd() } ];
#note Dumper [$gnuFind, $fileFindFast, $fileFind];
is_deeply($fileFindFast, $gnuFind, "File::Find::Fast");
is_deeply($fileFind, $gnuFind, "File::Find");
is_deeply($pirFresh, $gnuFind, "Path::Iterator::Rule");
is_deeply($pirReused, $gnuFind, "Path::Iterator::Rule2");
is_deeply($fdFind, $gnuFind, "Fd-find");

my $cmp = 
  cmpthese(1000, { 
      'gnuFind'          => sub { gnuFind() },
      'File::Find::Fast' => sub { fileFindFast() },
      'File::Find'       => sub { fileFind() },
      'Path::Iterator::Rule'  => sub { pirFresh() },
      'Path::Iterator::Rule2'  => sub { pirReused() },
      'Fd-find'          => sub { fd() },
  });

for(my $i=0;$i<@$cmp;$i++){
  #note join("\t", @{ $$cmp[$i] });
  my @a = @{ $$cmp[$i] };
  my $row = "";
  for(my $j=0;$j<@a;$j++){
    # 22 characters to help hold our longest string Path::Iterator::Rule2
    $row .= sprintf("%22s ", $a[$j]);
  }
  diag $row;
}
