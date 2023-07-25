-- Test lock handle allocation
DO $$
DECLARE
    printer_lockhandle varchar;
BEGIN
    CALL dbms_lock.allocate_unique (lockname => 'printer_lock', lockhandle => printer_lockhandle);
    IF ( printer_lockhandle IS NULL ) THEN
	RAISE EXCEPTION 'DBMS_LOCK.ALLOCATE_UNIQUE() FAIL';
    END IF;
END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory';

SELECT name, lockid FROM dbms_lock.dbms_lock_allocated;

SELECT pg_sleep(3);

-- Run dbms_lock.allocate_unique, the expiration date should be
-- updated then perform a request/release with the lock handle
DO $$
DECLARE
    lock_res int;
    printer_lockhandle varchar;
    DBMS_LOCK_X_MODE int := 6;
    rec record;
BEGIN
    CALL dbms_lock.allocate_unique (lockname => 'printer_lock', lockhandle => printer_lockhandle);
    IF ( printer_lockhandle IS NULL ) THEN
	RAISE EXCEPTION 'DBMS_LOCK.ALLOCATE_UNIQUE() FAIL';
    END IF;

    RAISE NOTICE 'Found lockhandle => %', printer_lockhandle;

    lock_res := dbms_lock.request(	lockhandle => printer_lockhandle,
					lockmode => DBMS_LOCK_X_MODE,
					timeout => 5,
					release_on_commit => false);

    IF ( lock_res <> 0 ) THEN
	RAISE EXCEPTION 'DBMS_LOCK.REQUEST() FAIL: %', lock_res;
    END IF;

    FOR rec IN SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory'
    LOOP
	RAISE NOTICE 'objid => % | mode => %', rec.objid, rec.mode;
    END LOOP;

    lock_res := dbms_lock.release(lockhandle => printer_lockhandle);

    IF ( lock_res <> 0 ) THEN
	RAISE EXCEPTION 'DBMS_LOCK.RELEASE() FAIL: %', lock_res;
    END IF;

END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory';

SELECT name, lockid FROM dbms_lock.dbms_lock_allocated;

