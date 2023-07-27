-- Create an exlusive lock in the first session
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

    INSERT INTO lock_test VALUES ('started', 1, clock_timestamp());

    COMMIT;

END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

-- Wait 5 seconds to give time to others tests sessions to meet the lock.
SELECT pg_sleep(5);

-- now release the lock
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

    INSERT INTO lock_test VALUES ('ended', 1, clock_timestamp());

    COMMIT;
END;
$$;

-- wait 5 seconds to give time to two other sessions to finish and release locks
SELECT pg_sleep(5);

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

