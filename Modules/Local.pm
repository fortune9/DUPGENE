package Local;

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
#Created: Thu May 31 20:46:39 EDT 2012
######################################################################


=head1 NAME

Local - a package containing basic functions used in OO-programming

=head1 DESCRIPTION

This package is not well documented yet. I will do it in near future

=cut

use strict;
use Carp qw/cluck/;
our $AUTOLOAD;

# report the warning message
sub warn
{
	my $self = shift;
	my $str = join(" ",@_) if(@_);

	$str = "Nothing to be reported\n" unless(defined $str);
	$str = _reformat($str);

	#cluck <<WARNING;
	Carp::carp <<WARNING;
#---------------------warning------------------------------#
$str
#----------------------------------------------------------#
WARNING

	return 1;
}

# report error message and die out
sub throw
{
	my $self = shift;
	my $str = join(" ",@_);

	$str = "Nothing to be reported\n" unless(defined $str);
	$str = _reformat($str);

	Carp::confess <<ERR;
#---------------------fatal error--------------------------#
$str
#----------------------------------------------------------#

ERR

	exit 1;
}

# format the string for pretty output
sub _reformat
{
	my $str = shift;
	my $lineLen = 60 - 4;
	$str =~ s/\s+/ /g;
	chomp($str);
	my $lenToFill = $lineLen - length($str) % $lineLen;
	$str .= " " x $lenToFill;

	my $formated = "";
	for(my $i = 0; $i < length($str); $i+=$lineLen)
	{
#		my $subLen = $i + $lineLen > length($str) ? length($str) - $i
#		: $lineLen;
		$formated .= '| '.substr($str, $i, $lineLen)." |\n";
	}

	chomp($formated);

	return $formated;
}

sub debug
{
	my $self = shift;
	if(ref $self) # an object maybe
	{
		$self->{'_debug'} = shift if(@_);
		return $self->{'_debug'} || 0;
	}

	return; # an empty string
}

# load the package/module dynamically, copied from Bio::Root::Root.pm
sub _load_module
{
	my ($self, $name) = @_;
	my ($module, $load, $m);
	$module = "_<$name.pm";
	return 1 if $main::{$module};

	# untaint operation for safe web-based running (modified after a
	# fix by Lincoln) HL
	if ($name !~ /^([\w:]+)$/) {
		$self->throw("$name is an illegal perl package name");
	}else{
		$name = $1;
	}

	$load = "$name.pm";
	$load = join('/', split('::',$load)); # work for linux, may not
	# for windows. I will update in future
	eval {
		require $load;
	};

	if ( $@ ) {
		$self->throw("Failed to load module $name. ".$@);
	}

	return 1;
}

# get the values using the parameter fields, copied from
# Bio::Root::RootI
sub _rearrange
{
	my $dummy = shift;
	my $order = shift;

	return () unless(@_);
	# dash is always needed for specifying the field
	# return @_ unless (substr($_[0]||'',0,1) eq '-'); # not necessary
	
	$dummy->warn("Even number of parameters are needed for ",
		(caller(0))[3], "in", (caller())[1]) and return () 
	     if(($#_ + 1) %2); # even number of parameters

	my %param;
	while( @_ ) {
		(my $key = shift) =~ tr/a-z\055/A-Z/d; #deletes all dashes!
		$param{$key} = shift;
	}
#	map { $_ = uc($_) } @$order; # for bug #1343, but is there perf
	# hit here?
	return @param{map { uc($_) } @$order};
}

# open the IO for the object according to the parameter provided
sub _initialize_io
{
	my($self, @args) = @_;
	my ($file,$fh) = $self->_rearrange([qw/FILE FH/],@args);

	if($fh and ref($fh) eq 'GLOB')
	{
		# $self->{'_io'}->{'fh'} = $fh; do nothing
	}else
	{
		open($fh,"$file") or $self->throw("Can not open $file:$!");
	}

	# store the information
	$self->{'_io'} = {fh => $fh, file => $file || undef};
}

# read one line from the opened filehandle
sub _readline
{
	my $self = shift;
	my $fh = $self->{'_io'}->{'fh'};

	my $line = <$fh>;
	$self->throw("Can not read a line from $fh in $self")
	unless(defined $line);
#	chomp($line);
	return $line;
}

sub max
{
	my $self = shift;

	my $max;

	foreach my $n (@_)
	{
		$max = $n unless(defined $max);
		$max = $n if $max < $n;
	}

	return $max;
}

sub min
{
	my $self = shift;

	my $min;

	foreach my $n (@_)
	{
		$min = $n unless(defined $min);
		$min = $n if $min > $n;
	}

	return $min;
}

sub set_attributes
{
	my ($self,@args) = @_;

	$self->warn("Old number elements are provided\n") and return unless( scalar(@args)%2 == 0);
	
	while(@args)
	{
		my $attr   = shift @args;
		my $value  = shift @args;

		$attr =~ s/^-+//; # allow -attr and attr two types of options

		$self->{$attr} = $value;
	}

	return $self;
}

sub _remove_end_blank
{
	my $self = shift;

	my @data = @_;
	foreach (@data)
	{
		$_ =~ s/^\s+//;
		$_ =~ s/\s+$//;
	}

	return @data;
}

=ignore

sub AUTOLOAD
{
	my $self = shift;
	my $attr = $AUTOLOAD;

	$attr =~ s/.*:://;

	$self->{$attr} = shift if @_;

	$self->warn("No value for $attr in $self") if(!defined($self->{$attr}) and $self->debug);
	
	return $self->{$attr};
}

=cut

sub DESTROY
{
	my $self = shift;
	# close open filehandles if applicable
	if(exists $self->{'_io'}->{'fh'})
	{
		close $self->{'_io'}->{'fh'} if(fileno $self->{'_io'}->{'fh'});
	}
	# $self->SUPER::DESTROY(@_); # no super class now
}

1;

