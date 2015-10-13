#!/usr/bin/perl -w
	eval 'exec perl -S $0 "$@"' if 0; # this line is called when this
	# script is run directly from a shell

######################################################################
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or (at
#your option) any later version.
#
#This program is distributed in the hope that it will be useful, but
#WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
#General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#Author:  Zhenguo Zhang
#Contact: fortunezzg@gmail.com
#Created: Mon Jun  4 21:29:14 EDT 2012
######################################################################

=head1 NAME

dupGene.pl - A program to infer gene duplications and losses based
solely on the number of paralogs in extant species. The program is
designed for running on a large-scale analysis.

=head1 DESCRIPTION

This program is to infer the number of paralogs in all internal nodes
and gene duplication/loss events along each branch in the species
tree using Maximum Parsimony method. 

Briefly, given a species tree and the number of paralogs in extant
species (leaf nodes in a species tree) in a gene family, one number is assigned to each
internal node to represent the inferred number of paralogs at that
node. After that, the number of duplications or losses on each branch can be
calculated by subtracting the number of paralogs in the child node
from the number in the parent node. Summing up all the duplications
and losses on all branches gives the total number of
duplications/losses (dubbed B<cost>) for this set of assigned number
of paralogs for internal nodes. Since there are more than one
possible values as candidates for the number of paralogs in each internal 
node and more combinations among different internal nodes, the 
I<Maximum Parsimony> method is trying to find the sets of inferred
number of paralogs in internal nodes
which give the minimal cost among all possible sets of values.

To efficiently find the set of values giving the minimal cost, we
implemented the dynamic progaming algorithm, which is introduced in 
the paper L<Durand et al, 2005|/Reference>.

=head1 COPYRIGHT

E<169> 2012 by Zhenguo Zhang L<http://www.personal.psu.edu/zuz17/> and the
Pennsylvania State University L<http://www.psu.edu/>.

=head1 LICENSE

GNU General Public License version 3 or later

=head1 AUTHOR 

 Zhenguo Zhang
 Institute of Molecular Evolutionary Genetics
 Department of Biology
 311 Mueller Laboratory
 The Pennsylvania State University
 University Park, PA 16802 USA
 Email: zuz17@psu.edu, fortunezzg@gmail.com

=head1 INSTALLATION

The program is written in Perl, so it can execute in any platform
(Linux/Unix, MacOS and Windows) where the Perl program is installed.
If you have not installed perl, download and install it from
L<http://www.perl.org/get.html>

After the Perl is installed, do the following to install dupGene

1. Download the latest version from Dr. Nei's website
L<https://homes.bio.psu.edu/people/faculty/nei/software.htm>

2. Uncompress the files into a local directory, say ./mybin
e.g., I<tar -xzf dupGene.tar.gz>
Now you should see dupGene.pl in ./mybin/

3. Run the program 
I<perl ./mybin/dupGene.pl> to see more options.

For more information, please see accompanying documents.

=head1 SYNOPSIS

perl dupGene.pl -s example.nwk -p example.in >example.out

run program without any arguments to see the usage information

=head1 INPUT

The input needs two files, one is the species tree in newick format
and the other is the number of paralogs for extant species (leaf nodes
in the species tree) for each gene family (or homologous group). 

In the newick tree file, each node, including internal node, should
have a unique id specified, because these ids are print out in output
to represent nodes where duplicaions/losses happened. Example:
 
 ((((hum, mou)Tn3, cow)Tn5,chi)Tn7,(zeb,(tet,med)Fn3)Fn5)An;

Ids are case insensitive.

The paralog-number file should be tab-delimited and
provide the species names in the first line followed by the paralogous
copies from the second line for each gene family. An example input
file as follows containing three gene families:
 
 hum     mou     cow     chi     zeb     tet     med
 4       4       4       4       4       4       4
 2       2       1       1       3       2       2
 1       1       1       1       1       1       1

See I<example.nwk> and I<example.in> for data format. 

=head1 OUTPUT

The output is print to the standard output (ussually screen) but you
can redirect it into a file by using '> myoutput'.

The output (tab-delimited) contains the inferred number of paralogs in
internal nodes and the duplications and losses along branches. Since
there may be more than one best equivalently parsimonious sets of
values for internal nodes in a gene family, we output each of the inference with five lines
, e.g., the following lines are shown the result for the 6th gene
family in the example.in

 # 6.1
 type    an      tn7     tn5     tn3     hum     mou     cow     chi   fn5     zeb     fn3     tet     med
 copy    1       2       2       2       2       2       2       3      1       3       1       1       0 
 dups    0       1       0       0       0       0       0       1      0       2       0       0       0
 loss    0       0       0       0       0       0       0       0      0       0       0       0       1

The B<1>st line starts with a '#' followed by a I<num1.num2> string.
I<num1> represents the order of the gene families in input
file. I<num2> gives the order of parsimonious results for this given
family. When there are more than one set of inferred number of paralogs
in internal nodes, the I<num2> increases, such as I<6.1, 6.2> in
example.out, both of which give the minimal total number of
duplications and losses.

The B<2>nd line specify the data type in the following lines and
species ids.

The B<3>rd to B<5>th lines give the number of paralogous copies
(I<copy> line), of duplications (I<dups> line) and of losses (I<loss>
line) occurred in each node. For duplications/losses, the numbers at a
given node represent the number of events taking place on the branch
from its parent node to itself.

=head1 Suggested Citation

Sayaka Miura*, Masafumi Nozawa*, Zhenguo Zhang, and Masatoshi Nei 
B<Patterns of Duplication of MicroRNA Genes Support the Hypothesis of
Genome Duplication in the Teleost Fish Lineage>, (I<submitted>)

=head1 Reference

B<A Hybrid Micro-Macroevolutionary Approach to Gene Tree
Reconstruction>.
D. Durand, B. V. Halldorsson, B. Vernot, 2005. Journal of Computational Biology, 13 (2): 320-335

=cut


use vars qw/$programPath/;
BEGIN{
	 use File::Basename;
	 $programPath = dirname($0);
}
use strict;
use lib "$programPath/Modules";
use Local::Phylogeny::Factory::InferGeneDynamic;
use Local::Phylogeny::TreeIO;
use Getopt::Long;

our $VERSION = 0.1;

my $spTreeFile;
my $paralogNumFile;

# guess the arguments
if($#ARGV < 3 and $ARGV[0] !~ /^-/) # the option names are not used
{
	($spTreeFile, $paralogNumFile) = @ARGV;
}else
{
	GetOptions(
	"species-tree=s"	=> \$spTreeFile,
	"paralog-num=s"	=> \$paralogNumFile
	);
}

&usage() unless($spTreeFile and $paralogNumFile);

my $startTime = time();

my $treeIO = Local::Phylogeny::TreeIO->new(-file => "$spTreeFile") or die
"can not open $spTreeFile for reading the species tree:$!";

my $spTree = $treeIO->next_tree;

my @spOrder = map { $_->id } $spTree->get_all_nodes;

my $ascendFactory =
Local::Phylogeny::Factory::InferGeneDynamic->new();

# parse the gene copy file
my @paralogNumHash  = _parse_paralog_num($paralogNumFile);
my $dataCounter = 0;
foreach my $paralogNumSet (@paralogNumHash)
{
	my $aTree = $ascendFactory->ascend($spTree, $paralogNumSet);
	# print "#" x 30,"\n","Fam: ", ++$dataCount,"->", $data->{'ConFam'},"\n", "#" x 30,"\n";
	my $treeCounter = 0;
	my $reset = 1;
	$dataCounter++;
	while($aTree->descend($reset))
	{
		++$treeCounter;
		#	print '*' x 30, "\nPossible $counter: gene copies, gains and losses\n";
		# print join("\t", qw/id internal curr_j loss gain/),"\n";
		print "# $dataCounter.$treeCounter\n";
		print join("\t", "type",@spOrder),"\n";
		my ($copyRef, $dupsRef, $lossRef) = _get_data($aTree);
		print join("\t", "copy", @$copyRef),"\n";
		print join("\t", "dups", @$dupsRef),"\n";
		print join("\t", "loss", @$lossRef),"\n";
		$reset = 0;
	}

	warn "# $dataCounter sets of input paralog numbers have been analyzed\n" 
	if($dataCounter % 50 == 0);
}

warn "# The whole work [$dataCounter sets of paralog numbers] is successfully finished\n";
my $stopTime = time();
my $elapsed = _format_time($stopTime - $startTime);

warn 'X' x 60, "\n";
warn "# The work started at ", scalar(localtime($startTime)),"\n";
warn "# The work stopped at ", scalar(localtime($stopTime)),"\n";
warn "# $elapsed time is used\n";
warn 'X' x 21, " Have a good day ", 'X' x 22,"\n";

exit 0;

sub usage
{
	print <<USAGE;
#####################################################################
#***                     dupGene.pl                             ***#
#####################################################################

Usage: $0 <--species-tree=file1> <--paralog-num=file2>

Options:

-s: --species-tree=file1, the file containing a species tree in
   newick format, and each extant and ancestral species has a unique
   id.

-p: --paralog-num=file2, the file containing the number of paralogs
   for extant species for each gene family. The first line provides 
   the species names which should match the ids in the species tree
   provided above. The paralogous copies start from the 2nd line.

See example.in and example_species_tree.nwk for example input.

Author:  Zhenguo Zhang
Contact: zuz17\@psu.edu
Created: Mon Jun  4 21:44:34 EDT 2012

USAGE

	exit 1;
}

sub _get_data
{
	my $tree = shift;
	my @copy;
	my @dups;
	my @loss;

	foreach my $sp (@spOrder)
	{
		my ($n) = $tree->get_node_by_id($sp);
		if($n and $n->isa('Local::Phylogeny::Node'))
		{
			push @copy, $n->curr_j;
			push @dups, $n->dups;
			push @loss, $n->loss;
		}else
		{
			push @copy, '-';
			push @dups, '-';
			push @loss, '-';
		}
	}

	return (\@copy,\@dups,\@loss);
}

sub _parse_paralog_num
{
	my $file = shift;

	my @copyPerTree; # an array with each element containing a set of
	# number of paralogs for extant species
	my @extantSpecies;
	open(IN, "< $file") or die "Can not open $file:$!";
	while(<IN>)
	{
		next if /^#/;
		next if /^\s*$/;
		chomp;
		@extantSpecies = split("\t", $_) and next unless (@extantSpecies);
		my %data;
		@data{@extantSpecies} = split "\t";
		push @copyPerTree, \%data;
	}
	close IN;

	return @copyPerTree;
}

sub _format_time
{
	my $seconds = shift;

	$seconds = int($seconds);

	return undef unless($seconds >= 0);

	# get minutes
	my $min = int($seconds/60);
	$seconds = $seconds % 60;

	# get hours
	my $hour = int($min/60);
	$min = $min % 60;

	# get days
	my $day = int($hour/24);
	$hour = $hour % 60;
	return ("${day}d ${hour}h ${min}m ${seconds}s");
}
