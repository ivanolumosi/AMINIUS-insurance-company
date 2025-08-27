-- ============================================================
-- Prereqs
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1) Upsert Client (Create/Update) -> returns client_id (UUID)
-- ============================================================
DROP FUNCTION IF EXISTS sp_upsert_client(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, BOOLEAN, VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION sp_upsert_client(
    p_client_id UUID,           -- 1st parameter (can be NULL for create)
    p_agent_id UUID,            -- 2nd parameter
    p_first_name VARCHAR(50),   -- 3rd parameter
    p_surname VARCHAR(50),      -- 4th parameter
    p_last_name VARCHAR(50),    -- 5th parameter
    p_phone_number VARCHAR(20), -- 6th parameter
    p_email VARCHAR(100),       -- 7th parameter
    p_address VARCHAR(500),     -- 8th parameter
    p_national_id VARCHAR(20),  -- 9th parameter
    p_date_of_birth DATE,       -- 10th parameter
    p_is_client BOOLEAN,        -- 11th parameter
    p_insurance_type VARCHAR(50), -- 12th parameter
    p_notes TEXT DEFAULT NULL   -- 13th parameter
) RETURNS UUID AS $$
DECLARE
    v_client_id UUID;
BEGIN
    IF p_client_id IS NULL THEN
        -- Create new client
        v_client_id := gen_random_uuid();

        INSERT INTO clients (
            client_id, agent_id, first_name, surname, last_name,
            phone_number, email, address, national_id,
            date_of_birth, is_client, insurance_type, notes
        ) VALUES (
            v_client_id, p_agent_id, p_first_name, p_surname, p_last_name,
            p_phone_number, p_email, p_address, p_national_id,
            p_date_of_birth, p_is_client, p_insurance_type, p_notes
        );

        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description)
        VALUES (
            p_agent_id, 'client_created', 'client', v_client_id,
            p_first_name || ' ' || p_surname || ' added as ' ||
            CASE WHEN p_is_client THEN 'client' ELSE 'prospect' END
        );

    ELSE
        -- Update existing client
        v_client_id := p_client_id;

        UPDATE clients
        SET first_name   = p_first_name,
            surname      = p_surname,
            last_name    = p_last_name,
            phone_number = p_phone_number,
            email        = p_email,
            address      = p_address,
            national_id  = p_national_id,
            date_of_birth= p_date_of_birth,
            is_client    = p_is_client,
            insurance_type = p_insurance_type,
            notes        = p_notes,
            modified_date= NOW()
        WHERE client_id = v_client_id;

        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description)
        VALUES (
            p_agent_id, 'client_updated', 'client', v_client_id,
            p_first_name || ' ' || p_surname || ' updated'
        );
    END IF;

    RETURN v_client_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 2) Create sp_convert_to_client function (missing)
-- ============================================================
DROP FUNCTION IF EXISTS sp_convert_to_client(UUID, UUID);

CREATE OR REPLACE FUNCTION sp_convert_to_client(
    p_client_id UUID,
    p_agent_id UUID
) RETURNS TABLE(
    rows_affected INTEGER
) AS $$
DECLARE
    v_rows INTEGER := 0;
    v_client_name TEXT;
BEGIN
    -- Get client name for activity log
    SELECT CONCAT(first_name, ' ', surname)
    INTO v_client_name
    FROM clients
    WHERE client_id = p_client_id AND agent_id = p_agent_id;

    -- Update prospect to client
    UPDATE clients
    SET is_client = TRUE,
        modified_date = NOW()
    WHERE client_id = p_client_id
      AND agent_id = p_agent_id
      AND is_client = FALSE
      AND is_active = TRUE;
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    -- Log activity if update was successful
    IF v_rows > 0 THEN
        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description)
        VALUES (
            p_agent_id, 
            'prospect_converted', 
            'client', 
            p_client_id,
            COALESCE(v_client_name, 'Unknown') || ' converted from prospect to client'
        );
    END IF;

    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 2) Get Clients
-- ============================================================
DROP FUNCTION IF EXISTS sp_get_clients(
    UUID, VARCHAR, VARCHAR, VARCHAR
);

