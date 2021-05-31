#!/usr/bin/env perl

############     q_filter.pl     ############
#
#	This Perl script reads sequence files in FASTQ format
#	and filters out sequences based on Phred quality scores.
#	Several options to adjust the  filtering process are
#	available.
#
#	The script is part of the "NGS tools for the novice"
#	authored by David Rosenkranz, Institue of Anthropology
#	Johannes Gutenberg University Mainz, Germany
#
#	Contact: rosenkrd@uni-mainz.de


############     HOW TO USE     ############
#
#	You can pass file names of the files to be processed and
#	options for the filtering process via arguments to the script.
#
#	Input files have to be passed to the scripts via -i:
#	-i file1.fas -i file2.fas
#
#	If you do not want to enter each file name seperately, you
#	can provide a file that contains a list all file names (one
#	file name per line). Pass the file name to the script via -I:
#	-I list_of_files.txt
#
#	By default, the script assumes your FASTQ file to be in
#	Sanger format (scores from 0-93 using ASCII 33-126).
#	You can change this setting via -f:
#	-f Sanger	| if your FASTQ file is in Sanger format.
#	-f Illumina	| if your FASTQ file is in Illumina format.
#
#	Selecting the correct format is crucial for correct computation!
#	Info:
#	Illumina 1.0+ = Illumina format
#	Illumina 1.8+ = Sanger format
#
#	In Illumina 1.5+ stretches of B corresponding to a Phred
#	score or 2 are used to indicate, that a specific final
#	proportion of the read should not be used in further
#	analysis. In Illumina 1.8+ (Sanger format) low quality ends
#	are indicated by strectches of #. If your FASTQ file is in
#	Illumina 1.5+ or Sanger (Illumina 1.8+) format, you can
#	choose to clip these ends prior to subsequent filtering
#	steps via -c:
#	- c 0	| do not clip low quality ends
#	- c 1	| clip low quality ends
#
#	This script allows three different methods of filtering
#	by quality that can be combined as you like. The following
#	examples show the default values:
#	1. Set a min. probability for a read to contain 0 errors:
#	-mp 50		| p>=50% that the read contains 0 errors
#	2. Define a min. average Phred score for each read:
#	-ma 16		| min. average score of the read = 20
#	3. Define a min. Phred score that each base has to exceed:
#	- ms 8		| min. score for each base of the read = 8
#
#	The script will create the following selfexplanatory output
#	files:
#	- filtered_out.fastq
#	- passed_filter.fastq
#	
#	Multiple files and combinations of all kinds of arguments
#	are allowed:
#	perl q_filter.pl -i input_file.fas -I list_of_files.txt -f Illumina -c 1 -mp 75 -ma 20 -ms 10



@input_files=();
$format="Sanger";
$clip=0;
$mp=50;
$ma=16;
$ms=8;
$|=1;

###   CHECK COMMAND LINE ARGUMENTS   ###
if(@ARGV==0)
	{
	print"No arguments passed to the script!\nIf you entered arguments try the following command:\nperl discard_redundant_sequences.pl -argument1 #argument2 ...\n\n";
	exit;
	}

$argv="";
foreach(@ARGV)
	{
	$argv.=$_;
	}
@arguments=split('-',$argv);

foreach(@arguments)
	{
	if($_=~/^ *i/)
		{
		$_=~s/^ *i//;
		$_=~s/ //g;
		push(@input_files,$_);
		}
	elsif($_=~/^ *I/)
		{
		$_=~s/^ *I//;
		$_=~s/ //g;
		open(FILES_IN,"$_");
		while(<FILES_IN>)
			{
			unless($_=~/^\s*$/)
				{
				$_=~s/\s//sg;
				push(@input_files,$_);
				}
			}
		}
	elsif($_=~/^ *c *[01]/)
		{
		$_=~s/^ *c//;
		$_=~s/ //g;
		$clip=$_;
		}
	elsif($_=~/^ *f/)
		{
		$_=~s/^ *f//;
		$_=~s/ //g;
		$format=$_;
		}	
	elsif($_=~/^ *mp/)
		{
		$_=~s/^ *mp//;
		$_=~s/ //g;
		$mp=$_;
		}	
	elsif($_=~/^ *ma/)
		{
		$_=~s/^ *ma//;
		$_=~s/ //g;
		$ma=$_;
		}
	elsif($_=~/^ *ms/)
		{
		$_=~s/^ *ms//;
		$_=~s/ //g;
		$ms=$_;
		}
	elsif($_!~/^\s*$/)
		{
		print"Don't know how to treat argument $_!\nIt will be ignored.\n\n";
		}
	}
if($format!~/^ *Illumina *$/i&&$format!~/^ *Sanger *$/i)
	{
	print"Input format has to be 'Sanger' or 'Illumina'\n";
	exit;
	}
