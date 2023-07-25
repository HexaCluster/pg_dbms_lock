use Test::Simple tests => 9;

$ENV{LANG}='C';

# Test that dbms_lock request acquire lock

# Execute test for sessions, it will block the two others sessions 5 seconds
$ret = `nohup psql -d regress_dbms_lock -f test/sql/session1.sql > results/session1.out 2>/dev/null`;
ok( $? == 0, "test for session1 lock");

# Start the two others sessions in shared lock, they should be executed at quite the same time
$ret = `nohup psql -d regress_dbms_lock -f test/sql/session2.sql > results/session2.out 2>/dev/null`;
ok( $? == 0, "test for session2 lock");

$ret = `nohup psql -d regress_dbms_lock -f test/sql/session3.sql > results/session3.out 2>/dev/null`;
ok( $? == 0, "test for session3 lock");

sleep(12);

$ret = `psql -d regress_dbms_lock -c "SELECT action, session, (date_trunc('second', executed) - lag(date_trunc('second', executed)) over()) FROM lock_test" > results/session.out`;
ok( $? == 0, "result for sessions 2 and 3 work");

$ret = `psql -d regress_dbms_lock -c "SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL;" >> results/session.out`;
ok( $? == 0, "pending advisory locks");

$ret = `diff results/session.out test/expected/session.out 2>&1`;
ok( $? == 0, "diff for exclusive/shared locks");

$ret = `diff results/session1.out test/expected/session1.out 2>&1`;
ok( $? == 0, "diff for exclusive/shared locks, session 1");

$ret = `diff results/session2.out test/expected/session2.out 2>&1`;
ok( $? == 0, "diff for exclusive/shared locks, session 2");

$ret = `diff results/session3.out test/expected/session3.out 2>&1`;
ok( $? == 0, "diff for exclusive/shared locks, session 3");

