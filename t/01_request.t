use Test::Simple tests => 2;

$ENV{LANG}='C';

# Test that dbms_lock request acquire lock

# Execute test for request/release
$ret = `psql -d regress_dbms_lock -f test/sql/request.sql > results/request.out 2>&1`;
ok( $? == 0, "test for request/release lock");

$ret = `diff results/request.out test/expected/request.out 2>&1`;
ok( $? == 0, "diff for request/release lock");

