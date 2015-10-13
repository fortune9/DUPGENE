package Local::Phylogeny::Node;

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
#Created: Wed May 30 16:11:44 EDT 2012
######################################################################

use strict;
use vars qw/$UNIQNODEID/;
use base qw/Local::Phylogeny/;

# from now make sure the unique id is given for each created node
# through the whole life of the program running
BEGIN {
	$UNIQNODEID = 0;
}

my $package = __PACKAGE__;
my @tags = qw/id bootstrap branch_length /;
my %supportedTags;
@supportedTags{@tags} = 1..($#tags + 1);

=head2 new

 Title   : new
 Usage   : my $n = Local::Phylogeny::Node->new()
 Function: create a new node
 Returns : Local::Phylogeny::Node obj
 Args    : optional
 -parent:    the ancestral node
 -children:  the child nodes
 for other possible options, see L</add_node_info> method

=cut

sub new
{
	my ($caller,@args) = @_;

	my $self = $caller->SUPER::new(@args);

	my $ok = _initialize($self,@args);

	$self->warn("Initializing failed in package $package") and return undef
	unless($ok);

	$self->_set_internal_id(++$UNIQNODEID); # give an unique id for each
	# new node
	
	return $self;
}

sub _initialize
{
	my $self = shift;

	my %params = @_;
	@params{map { $_ =~ s/^\s*\-+//; $_ =~ s/\s+$//; $_} keys %params } = values %params;

	# parse out the relationships first
	my ($parent,$children) = $self->_rearrange([qw/PARENT
		CHILDREN/],%params);
	$self->add_child($children), delete $params{'children'} if(defined $children);
	$self->set_parent($parent), delete $params{'parent'} if(defined $parent);

	# add other information if applicable
	$self->add_node_info(%params);

	return $self;
}

=head2 add_node_info

 Title   : add_node_info
 Usage   : my $ok = $self->add_node_info();
 Function: add the information to the node
 Returns : 1 for ok, 0 for fail
 Args    : a hash
  supported fields:
  id:          the normal id for the node
  bootstrap:   the bootstrap value
  branch_length: the length of branch linking this node to its parent

  for adding children/parent nodes, use add_child/set_parent, please

=cut

sub add_node_info
{
	my ($self, @args) = @_;

	my %params = @args;
	
	while(my ($attr, $value) = each %params)
	{
		$attr = $self->_preprocess_tag($attr);
		next if($attr eq 'parent' or
			    $attr eq 'children');

		$self->add_tag($attr, $value); # this will call subclass
		# method if applicable
	}

	return 1;
}

=head2 clone

 Title   : clone
 Usage   : my $clone = $self->clone;
 Function: clone a new copy of orginal node
 Returns : a Local::Phylogeny::Node object
 Args    : None
 Note that the parent/child relationship and internal_id of this node 
will not be cloned, others including tags, id, etc will be cloned

=cut

sub clone
{
	my $self = shift;

	my $newNode = $self->new();

	my %excluded;
	@excluded{qw/_parent _children _internal_id _tags/} =  1..3;

	while(my ($key,$value) = each %$self)
	{
		next if $excluded{$key};
		$newNode->{$key} = $value;
	}

	# clone tags now
	$newNode->{'_tags'} = _clone_tags($self) if($self->{'_tags'});

	return $newNode;
}


# clone the tags in this object
sub _clone_tags
{
	my $self = shift;
	my %tagHash;

	foreach my $tag (keys %{$self->{'_tags'}})
	{
		$tagHash{$tag} = [@{$self->{'_tags'}->{$tag}}];
	}

	return \%tagHash;
}

=head2 add_child

 Title   : add_child
 Usage   : my $ok = $pNode->add_child();
 Function: add the given node to the children pool
 Returns : 1 for ok, 0 for fail
 Args    : a Local::Phylogeny::Node or a ref to array of that
 Note when this method is called, the parent is also put into the pool
of parent nodes for current node

=cut

sub add_child
{
	my $self = shift;
	my $val  = shift;

	my @newChildPool;
	if(ref($val) eq 'ARRAY')
	{
		@newChildPool = @$val;
	}else
	{
		@newChildPool = $val;
	}

	# check the argument is a Local::Phylogeny::Node object
	$self->warn("The arguments for add_child are not
		Local::Phylogeny::Node objects")
	unless($newChildPool[0]->isa("Local::Phylogeny::Node"));
	#***
	# the following command may give the risk of adding the same node
	# for more than one time
	# to prevent add one node more than one times, check whether the
	# new child node is in the pool of children already
	# $self->{'_children'} = [@{$self->{'_children'} || []}, @newChildPool];
	$self->{'_children'} = [] unless(exists $self->{'_children'});
	foreach my $c (@newChildPool)
	{
		next if $self->has_child($c); # the child has been in the pool
		# of children
		push @{$self->{'_children'}}, $c;
		# add parent if not there, otherwise it may trigger infinite
		# recurse
		$c->reset_parent($self) unless($c->has_parent($self)); # each node can have at most one parent
	}
	return 1;
}

=head2 has_child

 Title   : has_child
 Usage   : my $true = $self->has_child();
 Function: test whether current node has this child
 Returns : Boolean value
 Args    : Another node to see if this is a child of current node
  
=cut

sub has_child
{
	my $self = shift;
	my $node = shift;

	return undef unless($node);

	foreach my $c ($self->children)
	{
		return 1 if $c eq $node;
	}

	return 0;
}


=head2 remove_child

 Title   : remove_child
 Usage   : my $ok = $self->remove_child();
 Function: remove the child node from current node
 Returns : Boolean value for sucess
 Args    : the child node to remove
  
=cut

sub remove_child
{
	my ($self,$node) = @_;
	$node->reset_parent(undef);
	my @newChildSet;
	my $removed = 0;
	foreach my $c ($self->children)
	{
		++$removed and next if($c eq $node); # compare reference address
		push @newChildSet, $c;
	}

	return 0 if $removed == 0; # none of the node is removed
	$self->add_child(\@newChildSet);
	return $removed;
}

=head2 get_children

 Title   : get_children
 Usage   : my @children = $self->get_children;
 Function: an alias of method L</children>
 Returns : array of Local::Phylogeny::Node objects
 Args    : None

=cut

sub get_children
{
	shift->children(@_);
}

=head2 children

 Title   : children
 Usage   : my @children = $node->children;
 Function: gets the array of child node objects
 Returns : array of Local::Phylogeny::Node objects
 Args    : None

=cut

sub children
{
	my $self = shift;
	return @{$self->{'_children'} || []};
}

=head2 child_num

 Title   : child_num
 Usage   : my $num = $node->child_num;
 Function: gets the number of children for this node
 Returns : count of children
 Args    : None

=cut

sub child_num
{
	my $self = shift;
	my @children = $self->children;
	return 0 unless(@children);
	return $#children  + 1;
}

=head2 set_parent

 Title   : set_parent
 Usage   : my $ok = $self->set_parent();
 Function: an alias of L</reset_parent> method
 Returns : 1 for ok, 0 for fail
 Args    : the parent node or undef
 Note: only one parent is allowed for each node, and this method also
 add this node to the parent as a child

=cut

sub set_parent
{
	my $self = shift;
	$self->reset_parent(@_);
}

=head2 reset_parent

 Title   : reset_parent
 Usage   : my $ok = $self->reset_parent();
 Function: reset the parent node for current node
 Returns : 1 for ok, 0 for fail
 Args    : the parent node or undef
 Note: only one parent is allowed for each node, and this method also
 add this node to the parent as a child

=cut

sub reset_parent
{
	my ($self,$node) = @_;
	if(!defined($node)) # undef for parent
	{
		$self->{'_parent'} = $node;
	}else
	{
		$self->warn("An Local::Phylogeny::Node object is needed for parent
		node") and return 0 unless($node->isa('Local::Phylogeny::Node'));
		$self->{'_parent'} = $node;
		$node->add_child($self) unless($node->has_child($self)); # can this trigger an infinite
		# recurse? give unless restriction to prevent it
	}

	return 1;
}

=head2 get_parent

 Title   : get_parent
 Usage   : my $ok = $self->get_parent();
 Function: get the parent node for current node
 Returns : an Local::Phylogeny::Node or undef
 Args    : None

=cut

sub get_parent
{
	my ($self) = @_;
	
	return $self->{'_parent'};
}

=head2 has_parent

 Title   : has_parent
 Usage   : my $true = $self->has_parent();
 Function: test whether this node has the given parent node
 Returns : Boolean value
 Args    : Another node

=cut

sub has_parent
{
	my ($self,$node) = @_;

	return undef unless($node);
	my $p = $self->get_parent;
	return 1 if($p and $p eq $node);
	return 0;
}

=head2 ancester

 Title   : ancester
 Usage   : $self->ancester;
 Function: alias for get_parent
 Returns : the parent node
 Args    : None

=cut

# alias for get_parent
sub ancester
{
	my $self = shift;
	$self->get_parent(@_);
}

=head2 neighbors

 Title   : neighbors
 Usage   : my @ns = $self->neighbors;
 Function: return the children and parent nodes of this node
 Returns : array of nodes
 Args    : None

=cut

sub neighbors
{
	my $self = shift;
	my @array = @{$self->{'_children'} || []};
	push @array, $self->get_parent if($self->get_parent);
	return @array;
}

=head2 is_leaf

 Title   : is_leaf
 Usage   : my $true = $self->is_leaf;
 Function: test whether this node is a leaf node
 Returns : boolean value
 Args    : None
When a node has not any child, we regard it as a leaf node

=cut

sub is_leaf
{
	my $self = shift;

	return $self->children? 0 : 1;
}

=head2 branch_length

 Title   : branch_length
 Usage   : my $blen = $self->branch_length;
 Function: get the associated branch length
 Returns : the branch length if available
 Args    : None

=cut

sub branch_length
{
	my $self = shift;
	return $self->{'_tags'}->{'branch_length'}; # it can be an undef
	# value
}

=head2 bootstrap

 Title   : bootstrap
 Usage   : my $boot = $self->bootstrap;
 Function: get the associated branch length
 Returns : the bootstrap value if available
 Args    : None

=cut

sub bootstrap
{
	my $self = shift;
	$self->{'_bootstrap'} = shift if(@_);
	if($self->is_leaf)
	{
		return 1; # 100%
	}
	return $self->{'_bootstrap'};
}

=for comment _set_internal_id
this is a hidden method internally used by the program only
Do not use this method unless you know what you are doing

=cut

sub _set_internal_id
{
	my $self = shift;
	$self->{'_internal_id'} = shift;
}

=head2 internal_id

 Title   : internal_id
 Usage   : my $internalId = $node->internal_id
 Function: return the internal_id associated with this node
 Returns : an integer
 Args    : None

=cut

sub internal_id
{
	my $self = shift;
	$self->{'_internal_id'};
}

=head2 reverse_edge

 Title   : reverse_edge
 Usage   : my $ok = $self->reverse_edge;
 Function: change the parent/child relationship of two nodes
 Returns : Boolean for success
 Args    : Another node

=cut

sub reverse_edge
{
	shift->throw((caller())[3]." has not been implemented yet in
		".caller());
}

=head2 clear_relationship

 Title   : clear_relationship
 Usage   : my $ok = $self->clear_relationship();
 Function: remove all the child and parent relations from this node
 Returns : Boolean value for success
 Args    : None

=cut

sub clear_relationship
{
	my $self = shift;

	$self->{'_children'} = [] if(exists $self->{'_children'});
	$self->{'_parent'}   = undef if(exists $self->{'_parent'});

	return 1;
}

=head2 is_supported_tag

 Title   : is_supported_tag
 Usage   : my $support = $self->is_supported_tag();
 Function: test whether the specified tag is supported by the node
 Returns : 1 if supported, otherwise 0
 Args    : tag name

=cut

#*** this method should be defined in all the subclasses to override
#the tags specified here
sub is_supported_tag
{
	my ($self,$tag) = @_;
	return undef unless($tag);
	$tag = $self->_preprocess_tag($tag);
	return  $supportedTags{$tag} ? 1 : 0
}


1;

