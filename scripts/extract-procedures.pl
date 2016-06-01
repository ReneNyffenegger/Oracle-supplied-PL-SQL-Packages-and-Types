#
#
#  ALL_OBJECTS                      ALL_PROCEDURES                                                   ALL_ARGUMENTS
#
#  OBJECT_TYPE     OBJECT_NAME      OBJECT_NAME    PROCEDURE_NAME SUBPROGRAMID OBJECT_TYPE OVERLOAD  OBJECT_NAME   PACKAGE_NAME ARGUMENT_NAME
#  --------------- -------------    -------------  -------------- ------------ ----------- --------  -----------   ------------ -------------
#  FUNCTION        OLAP_TEXT_SRF    OLAP_TEXT_SRF                              FUNCTION              OLAP_TEXT_SRF              ...
#  PROCEDURE       ODCIENVDUMP      ODCIENVDUMP                                PROCEDURE             ODCIENVDUMP                ...
#  PACKAGE         DBMS_OUTPUT      DBMS_OUTPUT    GET_LINES                 7 PACKAGE            1  GET_LINES     DBMS_OUTPUT  ...
#  PACKAGE         UTL_FILE         UTL_FILE       IS_OPEN                   3 PACKAGE               IS_OPEN       UTL_FILE     ..
#  PACKAGE BODY    DBMS_OUTPUT
#
#  TYPE            todo
#  LIBRARY         todo
#
#
use warnings;
use strict;

use DBI;
use DBD::Oracle;

my $username = shift;
my $password = shift;
my $database = shift || '';

my $dbh = DBI->connect("dbi:Oracle:$database", $username, $password) or die;

my $sth_obj = $dbh->prepare(
   "select owner, object_name, object_type 
     from all_objects
     where
       owner in ('SYS', 'SYSTEM', 'SYSMAN', 'ANONYMOUS', 'DBSNMP') and
       object_type in ('PACKAGE', /* 'TYPE' ,*/ 'FUNCTION', 'PROCEDURE')
  AND object_name = 'DBMS_OUTPUT'
     order by
       owner, object_name, object_type") or die;

# select object_name, procedure_name from all_procedures where rownum < 30  and procedure_name is null and owner in ('SYS', 'SYSTEM');
my $sth_prc = $dbh->prepare(
    "select /*object_name,*/ procedure_name, /*object_type,*/ overload
       from all_procedures
      where
        object_name = :1 and owner = :2 order by procedure_name, overload") or die;

# select argument_name, object_name, package_name, sequence, position from all_arguments where rownum < 30 and sequence - 1 != position;
my $sth_arg_fp = $dbh->prepare(
   "select argument_name, position, sequence
     from all_arguments
    where owner = :1 and object_name= :2 and  nvl(overload, '!') = nvl(:3, '!') order by position") or die;

my $sth_arg_pck = $dbh->prepare(
   "select argument_name, position, sequence
     from all_arguments
    where owner = :1 and object_name= :2 and package_name = :3 and nvl(overload, '!') = nvl(:4, '!') order by position") or die;

$sth_obj -> execute;

while (my $obj = $sth_obj -> fetchrow_hashref) {
  printf("%-20s %-30s %-10s\n", $obj->{OWNER}, $obj->{OBJECT_NAME}, $obj->{OBJECT_TYPE});

  $sth_prc -> execute($obj->{OBJECT_NAME}, $obj->{OWNER});

  while (my $prc = $sth_prc -> fetchrow_hashref) {

    printf("  %-30s %2s\n", $prc->{PROCEDURE_NAME} || '', 
#     $prc->{OBJECT_TYPE},
      $prc->{OVERLOAD} || ''
    );

    my $sth;
    if ($obj->{OBJECT_TYPE} eq 'FUNCTION' or $obj->{OBJECT_TYPE} eq 'PROCEDURE') {
      $sth_arg_fp -> execute($obj->{OWNER}, $prc->{OBJECT_NAME}, $prc->{OVERLOAD});
      $sth = $sth_arg_fp;
    }
    else {
      $sth_arg_pck -> execute($obj->{OWNER}, $prc->{PROCEDURE_NAME}, $prc->{OBJECT_NAME}, $prc->{OVERLOAD});
      $sth = $sth_arg_pck;
    }

    while(my $arg = $sth->fetchrow_hashref) {

       printf("    %-30s %2s %2s\n", $arg->{ARGUMENT_NAME} || '', $arg->{POSITION} ||'', $arg->{SEQUENCE} || '');
    }

  }


}

