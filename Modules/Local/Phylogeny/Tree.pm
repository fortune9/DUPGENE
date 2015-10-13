package Local::Phylogeny::Tree;

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
#Contact: fortunezzg\@gmail.com
#Created: Wed May 30 17:40:04 EDT 2012
######################################################################

use strict;
use vars qw/$TREEUNIQUEID/;
use Local::Phylogeny::Node;
use base qw/Local::Phylogeny/;

BEGIN{
	$TREEUNIQUEID = 0;
}

my $NODE_PACKAGE = "Local::Phylogeny::Node";
my $package = __PACKAGE__;
my %tags = (bootstrap => 1, branch_len => 1);

# the known tags for edge
sub known_tags
{
	my $self = shift;
	if(@_)
	{
		my $tag = shift;
		return 1 if($tags{$tag});
	}

	return keys(%tags);
}

=head2 new

 Title   : new
 Usage   : my $tree = Local::Phylogeny::Tree->new();
 Function: construct a tree using connected nodes
 Returns : Local::Phylogeny::Tree object
 Args    : 
  -start_node:  the start node for establishing the tree, if this is a
  rooted tree, this node is the root
  -rooted:   the boolean value whether this tree is rooted or not,
  default is unrooted
  -root: the root node. If provided, -start_node is ignored

=cut

sub new
{
	my ($caller,@args) = @_;

	my $self = $caller->SUPER::new(@args);

	my $ok = _initialize($self,@args);

	$self->warn("Initialize failed in package $package") and return
	undef unless($ok);

	return $self;
}

