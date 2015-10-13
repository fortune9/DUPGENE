package Local::Phylogeny;

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
#Created: Thu May 31 15:00:13 EDT 2012
######################################################################

use strict;
use base qw/Local/;

=head2 new

 Title   : new
 Usage   : my $self = Local::Phylogeny->new();
 Function: create a new object for this class or its subclass
 Returns : an Local::Phylogeny object
 Args    : None
 Note    : at present, this is the toppest new method for all the
 subclasses of Local::Phylogeny

=cut

sub new
{
	my ($caller,@args) = @_;

	my $class = ref($caller) || $caller;

	my $obj = {};

	bless $obj,$class;

	return $obj;
}

=head2 id

 Title   : id
 Usage   : my $id = $self->id;
 Function: return the id of object if it has
 Returns : the id value
 Args    : None

=cut

sub id
{
	my $self = shift;
	return $self->{'_id'} if(exists $self->{'_id'});
	return $self->{'_tags'}->{'id'}->[0] if(exists
		$self->{'_tags'}->{'id'});
	return undef;
}


#/************************************************
#tag related methods
#************************************************/

=head2 set_tag

 Title   : set_tag
 Usage   : my $ok = $self->set_tag()
 Function: assign a value for the tag
 Returns : 1 for ok, 0 for fail
 Args    : tag, value
 Note this will overwrite the existing values for the specified tag,
and only supported tag can be added at this moment. If you need add
one value to the same tag, then use add_tag. more than one value for
one tag can be provided.

=cut

sub set_tag
{
	my $self = shift;
	my $tag  = shift;

	$tag = $self->_preprocess_tag($tag);
	$self->warn_unsupported_tag($tag) and return 0 unless($self->is_supported_tag($tag));

	$self->warn("No value is provided for tag $tag in set_tag") and
	return 0 unless(@_);

	$self->{'_tags'} = {} unless(exists $self->{'_tags'});
	my $tagHash = $self->{'_tags'};
	# always store the tag values as array reference
	$tagHash->{$tag} = [@_];
	return 1;
}

=head2 add_tag

 Title   : add_tag
 Usage   : my $ok = $self->add_tag()
 Function: add a value to the array of a given tag
 Returns : 1 for ok, 0 for fail
 Args    : tag, value
 Note    : more than one value can be provided

=cut

sub add_tag
{
	my $self = shift;
	my $tag  = shift;

#	my ($tag,$val) = @_;
	$self->warn_unsupported_tag($tag) and return 0 unless($self->is_supported_tag($tag));

	$self->{'_tags'} = {} unless(exists $self->{'_tags'});
	my $tagHash = $self->{'_tags'};
	$tagHash->{$tag} = [@{$tagHash->{$tag} || []},@_];
	return 1;
}

=head2 get_tag

 Title   : get_tag
 Usage   : my $value = $node->get_tag();
 Function: return the values associated with this tag
 Returns : an array in list context and first value in scalar
 context. If no values, an empty array or undef is returned
 Args    : tag name
 
=cut

sub get_tag
{
	my ($self,$tag) = @_;
	$tag = $self->_preprocess_tag($tag);
	# not supported
	$self->warn_unsupported_tag($tag) and 
	return(wantarray? () : undef)
	unless($self->is_supported_tag($tag));

	# no values exist
	return(wantarray? () : undef)
	unless(exists $self->{'_tags'}->{"$tag"});

	return wantarray? @{$self->{'_tags'}->{"$tag"}} :
	$self->{'_tags'}->{"$tag"}->[0];
}

=head2 remove_tag

 Title   : remove_tag
 Usage   : my $ok = $self->remove_tag();
 Function: remove the tag and values
 Returns : 1 for success and 0 for fail
 Args    : tag-name
 
=cut

sub remove_tag
{
	my ($self,$tag) = @_;
	$tag = $self->_preprocess_tag($tag);

	# no values
	return 0 unless(exists $self->{'_tags'}->{"$tag"});

	$self->{'_tags'}->{"$tag"} = undef;
	delete $self->{'_tags'}->{"$tag"};

	return 1;
}

=head2 remove_all_tags

 Title   : remove_all_tags
 Usage   : my $ok = $self->remove_all_tags();
 Function: remove all the tags and values
 Returns : 1 for success and 0 for failure
 Args    : None
 
=cut

sub remove_all_tags
{
	my $self = shift;

	$self->{'_tags'} = {};

	return 1;
}

=head2 all_tag_names

 Title   : all_tag_names
 Usage   : my @tags = $self->all_tag_names();
 Function: get all the tag names the object have
 Returns : an array of names
 Args    : None

=cut

sub all_tag_names
{
	my $self = shift;
	return keys(%{$self->{'_tags'} || {}});
}

=head2 has_tag

 Title   : has_tag
 Usage   : my $ = $self->is_supported_tag();
 Function: test whether the object has this tag
 Returns : Boolean
 Args    : tag name

=cut

sub has_tag
{
	my ($self,$tag) = @_;
	$tag = $self->_preprocess_tag($tag);
	return exists $self->{'_tags'}->{"$tag"} ? 1 : 0;
}

=head2 match_tag

 Title   : match_tag
 Usage   : my $true = $self->match_tag();
 Function: test whether the object has a tag which has given value
 Returns : Boolean value
 Args    : (tagname, value)
 Note    : it will return true if the tag has the value even if other
 values exist

=cut

sub match_tag
{
	my ($self, $tag, $value) = @_;

	$self->warn("Tag name and value are necessary for matching nodes") 
		and return undef unless(defined $value);

	return 0 unless $self->has_tag($tag);
	my @values = $self->get_tag($tag);
	return 1 if(grep { $_ eq $value } @values);
}

=head2 warn_unsupported_tag

 Title   : warn_unsupported_tag
 Usage   : $self->warn_unsupported_tag();
 Function: print a waring message on then screen about a unsupported tag
 Returns : 1
 Args    : tag-name

=cut

sub warn_unsupported_tag
{
	my ($self, $tag) = @_;

	my ($package, $file, $line ) = caller(1);

	$self->warn("The tag $tag is not supported in $package at Line
		$line of $file");

	return 1;
}

sub _preprocess_tag
{
	my $self = shift;
	my $tag = shift;
	
	return unless(defined $tag);

	$tag =~ s/^\s*\-+//; # allow -attr and attr two types of options
	$tag =~ s/\s+$//; # remove trailing blanks

	return(lc($tag));
}

#/************************************************
#tag related methods end
#************************************************/

1;

