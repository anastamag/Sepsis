#!/usr/bin/env perl

############     discard_redundant_sequences.pl     ############
#
#	This Perl script reads sequence files in FASTA format and
#	outputs a FASTA file without redundant sequences. The
#	FASTA title will refer to the total abundance of the respective
#	sequence in the input file.
#
#	The script is part of the "NGS tools for the novice"
#	authored by David Rosenkranz, Institue of Anthropology
#	Johannes Gutenberg University Mainz, Germany
#
#	Contact: rosenkrd@uni-mainz.de



############     HOW TO USE     ############
#
#	You can pass file names of the files to be processed and
#	the output file name as arguments to the script.
#
#	Input files have to be passed to the scripts via -i:
#	-i file1.fas -i file2.fas
#
#	The output file name has to be passed to the script via -o:
#	-o output_file.txt
#
#	If no output file name is passed to the script, the results
#	will be saved in the file nonredundant.fas.
#
#	For example you can type the following command:
#	perl discard_redundant_sequences.pl -i file1.fas -o output_file.txt
#
#	If you do not want to enter each file name seperately, you
#	can provide a file that contains a list all file names (one
#	file name per line). Pass the file name to the script via -I:
#	-I list_of_files.txt
#
#	Multiple files and combinations of all kinds of arguments are
#	allowed:
#	perl discard_redundant_sequences.pl -i file1.fas -I list_of_files.txt -o output_file.txt




@input_files=();
$|=1;
$output_file_name="nonredundant.fas";

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
	elsif($_=~/^ *o/)
		{
		$_=~s/^ *o//;
		$_=~s/ //g;
		$output_file_name=$_;
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
print"The results will be saved in: $output_file_name\n\n";

###   START   ###
%sequences=();
$sequences=0;
$nonredundant_sequences=0;
foreach$file(@input_files_ok)
	{
	open(IN,$file);
	print"processing $file\n";
	while(<IN>)
		{
		if($_!~/^>/&&$_!~/^\s*$/)
			{
			chomp$_;
			$sequences++;
			$sequences{$_}++;
			}
		}
	}
open(OUT,">$output_file_name");
foreach(keys(%sequences))
	{
	$nonredundant_sequences++;
	print OUT ">$sequences{$_}\n$_\n";
	}
close OUT;
print"Total sequences in input file(s): $sequences\nNonredundant sequences saved in $output_file_name: $nonredundant_sequences\n\n";
exit;