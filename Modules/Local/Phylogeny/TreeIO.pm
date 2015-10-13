package Local::Phylogeny::TreeIO;


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
#Created: Tue May 29 16:14:51 EDT 2012
######################################################################

=head1 NAME

Local::Phylogeny::TreeIO - A package to parse the phylogentic trees in
different format

=head1 SYNOPSIS

use Local::Phylogeny::TreeIO;
my $input = "test.newick";
my $io = Local::Phylogeny::TreeIO->new(-file => "$input"
                                       -format => 'newick');
my $tree = $io->next_tree; # return the next tree object

=head1 DESCRIPTION

This package is to assist the phylogentic analysis on the gene/species
tree. It will return objects in L<Local::Phylogeny::Tree>, which
provides some functionalities different from L<Bio::Tree>, such as the
I<tag> method.

=head1 AUTHOR

Zhenguo Zhang, zuz17@psu.edu, fortunezzg@gmail.com

=cut

use strict;
use Local::Phylogeny::Tree;
use base qw /Local::Phylogeny/;

my $package = __PACKAGE__;
my $comma = ',';
my $colon = ':';

=head2 new

 Title   : new
 Usage   : my $io = Local::Phylogeny::TreeIO->new()
 Function: Parse the trees in input and store it in the object
 Returns : Local::Phylogeny::TreeIO
 Args    : a hash table
 -file: the file storing trees or for output
 -format: the tree format. Supported formats include:
  newick        Newick tree format

=cut

sub new
{
	my ($caller,@args) = @_;

	my $class = ref($caller) || $caller;
	
	if($class =~ /Local::Phylogeny::TreeIO::(\S+)/) # from subclass
	{
		my $self = $class->SUPER::new(@args);
		$self->_initialize(@args);
		return $self;
	}else
	{
		my %param = @args;
		@param{ map { lc $_ } keys %param } = values %param; 
		my $format = $param{'-format'} || $param{'format'};
		unless($format)
		{
			$class->warn("tree format is not specified and newick will be
				used") if($caller->debug);
			$format = "newick";
		}
#		$format ||= "newick";
		$format = lc($format);

		return unless( $class->_load_format_module($format) );
		return "Local::Phylogeny::TreeIO::$format"->new(@args);
	}

}

# this method is called from the subclass, not from this module
sub _initialize
{
	my($self, @args) = @_;
	$self->_initialize_io(@args); # open the io
}

=head2 _load_format_module

 Title   : _load_format_module
 Usage   :
 Function: Load the module for the specific tree format
 Returns :
 Args    :
 
=cut

sub _load_format_module
{
	my ($self,$format) = @_;

	my $module = "Local::Phylogeny::TreeIO::" . $format;

	my $ok;
	eval {
		$ok = $self->_load_module($module); # the module is 'required'
	};

	if($@)
	{
	print STDERR <<ERR;
$self: $format cannot be found
Exception $@
For more information about the TreeIO system please see the TreeIO
docs.This includes ways of checking for formats at compile time, not
run time
ERR
	}

	return $ok;
}

=head2 next_tree

 Title   : next_tree
 Usage   : my $tree = $io->next_tree;
 Function: get the next tree off the stream
 Returns : Local::Phylogeny::Tree
 Args    : None

=cut

sub next_tree
{
	my $self = shift;
	$self->throw("Cannot call method next_tree on Local::Phylogeny::TreeIO object
		must use a subclass");
}

=head2 write_tree

 Title   : write_tree
 Usage   : $io->write_tree($tree);
 Function: write a tree into file
 Returns : None
 Args    : Local::Phylogeny::Tree

=cut

sub write_tree
{
	my ($self,$tree) = @_;
	$self->throw("Cannot call method write_tree on Local::Phylogeny::TreeIO object
		must use a subclass");
}

1;

