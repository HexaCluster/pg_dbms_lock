-- Create a shared lock in the second session, it will be blocked
-- until the first session release the exclusive lock
DO $$
DECLARE
    v_result     integer;
    v_lockhandle varchar(200);
    dbms_lock_s_mode integer := 4;
BEGIN

    CALL dbms_lock.allocate_unique('control_lock', v_lockhandle);

    v_result := dbms_lock.request(v_lockhandle, dbms_lock_s_mode);

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

    INSERT INTO lock_test VALUES ('started', 2, clock_timestamp());

    CALL dbms_lock.sleep(2);

    INSERT INTO lock_test VALUES ('ended', 2, clock_timestamp());

    COMMIT;
END;
$$;

SELECT objid, mode FROM pg_locks WHERE objid IS NOT NULL AND locktype = 'advisory' ORDER BY objid;

