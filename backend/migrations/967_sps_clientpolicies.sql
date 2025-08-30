-- ============================================================
-- FIXED STORED PROCEDURES - ERROR RESOLUTION
-- ============================================================

-- First, drop all existing functions to avoid conflicts
DROP FUNCTION IF EXISTS sp_get_client_policies(UUID, UUID, VARCHAR(20), BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS sp_create_client_policy(UUID, VARCHAR(100), DATE, DATE, VARCHAR(20), TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_update_client_policy(UUID, VARCHAR(100), VARCHAR(20), DATE, DATE, TEXT, UUID, UUID, UUID, BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS sp_delete_client_policy(UUID, BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS sp_upsert_client_policy(UUID, VARCHAR(100), DATE, DATE, UUID, VARCHAR(20), TEXT, UUID, UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_get_clients_with_policies(UUID, UUID, BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS sp_soft_delete_client_policy(UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_get_policy_by_id(UUID) CASCADE;
DROP FUNCTION IF EXISTS sp_get_expiring_policies(UUID, INTEGER, VARCHAR(20)) CASCADE;

-- ============================================================
-- 1. FIXED: sp_get_client_policies - Fix EXTRACT issue
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_client_policies(
    p_client_id  UUID DEFAULT NULL,
    p_agent_id   UUID DEFAULT NULL,
    p_status     VARCHAR(20) DEFAULT NULL,
    p_is_active  BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    policy_id           UUID,
    client_id           UUID,
    policy_name         VARCHAR(100),
    status              VARCHAR(20),
    start_date          DATE,
    end_date            DATE,
    notes               TEXT,
    created_date        TIMESTAMPTZ,
    modified_date       TIMESTAMPTZ,
    is_active           BOOLEAN,
    policy_catalog_id   UUID,
    catalog_policy_name VARCHAR(100),
    type_id             UUID,
    type_name           VARCHAR(100),
    company_id          UUID,
    company_name        VARCHAR(100),
    days_until_expiry   INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cp.policy_id,
        cp.client_id,
        cp.policy_name,
        cp.status,
        cp.start_date,
        cp.end_date,
        cp.notes,
        cp.created_date,
        cp.modified_date,
        cp.is_active,
        cp.policy_catalog_id,
        pc.policy_name AS catalog_policy_name,
        cp.type_id,
        pt.type_name,
        cp.company_id,
        ic.company_name,
        -- FIXED: Cast the interval calculation to avoid EXTRACT error
        (cp.end_date - CURRENT_DATE)::INTEGER AS days_until_expiry
    FROM client_policies cp
    LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    LEFT JOIN policy_types pt   ON cp.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE (p_client_id IS NULL OR cp.client_id = p_client_id)
      AND (p_agent_id  IS NULL OR pc.agent_id  = p_agent_id)
      AND (p_status    IS NULL OR cp.status    = p_status)
      AND (p_is_active IS NULL OR cp.is_active = p_is_active)
    ORDER BY cp.end_date DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 2. FIXED: sp_get_policy_by_id - Fix EXTRACT issue
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_policy_by_id(p_policy_id UUID)
RETURNS TABLE (
    policy_id           UUID,
    client_id           UUID,
    policy_name         VARCHAR(100),
    status              VARCHAR(20),
    start_date          DATE,
    end_date            DATE,
    notes               TEXT,
    created_date        TIMESTAMPTZ,
    modified_date       TIMESTAMPTZ,
    is_active           BOOLEAN,
    policy_catalog_id   UUID,
    catalog_policy_name VARCHAR(100),
    type_id             UUID,
    type_name           VARCHAR(100),
    company_id          UUID,
    company_name        VARCHAR(100),
    days_until_expiry   INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cp.policy_id,
        cp.client_id,
        cp.policy_name,
        cp.status,
        cp.start_date,
        cp.end_date,
        cp.notes,
        cp.created_date,
        cp.modified_date,
        cp.is_active,
        cp.policy_catalog_id,
        pc.policy_name AS catalog_policy_name,
        cp.type_id,
        pt.type_name,
        cp.company_id,
        ic.company_name,
        -- FIXED: Cast the interval calculation to avoid EXTRACT error
        (cp.end_date - CURRENT_DATE)::INTEGER AS days_until_expiry
    FROM client_policies cp
    LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    LEFT JOIN policy_types pt   ON cp.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE cp.policy_id = p_policy_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 3. FIXED: sp_create_client_policy - Ensure unique signature
-- ============================================================
CREATE OR REPLACE FUNCTION sp_create_client_policy(
    p_client_id UUID,
    p_policy_name VARCHAR(100),
    p_start_date DATE,
    p_end_date DATE,
    p_status VARCHAR(20) DEFAULT 'Active',
    p_notes TEXT DEFAULT NULL,
    p_policy_catalog_id UUID DEFAULT NULL
)
RETURNS TABLE(policy_id UUID) AS $$
DECLARE
    v_policy_id UUID := gen_random_uuid();
    v_company_id UUID;
    v_type_id UUID;
BEGIN
    -- If policy_catalog_id is provided, get the related IDs
    IF p_policy_catalog_id IS NOT NULL THEN
        SELECT company_id, type_id
        INTO v_company_id, v_type_id
        FROM policy_catalog
        WHERE policy_catalog_id = p_policy_catalog_id;
    END IF;

    INSERT INTO client_policies (
        policy_id, client_id, policy_name, status, start_date, end_date,
        notes, policy_catalog_id, type_id, company_id, is_active, created_date
    )
    VALUES (
        v_policy_id, p_client_id, p_policy_name, p_status, p_start_date, p_end_date,
        p_notes, p_policy_catalog_id, v_type_id, v_company_id, TRUE, NOW()
    );
    
    RETURN QUERY SELECT v_policy_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 4. FIXED: sp_upsert_client_policy - Fix ambiguous column reference
-- ============================================================
CREATE OR REPLACE FUNCTION sp_upsert_client_policy(
    p_client_id UUID,
    p_policy_name VARCHAR(100),
    p_start_date DATE,
    p_end_date DATE,
    p_policy_id UUID DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT 'Active',
    p_notes TEXT DEFAULT NULL,
    p_policy_catalog_id UUID DEFAULT NULL,
    p_type_id UUID DEFAULT NULL,
    p_company_id UUID DEFAULT NULL
)
RETURNS TABLE(policy_id UUID) AS $$
DECLARE
    v_policy_id UUID;
    v_final_type_id UUID;
    v_final_company_id UUID;
BEGIN
    -- FIXED: Use table alias to avoid ambiguous column reference
    IF p_policy_id IS NOT NULL AND EXISTS (SELECT 1 FROM client_policies cp WHERE cp.policy_id = p_policy_id) THEN
        v_policy_id := p_policy_id;
        
        -- Determine final type_id and company_id
        IF p_policy_catalog_id IS NOT NULL THEN
            SELECT pc.type_id, pc.company_id INTO v_final_type_id, v_final_company_id
            FROM policy_catalog pc WHERE pc.policy_catalog_id = p_policy_catalog_id;
        ELSE
            v_final_type_id := p_type_id;
            v_final_company_id := p_company_id;
        END IF;
        
        UPDATE client_policies
        SET 
            policy_name = p_policy_name,
            status = p_status,
            start_date = p_start_date,
            end_date = p_end_date,
            notes = p_notes,
            policy_catalog_id = p_policy_catalog_id,
            type_id = v_final_type_id,
            company_id = v_final_company_id,
            modified_date = NOW()
        WHERE client_policies.policy_id = p_policy_id;
    ELSE
        -- Creating new policy
        v_policy_id := gen_random_uuid();
        
        -- Determine final type_id and company_id
        IF p_policy_catalog_id IS NOT NULL THEN
            SELECT pc.type_id, pc.company_id INTO v_final_type_id, v_final_company_id
            FROM policy_catalog pc WHERE pc.policy_catalog_id = p_policy_catalog_id;
        ELSE
            v_final_type_id := p_type_id;
            v_final_company_id := p_company_id;
        END IF;
        
        INSERT INTO client_policies (
            policy_id, client_id, policy_name, status, start_date, end_date,
            notes, policy_catalog_id, type_id, company_id, is_active, created_date
        )
        VALUES (
            v_policy_id, p_client_id, p_policy_name, p_status, p_start_date, p_end_date,
            p_notes, p_policy_catalog_id, v_final_type_id, v_final_company_id, TRUE, NOW()
        );
    END IF;
    
    RETURN QUERY SELECT v_policy_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 5. FIXED: sp_update_client_policy
-- ============================================================
CREATE OR REPLACE FUNCTION sp_update_client_policy(
    p_policy_id UUID,
    p_policy_name VARCHAR(100) DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_policy_catalog_id UUID DEFAULT NULL,
    p_type_id UUID DEFAULT NULL,
    p_company_id UUID DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE client_policies
    SET 
        policy_name = COALESCE(p_policy_name, policy_name),
        status = COALESCE(p_status, status),
        start_date = COALESCE(p_start_date, start_date),
        end_date = COALESCE(p_end_date, end_date),
        notes = COALESCE(p_notes, notes),
        policy_catalog_id = COALESCE(p_policy_catalog_id, policy_catalog_id),
        type_id = COALESCE(p_type_id, type_id),
        company_id = COALESCE(p_company_id, company_id),
        is_active = COALESCE(p_is_active, is_active),
        modified_date = NOW()
    WHERE policy_id = p_policy_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 6. FIXED: sp_delete_client_policy
-- ============================================================
CREATE OR REPLACE FUNCTION sp_delete_client_policy(
    p_policy_id UUID,
    p_hard_delete BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    IF p_hard_delete THEN
        DELETE FROM client_policies WHERE policy_id = p_policy_id;
    ELSE
        UPDATE client_policies 
        SET is_active = FALSE, status = 'Cancelled', modified_date = NOW()
        WHERE policy_id = p_policy_id;
    END IF;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. FIXED: sp_get_clients_with_policies - Fix EXTRACT issue
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_clients_with_policies(
    p_agent_id UUID DEFAULT NULL,
    p_client_id UUID DEFAULT NULL,
    p_include_inactive BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    client_id UUID,
    agent_id UUID,
    first_name VARCHAR(50),
    surname VARCHAR(50),
    last_name VARCHAR(50),
    full_name VARCHAR(152),
    phone_number VARCHAR(20),
    email VARCHAR(100),
    address TEXT,
    national_id VARCHAR(50),
    date_of_birth DATE,
    is_client BOOLEAN,
    insurance_type VARCHAR(50),
    client_notes TEXT,
    client_created_date TIMESTAMPTZ,
    client_modified_date TIMESTAMPTZ,
    client_is_active BOOLEAN,
    policy_id UUID,
    policy_name VARCHAR(100),
    status VARCHAR(20),
    start_date DATE,
    end_date DATE,
    policy_notes TEXT,
    policy_created_date TIMESTAMPTZ,
    policy_modified_date TIMESTAMPTZ,
    policy_is_active BOOLEAN,
    policy_catalog_id UUID,
    catalog_policy_name VARCHAR(100),
    type_id UUID,
    type_name VARCHAR(100),
    company_id UUID,
    company_name VARCHAR(100),
    days_until_expiry INTEGER
) 
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.agent_id,
        c.first_name,
        c.surname,
        c.last_name,
        (c.first_name || ' ' || c.surname || ' ' || c.last_name)::VARCHAR(152) AS full_name,
        c.phone_number,
        c.email,
        c.address,
        c.national_id,
        c.date_of_birth,
        c.is_client,
        c.insurance_type,
        c.notes AS client_notes,
        c.created_date AS client_created_date,
        c.modified_date AS client_modified_date,
        c.is_active AS client_is_active,

        cp.policy_id,
        cp.policy_name,
        cp.status,
        cp.start_date,
        cp.end_date,
        cp.notes AS policy_notes,
        cp.created_date AS policy_created_date,
        cp.modified_date AS policy_modified_date,
        cp.is_active AS policy_is_active,
        cp.policy_catalog_id,
        pc.policy_name AS catalog_policy_name,
        cp.type_id,
        pt.type_name,
        cp.company_id,
        ic.company_name,
        -- FIXED: Cast the interval calculation to avoid EXTRACT error
        (cp.end_date - CURRENT_DATE)::INTEGER AS days_until_expiry
    FROM clients c
        INNER JOIN client_policies cp 
            ON c.client_id = cp.client_id
           AND cp.policy_id IS NOT NULL
           AND cp.company_id IS NOT NULL
           AND cp.type_id IS NOT NULL
        LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
        LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
        LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE 
        (p_agent_id IS NULL OR c.agent_id = p_agent_id)
        AND (p_client_id IS NULL OR c.client_id = p_client_id)
        AND (
            p_include_inactive = TRUE 
            OR (COALESCE(c.is_active, TRUE) = TRUE AND COALESCE(cp.is_active, TRUE) = TRUE)
        )
    ORDER BY c.created_date DESC, cp.end_date DESC;
END;
$$;

-- ============================================================
-- 8. sp_soft_delete_client_policy (already correct)
-- ============================================================
CREATE OR REPLACE FUNCTION sp_soft_delete_client_policy(p_policy_id UUID)
RETURNS TABLE(success INTEGER, message TEXT) 
LANGUAGE plpgsql AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE client_policies
    SET is_active = FALSE,
        modified_date = NOW()
    WHERE policy_id = p_policy_id AND COALESCE(is_active, TRUE) = TRUE;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected > 0 THEN
        RETURN QUERY SELECT 1, 'Policy soft deleted successfully';
    ELSE
        RETURN QUERY SELECT 0, 'Policy not found or already inactive';
    END IF;
END;
$$;

-- ============================================================
-- 9. FIXED: sp_get_expiring_policies - Fix EXTRACT and INTERVAL issues
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_expiring_policies(
    p_agent_id UUID DEFAULT NULL,
    p_days_ahead INTEGER DEFAULT 30,
    p_status VARCHAR(20) DEFAULT 'Active'
)
RETURNS TABLE (
    policy_id           UUID,
    client_id           UUID,
    policy_name         VARCHAR(100),
    status              VARCHAR(20),
    start_date          DATE,
    end_date            DATE,
    notes               TEXT,
    created_date        TIMESTAMPTZ,
    modified_date       TIMESTAMPTZ,
    is_active           BOOLEAN,
    policy_catalog_id   UUID,
    catalog_policy_name VARCHAR(100),
    type_id             UUID,
    type_name           VARCHAR(100),
    company_id          UUID,
    company_name        VARCHAR(100),
    days_until_expiry   INTEGER,
    client_first_name   VARCHAR(50),
    client_surname      VARCHAR(50),
    client_phone        VARCHAR(20),
    renewal_priority    VARCHAR(10)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cp.policy_id,
        cp.client_id,
        cp.policy_name,
        cp.status,
        cp.start_date,
        cp.end_date,
        cp.notes,
        cp.created_date,
        cp.modified_date,
        cp.is_active,
        cp.policy_catalog_id,
        pc.policy_name AS catalog_policy_name,
        cp.type_id,
        pt.type_name,
        cp.company_id,
        ic.company_name,
        -- FIXED: Cast the interval calculation to avoid EXTRACT error
        (cp.end_date - CURRENT_DATE)::INTEGER AS days_until_expiry,
        c.first_name AS client_first_name,
        c.surname AS client_surname,
        c.phone_number AS client_phone,
        CASE 
            WHEN cp.end_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'Urgent'
            WHEN cp.end_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'Soon'
            ELSE 'Upcoming'
        END::VARCHAR(10) AS renewal_priority
    FROM client_policies cp
    INNER JOIN clients c ON cp.client_id = c.client_id
    LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    LEFT JOIN policy_types pt   ON cp.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + (p_days_ahead || ' days')::INTERVAL)
      AND (p_agent_id IS NULL OR c.agent_id = p_agent_id)
      AND (p_status IS NULL OR cp.status = p_status)
      AND cp.is_active = TRUE
      AND c.is_active = TRUE
    ORDER BY cp.end_date ASC;
END;
$$ LANGUAGE plpgsql;