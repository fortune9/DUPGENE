package Local::Phylogeny::Factory::InferGeneDynamic;


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
#Created: Mon Jun  4 09:53:00 EDT 2012
######################################################################

=head1 NAME

Local::Phylogeny::Factory::InferGeneDynamic - a package to infer the
number of paralogs in internal nodes of a species tree based on the number of gene
copies in extant species base on Maximum Parsimony

=head1 DESCRIPTION

In phylogeny analysis, it often needs analyze the gene duplications
and losses ocurring in a gene family. To do this, the tree constructed
for a gene family (gene tree) and the species tree can be reconciled
to infer the gene duplication/loss events.  However, this method relies
on the reliable gene tree topology. When this is not true, we can
directly infer the number of paralogs in internal nodes and
duplications/losses on each branch of species tree solely based on
gene copies in extant species.

The goal of this package is to infer the number of paralogs in all
internal nodes of a speceis tree and minimize the gene duplication
and loss events occurring in the whole species tree. To do this 
efficiently, we implemented the algorithm in L<Durand et
al,2006|/Reference>. Briefly, the dynamic programing algorithm is used
to determine the total number of gene duplication/loss events (dubbed
cost) at an internal node given the gene copies inherited from the
parent node and the costs from the child nodes. See the
L<paper|/Reference> for details.

=head1 Aurhor - Zhenguo Zhang

Email: zuz17@psu.edu, fortunezzg@gmail.com

=head1 Reference

B<A Hybrid Micro-Macroevolutionary Approach to Gene Tree Reconstruction>.
D. Durand, B. V. Halldorsson, B. Vernot, 2005. Journal of	Computational Biology, 13 (2): 320-335. 

=cut

use strict;
use Local::Phylogeny::Node::Ascended;
use Local::Phylogeny::Tree::Ascended;
use base qw/Local::Phylogeny::Factory/;

my $NODE_PACKAGE = 'Local::Phylogeny::Node::Ascended';
my $TREE_PACKAGE = 'Local::Phylogeny::Tree::Ascended';
my $package = __PACKAGE__;
my $TRUE = 1;
my $FALSE = 0;
my $defaultDupCoefficient = 1;
my $defaultLossCoefficient = 1;
my $HugeCost = 1e10; # the constant cost if parent is 0 copy and the
# child has at least one copy

# Note: this factory object can be applied many times after
# constructtion
sub new
{
	my ($caller,@args) = @_;

	# initialize this object by parent package
	my $self = $caller->SUPER::new(@args);
	# initialize this object firstly
	my $ok = _initialize($self,@args);
	$self->warn("Initialization failed in $package")
	and return undef unless($ok);

	return $self;
}

sub _initialize
{
	my $self = shift;
	my @args  = @_;
	
	my ($dupCost,$lossCost) =
	$self->_rearrange([qw/dup loss/],@args);
	$dupCost = defined($dupCost)? $dupCost : $defaultDupCoefficient;
	$lossCost = defined($lossCost)? $lossCost : $defaultLossCoefficient;
	$self->dup_cost_coefficient($dupCost);
	$self->loss_cost_coefficient($lossCost);

	# get the cost table based on dynamic programming
#	$self->ascend($self->species_tree->root) or 
#	$self->warn("Calculate the cost table failed in $package");

	return $self;
}

=head2 ascend

 Title   : ascend
 Usage   : my $ascendedTree = $self->ascend();
 Function: infer the number of paralogs in internal nodes of a species
 tree by minimizing the total number of duplications and losses
 Returns : A Local::Phylogeny::Tree::Ascended object
 Args    : A Local::Phylogeny::Tree object and a hash containing the
 number of paralogs in extant species in which the keys should match
 the species names in the provided tree

=cut

