# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use DBIx::Tree;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

############# create and populate the table we need.
open (PWD, "PWD") 
  or (print "not ok 2\n" and die "Could not open PWD for reading!");
while(<PWD>) {
        chomp;
        push @dbiparms, $_;
}
close (PWD);

use DBI;
my $dbh = DBI->connect(@dbiparms);
if ( defined $dbh ) {
        print "ok 2\n";
} else {
        print "not ok 2\n";
        die $DBI::errstr;
}

open (INSTALL, "INSTALL.SQL") 
  or (print "not ok 2\n" and die "Could not open INSTALL.SQL for reading!");
while(<INSTALL>) {
        chomp;

	# strip out NULL for mSQL
	#
	if (/^create/i and $dbiparms[0] =~ /msql/i) {
	    s/null//gi;
	}

        my $sth = $dbh->prepare($_);
        my $rc = $sth->execute;

        # ignore drop table.
        #
        if (!$rc and ! /^drop/i) {
            print "not ok 2\n";
            die "$DBI::errstr";
        }
}
close (INSTALL);

############# create an instance of the DBIx::Tree 
my $tree = new DBIx::Tree( connection => $dbh, 
                          table      => 'food', 
                          method     => sub { disp_tree(@_) },
                          columns    => ['food_id', 'food', 'parent_id'],
                          start_id   => '001');
if(ref $tree eq 'DBIx::Tree') {
    print "ok 3\n";
} else {
    print "not ok 3\n";
}

############# call do_query
if ($tree->do_query) {
    print "ok 4\n";
} else {
    print "not ok 4\n";
}

############# call tree
use vars qw($compare);

$tree->tree;
$rc = $compare eq 'FoodDairyBeveragesCoffee MilkWhole MilkSkim MilkCheeses' .
                  'CheddarStiltonSwissGoudaMuensterBeans and NutsBeans' .
                  'Black BeansKidney BeansRed Kidney BeansBlack Kidney' .
                  ' BeansNutsPecans';
if ($rc) {
    print "ok 5\n";
} else {
    print "not ok 5\n";
}

sub disp_tree {
    %parms = @_;
    my $item = $parms{item};
    $item =~ s/^\s+//;
    $item =~ s/\s+$//;
    $compare .= $item;
}

############# close the dbh
$dbh->disconnect;
