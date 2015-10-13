package Local::Phylogeny::TreeIO::newick;


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
#Created: Wed May 30 09:36:37 EDT 2012
######################################################################

=head1 NAME

Local::Phylogeny::TreeIO::newick - a module to parse newick format
trees

=head1 SYNOPSIS

use Local::Phylogeny::TreeIO;
my $io = Local::Phylogeny::TreeIO->new(-file   => 'test.newick',
                                       -format => 'newick');
my $tree = $io->next_tree;

=head1 DESCRIPTION

This module is to parse and write Newick format trees

=head1 Author - Zhenguo Zhang

Email: zuz17@psu.edu, fortunezzg@gmail.com

=cut

use strict;
use Local::Phylogeny::Tree;
use Local::Phylogeny::Node;
use base qw/Local::Phylogeny::TreeIO/;

my $NODE_PACKAGE = 'Local::Phylogeny::Node';
my $DEFAULT_TYPE_AT_P = 'id'; # the default type of data following
# the right parenthesis in newick string, bootstrap is also possible

=head2 new


 Title   : new
 Usage   : my $io = Local::Phylogeny::TreeIO->new();
 Function: create the treeIO object from newick format trees
 Returns : Local::Phylogeny::TreeIO::newick object
 Args    : 
    -type: optional. give the data type following the closing
	parenthesis in the newick format string. Default is I<id>. Other
	options include I<bootstrap>

=cut

# in fact, the new method is called from parent package
# Local::Phylogeny::TreeIO, after that, the _initialize method is
# called within this module
sub _initialize
{
	my ($self,@args) = @_;
	$self->SUPER::_initialize(@args); # call the method in parent package

	my ($type) = $self->_rearrange([qw/TYPE/], @args);
	# default is $DEFAULT_TYPE_AT_P = 'id'
	$self->data_type_at_p($type || $DEFAULT_TYPE_AT_P);
	# do nothing at this moment
	return 1;
}

=head2 data_type_at_p

 Title   : data_type_at_p
 Usage   : my $type = $self->data_type_at_p();
 Function: get/set the data type following the closing parenthesis in
          the newick string
 Returns : the type
 Args    : optional, new type

=cut

sub data_type_at_p
{
	my $self = shift;

	$self->{'_data_type_at_p'} = shift if(@_);

	return $self->{'_data_type_at_p'};
}

=head2 next_tree

 Title   : next_tree
 Usage   : my $tree = $io->next_tree;
 Function: return the tree object
 Returns : Local::Phylogeny::Tree
 Args    : None

=cut

sub next_tree
{
	my $self = shift;
	local $/ = ";\n"; # newick format trees end with ';'
	return unless $_ = $self->_readline;
	s/[\r\n]+//gs; # remove all the line breaks

	# start parse the parenthesis structure and get the tree
	my ($startNode,$rooted) = $self->_parse_nodes($_);

	my $tree = Local::Phylogeny::Tree->new(-start_node => $startNode,
	-rooted => $rooted);
	
	return $tree;
}

# parse nodes from the newick string
sub _parse_nodes
{
	my $self = shift;
	my $nwkStr = shift;

	my @nodeStack; # store all the nodes created
	my $chrs = "";
	my $currNode;

	while($nwkStr)
	{
		if($nwkStr =~ s/^\(//) # a new internal node
		{
			# create a node and store it
			my $node = $NODE_PACKAGE->new();
			push @nodeStack, $node;
		}elsif($nwkStr =~ s/^\)([^\(\),;]*)[,;]?//) # internal node ends
		{
			$currNode = pop @nodeStack;
			my $nodeInfo = $self->_parse_node_info($1); # return a hash ref
			$currNode->add_node_info(%$nodeInfo);
			# note, no parent node if this is the first node
			my $parentNode = $nodeStack[$#nodeStack] || undef;
			if($parentNode)
			{
				$parentNode->add_child($currNode);
			}
		}else # leaves, collecting data
		{
			$nwkStr =~ s/^([^\(\)]+)//;
			my @leaves = split(',',$1);
			my $parentNode = $nodeStack[$#nodeStack];
			foreach my $leafString (@leaves)
			{
				my $nodeInfo = $self->_parse_node_info($leafString);
				my $leafNode = $NODE_PACKAGE->new(%$nodeInfo);
				$parentNode->add_child($leafNode);
			}
		}
	}

	# guess it's a root or unrooted tree
	my $rooted = 0;
	my $childNum = $currNode->child_num;
	$rooted = 1 if($childNum == 2); # assuming two children represent a
	# rooted tree
	return ($currNode,$rooted); # first node
}

# parse the node information into hash from the newick string
sub _parse_node_info
{
	my $self = shift;
	my $infoStr = shift;

	# note, it is possible bootstrap at the id location
	my ($id, $bLen) = $self->_remove_end_blank(split(':', $infoStr));

	my %hash;

	# store all the id into lowercase
	$hash{$self->data_type_at_p} = lc($id) if(defined $id);
	$hash{'branch_length'} = $bLen if(defined $bLen);

	return \%hash;
}

=head2 write_tree

 Title   : write_tree
 Usage   : not implemented yet
 Function:
 Returns :
 Args    :

=cut

sub write_tree
{
	my $self = shift;

	$self->throw("'write_tree' method have not been implemented yet");
}

1;

