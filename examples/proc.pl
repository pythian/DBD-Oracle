#!/usr/bin/env perl
# Short examples of procedure calls from Oracle.pm
# These PL/SQL examples come from: Eric Bartley <bartley@cc.purdue.edu>.

use DBI;

use strict;

# Set trace level if '-# trace_level' option is given
DBI->trace( shift ) if 1 < @ARGV && $ARGV[0] =~ /^-#/ && shift;

die "syntax: $0 [-# trace] base user pass" if 3 > @ARGV;
my ( $inst, $user, $pass ) = @ARGV;

# So we don't have to check every DBI call we set RaiseError.
#     See the DBI docs if you're not familiar with RaiseError.
# AutoCommit is currently encouraged and may be required later.
my $dbh = DBI->connect( "dbi:Oracle:$inst", $user, $pass,
    { AutoCommit => 0, RaiseError => 1, PrintError => 0 } )
    or die "Unable to connect: $DBI::errstr";

# Create the package for the examples
$dbh->do( <<END_PLSQL_EXAMPLE );
CREATE OR REPLACE PACKAGE plsql_example IS
    PROCEDURE proc_np;
    PROCEDURE proc_in( err_code IN NUMBER );
    PROCEDURE proc_in_inout( test_num IN NUMBER, is_odd IN OUT NUMBER );
    FUNCTION func_np RETURN VARCHAR2;
END plsql_example;
END_PLSQL_EXAMPLE

$dbh->do( <<END_PLSQL_EXAMPLE );
CREATE OR REPLACE PACKAGE BODY plsql_example IS
    PROCEDURE proc_np IS
        whoami VARCHAR2(20) := NULL;
    BEGIN
        SELECT user INTO whoami FROM DUAL;
    END;

    PROCEDURE proc_in( err_code IN NUMBER ) IS
    BEGIN
        RAISE_APPLICATION_ERROR( err_code, 'This is a test.' );
    END;

    PROCEDURE proc_in_inout ( test_num IN NUMBER, is_odd IN OUT NUMBER ) IS
    BEGIN
        is_odd := MOD( test_num, 2 );
    END;

    FUNCTION func_np RETURN VARCHAR2 IS
        ret_val VARCHAR2(20);
    BEGIN
        SELECT user INTO ret_val FROM DUAL;
        RETURN ret_val;
    END;
END plsql_example;
END_PLSQL_EXAMPLE

my $sth;

print "\nExample 1\n";
# Calling a PLSQL procedure that takes no parameters. This shows you the
# basic's of what you need to execute a PLSQL procedure. Just wrap your
# procedure call in a BEGIN END; block just like you'd do in SQL*Plus.
#
# p.s. If you've used SQL*Plus's exec command all it does is wrap the
#      command in a BEGIN END; block for you.

$sth = $dbh->prepare( q{
BEGIN
    plsql_example.proc_np;
END;
} );
$sth->execute;


print "\nExample 2\n";
# Now we call a procedure that has 1 IN parameter. Here we use bind_param
# to bind out parameter to the prepared statement just like you might
# do for an INSERT, UPDATE, DELETE, or SELECT statement.
#
# I could have used positional placeholders (e.g. :1, :2, etc.) or
# ODBC style placeholders (e.g. ?), but I prefer Oracle's named
# placeholders (but few DBI drivers support them so they're not portable).
#
# proc_in() will RAISE_APPLICATION_ERROR which will cause the execute to 'fail'.
# Because we set RaiseError, the DBI will die() so we catch that with eval {}.

my $err_code = -20001;

$sth = $dbh->prepare( q{
BEGIN
    plsql_example.proc_in( :err_code );
END;
} );
$sth->bind_param( ":err_code", $err_code );
eval { $sth->execute; };
print 'After proc_in: $@ = ', "'$@', errstr = '$DBI::errstr'\n";


print "\nExample 3\n";
# Building on the last example, I've added 1 IN OUT parameter. We still
# use a placeholders in the call to prepare, the difference is that
# we now call bind_param_inout to bind the value to the place holder.
#
# Note that the third parameter to bind_param_inout is the maximum size
# of the variable. You normally make this slightly larger than necessary.
# But note that the perl variable will have that much memory assigned to
# it even if the actual value returned is shorter.

my $test_num = 5;
my $is_odd;

$sth = $dbh->prepare( q{
BEGIN
    plsql_example.proc_in_inout( :test_num, :is_odd );
END;
} );

# The value of $test_num is _copied_ here
$sth->bind_param( ":test_num", $test_num );
$sth->bind_param_inout( ":is_odd", \$is_odd, 1 );

# The execute will automagically update the value of $is_odd
$sth->execute;
print "$test_num is ", $is_odd ? "odd - ok" : "even - error!", "\n";


print "\nExample 4\n";
# What about the return value of a PL/SQL function? Well treat it the same
# as you would a call to a function from SQL*Plus. We add a placeholder
# for the return value and bind it with a call to bind_param_inout so
# we can access its value after execute.

my $whoami = "";

$sth = $dbh->prepare( q{
BEGIN
    :whoami := plsql_example.func_np;
END;
} );
$sth->bind_param_inout( ":whoami", \$whoami, 30 );
$sth->execute;
print "Your database user name is $whoami\n";

# Get rid of the example package
$dbh->do( 'DROP PACKAGE plsql_example' );
$dbh->disconnect;
