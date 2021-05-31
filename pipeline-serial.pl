#!/usr/bin/env perl

use strict;
use warnings;

#use Data::Dumper;

use Carp;
use Cwd;
use File::Basename;
use File::Copy;
use File::Glob qw(:globally :nocase);
use IO::File;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

my $fh;

# $wd:          where we are
# $scriptdir:   where the scripts are
my $wd        = cwd();
my $scriptdir = "$wd/scripts";

# Where the input comes from.
my $inputdir = "$wd/input";

my $sample_pattern = "Sample_[0-9][0-9]";

# The compressed fastq input files are assumed to live in subdirectories
# of the $inputdir directory.  These subdirectories of $inputdir
# are assumed to be called "<sample-name>_<something>".  The files
# themselves are assumed to be called "<something>.fastq.gz". The
# "<sample-name>" bit in the subdirectory name is something that matches
# $sample_pattern ("Sample_[0-9][0-9]").

# Collect the names of the compressed fastq files for each sample.
my %samples;
foreach my $gz_file (<"$inputdir/${sample_pattern}_*/*.fastq.gz">) {
    my $sample_name;

    if ( $gz_file =~ /\/($sample_pattern)_/ ) {
        $sample_name = $1;
    }
    else {
        croak("Could not find sample name in filename $gz_file");
    }
    push( @{ $samples{$sample_name} }, $gz_file );
}

# Read the adapter sequence.
$fh = IO::File->new( "adapterFW.txt", "r" ) or croak("$!");
my $fw_primer = $fh->getline();
$fh->close();
chomp($fw_primer);
$fw_primer =~ s/\r$//;

# @pipeline is an list of pipeline stages.
#
# Each stage is a hash that should contain at least an 'info' and a
# 'cmd' entry.  The 'info' entry is used in the output and the 'cmd'
# entry is a list of arguments to give to thu 'perl' executable.
#
# A stage may also contain an optional 'post' entry, which, if
# it exists, should be a subroutine that will be called as a
# "post-processing" step for that particular stage.
#
# The post-processing step is here being used to rename the output files
# of every pipeline stage that produces "outfile_*" files so that the
# files produced by that stage is clearly distinguishable from those
# produced by other stages.
#
my @pipeline = (
    {  'info' => 'QUALITY FILTER',
       'cmd'  => [qw(q_filter.pl -I input_files.txt)],
       'post' => sub {
           # Clean up.
           unlink "input_files.txt";
       }
    },
    {  'info' => 'FASTQ -> FASTA CONVERSION',
       'cmd'  => [qw(FASTQ_to_FASTA.pl -i passed_filter.fastq)],
       'post' => sub {
           # Clean up.
           unlink <"*.fastq">;
       }
    },
    {  'info' => 'REMOVE TAGS (primer)',
       'cmd'  => [qw(remove_TAGs.pl -i passed_filter.fas), '-t',
                  "$fw_primer" ],
       'post' => sub {
           # Clean up.
           unlink "passed_filter.fas";

           # Rename primer output file to "primer_..."
           move( "outfile_$fw_primer.fas", "primer_$fw_primer.fas" );
       }
    },
    {  'info' => 'LENGTH FILTER',
       'cmd'  => [qw(length_cutoff.pl -min 40 -max 75), '-i',
                  "primer_$fw_primer.fas" ],
       'post' => sub {
           # Clean up.
           unlink <"sequences_too_*.fas">;
           unlink "primer_$fw_primer.fas";
       }
    },
    {  'info' => 'REDUNDANCY FILTER (reads)',
       'cmd' =>
         [qw(discard_redundant_sequences.pl -i sequences_ok.fas)],
       'post' => sub {
           # Clean up.
           unlink "sequences_ok.fas";
       }
    },
    {  'info' => 'REMOVE TAGS (targets)',
       'cmd'  => [
           qw(remove_TAGs.pl -i nonredundant.fas -T ../Target_List.txt -5)
       ],
       'post' => sub {
           # Clean up.
           unlink "outfile_NO_TAG.fas";

           # Rename output files to "target_..." and also store the
           # names of these files in "unique_seqs.txt".
           $fh = IO::File->new( "unique_seqs.txt", "w" );
           for my $name (<"outfile_*.fas">) {
               if ( -s $name ) {
                   my $newname = $name;
                   $newname =~ s/^outfile/target/;
                   move( $name, $newname );
                   $fh->print( $newname, "\n" );
               }
               else {
                   # Delete empty files.
                   unlink $name;
               }
           }
           $fh->close();
       }
    },
    {  'info' => 'REDUNDANCY FILTER (targets)',
       'cmd'  => [
           qw(discard_redundant_sequences.pl -I unique_seqs.txt -o umis_count.fas)
       ],
       'post' => sub {
           # Clean up.
           unlink "unique_seqs.txt";
       }
    } );