if(@input_files==0)
	{
	print"No input file specified!\n";
	exit;
	}
unless($mp=~/^\d+$/&&$mp>=0&&$mp<=100)
	{
	print"Probability for sequence read to contain 0 errors has to be numerical (0 to 100)!\n";
	exit;
	}
if($format=~/Illumina/)
	{
	unless($ma=~/^\d+$/&&$ma>=-5&&$ma<=62)
		{
		print"Minimum average score for reads has to be numerical (-5 to 62)!\n";
		exit;
		}
	}
elsif($format=~/Sanger/)
	{
	unless($ma=~/^\d+$/&&$ma>=0&&$ma<=93)
		{
		print"Minimum average score for reads has to be numerical (0 to 93)!\n";
		exit;
		}
	}

###   PRINT ARGUMENTS   ###
print"The following files will be processed:\n";
foreach(@input_files)
	{
	if(-e $_)
		{
		print"$_\n";
		push(@input_files_ok,$_);
		}
	else
		{
		print"could not find file: $_. It will be ignored.\n";
		}
	}
if($format=~/Illumina/)
	{
	print"\nInput files are assumed to be Illumina format.";
	}
elsif($format=~/Sanger/)
	{
	print"\nInput files are assumed to be Sanger format.";
	}
if($clip==0)
	{
	print"\nLow quality ends will not be clipped prior sequence filtering.";
	}
elsif($clip==1)
	{
	print"\nLow quality ends will be clipped prior sequence filtering.";
	}
print"\nMinimum probability for a read to contain 0 errors: $mp%";
print"\nMinimum average Phred score for a sequence read: $ma";
print"\nMinimum Phred score for each base of a read: $ms\n\n";

###   START   ###
open(OUT1,">passed_filter.fastq");
open(OUT2,">filtered_out.fastq");
$ok=0;
$filtered_out=0;
$mp=$mp/100;
foreach$file(@input_files_ok)
	{
	print"processing $file";
	open(IN,$file);
	$title_index=0;
	$seq_index=0;
	$quality_prefix_index=0;
	$quality_index=0;
	while(<IN>)
		{
		if($_=~/^@/&&$title_index==0)
			{
			$title=$_;
			$title_index=1;
			}
		elsif($_=~/^[ATGCN]+\n?$/&&$seq_index==0)
			{
			$sequence=$_;
			$seq_index=1;
			}
		elsif($_=~/^\+/&&$quality_prefix_index==0)
			{
			$quality_header=$_;
			$quality_prefix_index=1;
			}
		elsif($quality_index==0)
			{
			$quality=$_;
			$quality_index=1;
			}
		if($title_index+$seq_index+$quality_prefix_index+$quality_index==4)
			{
			$title_index=0;
			$seq_index=0;
			$quality_prefix_index=0;
			$quality_index=0;
			chomp$quality;
			chomp$sequence;
			if($clip==1&&$quality=~/B+\n?$/&&$format=~/Illumina/)
				{
				$quality=~s/B+$//s;
				$sequence=substr($sequence,0,(length$sequence)-(length$&));
				}
			elsif($clip==1&&$quality=~/B+\n?$/&&$format=~/Sanger/)
				{
				$quality=~s/#+$//s;
				$sequence=substr($sequence,0,(length$sequence)-(length$&));
				}
			$prob_0_errors=1;
			$average_score=0;
			@quality=split('',$quality);
			if($format=~/Illumina/)
				{
				foreach(@quality)
					{
					$Phred=ord($_)-64;
					$prob=1-(10**(($Phred*-1)/10));
					$prob_0_errors=$prob_0_errors*$prob;
					$average_score+=$Phred;
					last if $prob_0_errors<$mp;
					last if $Phred<$ms;
					}
				}
			else
				{
				foreach(@quality)
					{
					$Phred=ord($_)-33;
					$prob=1-(10**(($Phred*-1)/10));
					$prob_0_errors=$prob_0_errors*$prob;
					$average_score+=$Phred;
					last if $prob_0_errors<$mp;
					last if $Phred<$ms;
					}
				}
			$average_score=$average_score/(length$sequence);
			if($average_score>=$ma&&$prob_0_errors>=$mp&&$Phred>=$ms)
				{
				print OUT1"$title$sequence\n$quality_header$quality\n";
				$ok++;
				}
			else
				{
				print OUT2"$title$sequence\n$quality_header$quality\n";
				$filtered_out++;
				}
			}
		}
	close IN;
	print" done.\n";
	}
close OUT1;
close OUT2;
print"\nSequences that filter:\t$ok\nSequences filtered out:\t$filtered_out\n\n";
exit;