CREATE OR REPLACE FUNCTION sp_get_clients(
    p_agent_id UUID,
    p_search_term VARCHAR(100) DEFAULT NULL,
    p_filter_type VARCHAR(20)  DEFAULT 'all',
    p_insurance_type VARCHAR(50) DEFAULT NULL
) RETURNS TABLE (
    client_id UUID,
    first_name VARCHAR,
    surname VARCHAR,
    last_name VARCHAR,
    phone_number VARCHAR,
    email VARCHAR,
    address VARCHAR,
    national_id VARCHAR,
    date_of_birth DATE,
    is_client BOOLEAN,
    insurance_type VARCHAR,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    policy_id UUID,
    policy_name VARCHAR,
    policy_type VARCHAR,
    policy_company VARCHAR,
    policy_status VARCHAR,
    policy_start_date DATE,
    policy_end_date DATE,
    policy_notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.first_name,
        c.surname,
        c.last_name,
        c.phone_number,
        c.email,
        c.address,
        c.national_id,
        c.date_of_birth,
        c.is_client,
        c.insurance_type,
        c.notes,
        c.created_date,
        c.modified_date,
        cp.policy_id,
        cp.policy_name,
        pt.type_name AS policy_type,
        ic.company_name AS policy_company,
        cp.status     AS policy_status,
        cp.start_date AS policy_start_date,
        cp.end_date   AS policy_end_date,
        cp.notes      AS policy_notes
    FROM clients c
    LEFT JOIN client_policies cp ON c.client_id = cp.client_id AND cp.is_active = TRUE
    LEFT JOIN policy_catalog pc  ON cp.policy_catalog_id = pc.policy_catalog_id
    LEFT JOIN policy_types pt    ON pc.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
    WHERE c.agent_id = p_agent_id
      AND c.is_active = TRUE
      AND (
          p_search_term IS NULL OR
          c.first_name   ILIKE '%' || p_search_term || '%' OR
          c.surname      ILIKE '%' || p_search_term || '%' OR
          c.last_name    ILIKE '%' || p_search_term || '%' OR
          c.phone_number ILIKE '%' || p_search_term || '%' OR
          c.email        ILIKE '%' || p_search_term || '%'
      )
      AND (
          p_filter_type = 'all' OR
          (p_filter_type = 'clients'   AND c.is_client = TRUE)  OR
          (p_filter_type = 'prospects' AND c.is_client = FALSE)
      )
      AND (p_insurance_type IS NULL OR c.insurance_type = p_insurance_type)
    ORDER BY c.first_name, c.surname;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 3) Get Client
-- ============================================================
DROP FUNCTION IF EXISTS sp_get_client(UUID, UUID);

CREATE OR REPLACE FUNCTION sp_get_client(
    p_client_id UUID,
    p_agent_id UUID
) RETURNS TABLE (
    client_id UUID,
    agent_id UUID,
    first_name VARCHAR,
    surname VARCHAR,
    last_name VARCHAR,
    phone_number VARCHAR,
    email VARCHAR,
    address VARCHAR,
    national_id VARCHAR,
    date_of_birth DATE,
    is_client BOOLEAN,
    insurance_type VARCHAR,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    is_active BOOLEAN,
    policy_id UUID,
    policy_name VARCHAR,
    policy_type VARCHAR,
    policy_company VARCHAR,
    policy_status VARCHAR,
    policy_start_date DATE,
    policy_end_date DATE,
    policy_notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.agent_id,
        c.first_name,
        c.surname,
        c.last_name,
        c.phone_number,
        c.email,
        c.address,
        c.national_id,
        c.date_of_birth,
        c.is_client,
        c.insurance_type,
        c.notes,
        c.created_date,
        c.modified_date,
        c.is_active,
        cp.policy_id,
        cp.policy_name,
        pt.type_name AS policy_type,
        ic.company_name AS policy_company,
        cp.status     AS policy_status,
        cp.start_date AS policy_start_date,
        cp.end_date   AS policy_end_date,
        cp.notes      AS policy_notes
    FROM clients c
    LEFT JOIN client_policies cp ON c.client_id = cp.client_id AND cp.is_active = TRUE
    LEFT JOIN policy_catalog pc  ON cp.policy_catalog_id = pc.policy_catalog_id
    LEFT JOIN policy_types pt    ON pc.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
    WHERE c.client_id = p_client_id
      AND c.agent_id  = p_agent_id
      AND c.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 3b) Get Client Appointments
