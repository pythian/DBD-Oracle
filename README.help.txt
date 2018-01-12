===============================================================================
Platform or Oracle Version specific notes, hints, tips etc:

Note that although some of these refer to specific systems and versions the
same or similar problems may exist on other systems or versions.

Most of this mess is due to Oracle's fondness for changing the
build/link process for OCI applications between versions.


-------------------------------------------------------------------------------
AIX 4 - core dump on login and similar problems

set 
	cc='xlc_r'
in config.sh. Rebuild everything, and make sure xlc_r is used everywhere.
set environment 
	ORACCENV='cc=xlc_r'; export ORACCENV 
to enforce this in oraxlc

Thanks to Goran Thyni <goran@bildbasen.kiruna.se> for this information.

-------------------------------------------------------------------------------
AIX - core dump on disconnect (SIGILL signal)

Try setting BEQUEATH_DETACH=YES in SQLNET.ORA and restarting Oracle instance.
See 'Hang during "repetitive connect/open/close/disconnect" test' below.

-------------------------------------------------------------------------------
HP-UX: General

Read README.hpux.txt. Then read it again.

HP's bundled C compiler is dumb. Very dumb. You're almost bound to have
problems if you use it - you'll certainly need to do a 'static link'
(see elsewhere). It is recommended that you use HP's ANSI C compiler
(which costs) or fetch and build the free GNU GCC compiler (v2.7.2.2 or later).

Note that using shared libraries on HP-UX 10.10 (and others?) requires
patch 441647. With thanks to John Liptak <jliptak@coefmd3.uswc.uswest.com>.

-------------------------------------------------------------------------------
HP-UX: Terry Greenlaw <z50816@mip.lasc.lockheed.com>

I traced a problem with "ld: Invalid loader fixup needed" to the file
libocic.a. On HP-UX 9 it contains position-dependant code and cannot be
used to generate dynamic load libraries. The only shared library that
Oracle ships under HP-UX is liboracle.sl which replaces libxa.a,
libsql.a, libora.a, libcvg.a, and libnlsrtl.a. The OCI stuff still
appears to only link statically under HU-UX 9.x [10.x seems okay].

You'll need to build DBD::Oracle statically linked into the perl binary.
See the static linking notes below.

If you get an error like: Bad magic number for shared library: Oracle.a
You'll need to build DBD::Oracle statically linked into the perl binary.

HP-UX 10 and Oracle 7.2.x do work together when creating dynamic libraries.
The problem was older Oracle libraries were built without the +z flag to cc,
and were therefore position-dependent libraries that can't be linked
dynamically. Newer Oracle releases don't have this problem and it may be
possible to even use the newer Oracle libraries under HP-UX 9. Oracle 7.3
will ONLY work under HP-UX 10, however.

HP-UX 10 and Oracle 7.3.x seem to have problems. You'll probably need
to build DBD::Oracle statically linked (see below).  The problem seems
to be related to Oracle's own shared library code trying to do a
dynamic load (from lxfgno() in libnlsrtl3.a or libclntsh.sl).  If you
get core dumps on login try uncommenting the /* #define signed */ line
in dbdimp.h as a long-shot. Please let me know if this fixes it for you
(but I doubt it will).

-------------------------------------------------------------------------------
For platforms which require static linking.

You'll need to build DBD::Oracle statically linked and then link it
into a perl binary:

	perl Makefile.PL LINKTYPE=static
	make
	make perl                  (makes a perl binary in current directory)
	make test FULLPERL=./perl  (run tests using the new perl binary)
	make install

You will probably need to have already built and installed a static
version of the DBI in order that it be automatically included when
you do the 'make perl' above.

Remember that you must use this new perl binary to access Oracle.

-------------------------------------------------------------------------------
Error: Can't find loadable object for module DBD::Oracle in @INC ...

You probably built DBD::Oracle for static linking rather than dynamic
linking.  See 'For platforms which require static linking' above for
more info.  If your platform supports dynamic linking then try to work
out why DBD::Oracle got built for static linking.

-------------------------------------------------------------------------------
Error: Syntax warnings/errors relating to 'signed'

