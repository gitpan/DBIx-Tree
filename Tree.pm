package DBIx::Tree;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);
$VERSION = '0.90';


# Preloaded methods go here.

# Constructor.
#
sub new {

    my $proto =  shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless ($self, $class);

    my %args = @_;

    $self->{dbh}    = $args{connection};
    $self->{table}  = $args{table};
    $self->{method} = $args{method};

    my $columns = $args{columns};
    $self->{columns}          = $columns;
    $self->{id_column}        = $columns->[0];
    $self->{data_column}      = $columns->[1];
    $self->{parent_id_column} = $columns->[2];

    $self->{start_id} = $args{start_id};

    return $self;
}

sub do_query {

    my $self = shift;

    my $columns = join(', ', @{ $self->{columns} } );
    my $sql = "SELECT $columns FROM " . $self->{table};

    my $sth = $self->{dbh}->prepare($sql);
    my $rc = $sth->execute;
    if (!$rc) {
        warn "Could not issue query: $DBI::errstr";
	return 0;
    }

    my (@array, $recno);
    $recno = 0;
    while (my $href = $sth->fetchrow_hashref) {
      foreach (@{ $self->{columns} }) {
	$array[$recno]{$_} = $href->{$_};
      }
      $recno++;
    }

    @{$self->{data}} = @array;
    
    1; # return success

}

sub tree {

  my $self = shift;

  my @array = @{ $self->{data} };

  my (%stack, $current);
  
  my $level = 1;

  # this non-recursive algorithm requires the use of a 
  # stack in order to process each element. After each
  # element is processed, it is removed from the stack 
  # (actually, the value of the hash that represents
  # the item is set to 0), and its children on the next
  # level are added to the stack. Then it starts all over
  # again until we run out of elements.
  #
  $stack{ $self->{start_id} } = 1;

  # $level starts out at 1. Every time we run out of items
  # to process at the current level (if $levelFound == 0)
  # $level is decremented. If we get to 0, we have run out of
  # items to process, and can call it quits.
  #
  my (@parent_id, @parent_name);
  while ($level) {

    # search the stack for an item whose level matches
    # $level.
    #
    my $levelFound = 0;
    foreach my $index (keys %stack) {
      if ($stack{$index} == $level) {
	
	# if we have found something whose level is equal
	# to $level, set the variable $current so we can
	# refer to it later. Also, set the flag $levelFound
	#
	$current = $index;
	$levelFound = 1;
	last;
	
      } 
    }
    
    # if we found something at the current level, its id will
    # be in $current, so let's process it. Otherwise, we drop
    # through this, decrement $level, and if $level is not 0,
    # start the process over again.
    #
    if ($levelFound) {

      my $reccount = $#array;

      ######################################
      #
      # loop through the array of rows until
      # we find the record with the id that
      # matches $current. This is the id of
      # the item we pulled off of $stack
      #
      ######################################
      my $item;
      for (my $i = 0; $i <= $reccount; $i++) {

	if ($array[$i]{$self->{id_column}} eq $current) {
	
	  ###############################
	  #
	  # the data column is used to get
	  # $item, which is the label in
	  # the tree diagram.
	  #
	  # The cartid property is the id
	  # of the shopping cart that was
	  # created in the new method
	  #
	  ###############################
	  $item   = $array[$i]{$self->{data_column}};
	
	  ###############################
	  #
	  # if the calling program defined
	  # a target script, define this 
	  # item on the tree as a hyperlink.
	  # include variables for id and 
	  # cartid.
	  #
	  # Otherwise, just add the item 
	  # as it is.
	  #
	  ###############################
	  my $meth = $self->{method};
	  &$meth( item        => $item, 
	          level       => $level, 
		  id          => $current, 
		  parent_id   => \@parent_id, 
		  parent_name => \@parent_name );
	  last;
	}
      }
      $stack{$current} = 0;

      #################################
      #
      # add all the children (if any)
      # of the current item to the stack
      #
      ###############################
      $reccount = $#array;
      for (my $i = 1; $i <= $reccount; $i++) {

	if ($array[$i]{$self->{parent_id_column}} eq $current) {
	  $stack{$array[$i]{$self->{id_column}}} = $level + 1;
	}

      }

      if ($item && $current) {
          push @parent_id, $current;
          push @parent_name, $item;
      }
      $level++ ;

    } else {

      $level--;
      pop @parent_id;
      pop @parent_name;

    }

  }
  return 1;

}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

DBIx::Tree - Perl module for generating a tree from a self-referential table

=head1 SYNOPSIS

  use DBIx::Tree;
  my $tree = new DBIx::Tree( connection => $dbh, 
                            table      => $table,
                            method     => sub { disp_tree(@_) },
                            columns    => [$id_col, $label_col, $parent_col],
                            start_id   => $start_id);
  $tree->do_query;
  $tree->tree;

=head1 DESCRIPTION

When you've got one of those nasty self-referential tables that you want
to bust out into a tree, this is the module to check out.  Assuming
there are no horribly broken nodes in your tree and (heaven forbid) any
circular references, this module will turn something like:

    food                food_id   parent_id
    ==================  =======   =========
    Food                001       NULL
    Beans and Nuts      002       001
    Beans               003       002
    Nuts                004       002
    Black Beans         005       003
    Pecans              006       004
    Kidney Beans        007       003
    Red Kidney Beans    008       007
    Black Kidney Beans  009       007
    Dairy               010       001
    Beverages           011       010
    Whole Milk          012       011
    Skim Milk           013       011
    Cheeses             014       010
    Cheddar             015       014
    Stilton             016       014
    Swiss               017       014
    Gouda               018       014
    Muenster            019       014
    Coffee Milk         020       011

into:

    Food (001)
      Dairy (010)
        Beverages (011)
          Coffee Milk (020)
          Whole Milk (012)
          Skim Milk (013)
        Cheeses (014)
          Cheddar (015)
          Stilton (016)
          Swiss (017)
          Gouda (018)
          Muenster (019)
      Beans and Nuts (002)
        Beans (003)
          Black Beans (005)
          Kidney Beans (007)
            Red Kidney Beans (008)
            Black Kidney Beans (009)
        Nuts (004)
          Pecans (006)

There are examples in the examples directory - one plain text example, and
two Tk examples.

=head1 TODO

Graceful handling of circular references.
Better docs.
Rewrite the algorithm.
Separate data acquisition from data formatting.

=head1 AUTHOR

Brian Jepson, bjepson@ids.net

This module was inspired by the Expanding Hierarchies example that I
stumbled across in the Microsoft SQL Server Database Developer's Companion
section of the Microsoft SQL Server Programmer's Toolkit.

=head1 SEE ALSO

perl(1).
DBI(3).
Tk(3).

=cut