-- ============================================================
DROP FUNCTION IF EXISTS sp_get_client_appointments(UUID, UUID);

CREATE OR REPLACE FUNCTION sp_get_client_appointments(
    p_client_id UUID,
    p_agent_id UUID
) RETURNS TABLE(
    appointment_id UUID,
    title VARCHAR,
    appointment_date DATE,
    start_time VARCHAR,  -- Changed from TIME to VARCHAR
    end_time VARCHAR,    -- Changed from TIME to VARCHAR
    type VARCHAR,
    status VARCHAR,
    location VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.appointment_id,
        a.title,
        a.appointment_date,
        a.start_time::VARCHAR,  -- Cast TIME to VARCHAR
        a.end_time::VARCHAR,    -- Cast TIME to VARCHAR
        a.type,
        a.status,
        a.location
    FROM appointments a
    WHERE a.client_id = p_client_id
      AND a.agent_id  = p_agent_id
      AND a.is_active = TRUE
    ORDER BY a.appointment_date DESC, a.start_time DESC;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 4) Delete Client
-- ============================================================
DROP FUNCTION IF EXISTS sp_delete_client(UUID, UUID);

CREATE OR REPLACE FUNCTION sp_delete_client(
    p_client_id UUID,
    p_agent_id UUID
) RETURNS INTEGER AS $$
DECLARE
    v_client_name TEXT;
    v_rows INT;
    v_agent_exists BOOLEAN := FALSE;
BEGIN
    -- Check if agent exists
    SELECT EXISTS(SELECT 1 FROM agent WHERE agent_id = p_agent_id) INTO v_agent_exists;
    
    -- Get client name
    SELECT CONCAT(first_name, ' ', surname)
    INTO v_client_name
    FROM clients
    WHERE client_id = p_client_id;

    -- Soft delete client
    UPDATE clients
    SET is_active = FALSE,
        modified_date = NOW()
    WHERE client_id = p_client_id
      AND agent_id = p_agent_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    -- Soft delete related appointments
    UPDATE appointments
    SET is_active = FALSE,
        modified_date = NOW()
    WHERE client_id = p_client_id
      AND agent_id = p_agent_id;

    -- Only log activity if agent exists (to avoid foreign key constraint)
    IF v_rows > 0 AND v_agent_exists THEN
        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description)
        VALUES (
            p_agent_id, 
            'client_deleted', 
            'client', 
            p_client_id, 
            COALESCE(v_client_name, 'Unknown client') || ' deleted'
        );
    END IF;

    RETURN v_rows;
END;
$$ LANGUAGE plpgsql;
-- ============================================================
-- 5) Client Statistics
-- ============================================================
DROP FUNCTION IF EXISTS sp_get_client_statistics(UUID);

CREATE OR REPLACE FUNCTION sp_get_client_statistics(
    p_agent_id UUID
) RETURNS TABLE(
    total_contacts BIGINT,
    total_clients BIGINT,
    total_prospects BIGINT,
    today_birthdays BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) AS total_contacts,
        SUM(CASE WHEN is_client THEN 1 ELSE 0 END) AS total_clients,
        SUM(CASE WHEN NOT is_client THEN 1 ELSE 0 END) AS total_prospects,
        COUNT(*) FILTER (
            WHERE EXTRACT(DAY FROM date_of_birth) = EXTRACT(DAY FROM NOW())
              AND EXTRACT(MONTH FROM date_of_birth) = EXTRACT(MONTH FROM NOW())
        ) AS today_birthdays
    FROM clients
    WHERE agent_id = p_agent_id
      AND is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 6) Today Birthdays
-- ============================================================
DROP FUNCTION IF EXISTS sp_get_today_birthdays(UUID);

