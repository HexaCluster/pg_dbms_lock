-----
-- Test exclusive lock request+release at session level
-----
DO $$
DECLARE
    lock_res int;
    DBMS_LOCK_X_MODE int := 6;
BEGIN
    lock_res := DBMS_LOCK.REQUEST( 123, DBMS_LOCK_X_MODE, 300, FALSE );
    IF ( lock_res <> 0 ) THEN
	RAISE EXCEPTION 'DBMS_LOCK.REQUEST() FAIL: %', lock_res;
    END IF;
END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

DO $$
DECLARE
    lock_res int;
BEGIN
    -- release lock
    lock_res := DBMS_LOCK.RELEASE( 123 );
    IF ( lock_res <> 0 ) THEN
        RAISE EXCEPTION 'DBMS_LOCK.RELEASE() FAIL: %', lock_res;
    END IF;
END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

----
-- Test shared lock request+release at session level
----
DO $$
DECLARE
    lock_res int;
    DBMS_LOCK_S_MODE int := 4;
BEGIN
    lock_res := DBMS_LOCK.REQUEST( 321, DBMS_LOCK_S_MODE, 300, FALSE );
    IF ( lock_res <> 0 ) THEN
	RAISE EXCEPTION 'DBMS_LOCK.REQUEST() FAIL: %', lock_res;
    END IF;
END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

DO $$
DECLARE
    lock_res int;
BEGIN
    -- release lock
    lock_res := DBMS_LOCK.RELEASE( 321 );
    IF ( lock_res <> 0 ) THEN
        RAISE EXCEPTION 'DBMS_LOCK.RELEASE() FAIL: %', lock_res;
    END IF;
END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

-----
-- Test xact exclusive lock request at transaction level
-----
BEGIN;

DO $$
DECLARE
    lock_res int;
    DBMS_LOCK_X_MODE int := 6;
BEGIN
    lock_res := DBMS_LOCK.REQUEST( 321, DBMS_LOCK_X_MODE, 300, TRUE );
    IF ( lock_res <> 0 ) THEN
	RAISE EXCEPTION 'DBMS_LOCK.REQUEST() FAIL: %', lock_res;
    END IF;
END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

COMMIT;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

-----
-- Test xact shared lock request at transaction level
-----
BEGIN;

DO $$
DECLARE
    lock_res int;
    DBMS_LOCK_S_MODE int := 4;
BEGIN
    lock_res := DBMS_LOCK.REQUEST( 321, DBMS_LOCK_S_MODE, 300, TRUE );
    IF ( lock_res <> 0 ) THEN
	RAISE EXCEPTION 'DBMS_LOCK.REQUEST() FAIL: %', lock_res;
    END IF;
END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

COMMIT;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;
