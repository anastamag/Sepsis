#!/usr/bin/env perl

# This script parses the target_*.fas files for the output directory
# named on the command line and summarises the target counts in
# target-counts.tsv where "NN" is the sample name.  The file is
# created inside the directory named on the command line.

use strict;
use warnings;

use IO::File;
use Carp;

#use Data::Dumper;

while ( scalar(@ARGV) > 0 ) {
    my $dir = $ARGV[0];
    if ( !defined($dir) || !-d $dir ) {
        croak
          "Command line argument \"$dir\" is not a directory name\n";
    }

    my $fh = IO::File->new( "$dir/targets-total-reads.tsv", "w" ) or
      croak("$!");
    $fh->printf("Target\tTotal reads\n");

    foreach my $file (<"$dir/target_*.fas">) {
        my $fh2 = IO::File->new( $file, "r" ) or croak("$!");

        $file =~ /target_(.*)\.fas/;
        my $target = $1;

        my $count = 0;
        while ( my $line = $fh2->getline() ) {
            if ( $line =~ /^>(\d+)/ ) {
                $count += $1;
            }
        }
        $fh2->close();

        $fh->printf( "%s\t%d\n", $target, $count );
    }
    $fh->close();

    printf( "Wrote %s/targets-total-reads.tsv\n", $ARGV[0] );

    shift(@ARGV);
} ## end while ( scalar(@ARGV) > 0)
