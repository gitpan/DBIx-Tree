use ExtUtils::MakeMaker qw(prompt WriteMakefile);
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'DBIx::Tree',
    'VERSION_FROM' => 'Tree.pm', # finds $VERSION
);

$connstr = prompt ("DBI Connection String?", "DBI:mSQL:test:localhost:1114");
$userid  = prompt ("User ID?", "");
$passwd  = prompt ("Password?", "");

open(PWD, ">PWD") || die "Could not open PWD for writing!";
print PWD $connstr, "\n";
print PWD $userid, "\n";
print PWD $passwd, "\n";