Remove the /* and */ surrounding the '/* #define signed */' line in dbdimp.h

-------------------------------------------------------------------------------
ORA-00900: invalid SQL statement "begin ... end"

You probably don't have PL/SQL Oracle properly/fully installed.

-------------------------------------------------------------------------------
Connection/Login slow. Takes a long time and may coredump

Oracle bug number: 227321 related to changing the environment before
connecting to oracle. Reported to be fixed in 7.1.6 (or by patch 353611).

To work around this bug, do not set any environment variables in your
oraperl script before you call ora_login, and when you do call
ora_login, the first argument must be the empty string.  This means
that you have to be sure that your environment variables ORACLE_SID
and ORACLE_HOME are set properly before you execute any oraperl
script.  It is probably also possible to pass the SID to ora_login as
part of the username (for example, ora_login("", "SCOTT/TIGER@PROD",
"")), although I have not tested this.
This workaround is based on information from Kevin Stock.

Also check $ORACLE_HOME/otrace/admin. If it contains big *.dat files
then you may have otrace enabled.  Try setting EPC_DISABLED=TRUE
in the environment of the database and listener before they're started.
Oracle 7.3.2.2.0 sets this to FALSE by default, which turns on tracing
of all SQL statements, and will cause very slow connects once that
trace file gets big. You can also add (ENVS='EPC_DISABLED=TRUE') to
the SID_DESC part of listener.ora entries. (With thanks to Johan
Verbrugghen jverbrug@be.oracle.com)

-------------------------------------------------------------------------------
Connection/Login takes a long time

Try connect('', 'user/passwd@tnsname', '').  See README.login.txt and
item above.

-------------------------------------------------------------------------------
Error: ORA-00604: error occurred at recursive SQL level  (DBD: login failed)

This can happen if TWO_TASK is defined but you connect using ORACLE_SID.

-------------------------------------------------------------------------------
Error: ld: Undefined symbols _environ _dlopen _dlclose ...
Environment:  SunOS 4.1.3, Oracle 7.1.6  Steve Livingston <mouche@hometown.com>

If you get link errors like: ld: Undefined symbols _environ _dlopen _dlclose ...
and the link command line includes '-L/usr/5lib -lc' then comment out the
'CLIBS= $(OTHERLIBS) -L/usr/5lib -lc' line in the Makefile.

-------------------------------------------------------------------------------
Error: fatal: relocation error: symbol not found: main
Environment:  Solaris, GCC

Do not use GNU as or GNU ld on Solaris. Delete or rename them, they are
just bad news.  In the words of John D Groenveld <groenvel@cse.psu.edu>:
Run, don't walk, to your console and 'mv /opt/gnu/bin/as /opt/gnu/bin/gas;
mv /opt/gnu/bin/ld /opt/gnu/bin/gld'. You can add -v to the gcc command
in the Makefile to see what GCC is using.

-------------------------------------------------------------------------------
Error: relocation error:symbol not found:setitimer
Environment:  SVR4, stephen.zander@mckesson.com

