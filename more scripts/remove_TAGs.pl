#!/usr/bin/env perl

############     remove_TAGs.pl     ############
#
#	This Perl script reads sequence files in FASTA format and
#	removes TAG sequences. Optionally, everything preceeding or
#	following the TAG sequence can also be removed.
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
#	TAGs have to be passed to the script via -t:
#	-t ATGCTAGA -t TTAGCGTT
#
#	A bare digit from 1-5 (1 or 2 or 3 or 4 or 5) will tell the script,
#	what exactly has to be removed from the sequence that contains
#	a TAG. By default it is set to 2.
#	-1 = only the TAG.
#	-2 = the TAG and everything before.
#	-3 = the TAG and everything after.
#	-4 = everything preceeding the TAG (but not the TAG itself)
#	-5 = everything following the TAG (but not the TAG itself)
#
#	For example you can type the following command:
#	perl remove_TAGs.pl -i file1.fas -t ATGCTAGA -1
#
#	The resulting output files can be identified by the TAG. In this
#	case:
#	outfile_ATGCTAGA.fas
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
#	perl remove_TAGs.pl -i file1.fas -I list_of_files.txt -t ATGCTAGA -T list_of_TAGs.txt -1
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
$how_to_cut=2;
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
	elsif($_=~/^ *[12345] *$/)
		{
		$_=~s/ *//g;
		$_=~s/ //g;
		$how_to_cut=$_;
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

print"\nThe following TAGs will be removed:\n";
foreach(@tags)
	{
	print"$_\n";
	}
print"\nMode of removal: ";
if($how_to_cut==1)
	{
	print"Only the TAG.\n\n";
	}
elsif($how_to_cut==2)
	{
	print"The TAG and everything before.\n\n";
	}
elsif($how_to_cut==3)
	{
	print"The TAG and everything after.\n\n";
	}
elsif($how_to_cut==4)
	{
	print"Everything preceeding the TAG (but not the TAG itself).\n\n";
	}
elsif($how_to_cut==5)
	{
	print"Everything following the TAG (but not the TAG itself).\n\n";
	}

###   START   ###
$noTAG=0;
%tags=();
%count_tags=();
%count_tags_for_print=();
open(NOTAG,">outfile_NO_TAG.fas");
foreach$file(@input_files_ok)
	{
	print"processing $file\n";
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
						
						if($how_to_cut==1)
							{search_TAG1();}
						elsif($how_to_cut==2)
							{search_TAG2();}
						elsif($how_to_cut==3)
							{search_TAG3();}
						elsif($how_to_cut==4)
							{search_TAG4();}
						elsif($how_to_cut==5)
							{search_TAG5();}
						
						sub search_TAG1
							{
							if($seq=~s/$tag//i)
								{
								$tag_found=1;
								if($seq=~/[ATGCUN]/)
									{
									$tags{$tag}.="$title$seq\n";
									}
								$count_tags{$tag}++;
								$count_tags_for_print{$tag}++;
								check_for_print();
								}
							}
						sub search_TAG2
							{
							if($seq=~s/^.*?$tag//i)
								{
								$tag_found=1;
								if($seq=~/[ATGCUN]/)
									{
									$tags{$tag}.="$title$seq\n";
									}
								$count_tags{$tag}++;
								$count_tags_for_print{$tag}++;
								check_for_print();
								}
							}
						sub search_TAG3
							{
							if($seq=~s/$tag.*?[\n]*?$//i)
								{
								$tag_found=1;
								if($seq=~/[ATGCUN]/)
									{
									$tags{$tag}.="$title$seq\n";
									}
								$count_tags{$tag}++;
								$count_tags_for_print{$tag}++;
								check_for_print();
								}
							}
						sub search_TAG4
							{
							if($seq=~s/^.*?$tag/$tag/i)
								{
								$tag_found=1;
								if($seq=~/[ATGCUN]/)
									{
									$tags{$tag}.="$title$seq\n";
									}
								$count_tags{$tag}++;
								$count_tags_for_print{$tag}++;
								check_for_print();
								}
							}
						sub search_TAG5
							{
							if($seq=~s/$tag.*?[\n]*?$/$tag/i)
								{
								$tag_found=1;
								if($seq=~/[ATGCUN]/)
									{
									$tags{$tag}.="$title$seq\n";
									}
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
	print"removed $_: $count_tags{$_}\n";
	}
print"no TAG found: $noTAG\n\n";
exit;