CREATE OR REPLACE FUNCTION sp_get_today_birthdays(
    p_agent_id UUID
) RETURNS TABLE(
    client_id UUID,
    first_name VARCHAR,
    surname VARCHAR,
    last_name VARCHAR,
    phone_number VARCHAR,
    email VARCHAR,
    insurance_type VARCHAR,
    date_of_birth DATE,
    age INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.first_name,
        c.surname,
        c.last_name,
        c.phone_number,
        c.email,
        c.insurance_type,
        c.date_of_birth,
        EXTRACT(YEAR FROM AGE(NOW(), c.date_of_birth))::INT AS age
    FROM clients c
    WHERE c.agent_id = p_agent_id
      AND c.is_active = TRUE
      AND EXTRACT(DAY FROM c.date_of_birth) = EXTRACT(DAY FROM NOW())
      AND EXTRACT(MONTH FROM c.date_of_birth) = EXTRACT(MONTH FROM NOW())
    ORDER BY c.first_name, c.surname;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7) Get All Clients
-- ============================================================
DROP FUNCTION IF EXISTS sp_get_all_clients(UUID, VARCHAR, VARCHAR, BOOLEAN, INT, INT);

CREATE OR REPLACE FUNCTION sp_get_all_clients(
    p_agent_id UUID,
    p_search_term VARCHAR(100)  DEFAULT NULL,
    p_insurance_type VARCHAR(50) DEFAULT NULL,
    p_is_client BOOLEAN DEFAULT NULL,
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 50
) RETURNS TABLE(
    client_id UUID,
    first_name VARCHAR,
    surname VARCHAR,
    last_name VARCHAR,
    phone_number VARCHAR,
    email VARCHAR,
    address VARCHAR,
    national_id VARCHAR,
    date_of_birth DATE,
    age INT,
    is_client BOOLEAN,
    insurance_type VARCHAR,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    policy_count BIGINT,
    next_expiry_date DATE
) AS $$
DECLARE
    v_offset INT := (p_page_number - 1) * p_page_size;
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.first_name,
        c.surname,
        c.last_name,
        c.phone_number,
        c.email,
        c.address,
        c.national_id,
        c.date_of_birth,
        EXTRACT(YEAR FROM AGE(NOW(), c.date_of_birth))::INT AS age,
        c.is_client,
        c.insurance_type,
        c.notes,
        c.created_date,
        c.modified_date,
        COUNT(cp.policy_id) AS policy_count,
        MAX(cp.end_date)    AS next_expiry_date
    FROM clients c
    LEFT JOIN client_policies cp
      ON c.client_id = cp.client_id
     AND cp.is_active = TRUE
    WHERE c.agent_id  = p_agent_id
      AND c.is_active = TRUE
      AND (
          p_search_term IS NULL OR
          c.first_name   ILIKE '%' || p_search_term || '%' OR
          c.surname      ILIKE '%' || p_search_term || '%' OR
          c.last_name    ILIKE '%' || p_search_term || '%' OR
          c.phone_number ILIKE '%' || p_search_term || '%' OR
          c.email        ILIKE '%' || p_search_term || '%'
      )
      AND (p_insurance_type IS NULL OR c.insurance_type = p_insurance_type)
      AND (p_is_client IS NULL OR c.is_client = p_is_client)
    GROUP BY c.client_id, c.first_name, c.surname, c.last_name,
             c.phone_number, c.email, c.address, c.national_id,
             c.date_of_birth, c.is_client, c.insurance_type,
             c.notes, c.created_date, c.modified_date
    ORDER BY c.created_date DESC
    OFFSET v_offset LIMIT p_page_size;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 8) Search Clients
-- ============================================================
DROP FUNCTION IF EXISTS sp_search_clients(UUID, VARCHAR);

