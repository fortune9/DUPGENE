package Local::Phylogeny::Tree::Ascended;

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
#Created: Mon Jun  4 12:24:25 EDT 2012
######################################################################

use strict;
use Local::Phylogeny::Tree;
use Local::Phylogeny::Node::Ascended;
use base qw/Local::Phylogeny::Tree/;

=head1 NAME

Local::Phylogeny::Tree::Ascended - A package to store the data and
methods for a tree with inferred gene duplications/losses in each node

=head1 DESCRIPTION

This package has not been well documented. I will do it when I have
time.

=head1 AUTHOR - Zhenguo Zhang

Email: zuz17@psu.edu

=cut

=head1 new

 Title   : new
 Usage   : my $ascendedTree = Local::Phylogeny::Tree::Ascended->new();
 Function: get an tree object of Local::Phylogeny::Tree::Ascended
 Returns : an object of Local::Phylogeny::Tree::Ascended
 Args    : a tree of Local::Phylogeny::Tree or parameters for creating
 a new object of Local::Phylogeny::Tree

=cut

sub new
{
	my ($caller, @args) = @_;
	my $self;

	if($#args == 0 and $args[0]->isa("Local::Phylogeny::Tree")) # only one parameter, probably a tree object
	{
		$self = $args[0]->clone; # get a clone first
		bless $self, ref($caller) || $caller;
	}else # more parameters for creating a tree object
	{
		# create a new tree
		$self = $caller->SUPER::new(@args);
	}

	# change every node to Ascended type, too
	for ($self->get_all_nodes)
	{
		bless $_, 'Local::Phylogeny::Node::Ascended';
	}

	return $self;
}


=head2 descend

 Title   : descend
 Usage   : my $ok = $self->descend();
 Function: gets the next tree state (including number of paralogs,
 gene duplications/losses on each branch) which gives the minimum cost
 (total number of duplications/losses inferred on the tree)
 Returns : True if the next state is available, otherwise false
 Args    : A boolean value to tell the program whether to start over
 from the first valid state of the tree. Default false

=cut

sub descend
{
	my $self = shift;
	my $reset = shift;

	my $root = $self->root;

	# set the loss and duplication value for each species node
	# Note: the copy in the most ancester is 1.
	my $success =
	$root->_descend($reset,1); # return false
	# when all the possible trees are returned, unless reset is true

	return $success;
}

sub max_num_paralogs
{
	my $self = shift;
	$self->{'_max_num_paralogs'} = shift if(@_);
	return $self->{'_max_num_paralogs'};
}

1;

