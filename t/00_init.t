use Test::Simple tests => 4;

$ENV{LANG}='C';

# Test that dbms_lock request acquire lock

# Cleanup garbage from previous regression test runs
`rm -f results/ 2>/dev/null`;

`mkdir results 2>/dev/null`;

# First drop the test database and users
`psql -c "DROP DATABASE regress_dbms_lock" 2>/dev/null`;

# Create the test database
$ret = `psql -c "CREATE DATABASE regress_dbms_lock"`;
ok( $? == 0, "Create test regression database: regress_dbms_lock");

$ret = `psql -d regress_dbms_lock -c "CREATE EXTENSION pg_background" > /dev/null 2>&1`;
ok( $? == 0, "Create extension pg_background");

$ret = `psql -d regress_dbms_lock -c "CREATE EXTENSION pg_dbms_lock" > /dev/null 2>&1`;
ok( $? == 0, "Create extension pg_dbms_lock");

$ret = `psql -d regress_dbms_lock -c "CREATE TABLE lock_test (action varchar(10), session int, executed timestamp);" > /dev/null 2>&1`;
ok( $? == 0, "Create test table");