CREATE OR REPLACE FUNCTION sp_search_clients(
    p_agent_id UUID,
    p_search_term VARCHAR(100)
) RETURNS TABLE (
    client_id UUID,
    first_name VARCHAR,
    surname VARCHAR,
    last_name VARCHAR,
    phone_number VARCHAR,
    email VARCHAR,
    is_client BOOLEAN,
    insurance_type VARCHAR,
    age INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.first_name,
        c.surname,
        c.last_name,
        c.phone_number,
        c.email,
        c.is_client,
        c.insurance_type,
        EXTRACT(YEAR FROM AGE(NOW(), c.date_of_birth))::INT AS age
    FROM clients c
    WHERE c.agent_id = p_agent_id
      AND c.is_active = TRUE
      AND (
          c.first_name   ILIKE '%' || p_search_term || '%' OR
          c.surname      ILIKE '%' || p_search_term || '%' OR
          c.last_name    ILIKE '%' || p_search_term || '%' OR
          c.phone_number ILIKE '%' || p_search_term || '%' OR
          c.email        ILIKE '%' || p_search_term || '%' OR
          c.national_id  ILIKE '%' || p_search_term || '%'
      )
    ORDER BY c.first_name, c.surname;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
--sp_get_clients_by_insurance_type 
-- ============================================================
DROP FUNCTION IF EXISTS sp_get_clients_by_insurance_type(UUID, VARCHAR);

CREATE OR REPLACE FUNCTION sp_get_clients_by_insurance_type(
    p_agent_id UUID,
    p_insurance_type VARCHAR
) RETURNS TABLE(
    client_id UUID,
    first_name VARCHAR,
    surname VARCHAR,
    last_name VARCHAR,
    phone_number VARCHAR,
    email VARCHAR,
    address VARCHAR,
    date_of_birth DATE,
    age INTEGER,
    is_client BOOLEAN,
    insurance_type VARCHAR,
    created_date TIMESTAMPTZ,
    policy_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.client_id,
        c.first_name,
        c.surname,
        c.last_name,
        c.phone_number,
        c.email,
        c.address,
        c.date_of_birth,
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.date_of_birth))::INTEGER as age,
        c.is_client,
        c.insurance_type,
        c.created_date,
        COUNT(cp.policy_id) as policy_count
    FROM clients c
    LEFT JOIN client_policies cp ON c.client_id = cp.client_id AND cp.is_active = TRUE
    WHERE
        c.agent_id = p_agent_id
        AND c.is_active = TRUE
        AND c.insurance_type = p_insurance_type
    GROUP BY
        c.client_id, c.first_name, c.surname, c.last_name, c.phone_number,
        c.email, c.address, c.date_of_birth, c.is_client, c.insurance_type, c.created_date
    ORDER BY c.first_name, c.surname;
END;
$$ LANGUAGE plpgsql;


-- Get client details for getClientWithPolicies
DROP FUNCTION IF EXISTS sp_get_client_with_policies_client(UUID, UUID);

