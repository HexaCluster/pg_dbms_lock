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

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' AND database = (SELECT oid FROM pg_database WHERE datname = current_database()) ORDER BY objid;

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

    FOR rec IN SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' AND database = (SELECT oid FROM pg_database WHERE datname = current_database()) ORDER BY objid
    LOOP
	RAISE NOTICE 'objid => % | mode => %', rec.objid, rec.mode;
    END LOOP;

    lock_res := dbms_lock.release(lockhandle => printer_lockhandle);

    IF ( lock_res <> 0 ) THEN
	RAISE EXCEPTION 'DBMS_LOCK.RELEASE() FAIL: %', lock_res;
    END IF;

END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' AND database = (SELECT oid FROM pg_database WHERE datname = current_database()) ORDER BY objid;

SELECT name, lockid FROM dbms_lock.dbms_lock_allocated;

TRUNCATE dbms_lock.dbms_lock_allocated;


-- Create two named lock to validate the lock id search
DO $$
DECLARE
    v_lockhandle varchar(200);
    v_result     integer;
    dbms_lock_x_mode integer := 6;
BEGIN
    CALL dbms_lock.allocate_unique('control_lock', v_lockhandle);

    v_result := dbms_lock.request(v_lockhandle, dbms_lock_x_mode);

    IF v_result <> 0 THEN
        RAISE NOTICE '%', (
           case 
              when v_result=1 then 'Timeout'
              when v_result=2 then 'Deadlock'
              when v_result=3 then 'Parameter Error'
              when v_result=4 then 'Already owned'
              when v_result=5 then 'Illegal Lock Handle'
            end);
    END IF;

END;
$$;

DO $$
DECLARE
    v_lockhandle varchar(200);
    v_result     integer;
    dbms_lock_x_mode integer := 6;
BEGIN
    CALL dbms_lock.allocate_unique('printer_lock', v_lockhandle);

    v_result := dbms_lock.request(v_lockhandle, dbms_lock_x_mode);

    IF v_result <> 0 THEN
        RAISE NOTICE '%', (
           case 
              when v_result=1 then 'Timeout'
              when v_result=2 then 'Deadlock'
              when v_result=3 then 'Parameter Error'
              when v_result=4 then 'Already owned'
              when v_result=5 then 'Illegal Lock Handle'
            end);
    END IF;

END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' AND database = (SELECT oid FROM pg_database WHERE datname = current_database()) ORDER BY objid;
SELECT name, lockid FROM dbms_lock.dbms_lock_allocated;

DO $$
DECLARE
    v_lockhandle varchar(200);
    v_result     integer;
BEGIN
    CALL dbms_lock.allocate_unique('control_lock', v_lockhandle);

    v_result := dbms_lock.release(v_lockhandle);

    IF v_result <> 0 THEN
        RAISE NOTICE '%', (
           case 
              when v_result=1 then 'Timeout'
              when v_result=2 then 'Deadlock'
              when v_result=3 then 'Parameter Error'
              when v_result=4 then 'Already owned'
              when v_result=5 then 'Illegal Lock Handle'
            end);
    END IF;

    CALL dbms_lock.allocate_unique('printer_lock', v_lockhandle);

    v_result := dbms_lock.release(v_lockhandle);

    IF v_result <> 0 THEN
        RAISE NOTICE '%', (
           case 
              when v_result=1 then 'Timeout'
              when v_result=2 then 'Deadlock'
              when v_result=3 then 'Parameter Error'
              when v_result=4 then 'Already owned'
              when v_result=5 then 'Illegal Lock Handle'
            end);
    END IF;

END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' AND database = (SELECT oid FROM pg_database WHERE datname = current_database()) ORDER BY objid;
SELECT name, lockid FROM dbms_lock.dbms_lock_allocated;

