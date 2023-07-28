----
-- Script to create the base objects of the pg_dbms_lock extension
----

CREATE TABLE dbms_lock.dbms_lock_allocated (
	name varchar(128) PRIMARY KEY,		-- Name of the lock
	lockid bigint,				-- Lock identifier number
	expiration timestamp(0)			-- Planned lock expiration date
);
COMMENT ON TABLE dbms_lock.dbms_lock_allocated
    IS 'Describes user-allocated named locks.';
REVOKE ALL ON TABLE dbms_lock.dbms_lock_allocated FROM PUBLIC;

----
-- DBMS_LOCK.SLEEP
----
CREATE OR REPLACE PROCEDURE dbms_lock.sleep( seconds double precision )
    LANGUAGE PLPGSQL
    AS $$
BEGIN
    PERFORM pg_sleep(seconds);
END;
$$;

COMMENT ON PROCEDURE dbms_lock.sleep(double precision)
    IS 'Amount of seconds, to suspend the current session.';
REVOKE ALL ON PROCEDURE dbms_lock.sleep FROM PUBLIC;

----
-- DBMS_LOCK.ALLOCATE_UNIQUE
----
CREATE OR REPLACE PROCEDURE dbms_lock.allocate_unique (
	lockname IN varchar,
	lockhandle OUT varchar,
	expiration_secs IN integer DEFAULT 864000)
    LANGUAGE PLPGSQL
    AS $$
DECLARE
    query text;
    lockhandle_id int;
    expire_date timestamp;
    start_id int := 1073741824; -- Lock ids associated to lock name must be taken from this value