PIPELINE:
# Run the pipeline for each sample.
foreach my $sample_name ( keys(%samples) ) {
    print( '=' x ( 80 - ( length($sample_name) + 6 ) ),
           ':: ', $sample_name, ' ::', "\n" );
    my $sample = $samples{$sample_name};

    # All produced files will go into the $outputdir directory.
    my $outputdir = "$wd/output-$sample_name";
    mkdir($outputdir);

    my @fastq_files = ();

    # Uncompress original files into the $outputdir directory if needed.
    foreach my $gz_file ( @{$sample} ) {
        my $fastq_file = "$outputdir/" . basename( $gz_file, '.gz' );
        if ( !-f $fastq_file ||
             ( stat $gz_file )[9] > ( stat $fastq_file )[9] )
        {
            printf( "Uncompressing %s to %s\n", $gz_file, $fastq_file );
            gunzip( $gz_file => $fastq_file, MultiStream => 1 ) or
              croak("$GunzipError");
        }

        push( @fastq_files, $fastq_file );
    }

    # Change directory to the $outputdir directory.  All work from now
    # on is happening in this directory.
    chdir($outputdir);

    # Create a file list of the uncompressed fastq files.
    $fh = IO::File->new( "input_files.txt", "w" ) or croak("$!");
    $fh->print( join( "\n", @fastq_files ), "\n" );
    $fh->close();

    # Loop over the stages of the pipeline, displaying a banner for each
    # and executing 'perl' with the given command line.  If there is a
    # post-processing stage, do that too.
    for my $part (@pipeline) {
        my $len = 80 - ( length( $part->{'info'} ) + 6 );
        print '-' x $len, ':: ', $part->{'info'}, ' ::', "\n";

        if ( exists( $part->{'cmd'} ) ) {
            my $script = "$scriptdir/" . @{ $part->{'cmd'} }[0];
            system( 'perl', $script,
                    @{ $part->{'cmd'} }[ 1 .. $#{ $part->{'cmd'} } ] );
        }

        if ( exists( $part->{'post'} ) ) {
            &{ $part->{'post'} };
        }
        print $part->{'info'}, " is done.\n";
    }
} ## end foreach my $sample_name ( keys...)

# Read the pathogen barcodes.
my %pathogen;
$fh = IO::File->new( "barcodes.tsv", "r" ) or croak("$!");
$fh->getline();    # skip header line
while ( my $line = $fh->getline() ) {
    chomp($line);
    $line =~ s/\r$//;
    my @fields = split( /\t/, $line );
    $pathogen{ $fields[2] } = $fields[1];
}
$fh->close();

# Parse umis_count.fas from each sample and extract the counts for
# each barcode. Write result to heatmap.tsv (a tab-delitied file).
my %count;
foreach my $sample_name ( keys(%samples) ) {
    my $filename = "output-$sample_name/umis_count.fas";
    $fh = IO::File->new( $filename, "r" ) or croak("$!");
    while ( my $line = $fh->getline() ) {
        chomp($line);
        $line =~ s/^>//;
        my $count = $line;
        my $barcode = substr( $fh->getline(), 0, 5 );

        $count{$sample_name}{$barcode} += $count;
        if ( !exists( $pathogen{$barcode} ) ) {
            $pathogen{$barcode} = "??? ($barcode)";
        }
    }
    $fh->close();
}

$fh = IO::File->new( "heatmap.tsv", "w" ) or croak("$!");
foreach my $barcode ( sort { $pathogen{$a} cmp $pathogen{$b} }
                      keys(%pathogen) )
{
    $fh->printf( "\t%s", $pathogen{$barcode} );
}
$fh->print("\n");

foreach my $sample_name ( sort { $a cmp $b } keys(%samples) ) {
    $fh->print($sample_name);
    foreach my $barcode ( sort { $pathogen{$a} cmp $pathogen{$b} }
                          keys(%pathogen) )
    {
        $fh->printf( "\t%s", $count{$sample_name}{$barcode} );
    }
    $fh->print("\n");
}
$fh->close();
