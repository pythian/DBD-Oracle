#!/usr/bin/env perl
#
# bind.pl
#
# This shows how a placeholder may be used to implement a simple lookup.

use DBI;

use strict;

# Set trace level if '-# trace_level' option is given
DBI->trace( shift ) if 1 < @ARGV && $ARGV[0] =~ /^-#/ && shift;

die "syntax: $0 [-# trace] base user pass" if 3 > @ARGV;
my ( $inst, $user, $pass ) = @ARGV;

# Connect to database
my $dbh = DBI->connect( "dbi:Oracle:$inst", $user, $pass,
    { AutoCommit => 0, RaiseError => 1, PrintError => 0 } )
    or die $DBI::errstr;

# Prepare the SELECT statement using a placeholder
my $sth = $dbh->prepare( 'SELECT created FROM all_users WHERE username = ?' );

my ( $created );
$| = 1;
print "Enter an empty line to finish\n";
print "Userid? ";
while ( <STDIN> ) {
    chomp;
    last if ! $_;
    $sth->execute( uc( $_ ) );

    # Note that the variable is in parentheses to force array context
    if ( ( $created ) = $sth->fetchrow_array ) {
        print "$created\n";
    }
    else {
        print "unknown\n";
    }
    print "Userid? ";
}

$sth->finish;
$dbh->disconnect;
