#!/usr/bin/env perl

############     sort_by_TAGs.pl     ############
#
#	This Perl script will sort sequences from FASTA files
#	according to user defined TAG sequences (TAGs).
#	
#	The script is part of the "NGS tools for the novice"
#	authored by David Rosenkranz, Institue of Anthropology
#	Johannes Gutenberg University Mainz, Germany
#
#	Contact: rosenkrd@uni-mainz.de



############     HOW TO USE     ############
#
#	You can pass file names of the files to be processed and TAGs
#	as arguments to the script.
#
#	Input files have to be passed to the scripts via -i:
#	-i file1.fas -i file2.fas
#
#	TAGs have to be passed to the script via -t:
#	-t ATGCTAGA -t TTAGCGTT
#
#	A bare digit from 1-3 (1 or 2 or 3) will tell the script, where the
#	TAG has to be searched (at the beginning of the sequence, at the
#	end of the sequence or anywhere within the sequence). By default
#	it is set to 3.
#	-1 = search TAGs at the begin of each sequence.
#	-2 = search TAGs at the end of each sequence.
#	-3 = search TAGs anywhere within each sequence.
#
#	For example you can type the following command:
#	perl sort_by_TAGs.pl -i file1.fas -t ATGCTAGA -1
#
#	The resulting output files can be identified by the TAG. In this
#	case:
#	outfile_ATGCTAGA.txt
#
#	If you do not want to enter each file name or each TAG seperately,
#	you can provide a file that contains a list all file names (one file
#	name per line) or a file that contains a list of all TAGs (one TAG
#	per line) respectively. Pass the file name to the script via -I (for a
#	list of files) or via -T (for a list of TAGs):
#	-I list_of_files.txt -T list_of_TAGs.txt
#
#	Multiple files and combinations of all kinds of arguments are
#	allowed:
#	perl sort_by_TAGs.pl -i file1.fas -I list_of_files.txt -t ATGCTAGA -T list_of_TAGs.txt -1
#
#	You can adjust the number of sequences that are stored in memory
#	before they are printed to the output file (by default 10000). If
#	you run out of memory (e.g. if you have many many TAGs), you can
#	adjust this parameter downwards. Note, that this can potentially
#	slow down computation velocity. The new value has to be passed to
#	the script via -m
#
#	The command would look something like this:
#	perl remove_TAGs.pl -i file1.fas -t ATGCTAGA -m 1000



@input_files=();
@tags=();
$tag_location=3;
$collect_before_print=10000;
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
	elsif($_=~/^ *t/)
		{
		$_=~s/^ *t//;
		$_=~s/ //g;
		push(@tags,$_);
		}
	elsif($_=~/^ *T/)
		{
		$_=~s/^ *T//;
		$_=~s/ //g;
		open(TAGS_IN,"$_");
		while(<TAGS_IN>)
			{
			unless($_=~/^\s*$/)
				{
				$_=~s/\s//sg;
				push(@tags,$_);
				}
			}
		}
	elsif($_=~/^ *[123] *$/)
		{
		$_=~s/ *//g;
		$_=~s/ //g;
		$tag_location=$_;
		}
	elsif($_=~/^ *m/)
		{
		$_=~s/^ *m//;
		$_=~s/ //g;
		$collect_before_print=$_;
		}
	elsif($_!~/^\s*$/)
		{
		print"Don't know how to treat argument $_!\nIt will be ignored.\n\n";
		}
	}

unless($collect_before_print=~/^\d+$/)
	{
	print"Number of sequences kept in memory has to be numerical!\n";
	exit;
	}
if(@input_files==0)
	{
	print"No input file specified!\n";
	exit;
	}
if(@tags==0)
	{
	print"No TAGs specified!\n";
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

print"\nThe following TAGs will be searched:\n";
foreach(@tags)
	{
	print"$_\n";
	}
print"\nLocation of the TAG has to be: ";
if($tag_location==1)
	{
	print"AT THE BEGIN of the sequence.\n\n";
	}
elsif($tag_location==2)
	{
	print"AT THE END of the sequence.\n\n";
	}
elsif($tag_location==3)
	{
	print"ANYWHERE in the sequence.\n\n";
	}

###   START   ###
$noTAG=0;
%tags=();
%count_tags=();
%count_tags_for_print=();
open(NOTAG,">outfile_NO_TAG.fas");
foreach$file(@input_files_ok)
	{
	print"processing $file";
	open(IN,$file);
	while(<IN>)
		{
		if($_=~/^>/)
			{
			check_tag();
			sub check_tag
				{
				if($seq)
					{
					$seq=~s/\n//g;
					$tag_found=0;
					foreach$tag(@tags)
						{
						last if $tag_found==1;
						
						if($tag_location==1)
							{search_TAG1();}
						elsif($tag_location==2)
							{search_TAG2();}
						elsif($tag_location==3)
							{search_TAG3();}
						
						sub search_TAG1
							{
							if($seq=~/^$tag/i)
								{
								$tag_found=1;
								$tags{$tag}.="$title$seq\n";
								$count_tags{$tag}++;
								$count_tags_for_print{$tag}++;
								check_for_print();
								}
							}
						sub search_TAG2
							{
							if($seq=~/$tag\n*$/i)
								{
								$tag_found=1;
								$tags{$tag}.="$title$seq\n";
								$count_tags{$tag}++;
								$count_tags_for_print{$tag}++;
								check_for_print();
								}
							}
						sub search_TAG3
							{
							if($seq=~/$tag/i)
								{
								$tag_found=1;
								$tags{$tag}.="$title$seq\n";
								$count_tags{$tag}++;
								$count_tags_for_print{$tag}++;
								check_for_print();
								}
							}	
						
						sub check_for_print
							{
							if($count_tags_for_print{$tag}==$collect_before_print)
								{
								print".";
								open(OUT,">>outfile_$tag.fas");
								print OUT $tags{$tag};
								$tags{$tag}="";
								$count_tags_for_print{$tag}=0;
								close OUT;
								}
							}
						}
					if($tag_found==0)
						{
						print NOTAG "$title$seq\n";
						$noTAG++;
						}
					$seq="";
					}
				}
			$title=$_;
			}
		else
			{
			$seq.=$_;
			}
		}
	close IN;
	print " done.\n"
	}
check_tag();
close NOTAG;
foreach$tag(@tags)
	{
	open(OUT,">>outfile_$tag.fas");
	print OUT $tags{$tag};
	$tags{$tag}="";
	close OUT;
	}
foreach(keys(%count_tags))
	{
	print"found $_: $count_tags{$_}\n";
	}
print"no TAG found: $noTAG\n\n";
exit;