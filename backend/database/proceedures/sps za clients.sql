




















-- ===========================================================
-- Get Client Statistics
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_client_statistics(p_agent_id UUID)
RETURNS TABLE(
    total_contacts BIGINT,
    total_clients BIGINT,
    total_prospects BIGINT,
    today_birthdays BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) AS total_contacts,
        COUNT(CASE WHEN is_client = TRUE THEN 1 END) AS total_clients,
        COUNT(CASE WHEN is_client = FALSE THEN 1 END) AS total_prospects,
        COUNT(CASE WHEN EXTRACT(DAY FROM date_of_birth) = EXTRACT(DAY FROM CURRENT_DATE) 
                   AND EXTRACT(MONTH FROM date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE) 
              THEN 1 END) AS today_birthdays
    FROM client
    WHERE agent_id = p_agent_id AND is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Today's Birthdays
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_today_birthdays(p_agent_id UUID)
RETURNS TABLE(
    client_id UUID,
    first_name VARCHAR(50),
    surname VARCHAR(50),
    last_name VARCHAR(50),
    phone VARCHAR(20),
    email VARCHAR(100),
    insurance_type VARCHAR(50),
    date_of_birth DATE,
    age INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.first_name,
        c.surname,
        c.last_name,
        c.phone,
        c.email,
        c.insurance_type,
        c.date_of_birth,
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.date_of_birth))::INTEGER AS age
    FROM client c
    WHERE 
        c.agent_id = p_agent_id 
        AND c.is_active = TRUE
        AND EXTRACT(DAY FROM c.date_of_birth) = EXTRACT(DAY FROM CURRENT_DATE)
        AND EXTRACT(MONTH FROM c.date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE)
    ORDER BY c.first_name, c.surname;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Enhanced Client Statistics
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_enhanced_client_statistics(p_agent_id UUID)
RETURNS TABLE(
    total_clients BIGINT,
    total_prospects BIGINT,
    total_contacts BIGINT,
    active_policies BIGINT,
    expiring_policies BIGINT,
    today_birthdays BIGINT,
    month_birthdays BIGINT,
    new_this_week BIGINT,
    new_this_month BIGINT,
    insurance_type_breakdown JSONB
) AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_month_start DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_month_end DATE := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
BEGIN
    RETURN QUERY
    SELECT 
        -- Client counts
        COUNT(CASE WHEN c.is_client = TRUE THEN 1 END) AS total_clients,
        COUNT(CASE WHEN c.is_client = FALSE THEN 1 END) AS total_prospects,
        COUNT(*) AS total_contacts,
        
        -- Policy statistics
        (SELECT COUNT(*) FROM client_policy cp 
         INNER JOIN client cl ON cp.client_id = cl.client_id 
         WHERE cl.agent_id = p_agent_id AND cp.is_active = TRUE AND cp.status = 'Active') AS active_policies,
        
        (SELECT COUNT(*) FROM client_policy cp 
         INNER JOIN client cl ON cp.client_id = cl.client_id 
         WHERE cl.agent_id = p_agent_id AND cp.is_active = TRUE 
         AND cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days')) AS expiring_policies,
        
        -- Birthday statistics
        COUNT(CASE WHEN EXTRACT(MONTH FROM c.date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE) 
                   AND EXTRACT(DAY FROM c.date_of_birth) = EXTRACT(DAY FROM CURRENT_DATE) 
              THEN 1 END) AS today_birthdays,
        
        COUNT(CASE WHEN EXTRACT(MONTH FROM c.date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE) 
              THEN 1 END) AS month_birthdays,
        
        -- Recent additions
        COUNT(CASE WHEN c.created_date >= (CURRENT_DATE - INTERVAL '7 days') THEN 1 END) AS new_this_week,
        COUNT(CASE WHEN c.created_date >= (CURRENT_DATE - INTERVAL '30 days') THEN 1 END) AS new_this_month,
        
        -- Insurance type breakdown as JSON
        (SELECT jsonb_agg(
            jsonb_build_object(
                'insurance_type', insurance_type,
                'count', total_count,
                'client_count', client_count,
                'prospect_count', prospect_count
            )
        )
         FROM (
            SELECT 
                c2.insurance_type,
                COUNT(*) AS total_count,
                COUNT(CASE WHEN c2.is_client = TRUE THEN 1 END) AS client_count,
                COUNT(CASE WHEN c2.is_client = FALSE THEN 1 END) AS prospect_count
            FROM client c2 
            WHERE c2.agent_id = p_agent_id AND c2.is_active = TRUE
            GROUP BY c2.insurance_type
         ) breakdown) AS insurance_type_breakdown
         
    FROM client c 
    WHERE c.agent_id = p_agent_id AND c.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;
-- Enable extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. Upsert Client (Insert or Update)
-- ============================================================
CREATE OR REPLACE FUNCTION sp_upsert_client(
    p_client_id UUID DEFAULT NULL,
    p_agent_id UUID,
    p_first_name VARCHAR(50),
    p_surname VARCHAR(50),
    p_last_name VARCHAR(50),
    p_phone VARCHAR(20),
    p_email VARCHAR(100),
    p_address VARCHAR(500),
    p_national_id VARCHAR(20),
    p_date_of_birth DATE,
    p_is_client BOOLEAN,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_client_id UUID := p_client_id;
BEGIN
    IF v_client_id IS NULL THEN
        v_client_id := gen_random_uuid();
        
        INSERT INTO clients (
            client_id, agent_id, first_name, surname, last_name, phone, 
            email, address, national_id, date_of_birth, is_client, notes, created_date
        )
        VALUES (
            v_client_id, p_agent_id, p_first_name, p_surname, p_last_name, p_phone,
            p_email, p_address, p_national_id, p_date_of_birth, p_is_client, p_notes, NOW()
        );

        INSERT INTO activitylog (agent_id, activitytype, entitytype, entityid, description)
        VALUES (
            p_agent_id, 'client_created', 'client', v_client_id,
            p_first_name || ' ' || p_surname || ' added as ' || 
            CASE WHEN p_is_client THEN 'client' ELSE 'prospect' END
        );
    ELSE
        UPDATE clients 
        SET 
            first_name = p_first_name,
            surname = p_surname,
            last_name = p_last_name,
            phone = p_phone,
            email = p_email,
            address = p_address,
            national_id = p_national_id,
            date_of_birth = p_date_of_birth,
            is_client = p_is_client,
            notes = p_notes,
            modified_date = NOW()
        WHERE client_id = v_client_id;

        INSERT INTO activitylog (agent_id, activitytype, entitytype, entityid, description)
        VALUES (
            p_agent_id, 'client_updated', 'client', v_client_id,
            p_first_name || ' ' || p_surname || ' updated'
        );
    END IF;

    RETURN v_client_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 2. Get Clients (with search, filter)
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_clients(
    p_agent_id UUID,
    p_search_term VARCHAR(100) DEFAULT NULL,
    p_filter_type VARCHAR(20) DEFAULT 'all',
    p_insurance_type VARCHAR(50) DEFAULT NULL
)
RETURNS TABLE (
    client_id UUID,
    first_name VARCHAR,
    surname VARCHAR,
    last_name VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    address VARCHAR,
    national_id VARCHAR,
    date_of_birth DATE,
    is_client BOOLEAN,
    insurance_type VARCHAR,
    notes TEXT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP,
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
        c.client_id, c.first_name, c.surname, c.last_name, c.phone, c.email,
        c.address, c.national_id, c.date_of_birth, c.is_client, c.insurance_type,
        c.notes, c.created_date, c.modified_date,
        cp.policy_id, cp.policy_name, pt.typename, ic.companyname,
        cp.status, cp.startdate, cp.enddate, cp.notes
    FROM clients c
    LEFT JOIN clientpolicies cp 
        ON c.client_id = cp.client_id AND cp.is_active = TRUE
    LEFT JOIN policycatalog pc 
        ON cp.policycatalogid = pc.policycatalogid
    LEFT JOIN policytypes pt 
        ON pc.typeid = pt.typeid
    LEFT JOIN insurancecompanies ic 
        ON pc.companyid = ic.companyid
    WHERE c.agent_id = p_agent_id AND c.is_active = TRUE
      AND (p_search_term IS NULL OR 
           c.first_name ILIKE '%' || p_search_term || '%' OR
           c.surname ILIKE '%' || p_search_term || '%' OR
           c.last_name ILIKE '%' || p_search_term || '%' OR
           c.phone ILIKE '%' || p_search_term || '%' OR
           c.email ILIKE '%' || p_search_term || '%')
      AND (
          p_filter_type = 'all' OR
          (p_filter_type = 'clients' AND c.is_client = TRUE) OR
          (p_filter_type = 'prospects' AND c.is_client = FALSE)
      )
      AND (p_insurance_type IS NULL OR c.insurance_type = p_insurance_type)
    ORDER BY c.first_name, c.surname;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 3. Get Single Client (with policies + appointments)
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_client(
    p_client_id UUID,
    p_agent_id UUID
)
RETURNS SETOF RECORD AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.*, cp.policy_id, cp.policy_name, pt.typename, ic.companyname,
        cp.status, cp.startdate, cp.enddate, cp.notes
    FROM clients c
    LEFT JOIN clientpolicies cp 
        ON c.client_id = cp.client_id AND cp.is_active = TRUE
    LEFT JOIN policycatalog pc 
        ON cp.policycatalogid = pc.policycatalogid
    LEFT JOIN policytypes pt 
        ON pc.typeid = pt.typeid
    LEFT JOIN insurancecompanies ic 
        ON pc.companyid = ic.companyid
    WHERE c.client_id = p_client_id AND c.agent_id = p_agent_id AND c.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 4. Delete Client (Soft Delete)
-- ============================================================
CREATE OR REPLACE FUNCTION sp_delete_client(
    p_client_id UUID,
    p_agent_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    v_client_name TEXT;
    v_rows INT;
BEGIN
    SELECT first_name || ' ' || surname INTO v_client_name
    FROM clients WHERE client_id = p_client_id;

    UPDATE clients
    SET is_active = FALSE, modified_date = NOW()
    WHERE client_id = p_client_id AND agent_id = p_agent_id;

    UPDATE appointments
    SET is_active = FALSE, modified_date = NOW()
    WHERE client_id = p_client_id AND agent_id = p_agent_id;

    INSERT INTO activitylog (agent_id, activitytype, entitytype, entityid, description)
    VALUES (p_agent_id, 'client_deleted', 'client', p_client_id, v_client_name || ' deleted');

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 5. Client Statistics
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_client_statistics(
    p_agent_id UUID
)
RETURNS TABLE (
    total_contacts INT,
    total_clients INT,
    total_prospects INT,
    today_birthdays INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) AS total_contacts,
        SUM(CASE WHEN is_client THEN 1 ELSE 0 END) AS total_clients,
        SUM(CASE WHEN NOT is_client THEN 1 ELSE 0 END) AS total_prospects,
        COUNT(*) FILTER (
            WHERE EXTRACT(DAY FROM date_of_birth) = EXTRACT(DAY FROM CURRENT_DATE)
              AND EXTRACT(MONTH FROM date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE)
        ) AS today_birthdays
    FROM clients
    WHERE agent_id = p_agent_id AND is_active = TRUE;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 6. Today's Birthdays
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_today_birthdays(
    p_agent_id UUID
)
RETURNS TABLE (
    client_id UUID,
    first_name VARCHAR,
    surname VARCHAR,
    last_name VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    insurance_type VARCHAR,
    date_of_birth DATE,
    age INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id, c.first_name, c.surname, c.last_name, c.phone, c.email,
        c.insurance_type, c.date_of_birth,
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.date_of_birth))::INT AS age
    FROM clients c
    WHERE c.agent_id = p_agent_id AND c.is_active = TRUE
      AND EXTRACT(DAY FROM c.date_of_birth) = EXTRACT(DAY FROM CURRENT_DATE)
      AND EXTRACT(MONTH FROM c.date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE)
    ORDER BY c.first_name, c.surname;
END;
$$ LANGUAGE plpgsql;