Error: can't load ./blib/arch/auto/DBD/Oracle/Oracle.so for module DBD::Oracle:
DynamicLinker:/usr/local/bin/perl:relocation error:symbol not found:setitimer
Fix: Try adding the '-lc' to $ORACLE_HOME/rdbms/lib/sysliblist (just
make sure it's not on a new line).

-------------------------------------------------------------------------------
Error: relocation error:symbol not found:mutex_init
Environment:  UnixWare 7.x, earle.nietzel@es.unisys.com

On the UnixWare 7.x platform the compiler flag -Kthread is commonly used
when compiling for mulithread however in this case you should use -lthread.
The compiler will complain that you should be using -Kthread and not
-lthread, you should ignore these messages. Besure to check this compiler
flag in $ORACLE_HOME/lib/sysliblist also.

-------------------------------------------------------------------------------
Error: Undefined symbols __cg92_used at link time.
Environment:  Solaris, GCC

Fix: If you're compiling Oracle applications with gcc on Solaris you need to
link with a file called $ORACLE_HOME/lib/__fstd.o. If you compile with the
SparcWorks compiler you need to add the command line option on -xcg92
to resolve these symbol problems cleanly.

Alligator Descartes <descarte@hermetica.com>

-------------------------------------------------------------------------------
Environment:  SunOS 4.1.3, Oracle 7.1.3  John Carlson <carlson@tis.llnl.gov>

Problem:  oraperl and DBD::Oracle fail to link.  Some messing around with
the library order makes the link succeed.  Now I get a "Bad free()" when
ora_logoff is called.

Solution:
In my case, this was caused by a faulty oracle install.  The install grabbed
the wrong version of mergelib (The X11R6 one) instead of the one in
$ORACLE_HOME/bin.  Try a more limited path and reinstall Oracle again.

-------------------------------------------------------------------------------
Environment: SGI IRIX

From Dennis Box <dbox@fndapl.fnal.gov>:

Details instructions are available from http://misdev.fnal.gov/~dbox/n32/
(To build IRIX n32 format using the Oracle n32 toolkit.)

From Mark Duffield <duffield@ariad.com>:  (possibly now out of date)

Oracle only supports "-32" and "-mips2" compilation flags, not "-n32".
Configure and build perl with -32 flag (see perl hints/irix_6.sh file
in the perl distribution).
Rebuild DBI (which will now use the -32 flag).
Rebuild DBD::Oracle (which will now use the -32 flag).

Since IRIX depends on the perl executable in /usr/sbin, you'll have to
keep it around along with the one you just built.  Some care will need
to be taken to make sure that you are getting the right perl, either
through explicitly running the perl you want, or with a file header in
your perl file.  The file header is probably the better solution of the two.

In summary, until Oracle provides support for either the "-n32" or the "-64"
compiler switches, you'll have to have a perl, DBI, and DBD-Oracle which are
compiled and linked "-32".  I understand that Oracle is working on a 64bit
versions of V7.3.3 for SGI (or MIPS ABI as they call it), but I don't have
any firm dates.

You may also need to use perl Makefile.PL -p.

-------------------------------------------------------------------------------
Environment:  64-bit platforms (DEC Alpha, OSF, SGI/IRIX64 v6.4)

Problem: 0 ORA-00000: normal, successful completion

Solution: Add '#define A_OSF' to Oracle.h above '#include <oratypes.h>' and
complain to Oracle about bugs in their header files on 64 bit systems.

-------------------------------------------------------------------------------
Link errors or test core dumps

Try each of these in turn (follow each with a make && make test):
	perl Makefile.PL -nob
	perl Makefile.PL -c
	perl Makefile.PL -l
	perl Makefile.PL -n LIBCLNTSH
let me know if any of these help.

===============================================================================
Hang during "repetitive connect/open/close/disconnect" test:

From: "Alexi S. Lookin" <aslookin@alfabank.ru>

In short,  this problem was solved after addition of parameter
BEQUEATH_DETACH=YES in SQLNET.ORA and restarting Oracle instance.

Browsed Net8 doc (A67440-01 Net8 Admin Guide for Oracle 8.1.5,
Feb.1999) and found some mention of inadequate bequeath behaviour when
disconnecting bequeath session, and some solution for this problem at
page 10-15 (may vary at any other release) :

"p.10-15
Child Process Termination

Since the client application spawns a server process internally through
the Bequeath protocol as a child process, the client application
becomes responsible for cleaning up the child process when it
completes. When the server process completes its connection
responsibilities, it becomes a defunct process. Signal handlers are
responsible for cleaning up these defunct processes. Alternatively, you
may configure your client SQLNET.ORA file to pass this process to the
UNIX init process by disabling signal handlers.

Use the Net8 Assistant to configure a client to disable the UNIX signal
handler. The SQLNET.ORA parameter set to disable is as follows:
    bequeath_detach=yes

This parameter causes all child processes to be passed over to the UNIX
init process (pid = 1). The init process automatically checks for
"defunct" child processes and terminates them.

Bequeath automatically chooses to use a signal handler in tracking
child process status changes. If your application does not use any
signal handling, then this default does not affect you."

===============================================================================

End.