CREATE OR REPLACE FUNCTION sp_get_client_with_policies_client(
    p_client_id UUID,
    p_agent_id UUID
) RETURNS TABLE(
    client_id UUID,
    agent_id UUID,
    first_name VARCHAR,
    surname VARCHAR,
    last_name VARCHAR,
    phone_number VARCHAR,
    email VARCHAR,
    address VARCHAR,
    national_id VARCHAR,
    date_of_birth DATE,
    age INTEGER,
    is_client BOOLEAN,
    insurance_type VARCHAR,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.agent_id,
        c.first_name,
        c.surname,
        c.last_name,
        c.phone_number,
        c.email,
        c.address,
        c.national_id,
        c.date_of_birth,
        EXTRACT(YEAR FROM AGE(NOW(), c.date_of_birth))::INTEGER AS age,
        c.is_client,
        c.insurance_type,
        c.notes,
        c.created_date,
        c.modified_date,
        c.is_active
    FROM clients c
    WHERE c.client_id = p_client_id
      AND c.agent_id = p_agent_id
      AND c.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- Get policies for getClientWithPolicies
DROP FUNCTION IF EXISTS sp_get_client_with_policies_policies(UUID, UUID);

CREATE OR REPLACE FUNCTION sp_get_client_with_policies_policies(
    p_client_id UUID,
    p_agent_id UUID
) RETURNS TABLE(
    policy_id UUID,
    client_id UUID,
    policy_name VARCHAR,
    policy_type VARCHAR,
    company_name VARCHAR,
    status VARCHAR,
    start_date DATE,
    end_date DATE,
    days_until_expiry INTEGER,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cp.policy_id,
        cp.client_id,
        cp.policy_name,
        pt.type_name AS policy_type,
        ic.company_name,
        cp.status,
        cp.start_date,
        cp.end_date,
        (cp.end_date - CURRENT_DATE)::INTEGER AS days_until_expiry,
        cp.notes,
        cp.created_date,
        cp.modified_date,
        cp.is_active
    FROM client_policies cp
    LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    LEFT JOIN policy_types pt ON pc.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
    INNER JOIN clients c ON cp.client_id = c.client_id
    WHERE cp.client_id = p_client_id
      AND c.agent_id = p_agent_id
      AND cp.is_active = TRUE
      AND c.is_active = TRUE
    ORDER BY cp.created_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Get recent appointments for getClientWithPolicies
DROP FUNCTION IF EXISTS sp_get_client_with_policies_appointments(UUID, UUID);

CREATE OR REPLACE FUNCTION sp_get_client_with_policies_appointments(
    p_client_id UUID,
    p_agent_id UUID
) RETURNS TABLE(
    appointment_id UUID,
    title VARCHAR,
    appointment_date DATE,
    start_time VARCHAR,
    end_time VARCHAR,
    type VARCHAR,
    status VARCHAR,
    location VARCHAR,
    priority VARCHAR,
    notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.title,
        a.appointment_date,
        a.start_time::VARCHAR,
        a.end_time::VARCHAR,
        a.type,
        a.status,
        a.location,
        a.priority,
        a.notes
    FROM appointments a
    WHERE a.client_id = p_client_id
      AND a.agent_id = p_agent_id
      AND a.is_active = TRUE
    ORDER BY a.appointment_date DESC, a.start_time DESC
    LIMIT 5; -- Get only recent appointments
END;
$$ LANGUAGE plpgsql;

-- Get active reminders for getClientWithPolicies
DROP FUNCTION IF EXISTS sp_get_client_with_policies_reminders(UUID, UUID);

CREATE OR REPLACE FUNCTION sp_get_client_with_policies_reminders(
    p_client_id UUID,
    p_agent_id UUID
) RETURNS TABLE(
    reminder_id UUID,
    reminder_type VARCHAR,
    title VARCHAR,
    description TEXT,
    reminder_date DATE,
    reminder_time VARCHAR,
    priority VARCHAR,
    status VARCHAR,
    created_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.reminder_id,
        r.reminder_type,
        r.title,
        r.description,
        r.reminder_date,
        r.reminder_time::VARCHAR,
        r.priority,
        r.status,
        r.created_date
    FROM reminders r
    WHERE r.client_id = p_client_id
      AND r.agent_id = p_agent_id
      AND r.status = 'Active'
    ORDER BY r.reminder_date ASC, r.reminder_time ASC
    LIMIT 5; -- Get only active reminders
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9) Navbar Badge Counts
-- ============================================================
DROP FUNCTION IF EXISTS sp_getnavbarbadgecounts(UUID);

CREATE OR REPLACE FUNCTION sp_getnavbarbadgecounts(
    p_agentid UUID
) RETURNS TABLE(
    clientscount BIGINT,
    policiescount BIGINT,
    reminderscount BIGINT,
    appointmentscount BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT CASE WHEN c.is_active = TRUE THEN c.client_id END) AS clientscount,
        COUNT(DISTINCT CASE WHEN p.is_active = TRUE THEN p.policy_id END) AS policiescount,
        COUNT(DISTINCT CASE WHEN r.status = 'Active' THEN r.reminder_id END) AS reminderscount,
        COUNT(DISTINCT CASE
            WHEN a.is_active = TRUE
            AND a.status NOT IN ('Completed', 'Cancelled')
            THEN a.appointment_id END) AS appointmentscount
    FROM (SELECT 1 AS dummy) d
    LEFT JOIN clients c ON c.agent_id = p_agentid
    LEFT JOIN client_policies p ON p.client_id = c.client_id
    LEFT JOIN reminders r ON r.agent_id = p_agentid
    LEFT JOIN appointments a ON a.agent_id = p_agentid;
END;
$$ LANGUAGE plpgsql;

