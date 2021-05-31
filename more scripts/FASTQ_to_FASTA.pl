#!/usr/bin/env perl

############    FASTQ_to_FASTA.pl     ############
#
#	This Perl script converts FASTQ files into FASTA format
#
#	The script is part of the "NGS tools for the novice"
#	authored by David Rosenkranz, Institue of Anthropology
#	Johannes Gutenberg University Mainz, Germany
#
#	Contact: rosenkrd@uni-mainz.de



############     HOW TO USE     ############
#
#	You can pass file names of the files to be processed as
#	arguments to the script.
#
#	Input files have to be passed to the scripts via -i:
#	-i file1.fas -i file2.fas
#
#	If you do not want to enter each file name seperately, you
#	can provide a file that contains a list all file names (one
#	file name per line). Pass the file name to the script via -I:
#	-I list_of_files.txt
#
#	Multiple files and combinations of all kinds of arguments are
#	allowed. For example you can type the following command:
#	perl FASTQ_to_FASTA -i file1.fas -I list_of_files.txt
#
#	The FASTQ file example.fastq will be converted to example.fas




@input_files=();
$|=1;

###   CHECK COMMAND LINE ARGUMENTS   ###
if(@ARGV==0)
	{
	print"No arguments passed to the script!\nIf you entered arguments try the following command:\nperl sort_by_tag.pl -argument1 #argument2 ...\n\n";
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
	elsif($_!~/^\s*$/)
		{
		print"Don't know how to treat argument $_!\nIt will be ignored.\n\n";
		}
	}
if(@input_files==0)
	{
	print"No input file specified!\n";
	exit;
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

###   START   ###
foreach$file(@input_files_ok)
	{
	print"processing $file";
	$out_file_name=$file;
	$out_file_name=~s/\..+$//;
	$out_file_name.=".fas";
	open(OUT,">$out_file_name");
	open(IN,$file);
	$title_index=0;
	$seq_index=0;
	$quality_prefix_index=0;
	$quality_index=0;
	$seq_count=0;
	while(<IN>)
		{
		if($_=~/^@/&&$title_index==0)
			{
			$title=$_;
			$title=~s/^@/>/;
			$title_index=1;
			}
		elsif($_=~/^[ATGCUN]+[\n]*$/&&$seq_index==0)
			{
			$sequence=$_;
			$seq_index=1;
			}
		elsif($_=~/^\+/&&$quality_prefix_index==0)
			{
			$quality_prefix_index=1;
			}
		elsif($quality_index==0)
			{
			$quality_index=1;
			}
		if($title_index+$seq_index+$quality_prefix_index+$quality_index==4)
			{
			print OUT "$title$sequence";
			$seq_count++;
			$title_index=0;
			$seq_index=0;
			$quality_prefix_index=0;
			$quality_index=0;
			}
		}
	close IN;
	close OUT;
	print" done. Sequences: $seq_count\n";
	}
exit;