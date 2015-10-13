package Local::Phylogeny::Node::Ascended;

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
#Created: Mon Jun  4 12:52:34 EDT 2012
######################################################################

use strict;
use Local::Phylogeny::Node;
use base qw/Local::Phylogeny::Node/;

my %extendedTags;
@extendedTags{qw/num_paralogs cost_table dups loss curr_loss
	curr_dups j_boundary j_index curr_j/} = 1..9;
my ($TRUE, $FALSE) = (1, 0);

=head2 new

 Title   : new
 Usage   : my $ascendedNode = Local::Phylogeny::Node::Ascended->new();
 Function: gets a new Local::Phylogeny::Node::Ascended object
 Returns : an object of Local::Phylogeny::Node::Ascended
 Args    : a object of Local::Phylogeny::Node or paramters to create a
 such object

=cut

sub new
{
	my ($caller, @args) = @_;

	if($#args == 0 and $args[0]->isa("Local::Phylogeny::Node"))
	{
		return bless $args[0], ref($caller) || $caller;
	}else
	{
		return $caller->SUPER::new(@args);
	}
}

sub _descend
{
	my ($self,$reset,$i) = @_;

	my $numPara = $self->num_paralogs || 0; # number of paralogs in
	# this node

	if($self->is_leaf)
	{
		my $loss = $self->max($i - $numPara,0);
		my $dups = $self->max($numPara - $i,0);
		$self->loss($loss); # given $i, the total loss and gain
		$self->dups($dups);
		$self->curr_j($numPara);
		return $reset
	}

	# otherwise internal nodes, search for alternative values before
	# change current j, unless reset is true
	if($reset) # start from the first possible node state
	{
		my $jIndex = $self->j_index(0);
		my $jRef = $self->get_minimum_cost($i)->[1];
		my $j = $jRef->[$jIndex];

		my $loss = $self->max($i - $j - $numPara, 0);
		my $dups = $self->max($numPara + $j - $i, 0);

		$self->loss($loss);
		$self->dups($dups);
		$self->curr_j($j);

		# set the j_index for all children to the 1st state
		my @children = $self->children;
		for( my $c = 0; $c <= $#children; $c++)
		{
			my $child = $children[$c];
			$child->_descend($TRUE,$j) or $self->throw("There must be
				at least one j value available for node ", $child->id,
			"given i at $j");
		}

		return $TRUE;

	}else # this is not the first time to search optimal subtree under
	      # this node. Then just change the deepest one at first
	{
		my $jRef = $self->get_minimum_cost($i)->[1];
		my $jIndex = $self->j_index; # the j index for current i
		my $j = $jRef->[$jIndex];
		#################################
		# 1st step
		# check alternative j values in its child nodes
		#################################
		my @children = $self->children();
		for(my $c = 0; $c <= $#children; $c++)
		{
			my $child = $children[$c];
			# if this child is leaf and an old value is used for
			# current node, then just ignore the checking for the
			# child node, bacause nothing will change for child node
			next if($child->is_leaf);

			my $success = $child->_descend($FALSE,$j);
			if($success)
			{
				# reset all previous examined child nodes of $self
				if($c > 0)
				{
					for(my $previous = 0; $previous < $c; $previous++)
					{
						my $ok = $children[$previous]->_descend($TRUE,$j);
					}
				}

				return $TRUE;
			}
		}

		########################################
		# 2nd step:
		# none of the children have alternative values, check next
		# state of current node
		########################################
		$jIndex = $self->j_index($self->j_index+1);
		return $FALSE if($jIndex > $#$jRef); # no available j for
		# current $i
		
		$j = $jRef->[$jIndex];
		my $loss = $self->max($i - $j - $numPara, 0);
		my $dups = $self->max($numPara + $j - $i, 0);
		$self->loss($loss);
		$self->dups($dups);
		$self->curr_j($j);

		# reset all children nodes based on this new $j value
		for(my $c = 0; $c <= $#children; $c++)
		{
			my $child = $children[$c];
			my $success = $child->_descend($TRUE,$j); 
			$self->throw("No avalable values for \$j in children
				of", $child->id, "when i is at $j") unless($success);
		}

		return $TRUE;

	}

}

sub record_minimum_cost
{
	my ($self, $iVal, $jRef, $cost) = @_;
	my $costTable = $self->get_tag('cost_table') || {};
	$costTable->{$iVal} = [$cost, $jRef];
	$self->set_tag('cost_table', $costTable);
}

sub get_minimum_cost
{
	my ($self, $iVal) = @_;
	my $costTable = $self->get_tag('cost_table') or return undef;
	return $costTable->{$iVal} if(exists $costTable->{$iVal});
	return undef;
}

sub j_boundary
{
	my $self = shift;
	$self->set_tag('j_boundary', $_[0]) if(@_);
	$self->get_tag('j_boundary');
}

sub j_index
{
	my $self = shift;
	$self->set_tag('j_index', $_[0]) if(@_);
	$self->get_tag('j_index') || 0;
}

sub curr_j
{
	my $self = shift;
	$self->set_tag('curr_j', $_[0]) if(@_);
	$self->get_tag('curr_j');
}

sub _first_element
{
	my @all = @_;

	return $all[0] if(@all);
	return undef;
}
sub is_supported_tag
{
	my ($self,$tag) = @_;
	return undef unless($tag);
	return 1 if $self->SUPER::is_supported_tag($tag); # call parent
	# method first
	$tag = $self->_preprocess_tag($tag);
	return  $extendedTags{$tag} ? 1 : 0
}

# this is a leaf in a tree, but it has been lost during evolution. It
# is put here just for information
sub pseudo_leaf
{
	my $self = shift;
	$self->{'_pseudo_leaf'} = shift if(@_);
	return $self->{'_pseudo_leaf'};
}


#####################################################
# some special methods related to gain and loss states
#####################################################
sub curr_dups
{
	my $self = shift;
	$self->{'_curr_dups'} = shift if(@_);
	return $self->{'_curr_dups'} || 0;
}

sub curr_loss
{
	my $self = shift;
	$self->{'_curr_loss'} = shift if(@_);
	return $self->{'_curr_loss'} || 0;
}

sub dups
{
	my $self = shift;
	$self->set_tag('dups', $_[0]) if(@_);
	$self->get_tag('dups');
}

sub loss
{
	my $self = shift;
	$self->set_tag('loss', $_[0]) if(@_);
	$self->get_tag('loss');
}

# the status if this node has been checked during ascend process
sub _ascended
{
	my $self = shift;
	$self->{'_ascended'} = shift if(@_);
	return $self->{'_ascended'};
}

# number gene copies for this node
sub num_paralogs
{
	my $self = shift;
	$self->set_tag('num_paralogs', $_[0]) if(@_);
	$self->get_tag('num_paralogs');
}


1;

