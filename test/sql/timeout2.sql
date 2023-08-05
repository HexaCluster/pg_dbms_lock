-- Create an exlusive lock in the first session
DO $$
DECLARE
    v_result     integer;
    dbms_lock_x_mode integer := 6;
BEGIN

    -- should fail with timeout
    v_result := dbms_lock.request(123, dbms_lock_x_mode, 1);

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

