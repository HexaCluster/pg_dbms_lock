use Test::Simple tests => 7;

$ENV{LANG}='C';

# Test that dbms_lock request reach lock timeout

# Execute test for timeouts, it will block the other session enough time to reach a timeout
$ret = `nohup psql -d regress_dbms_lock -f test/sql/timeout1.sql > results/timeout1.out &`;
ok( $? == 0, "test for lock timeout 1");

sleep(1);

$ret = `psql -d regress_dbms_lock -c "SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' AND database = (SELECT oid FROM pg_database WHERE datname = current_database()) ORDER BY objid;" > results/timeout.out`;
ok( $? == 0, "pending advisory locks");

# Start the other session that should lock timeout
$ret = `psql -d regress_dbms_lock -f test/sql/timeout2.sql > results/timeout2.out 2>&1`;
ok( $? == 0, "test for lock timeout 2");

sleep(3);

$ret = `psql -d regress_dbms_lock -c "SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' AND database = (SELECT oid FROM pg_database WHERE datname = current_database()) ORDER BY objid;" >> results/timeout.out`;
ok( $? == 0, "pending advisory locks");

$ret = `diff results/timeout.out test/expected/timeout.out 2>&1`;
ok( $? == 0, "diff for timeout locks");

$ret = `diff results/timeout1.out test/expected/timeout1.out 2>&1`;
ok( $? == 0, "diff for exclusive/shared locks, timeout 1");

$ret = `diff results/timeout2.out test/expected/timeout2.out 2>&1`;
ok( $? == 0, "diff for exclusive/shared locks, timeout 2");