# this is a dynamic programming algorithm to get the mininum number of
# total gain and loss in a tree
sub ascend
{
	my ($self, $spTree, $paraNumHashRef) = @_;
	while(my ($key, $val) = each %$paraNumHashRef)
	{
		$key =~ s/^\s+//;
		$key =~ s/\s+$//;
		$paraNumHashRef->{lc($key)} = $val;
	}

	$self->warn("A rooted tree is needed for inferring gene
		cuplication/loss on it") and return undef unless($spTree->is_rooted);
	# 1. clone the original tree
	my $ascendedTree  = $TREE_PACKAGE->new($spTree);
	# 2. assign num of paralogs for extant speceis nodes
	my $maxParaNum = -100; # maximum number of pralogous copies in extant
	# species
	foreach my $n ($ascendedTree->get_all_nodes)
	{
		next unless($n->is_leaf);
		my $num = $paraNumHashRef->{lc($n->id)};
		$self->throw("The number of paralogs for node",$n->id,"is not
			found") unless(defined $num);
		$n->set_tag("num_paralogs", $num);
		$maxParaNum = $num if $maxParaNum < $num;
	}
	$ascendedTree->max_num_paralogs($maxParaNum);

	# now start real inference
	$self->_ascend($ascendedTree->root,$ascendedTree);
	
	return $ascendedTree; # this tree has been traversed for each node
}

sub _ascend
{
	my ($self, $node, $ascendedTree) = @_;

	my $dupCost = $self->dup_cost_coefficient;
	my $lossCost = $self->loss_cost_coefficient;
	my $copy = $node->num_paralogs || 0;
	my $jMax = $ascendedTree->max_num_paralogs;

	my $iMax;
	if($node eq $ascendedTree->root) # this is the root node
	{
		$iMax = 1;
#		$jMax = $node->j_boundary;
	}else
	{
		#	my ($parent) = $node->get_parent;
		$iMax = $ascendedTree->max_num_paralogs;
#		$jMax = $iMax - $copy;
	}

#	my $maxCopy = $self->get_max_copy; # the maximum paralogous copy
	# in all species. Now the internal nodes are included
#	my $speciesTree = $self->get_species_tree();

	# this is a leaf node
	if($node->is_leaf())
	{
		for(my $i = 1; $i <= $iMax; $i++)
		{
			my $cost = $dupCost * max($i - $copy,0) +
			           $lossCost * max($copy - $i,0);
			# store the following information:
			# the number of paralogs in parent, the number of paralogs
			# in this node and the associated cost
			$node->record_minimum_cost($i,[$copy],$cost);
		}
		# now allowing the parent node has copy 0, but this is
		# inhibited when there are copies for any child.
		if($copy == 0) # no copy for this child
		{
			$node->record_minimum_cost(0,[$copy],0);
		}else # give a very huge number to suppress this when there is
		# > 0 copy
		{
			$node->record_minimum_cost(0,[$copy],$HugeCost);
		}
		$node->_ascended(1);
		return 1;
	}

	# otherwise internal node, get the cost from its children firstly
	my @children = $node->children();
	my %costFromChild; # record the minimum cost given the copy number
	# for current node
	# record the j_boundary for the current node
	$node->j_boundary($jMax);
	foreach my $child (@children) # update cost table for each child
	{
		$self->_ascend($child, $ascendedTree);
		for(my $j = 0; $j <= $jMax; $j++) # j can start from 0 
		{
			$costFromChild{$j} += $child->get_minimum_cost($j)->[0];
		}
	}

	# get the minimum cost for current node given each $i
	# now allowing the parent and child out to be 0
	for(my $i = 0; $i <= $iMax; $i++)
	{
		my $minCostForI;
		my %minCostJ;
		for(my $j = 0; $j <= $jMax; $j++)
		{
			my $childCost = $costFromChild{$j};
			my $cost = $dupCost*max($copy + $j - $i,0) +
			           $lossCost*max($i - $j - $copy,0)+
					   $childCost;
			if($i ==0 and $j + $copy >0) # this is not allowed, assuming
				# at least one copy in ancestor if there are copies
				# for current node
			{
				$cost = $HugeCost;
			}
			# update the cost information for given $i
			if(!defined($minCostForI))
			{
				$minCostForI = $cost;
				$minCostJ{$j}++;
			}elsif($minCostForI > $cost) # current is better 
			{
				$minCostForI = $cost;
				%minCostJ = ();
				$minCostJ{$j}++;
			}elsif($minCostForI == $cost) # more than one j gives the
			# same cost
			{
				$minCostJ{$j}++;
			}else
			{
			}
		}
		# update the cost table for this node and this 'i'
		$node->record_minimum_cost($i,[keys(%minCostJ)],$minCostForI);
	}

	$node->_ascended(1);
	return 1;
}

sub max
{
	my $max;

	foreach my $el (@_)
	{
		$max = $el unless(defined($max));
		$max = $el if($max < $el); # update
	}

	return $max;
}

sub dup_cost_coefficient
{
	my $self = shift;
	$self->{'_dup_coefficient'} = shift if(@_);
	return $self->{'_dup_coefficient'};
}

sub loss_cost_coefficient
{
	my $self = shift;
	$self->{'_loss_coefficient'} = shift if(@_);
	return $self->{'_loss_coefficient'};
}

1;