sub _initialize
{
	my $self = shift;
	my @args = @_;

	# represent a tree using node set and edge set, separately
	my ($startNode,$rooted, $rootNode) = 
	$self->_rearrange([qw/START_NODE ROOTED ROOT/],@args);
	$startNode ||= $rootNode if(defined $rootNode);
	$self->warn("Parameter '-start_node' or '-root' is necessary to construct a
		tree in $package") 
	and return undef unless(defined($startNode) and
	$startNode->isa($NODE_PACKAGE));
	
	# record important information
	$self->{'_start_node'} = $startNode;
	$self->{'_rooted'} = $rooted || 0;
#	$self->{'_root_node'} = $rootNode;
	$self->{'_internal_id'} = ++$TREEUNIQUEID;

	return 1;
}

=head2 internal_id

 Title   : internal_id
 Usage   : my $id = $self->internal_id;
 Function: get the unique internal id of the tree
 Returns : internal_id
 Args    : None
 Note    : each tree is associated with a unique internal id
=cut

sub internal_id
{
	shift->{'_internal_id'};
}

=head2 start_node

 Title   : start_node
 Usage   : my $node = $self->start_node
 Function: gets the stating node for this tree
 Returns : a node
 Args    : None

=cut

sub start_node
{
	my $self = shift;
#	$self->{'_start'} = shift if(@_);
	return $self->{'_start_node'} || $self->root;
}

=head2 get_root_node

 Title   : get_root_node
 Usage   : my $rootNode = $self->get_root_node;
 Function: an alias of L</root> method
 Returns : The root node if available
 Args    : None

=cut

sub get_root_node
{
	shift->root(@_);
}

=head2 root

 Title   : root
 Usage   : my $root = $self->root;
 Function: gets the root node of the tree
 Returns : the root node or undef
 Args    : None
 
=cut

sub root
{
	my $self = shift;
	$self->warn("This $self is not a rooted tree, so no root node")
		and return undef unless($self->is_rooted);

	return $self->start_node;
}

=head2 clone

 Title   : clone
 Usage   : my $newTree = $self->clone;
 Function: get a new copy of the tree
 Returns : a Local::Phylogeny::Tree object
 Args    : The node from which the subtree will be cloned. Default is
the root node

 Note: all the information about the nodes will be cloned and tree
 information except root_node and start_node will be cloned too

=cut

sub clone
{
	my $self = shift;
	# clone the nodes and tree structure
	
	my $newStartNode = $self->_clone(@_);

	my $tree = $self->new(-start_node => $newStartNode);

	# add other information
	my %excluded;
	@excluded{qw/_start_node _root_node _internal_id/} =  1..2;
	while(my ($key,$value) = each %$self)
	{
		next if $excluded{$key};
		$tree->{"$key"} = $value;
	}
	return $tree;
}

sub _clone
{
	my ($self,$parent,$parent_cloned) = @_;
	$parent ||= $self->get_root_node;
	$parent_cloned ||= $parent->clone;

	my @children = $parent->children; # the kids from the original
	# tree

	# clone each kid and connect to the cloned parent
	foreach my $c (@children)
	{
		my $clonedChild = $c->clone; # get a node clone
		$parent_cloned->add_child($clonedChild);
		$self->_clone($c,$clonedChild); # clone the subtree
		# starting at $c too
	}

	return $parent_cloned;
}

=head2 sub_tree

 Title   : sub_tree
 Usage   : my $new_tree = $self->sub_tree();
 Function: get the new tree starting at the given node downwards the
          original tree
 Returns : a Local::Phylogeny::Tree object
 Args    : an Local::Phylogeny::node

=cut

sub sub_tree
{
	my ($self,$node) = @_;

	$self->warn("A node is necessary to get the sub tree") and return
	undef unless(ref($node) and $node->isa("$NODE_PACKAGE"));

	my $subTree = $self->clone($node);
	# remove the parent of the start/root node
	$subTree->start_node->reset_parent(undef);
	$subTree->id(($subTree->id || "")." subtree");

	return $subTree;
}

=head2 id

 Title   : id
 Usage   : my $id = $self->id();
 Function: get/set the tree id
 Returns : the tree id
 Args    : optional, the new id
 Note    : the id may not be unique for each tree

=cut

sub id
{
	my $self = shift;
	$self->{'_id'} = shift if(@_);
	return $self->{'_id'} || 'Unknown';
}

=head2 is_rooted

 Title   : is_rooted
 Usage   : my $aRootTree = $self->is_rooted
 Function: test whether this tree is rooted or not
 Returns : Boolean value
 Args    : None
 Note    : the test does not depend on the root node, but other
information, because the root node in this package is just a node to
start traversing this tree

=cut

sub is_rooted
{
	return shift->{'_rooted'};
}

=head2 is_supported_tag

 Title   : is_supported_tag
 Usage   : my $support = $self->is_supported_tag();
 Function: test whether the specified tag is supported by the tree
 Returns : Boolean value
 Args    : tag-name

=cut

sub is_supported_tag
{
	# at this moment, everything is fine
	return 1;
}

=head2 get_all_nodes

 Title   : get_all_nodes
 Usage   : my @nodes = $self->get_all_nodes;
 Function: gets all the nodes in this tree or a subtree if a node is
           given
 Returns : an array of nodes
 Args    : Optional, a node from which its all descendents will be
           returned. Default is the start node

=cut

sub get_all_nodes
{
	my ($self,$node) = @_;
	$node ||= $self->start_node or ($self->warn("A node is needed
			for geting all the nodes in a tree") and return ());

	my @nodes = _get_all_descendents($node);

	return @nodes;
}

# note the return also include the input node
sub _get_all_descendents
{
	my $node = shift;

	my @children = $node->children;

	return $node unless(@children); # no child

	# otherwise get the descendents of the current children
	my @descendents;
	foreach my $c (@children)
	{
		push @descendents, _get_all_descendents($c);
	}

	return ($node, @descendents);
}

# determine the root of tree based on some criteria
sub reroot_tree
{
	my $self = shift;
	my $method = shift;

	if($method =~ /^mid/i) # mid-point rooting
	{
		my $rootedTree = _midpoint_rooting($self);
		return $rootedTree;
	}else
	{
		$self->warn("Rooting method $method has not been implemented");
		return undef;
	}
}

sub _midpoint_rooting
{
	my $self = shift;
	my @leafIndices = $self->leaf_index;

	# choose the longest distance for each leaf from other leaves
	my $longestDist; # longest distance for a leaf
	my $longestPath; # the associated path
	foreach my $leafIndex (@leafIndices)
	{
		my $distance = _longest_distance_to_leaf($self,$leafIndex);
		($longestDist,$longestPath) = @$distance unless($longestPath);
		if($longestDist < $distance->[0])
		{
			($longestDist,$longestPath) = @$distance;
		}
	}
	# manipulate the longest path now
	my $halfDist = $longestDist/2;
	my $accuDist = 0;
	my @midPoint; # this store the two nodes near the mid-point and
	# the distance to each node
	for(my $i = 0; $i < $#$longestPath; $i++)
	{
		my $bLen =
		$self->edge_property($longestPath->[$i],$longestPath->[$i+1],"branch_len");
		my $bootstrap =
		$self->edge_property($longestPath->[$i],$longestPath->[$i+1],"bootstrap");
		if($accuDist + $bLen >= $halfDist) # middle point is here
		{
			@midPoint = ($longestPath->[$i],$longestPath->[$i+1], $halfDist - $accuDist, $accuDist +
			$bLen - $halfDist);
			push @midPoint,$bootstrap if(defined $bootstrap);
			last; #Found it
		}
		$accuDist += $bLen;
	}
	
	# clone a new tree and assign the direction for each edge in the tree

	my $rootedTree = _copy_tree($self);
	$rootedTree->remove_edge(@midPoint[0,1]);
	my $rootNode = $NODE_PACKAGE->new(-id => 'midpoint_root');
	$rootedTree->add_node($rootNode);
	$rootedTree->add_edge($midPoint[0],$rootNode,0,{branch_len =>
	$midPoint[2]});
	$rootedTree->add_edge($midPoint[1],$rootNode,0,{branch_len =>
	$midPoint[3]});
	# add bootstrap value if availbale
	if($midPoint[4])
	{
		$rootedTree->edge_property($midPoint[0],$rootNode,'bootstrap',$midPoint[4]);
		$rootedTree->edge_property($midPoint[1],$rootNode,'bootstrap',$midPoint[4]);
	}
	$rootedTree->root($rootNode);
	$rootedTree->start_node($rootNode); # do not forget this for
	# newick output
	$rootedTree->assign_direction(); # assign direction for each edge based
	# on the root node

	return $rootedTree;
}

sub _longest_distance_to_leaf
{
	my $tree = shift;
	my $sourceIndex = shift;

	# using breadth-first algorithm to calculate the distance
	my %distance;
	my %visited;
	my %predecessor; # record the predecesor for each node

	my @queue = ($sourceIndex);
	$distance{$sourceIndex}->{$sourceIndex} = 0;
	while(@queue)
	{
		my $currNode = shift(@queue);
		my $neighborsRef = $tree->neighbors($currNode);
		$visited{$currNode}++; # all the neighbors have been checked
		foreach my $n (@$neighborsRef)
		{
			my $id = $n->internal_id;
			next if $visited{$id};
			my $edgeDist =
			$tree->edge_property($currNode,$id,"branch_len");
			$distance{$sourceIndex}->{$id} =
			$distance{$sourceIndex}->{$currNode} + $edgeDist;
			$predecessor{$id} = $currNode;
			push @queue, $id;
		}
	}

	# choose the leaf which gives the longest distance
	my @leafIndices = $tree->leaf_index;
	my @longestDist;
	foreach my $leafIndex (@leafIndices)
	{
		next if $leafIndex == $sourceIndex;
		my $dist = $distance{$sourceIndex}->{$leafIndex};
		@longestDist = ($dist,$leafIndex) unless(@longestDist);
		if($dist > $longestDist[0]) # longer one found
		{
			@longestDist = ($dist,$leafIndex);
		}
	}

	# calculate the path for this leaf
	my $path = _get_path(\%predecessor,$longestDist[1]);
	return [$longestDist[0],$path];
}

sub _get_path
{
	my $predecessorRef = shift;
	my $node = shift;

	unless(exists $predecessorRef->{$node}) # no precursor
	{
		return [$node];
	}

	# get the precursor path first
	my $prePath = _get_path($predecessorRef,$predecessorRef->{$node});
	return [@$prePath,$node];
}


# get condensed tree based on the bootstrap value or others
sub condense_tree
{
}

=head2 get_node_by_id

 Title   : get_node_by_id
 Usage   : my @nodes = $self->get_node_by_id();
 Function: gets the nodes matching the given id
 Returns : an array of nodes with the specified id
 Args    : an id

=cut

sub get_node_by_id
{
	my ($self,$id) = @_;
	$self->find_node("id",lc($id));
}

=head2 find_node

 Title   : find_node
 Usage   : my @nodes = $self->find_node();
 Function: gets the nodes matching the value of given type
 Returns : an array of nodes
 Args    : (type, value). If only one argument is given, it is assumed
 to be the I<value> and I<type> is B<id>
 Note    : at present, the I<type> is searched against tags only

=cut

sub find_node
{
	my ($self,$type,$value) = @_;

	$self->warn("None was provided to ", (caller())[3]) and return ()
	unless(defined $type);

	unless(defined $value)
	{
		$value = $type;
		$type  = "id";
	}

	$type = $self->_preprocess_tag($type);

	my @nodes = grep { $_->match_tag($type,$value)  } $self->get_all_nodes;

	return @nodes;
}

sub get_node_by_internal_id
{
	my $self = shift;
	
	my @nodes;

	my $nodeSetRef = $self->{'_node'}; # this is array reference to
	# store all the nodes

	foreach my $id (@_)
	{
		$self->warn("Unknown internal id $id") and next
		unless(exists($nodeSetRef->[$id]));
		my $node = $nodeSetRef->[$id];
		push @nodes,$node;
	}

	return undef unless(@nodes);
	return \@nodes;
}


# get all the nodes for this tree
sub all_nodes
{
	my $self = shift;
	return $self->{'_node'};
}

# get only leaf nodes
sub leaf_nodes
{
	my $self = shift;
	my @leafIndices = $self->leaf_index;
	$self->get_node_by_internal_id(@leafIndices);
}


1;