BEGIN
    IF lockname IS NULL THEN
	RAISE EXCEPTION 'Parameter error';
    END IF;

    BEGIN
	-- Set the expire date
	expire_date = clock_timestamp() + (expiration_secs::text || ' seconds')::interval;

	-- Verify if the lockhandle already exists
        SELECT lockid INTO lockhandle_id FROM dbms_lock.dbms_lock_allocated WHERE name = lockname;

        -- Get a new lock id based on lockid > start_id
        IF lockhandle_id IS NULL THEN
            SELECT max(lockid) + 1 INTO lockhandle_id FROM dbms_lock.dbms_lock_allocated;
            IF lockhandle_id IS NULL THEN
                lockhandle_id = start_id;
            END IF;
        END IF;
    
        -- Create an entry in the dbms_lock.dbms_lock_allocated table
        -- that will be completed by the call to dbms_lock.request
        query := format('INSERT INTO dbms_lock.dbms_lock_allocated VALUES (''%L'', %s, ''%L'') ON CONFLICT (name) DO UPDATE SET expiration = ''%L''', lockname, lockhandle_id, expire_date::timestamp(0), expire_date::timestamp(0));
        query := 'SELECT * FROM pg_background_result(pg_background_launch(''' || query || ''')) as (result TEXT)';
        EXECUTE query;

	-- Set output parameter
	lockhandle := lockhandle_id::varchar;

	-- Cleanup named locks that have expired
        DELETE FROM dbms_lock.dbms_lock_allocated WHERE expiration < clock_timestamp();
    EXCEPTION
      WHEN OTHERS THEN
        RAISE EXCEPTION 'cannot register named dbms_lock advisory lock (%) into table dbms_lock.dbms_lock_allocated: %', lockname, SQLERRM;
    END;
END;
$$;

COMMENT ON PROCEDURE dbms_lock.allocate_unique(varchar, varchar, integer)
    IS 'Allocates a unique lock identifier (in the range of 1073741824 to 1999999999) given a lock name.';
REVOKE ALL ON PROCEDURE dbms_lock.allocate_unique FROM PUBLIC;

----
-- DBMS_LOCK.REQUEST
----
CREATE OR REPLACE FUNCTION dbms_lock.request(
	id integer,				-- Numeric identifier of the lock
	lockmode integer DEFAULT 6,			-- Locking mode requested for lock
	timeout integer DEFAULT 32767,			-- Time in seconds to wait for successful conversion
	release_on_commit boolean DEFAULT false		-- If TRUE, release lock automatically on COMMIT or ROLLBACK
) RETURNS integer
    LANGUAGE PLPGSQL
    AS $$
DECLARE
    t_start timestamp with time zone := clock_timestamp();
    ret boolean := false;
    start_id int := 1073741824; -- Lock ids associated to lock name must be taken from this value
BEGIN
    IF id >= start_id THEN
	RAISE NOTICE 'Parameter error';
	return 3;
    END IF;

    -- We only support Exclusive and Shared locks
    IF lockmode != 6 and lockmode != 4 THEN
	RAISE NOTICE 'the DBMS_LOCK lock mode %d is not supported', lock_mode;
	RETURN 3;
    END IF;

    -- Limit timeout possibility to MAXWAIT
    IF timeout > 32767 THEN
	RAISE NOTICE 'Parameter error';
	return 3;
    END IF;

    IF EXISTS (SELECT objid FROM pg_locks WHERE locktype = 'advisory' AND pid = pg_backend_pid() AND objid = id) THEN
        RAISE WARNING 'Already own lock specified by id or lockhandle';
        RETURN 4;
    END IF;
    
    LOOP
	IF release_on_commit THEN
	    IF lockmode = 4 THEN
	        SELECT pg_try_advisory_xact_lock_shared(id) INTO ret;
	    ELSE
	        SELECT pg_try_advisory_xact_lock(id) INTO ret;
	    END IF;
	ELSE
	    IF lockmode = 4 THEN
	        SELECT pg_try_advisory_lock_shared(id) INTO ret;
	    ELSE
	        SELECT pg_try_advisory_lock(id) INTO ret;
	    END IF;
	END IF;
        IF ret THEN
	    -- Success
            RETURN 0;
        END IF;

        IF (clock_timestamp() > t_start + (timeout||' seconds')::interval) THEN
            -- The timeout exceeding
	    RAISE WARNING 'Could not acquire advisory lock in % seconds', timeout;
	    RETURN 1;
        END IF;

	-- The lock cannot be held, wait 10 ms and retry
        PERFORM pg_sleep(0.01);
    END LOOP;

END;
$$;

COMMENT ON FUNCTION dbms_lock.request(integer, integer, integer, boolean)
    IS 'Acquire a lock in the mode specified by the lockmode parameter. Note that only Exclusive (X_MODE) and Shared (S_MODE) mode are supported.';
REVOKE ALL ON FUNCTION dbms_lock.request FROM PUBLIC;

CREATE OR REPLACE FUNCTION dbms_lock.request(
	lockhandle varchar,				-- Numeric identifier of the lock
	lockmode integer DEFAULT 6,			-- Locking mode requested for lock
	timeout integer DEFAULT 32767,			-- Time in seconds to wait for successful conversion
	release_on_commit boolean DEFAULT false		-- If TRUE, release lock automatically on COMMIT or ROLLBACK
) RETURNS integer
    LANGUAGE PLPGSQL
    AS $$
DECLARE
    t_start timestamp with time zone := clock_timestamp();
    ret boolean := false;
    start_id int := 1073741824; -- Lock ids associated to lock name must be taken from this value
BEGIN
    IF lockhandle::integer < start_id THEN
	RAISE NOTICE 'Illegal lock handle';
	return 5;
    END IF;

    -- We only support Exclusive and Shared locks
    IF lockmode != 6 and lockmode != 4 THEN
	RAISE NOTICE 'the DBMS_LOCK lock mode %d is not supported', lock_mode;
	RETURN 3;
    END IF;

    -- Limit timeout possibility to MAXWAIT
    IF timeout > 32767 THEN
	RAISE NOTICE 'Parameter error';
	return 3;
    END IF;

    IF EXISTS (SELECT objid FROM pg_locks WHERE locktype = 'advisory' AND pid = pg_backend_pid() AND objid = lockhandle::integer) THEN
        RAISE WARNING 'Already own lock specified by id or lockhandle';
        RETURN 4;
    END IF;

    LOOP
	IF release_on_commit THEN
	    IF lockmode = 4 THEN
	        SELECT pg_try_advisory_xact_lock_shared(lockhandle::integer) INTO ret;
	    ELSE
	        SELECT pg_try_advisory_xact_lock(lockhandle::integer) INTO ret;
	    END IF;
	ELSE
	    IF lockmode = 4 THEN
	        SELECT pg_try_advisory_lock_shared(lockhandle::integer) INTO ret;
	    ELSE
	        SELECT pg_try_advisory_lock(lockhandle::integer) INTO ret;
	    END IF;
	END IF;

        IF ret THEN
	    -- Success
            RETURN 0;
        END IF;

        IF (clock_timestamp() > t_start + (timeout||' seconds')::interval) THEN
            -- The timeout exceeding
	    RAISE WARNING 'Could not acquire advisory lock in % seconds', timeout;
	    RETURN 1;
        END IF;

	-- The lock cannot be held, wait 10 ms and retry
        PERFORM pg_sleep(0.01);
    END LOOP;

END;
$$;

----
-- DBMS_LOCK.RELEASE
----
CREATE OR REPLACE FUNCTION dbms_lock.release(
	id integer				-- Numeric identifier of the lock
) RETURNS integer
    LANGUAGE PLPGSQL
    AS $$
DECLARE
    ret boolean := false;
    is_shared boolean;
    start_id int := 1073741824;
BEGIN
    IF id >= start_id THEN
	RAISE NOTICE 'Parameter error';
	return 3;
    END IF;

    -- Search if this is a shared advisory lock or not
    SELECT (CASE WHEN mode = 'ShareLock' THEN true ELSE false END) INTO is_shared
	FROM pg_locks WHERE objid = id AND locktype = 'advisory';
    IF NOT FOUND THEN
        -- The lock is not owned
        RAISE WARNING 'parameter error';
        RETURN 3;
    END IF;

    IF is_shared THEN
        SELECT pg_advisory_unlock_shared(id) INTO ret;
    ELSE
        SELECT pg_advisory_unlock(id) INTO ret;
    END IF;
    IF ret THEN
	-- Success
        RETURN 0;
    END IF;

    -- The lock is not owned
    RAISE WARNING 'Do not own lock %; cannot release', id;
    RETURN 4;

END;
$$;

COMMENT ON FUNCTION dbms_lock.release(integer)
    IS 'Releases a previously acquired lock.';
REVOKE ALL ON FUNCTION dbms_lock.release FROM PUBLIC;

CREATE OR REPLACE FUNCTION dbms_lock.release(
	lockhandle varchar			-- Handle for lock returned by ALLOCATE_UNIQUE
) RETURNS integer
    LANGUAGE PLPGSQL
    AS $$
DECLARE
    ret boolean := false;
    is_shared boolean;
    start_id int := 1073741824; -- Lock ids associated to lock name must be taken from this value
BEGIN
    IF lockhandle::integer < start_id THEN
	RAISE NOTICE 'Illegal lock handle';
	return 5;
    END IF;

    -- Search if this is a shared advisory lock or not
    SELECT (CASE WHEN mode = 'ShareLock' THEN true ELSE false END) INTO is_shared
	FROM pg_locks WHERE objid = lockhandle::integer AND locktype = 'advisory';
    IF NOT FOUND THEN
        -- The lock is not owned
        RAISE WARNING 'Do not own lock %; cannot release', lockhandle;
        RETURN 4;
    END IF;

    IF is_shared THEN
        SELECT pg_advisory_unlock_shared(lockhandle::integer) INTO ret;
    ELSE
        SELECT pg_advisory_unlock(lockhandle::integer) INTO ret;
    END IF;

    IF ret THEN
	-- Success
        RETURN 0;
    END IF;

    -- The lock is not owned
    RAISE WARNING 'Do not own lock %; cannot release', lockhandle::integer;
    RETURN 4;

END;
$$;

