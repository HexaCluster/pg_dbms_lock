use Test::Simple tests => 2;

$ENV{LANG}='C';

# Test that dbms_lock request acquire lock

# Execute test for allocate/request/release
$ret = `psql -d regress_dbms_lock -f test/sql/allocate.sql > results/allocate.out 2>&1`;
ok( $? == 0, "test for allocate/request/release lock");

$ret = `diff results/allocate.out test/expected/allocate.out 2>&1`;
ok( $? == 0, "diff for allocate/request/release lock");

