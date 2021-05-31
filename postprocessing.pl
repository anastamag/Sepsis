#!/usr/bin/env perl

# Parses the umis_count.fas files in all output-* subdirectories in
# the current directory and creates a tab-delimited output file called
# heatmap.tsv.  Also uses the barcode.tsv file which should be present
# int the current directory.

use strict;
use warnings;

use IO::File;

#use Data::Dumper;

# Read the pathogen barcodes.
my %pathogen;
my $fh = IO::File->new( "barcodes.tsv", "r" ) or croak("$!");

$fh->getline();    # skip header line
while ( my $line = $fh->getline() ) {
    chomp($line);
    $line =~ s/\r$//;
    my @fields = split( /\t/, $line );
    $pathogen{ $fields[2] } = $fields[1];
}
$fh->close();

my %count;
my %barcode_count;
foreach my $filename (<"output-*/umis_count.fas">) {
    $filename =~ /^output-([^\/]+)/;
    my $sample_name = $1;

    $fh = IO::File->new( $filename, "r" ) or croak("$!");
    while ( my $line = $fh->getline() ) {
        chomp($line);
        $line =~ s/^>//;
        my $count         = $line;
        my $barcode       = $fh->getline();
        chomp($barcode);
        my $short_barcode = substr( $barcode, 0, 5 );

        $count{$sample_name}{$short_barcode} += $count;
        $barcode_count{$sample_name}{$barcode} += $count;

        if ( !exists( $pathogen{$short_barcode} ) ) {
            $pathogen{$short_barcode} = "??? ($short_barcode)";
        }
    }
    $fh->close();
}

$fh = IO::File->new( "heatmap.tsv", "w" ) or croak("$!");
foreach my $short_barcode ( sort { $pathogen{$a} cmp $pathogen{$b} }
                            keys(%pathogen) )
{
    $fh->printf( "\t%s", $pathogen{$short_barcode} );
}
$fh->print("\n");

foreach my $sample_name ( sort { $a cmp $b } keys(%count) ) {
    $fh->print($sample_name);
    foreach my $short_barcode ( sort { $pathogen{$a} cmp $pathogen{$b} }
                                keys(%pathogen) )
    {
        $fh->printf( "\t%s", $count{$sample_name}{$short_barcode} );
    }
    $fh->print("\n");
}
$fh->close();

$fh = IO::File->new( "Target_List.txt", "r" ) or croak("$!");
my $fh2 = IO::File->new( "target_counts.tsv", "w" ) or croak("$!");

# print header
$fh2->printf("Name\tTarget sequence");
foreach my $sample_name ( sort { $a cmp $b } keys(%barcode_count) ) {
    $fh2->printf( "\t%s", $sample_name );
}
$fh2->print("\n");

$fh->getline();    # skip header
while ( my $line = $fh->getline() ) {
    chomp($line);
    $line =~ s/\r$//;
    $line =~ s/^\s*//;
    my ( $name, $barcode ) = split( /\s+/, $line );

    $fh2->printf( "%s\t%s", $name, $barcode );
    foreach my $sample_name ( sort { $a cmp $b } keys(%barcode_count) )
    {
        $fh2->printf( "\t%s",
                      $barcode_count{$sample_name}{$barcode} || 0 );
    }
    $fh2->print("\n");
}

$fh2->close();
$fh->close();
