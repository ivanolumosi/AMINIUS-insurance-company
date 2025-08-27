-- ============================================
-- Get Policy Catalog with Filters (by type/name)
-- ============================================
CREATE OR REPLACE FUNCTION sp_get_policy_catalog(
    p_agent_id     UUID,                    -- required
    p_policy_type  VARCHAR(50)  DEFAULT NULL,
    p_company_id   UUID         DEFAULT NULL,
    p_company_name VARCHAR(100) DEFAULT NULL,
    p_search_term  VARCHAR(100) DEFAULT NULL,
    p_is_active    BOOLEAN      DEFAULT TRUE
)
RETURNS TABLE (
    policy_catalog_id UUID,
    agent_id          UUID,
    policy_name       VARCHAR(100),
    policy_type       VARCHAR(50),
    company_id        UUID,
    company_name      VARCHAR(100),
    notes             TEXT,
    is_active         BOOLEAN,
    created_date      TIMESTAMPTZ,
    modified_date     TIMESTAMPTZ,
    company_active    BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pc.policy_catalog_id,
        pc.agent_id,
        pc.policy_name,
        pc.policy_type,
        pc.company_id,
        pc.company_name,
        pc.notes,
        pc.is_active,
        pc.created_date,
        pc.modified_date,
        ic.is_active AS company_active
    FROM policy_catalog pc
    LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
    WHERE 
        pc.agent_id = p_agent_id
        AND (p_policy_type  IS NULL OR pc.policy_type  = p_policy_type)
        AND (p_company_id   IS NULL OR pc.company_id   = p_company_id)
        AND (p_company_name IS NULL OR pc.company_name ILIKE '%' || p_company_name || '%')
        AND (p_search_term  IS NULL OR pc.policy_name  ILIKE '%' || p_search_term  || '%')
        AND (p_is_active    IS NULL OR pc.is_active    = p_is_active)
    ORDER BY pc.policy_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Create Policy Catalog Item
-- ============================================
CREATE OR REPLACE FUNCTION sp_create_policy_catalog_item(
    p_agent_id    UUID,
    p_policy_name VARCHAR(100),
    p_policy_type VARCHAR(50),
    p_company_id  UUID,
    p_notes       TEXT DEFAULT NULL
)
RETURNS TABLE(policy_catalog_id UUID, error_message TEXT) AS $$
DECLARE
    v_policy_catalog_id UUID := gen_random_uuid();
    v_company_name      VARCHAR(100);
BEGIN
    SELECT company_name 
      INTO v_company_name
      FROM insurance_companies 
     WHERE company_id = p_company_id;

    IF v_company_name IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, 'Company not found'::TEXT;
        RETURN;
    END IF;

    INSERT INTO policy_catalog (
        policy_catalog_id, agent_id, policy_name, policy_type, company_id, company_name, notes
    )
    VALUES (
        v_policy_catalog_id, p_agent_id, p_policy_name, p_policy_type, p_company_id, v_company_name, p_notes
    );

    RETURN QUERY SELECT v_policy_catalog_id, NULL::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Update Policy Catalog Item
-- ============================================
CREATE OR REPLACE FUNCTION sp_update_policy_catalog_item(
    p_policy_catalog_id UUID,
    p_agent_id          UUID,
    p_policy_name       VARCHAR(100) DEFAULT NULL,
    p_policy_type       VARCHAR(50)  DEFAULT NULL,
    p_company_id        UUID         DEFAULT NULL,
    p_notes             TEXT         DEFAULT NULL,
    p_is_active         BOOLEAN      DEFAULT NULL
)
RETURNS TABLE(rows_affected INTEGER, error_message TEXT) AS $$
DECLARE
    v_company_name  VARCHAR(100);
    v_rows_affected INTEGER;
BEGIN
    IF p_company_id IS NOT NULL THEN
        SELECT company_name 
          INTO v_company_name
          FROM insurance_companies 
         WHERE company_id = p_company_id;

        IF v_company_name IS NULL THEN
            RETURN QUERY SELECT 0, 'Company not found'::TEXT;
            RETURN;
        END IF;
    END IF;

    UPDATE policy_catalog 
       SET policy_name  = COALESCE(p_policy_name, policy_name),
           policy_type  = COALESCE(p_policy_type, policy_type),
           company_id   = COALESCE(p_company_id, company_id),
           company_name = COALESCE(v_company_name, company_name),
           notes        = COALESCE(p_notes, notes),
           is_active    = COALESCE(p_is_active, is_active),
           modified_date = NOW()
     WHERE policy_catalog_id = p_policy_catalog_id
       AND agent_id = p_agent_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected, NULL::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Delete Policy Catalog Item (soft delete)
-- ============================================
CREATE OR REPLACE FUNCTION sp_delete_policy_catalog_item(
    p_policy_catalog_id UUID,
    p_agent_id          UUID
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE policy_catalog 
       SET is_active = FALSE,
           modified_date = NOW()
     WHERE policy_catalog_id = p_policy_catalog_id
       AND agent_id = p_agent_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Get Client Policies
-- ============================================
CREATE OR REPLACE FUNCTION sp_get_client_policies(
    p_client_id   UUID,
    p_status      VARCHAR(20)  DEFAULT NULL,
    p_policy_type VARCHAR(50)  DEFAULT NULL
)
RETURNS TABLE (
    policy_id         UUID,
    client_id         UUID,
    policy_name       VARCHAR(100),
    policy_type       VARCHAR(50),
    company_name      VARCHAR(100),
    status            VARCHAR(20),
    start_date        DATE,
    end_date          DATE,
    notes             TEXT,
    created_date      TIMESTAMPTZ,
    modified_date     TIMESTAMPTZ,
    is_active         BOOLEAN,
    days_until_expiry INTEGER,
    client_name       VARCHAR(255),
    client_phone      VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cp.policy_id,
        cp.client_id,
        cp.policy_name,
        cp.policy_type,
        cp.company_name,
        cp.status,
        cp.start_date,
        cp.end_date,
        cp.notes,
        cp.created_date,
        cp.modified_date,
        cp.is_active,
        EXTRACT(day FROM (cp.end_date - CURRENT_DATE))::INTEGER AS days_until_expiry,
        c.first_name || ' ' || c.surname AS client_name,
        c.phone_number AS client_phone
    FROM client_policies cp
    INNER JOIN clients c ON cp.client_id = c.client_id
    WHERE 
        cp.client_id = p_client_id
        AND cp.is_active = TRUE
        AND (p_status      IS NULL OR cp.status      = p_status)
        AND (p_policy_type IS NULL OR cp.policy_type = p_policy_type)
    ORDER BY cp.start_date DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Create Client Policy
-- ============================================
CREATE OR REPLACE FUNCTION sp_create_client_policy(
    p_client_id     UUID,
    p_policy_name   VARCHAR(100),
    p_policy_type   VARCHAR(50),
    p_company_name  VARCHAR(100),
    p_start_date    DATE,
    p_end_date      DATE,
    p_status        VARCHAR(20) DEFAULT 'Active',
    p_notes         TEXT        DEFAULT NULL
)
RETURNS TABLE(policy_id UUID) AS $$
DECLARE
    v_policy_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO client_policies (
        policy_id, client_id, policy_name, policy_type, company_name, status, start_date, end_date, notes
    )
    VALUES (
        v_policy_id, p_client_id, p_policy_name, p_policy_type, p_company_name, p_status, p_start_date, p_end_date, p_notes
    );

    RETURN QUERY SELECT v_policy_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Update Client Policy
-- ============================================
CREATE OR REPLACE FUNCTION sp_update_client_policy(
    p_policy_id     UUID,
    p_policy_name   VARCHAR(100) DEFAULT NULL,
    p_policy_type   VARCHAR(50)  DEFAULT NULL,
    p_company_name  VARCHAR(100) DEFAULT NULL,
    p_status        VARCHAR(20)  DEFAULT NULL,
    p_start_date    DATE         DEFAULT NULL,
    p_end_date      DATE         DEFAULT NULL,
    p_notes         TEXT         DEFAULT NULL,
    p_is_active     BOOLEAN      DEFAULT NULL
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE client_policies 
       SET policy_name  = COALESCE(p_policy_name, policy_name),
           policy_type  = COALESCE(p_policy_type, policy_type),
           company_name = COALESCE(p_company_name, company_name),
           status       = COALESCE(p_status, status),
           start_date   = COALESCE(p_start_date, start_date),
           end_date     = COALESCE(p_end_date, end_date),
           notes        = COALESCE(p_notes, notes),
           is_active    = COALESCE(p_is_active, is_active),
           modified_date = NOW()
     WHERE policy_id = p_policy_id;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;

-- -- ============================================
-- -- Get Expiring Policies (next N days)
-- -- ============================================
-- CREATE OR REPLACE FUNCTION sp_get_expiring_policies(
--     p_agent_id   UUID,
--     p_days_ahead INTEGER DEFAULT 30
-- )
-- RETURNS TABLE (
--     policy_id         UUID,
--     client_id         UUID,
--     policy_name       VARCHAR(100),
--     policy_type       VARCHAR(50),
--     company_name      VARCHAR(100),
--     status            VARCHAR(20),
--     start_date        DATE,
--     end_date          DATE,
--     notes             TEXT,
--     client_name       VARCHAR(255),
--     client_phone      VARCHAR(20),
--     client_email      VARCHAR(100),
--     days_until_expiry INTEGER
-- ) AS $$
-- DECLARE
--     v_start_date DATE := CURRENT_DATE;
--     v_end_date   DATE := (CURRENT_DATE + (p_days_ahead || ' days')::INTERVAL)::DATE;
-- BEGIN
--     RETURN QUERY
--     SELECT 
--         cp.policy_id,
--         cp.client_id,
--         cp.policy_name,
--         cp.policy_type,
--         cp.company_name,
--         cp.status,
--         cp.start_date,
--         cp.end_date,
--         cp.notes,
--         c.first_name || ' ' || c.surname AS client_name,
--         c.phone_number AS client_phone,
--         c.email AS client_email,
--         EXTRACT(day FROM (cp.end_date - v_start_date))::INTEGER AS days_until_expiry
--     FROM client_policies cp
--     INNER JOIN clients c ON cp.client_id = c.client_id
--     WHERE 
--         c.agent_id = p_agent_id 
--         AND cp.status = 'Active'
--         AND cp.is_active = TRUE
--         AND c.is_active = TRUE
--         AND cp.end_date BETWEEN v_start_date AND v_end_date
--     ORDER BY cp.end_date ASC;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ============================================
-- -- Get Policy Statistics (agent)
-- -- ============================================
-- CREATE OR REPLACE FUNCTION sp_get_policy_statistics(p_agent_id UUID)
-- RETURNS TABLE (
--     total_policies        BIGINT,
--     active_policies       BIGINT,
--     expired_policies      BIGINT,
--     lapsed_policies       BIGINT,
--     inactive_policies     BIGINT,
--     expiring_in_30_days   BIGINT,
--     expiring_in_7_days    BIGINT,
--     new_policies_this_month BIGINT,
--     motor_policies        BIGINT,
--     life_policies         BIGINT,
--     health_policies       BIGINT,
--     travel_policies       BIGINT,
--     property_policies     BIGINT,
--     marine_policies       BIGINT,
--     business_policies     BIGINT,
--     catalog_policies      BIGINT
-- ) AS $$
-- DECLARE
--     v_today       DATE := CURRENT_DATE;
--     v_month_start DATE := DATE_TRUNC('month', v_today)::DATE;
--     v_month_end   DATE := (DATE_TRUNC('month', v_today) + INTERVAL '1 month - 1 day')::DATE;
-- BEGIN
--     RETURN QUERY
--     SELECT 
--         COUNT(DISTINCT cp.policy_id)                                                   AS total_policies,
--         COUNT(DISTINCT CASE WHEN cp.status = 'Active'  THEN cp.policy_id END)          AS active_policies,
--         COUNT(DISTINCT CASE WHEN cp.status = 'Expired' THEN cp.policy_id END)          AS expired_policies,
--         COUNT(DISTINCT CASE WHEN cp.status = 'Lapsed'  THEN cp.policy_id END)          AS lapsed_policies,
--         COUNT(DISTINCT CASE WHEN cp.status = 'Inactive' THEN cp.policy_id END)         AS inactive_policies,
--         COUNT(DISTINCT CASE WHEN cp.end_date BETWEEN v_today AND (v_today + INTERVAL '30 days')
--                              AND cp.status = 'Active' THEN cp.policy_id END)           AS expiring_in_30_days,
--         COUNT(DISTINCT CASE WHEN cp.end_date BETWEEN v_today AND (v_today + INTERVAL '7 days')
--                              AND cp.status = 'Active' THEN cp.policy_id END)           AS expiring_in_7_days,
--         COUNT(DISTINCT CASE WHEN cp.start_date BETWEEN v_month_start AND v_month_end
--                              THEN cp.policy_id END)                                    AS new_policies_this_month,
--         COUNT(DISTINCT CASE WHEN cp.policy_type = 'Motor'    THEN cp.policy_id END)    AS motor_policies,
--         COUNT(DISTINCT CASE WHEN cp.policy_type = 'Life'     THEN cp.policy_id END)    AS life_policies,
--         COUNT(DISTINCT CASE WHEN cp.policy_type = 'Health'   THEN cp.policy_id END)    AS health_policies,
--         COUNT(DISTINCT CASE WHEN cp.policy_type = 'Travel'   THEN cp.policy_id END)    AS travel_policies,
--         COUNT(DISTINCT CASE WHEN cp.policy_type = 'Property' THEN cp.policy_id END)    AS property_policies,
--         COUNT(DISTINCT CASE WHEN cp.policy_type = 'Marine'   THEN cp.policy_id END)    AS marine_policies,
--         COUNT(DISTINCT CASE WHEN cp.policy_type = 'Business' THEN cp.policy_id END)    AS business_policies,
--         COUNT(DISTINCT pc.policy_catalog_id)                                           AS catalog_policies
--     FROM client_policies cp
--     INNER JOIN clients c ON cp.client_id = c.client_id
--     LEFT JOIN policy_catalog pc ON pc.agent_id = c.agent_id AND pc.is_active = TRUE
--     WHERE c.agent_id = p_agent_id AND cp.is_active = TRUE AND c.is_active = TRUE;
-- END;
-- $$ LANGUAGE plpgsql;

-- ============================================
-- Lookup helpers
-- ============================================
-- Get Insurance Companies
-- ============================================
CREATE OR REPLACE FUNCTION sp_get_insurance_companies_all(
    p_is_active BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    company_id   UUID,
    company_name VARCHAR(100),
    is_active    BOOLEAN,
    created_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ic.company_id,
        ic.company_name,
        ic.is_active,
        ic.created_date
    FROM insurance_companies ic
    WHERE (p_is_active IS NULL OR ic.is_active = p_is_active)
    ORDER BY ic.company_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Get Policy Types
-- ============================================
CREATE OR REPLACE FUNCTION sp_get_policy_types_all(
    p_is_active BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    type_id      UUID,
    type_name    VARCHAR(100),
    is_active    BOOLEAN,
    created_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.type_id,
        pt.type_name,
        pt.is_active,
        pt.created_date
    FROM policy_types pt
    WHERE (p_is_active IS NULL OR pt.is_active = p_is_active)
    ORDER BY pt.type_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Policy Templates
-- ============================================
CREATE OR REPLACE FUNCTION sp_get_policy_templates(
    p_agent_id    UUID,                -- required first
    p_policy_type VARCHAR(50) DEFAULT NULL,
    p_is_active   BOOLEAN     DEFAULT TRUE
)
RETURNS TABLE (
    template_id           UUID,
    agent_id              UUID,
    template_name         VARCHAR(100),
    policy_type           VARCHAR(50),
    default_term_months   INTEGER,
    default_premium       DECIMAL(10,2),
    coverage_description  TEXT,
    terms                 TEXT,
    is_active             BOOLEAN,
    created_date          TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.template_id,
        pt.agent_id,
        pt.template_name,
        pt.policy_type,
        pt.default_term_months,
        pt.default_premium,
        pt.coverage_description,
        pt.terms,
        pt.is_active,
        pt.created_date
    FROM policy_templates pt
    WHERE 
        pt.agent_id = p_agent_id
        AND (p_policy_type IS NULL OR pt.policy_type = p_policy_type)
        AND (p_is_active   IS NULL OR pt.is_active   = p_is_active)
    ORDER BY pt.template_name ASC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_create_policy_template(
    p_agent_id             UUID,          -- required
    p_template_name        VARCHAR(100),  -- required
    p_policy_type          VARCHAR(50),   -- required
    p_default_term_months  INTEGER        DEFAULT NULL,
    p_default_premium      DECIMAL(10,2)  DEFAULT NULL,
    p_coverage_description TEXT           DEFAULT NULL,
    p_terms                TEXT           DEFAULT NULL
)
RETURNS TABLE(template_id UUID) AS $$
DECLARE
    v_template_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO policy_templates (
        template_id, agent_id, template_name, policy_type,
        default_term_months, default_premium, coverage_description, terms
    )
    VALUES (
        v_template_id, p_agent_id, p_template_name, p_policy_type,
        p_default_term_months, p_default_premium, p_coverage_description, p_terms
    );

    RETURN QUERY SELECT v_template_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Validation
-- ============================================
CREATE OR REPLACE FUNCTION sp_validate_policy_data(
    p_policy_name VARCHAR(100),   -- required first
    p_policy_type VARCHAR(50),    -- required second
    p_company_id  UUID  DEFAULT NULL,
    p_start_date  DATE  DEFAULT NULL,
    p_end_date    DATE  DEFAULT NULL
)
RETURNS TABLE(
    is_valid          BOOLEAN,
    validation_errors TEXT
) AS $$
DECLARE
    v_is_valid BOOLEAN := TRUE;
    v_validation_errors TEXT := '';
BEGIN
    IF p_policy_name IS NULL OR LENGTH(TRIM(p_policy_name)) = 0 THEN
        v_is_valid := FALSE;
        v_validation_errors := v_validation_errors || 'Policy name is required. ';
    END IF;

    IF p_policy_type IS NULL
       OR NOT EXISTS (SELECT 1 FROM policy_types WHERE type_name = p_policy_type AND is_active = TRUE) THEN
        v_is_valid := FALSE;
        v_validation_errors := v_validation_errors || 'Valid policy type is required. ';
    END IF;

    IF p_company_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM insurance_companies WHERE company_id = p_company_id AND is_active = TRUE) THEN
        v_is_valid := FALSE;
        v_validation_errors := v_validation_errors || 'Valid insurance company is required. ';
    END IF;

    IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL AND p_start_date >= p_end_date THEN
        v_is_valid := FALSE;
        v_validation_errors := v_validation_errors || 'End date must be after start date. ';
    END IF;

    RETURN QUERY SELECT v_is_valid, TRIM(v_validation_errors);
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Catalog APIs
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_policy_catalog(
    p_agent_id    UUID DEFAULT NULL,
    p_company_id  UUID DEFAULT NULL,
    p_category_id UUID DEFAULT NULL,
    p_type_id     UUID DEFAULT NULL,
    p_is_active   BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    policy_catalog_id UUID,
    agent_id          UUID,
    policy_name       VARCHAR(100),
    company_id        UUID,
    company_name      VARCHAR(100),
    notes             TEXT,
    is_active         BOOLEAN,
    created_date      TIMESTAMPTZ,
    modified_date     TIMESTAMPTZ,
    category_id       UUID,
    category_name     VARCHAR(100),
    type_id           UUID,
    type_name         VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pc.policy_catalog_id,
        pc.agent_id,
        pc.policy_name,
        pc.company_id,
        ic.company_name,
        pc.notes,
        pc.is_active,
        pc.created_date,
        pc.modified_date,
        pc.category_id,
        pcat.category_name,
        pc.type_id,
        pt.type_name
    FROM policy_catalog pc
    LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
    LEFT JOIN policy_categories pcat ON pc.category_id = pcat.category_id
    LEFT JOIN policy_types pt ON pc.type_id = pt.type_id
    WHERE (p_agent_id   IS NULL OR pc.agent_id   = p_agent_id)
      AND (p_company_id IS NULL OR pc.company_id = p_company_id)
      AND (p_category_id IS NULL OR pc.category_id = p_category_id)
      AND (p_type_id    IS NULL OR pc.type_id    = p_type_id)
      AND (p_is_active  IS NULL OR pc.is_active  = p_is_active)
    ORDER BY pc.policy_name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_create_policy_catalog_item(
    p_agent_id    UUID,          -- required
    p_policy_name VARCHAR(100),  -- required
    p_company_id  UUID,          -- required
    p_notes       TEXT DEFAULT NULL,
    p_category_id UUID DEFAULT NULL,
    p_type_id     UUID DEFAULT NULL
)
RETURNS TABLE(policy_catalog_id UUID) AS $$
DECLARE
    v_policy_catalog_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO policy_catalog (
        policy_catalog_id, agent_id, policy_name, company_id, 
        notes, category_id, type_id, is_active, created_date
    )
    VALUES (
        v_policy_catalog_id, p_agent_id, p_policy_name, p_company_id,
        p_notes, p_category_id, p_type_id, TRUE, NOW()
    );
    
    RETURN QUERY SELECT v_policy_catalog_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_update_policy_catalog_item(
    p_policy_catalog_id UUID,    -- required first
    p_policy_name       VARCHAR(100) DEFAULT NULL,
    p_company_id        UUID         DEFAULT NULL,
    p_notes             TEXT         DEFAULT NULL,
    p_category_id       UUID         DEFAULT NULL,
    p_type_id           UUID         DEFAULT NULL,
    p_is_active         BOOLEAN      DEFAULT NULL
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE policy_catalog
       SET policy_name   = COALESCE(p_policy_name, policy_name),
           company_id    = COALESCE(p_company_id, company_id),
           notes         = COALESCE(p_notes, notes),
           category_id   = COALESCE(p_category_id, category_id),
           type_id       = COALESCE(p_type_id, type_id),
           is_active     = COALESCE(p_is_active, is_active),
           modified_date = NOW()
     WHERE policy_catalog_id = p_policy_catalog_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_delete_policy_catalog_item(
    p_policy_catalog_id UUID,   -- required first
    p_hard_delete       BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    IF p_hard_delete = TRUE THEN
        DELETE FROM policy_catalog WHERE policy_catalog_id = p_policy_catalog_id;
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    ELSE
        UPDATE policy_catalog 
           SET is_active = FALSE,
               modified_date = NOW()
         WHERE policy_catalog_id = p_policy_catalog_id;
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    END IF;

    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;
-- ============================================================
-- Upsert Policy Catalog
-- ============================================================
CREATE OR REPLACE FUNCTION sp_upsert_policy_catalog(
    p_agent_id          UUID,
    p_policy_name       VARCHAR(100),
    p_company_id        UUID,
    p_policy_catalog_id UUID DEFAULT NULL,
    p_notes             TEXT DEFAULT NULL,
    p_category_id       UUID DEFAULT NULL,
    p_type_id           UUID DEFAULT NULL
)
RETURNS TABLE(policy_catalog_id UUID) AS $$
DECLARE
    v_policy_catalog_id UUID;
BEGIN
    IF p_policy_catalog_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM policy_catalog WHERE policy_catalog_id = p_policy_catalog_id) THEN
        v_policy_catalog_id := gen_random_uuid();
        INSERT INTO policy_catalog (
            policy_catalog_id, agent_id, policy_name, company_id, 
            notes, category_id, type_id, is_active, created_date
        )
        VALUES (
            v_policy_catalog_id, p_agent_id, p_policy_name, p_company_id,
            p_notes, p_category_id, p_type_id, TRUE, NOW()
        );
    ELSE
        v_policy_catalog_id := p_policy_catalog_id;
        UPDATE policy_catalog
           SET policy_name  = p_policy_name,
               company_id   = p_company_id,
               notes        = p_notes,
               category_id  = p_category_id,
               type_id      = p_type_id,
               modified_date = NOW()
         WHERE policy_catalog_id = p_policy_catalog_id;
    END IF;

    RETURN QUERY SELECT v_policy_catalog_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- Extended Client Policies
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
        EXTRACT(day FROM (cp.end_date - CURRENT_DATE))::INTEGER AS days_until_expiry
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
-- Get Policy By ID
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_policy_by_id(
    p_policy_id UUID
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
        EXTRACT(day FROM (cp.end_date - CURRENT_DATE))::INTEGER AS days_until_expiry
    FROM client_policies cp
    LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    LEFT JOIN policy_types pt   ON cp.type_id = pt.type_id
    LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE cp.policy_id = p_policy_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- Create Client Policy
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
    SELECT company_id, type_id
    INTO v_company_id, v_type_id
    FROM policy_catalog
    WHERE policy_catalog_id = p_policy_catalog_id;

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
-- Update Client Policy
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
-- Delete Client Policy
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
-- Upsert Client Policy
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
BEGIN
    IF p_policy_id IS NULL OR NOT EXISTS (SELECT 1 FROM client_policies WHERE policy_id = p_policy_id) THEN
        v_policy_id := gen_random_uuid();
        INSERT INTO client_policies (
            policy_id, client_id, policy_name, status, start_date, end_date,
            notes, policy_catalog_id, type_id, company_id, is_active, created_date
        )
        VALUES (
            v_policy_id, p_client_id, p_policy_name, p_status, p_start_date, p_end_date,
            p_notes, p_policy_catalog_id, p_type_id, p_company_id, TRUE, NOW()
        );
    ELSE
        v_policy_id := p_policy_id;
        UPDATE client_policies
        SET 
            policy_name = p_policy_name,
            status = p_status,
            start_date = p_start_date,
            end_date = p_end_date,
            notes = p_notes,
            policy_catalog_id = p_policy_catalog_id,
            type_id = p_type_id,
            company_id = p_company_id,
            modified_date = NOW()
        WHERE policy_id = p_policy_id;
    END IF;
    
    RETURN QUERY SELECT v_policy_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- Policy Statistics
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_policy_statistics(
    p_agent_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    total_policies BIGINT,
    active_policies BIGINT,
    expired_policies BIGINT,
    cancelled_policies BIGINT,
    expiring_in_30_days BIGINT,
    expiring_in_60_days BIGINT
) AS $$
DECLARE
    v_start_date DATE := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '1 year');
    v_end_date DATE := COALESCE(p_end_date, CURRENT_DATE);
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) AS total_policies,
        SUM(CASE WHEN cp.status = 'Active' THEN 1 ELSE 0 END),
        SUM(CASE WHEN cp.status = 'Expired' THEN 1 ELSE 0 END),
        SUM(CASE WHEN cp.status = 'Cancelled' THEN 1 ELSE 0 END),
        SUM(CASE WHEN cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days') THEN 1 ELSE 0 END),
        SUM(CASE WHEN cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '60 days') THEN 1 ELSE 0 END)
    FROM client_policies cp
        LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    WHERE cp.is_active = TRUE
        AND cp.created_date BETWEEN v_start_date AND v_end_date
        AND (p_agent_id IS NULL OR pc.agent_id = p_agent_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sp_get_policy_statistics_detailed(
    p_agent_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    group_type VARCHAR(20),
    group_name VARCHAR(100),
    policy_count BIGINT,
    active_count BIGINT
) AS $$
DECLARE
    v_start_date DATE := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '1 year');
    v_end_date DATE := COALESCE(p_end_date, CURRENT_DATE);
BEGIN
    RETURN QUERY
    SELECT 
        'By Company',
        ic.company_name,
        COUNT(*),
        SUM(CASE WHEN cp.status = 'Active' THEN 1 ELSE 0 END)
    FROM client_policies cp
        LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
        LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    WHERE cp.is_active = TRUE
        AND cp.created_date BETWEEN v_start_date AND v_end_date
        AND (p_agent_id IS NULL OR pc.agent_id = p_agent_id)
    GROUP BY ic.company_name
    
    UNION ALL
    
    SELECT 
        'By Type',
        pt.type_name,
        COUNT(*),
        SUM(CASE WHEN cp.status = 'Active' THEN 1 ELSE 0 END)
    FROM client_policies cp
        LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
        LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    WHERE cp.is_active = TRUE
        AND cp.created_date BETWEEN v_start_date AND v_end_date
        AND (p_agent_id IS NULL OR pc.agent_id = p_agent_id)
    GROUP BY pt.type_name
    
    ORDER BY group_type, policy_count DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- POLICY SEARCH AND FILTERING FUNCTIONS
-- ============================================

-- Search Policies
CREATE OR REPLACE FUNCTION sp_search_policies(
    p_search_term VARCHAR(100) DEFAULT NULL,
    p_agent_id UUID DEFAULT NULL,
    p_client_id UUID DEFAULT NULL,
    p_company_id UUID DEFAULT NULL,
    p_type_id UUID DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_page_size INTEGER DEFAULT 50,
    p_page_number INTEGER DEFAULT 1
)
RETURNS TABLE (
    policy_id UUID,
    client_id UUID,
    policy_name VARCHAR(100),
    status VARCHAR(20),
    start_date DATE,
    end_date DATE,
    notes TEXT,
    company_id UUID,
    company_name VARCHAR(100),
    type_id UUID,
    type_name VARCHAR(100),
    policy_catalog_id UUID,
    catalog_policy_name VARCHAR(100),
    days_until_expiry INTEGER
) AS $$
DECLARE
    v_offset INTEGER := (p_page_number - 1) * p_page_size;
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
        cp.company_id,
        ic.company_name,
        cp.type_id,
        pt.type_name,
        cp.policy_catalog_id,
        pc.policy_name,
        EXTRACT(DAYS FROM (cp.end_date - CURRENT_DATE))::INTEGER
    FROM client_policies cp
        LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
        LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
        LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE cp.is_active = TRUE
        AND (p_search_term IS NULL OR cp.policy_name ILIKE '%' || p_search_term || '%' OR cp.notes ILIKE '%' || p_search_term || '%')
        AND (p_agent_id IS NULL OR pc.agent_id = p_agent_id)
        AND (p_client_id IS NULL OR cp.client_id = p_client_id)
        AND (p_company_id IS NULL OR cp.company_id = p_company_id)
        AND (p_type_id IS NULL OR cp.type_id = p_type_id)
        AND (p_status IS NULL OR cp.status = p_status)
        AND (p_start_date IS NULL OR cp.start_date >= p_start_date)
        AND (p_end_date IS NULL OR cp.end_date <= p_end_date)
    ORDER BY cp.created_date DESC
    LIMIT p_page_size OFFSET v_offset;
END;
$$ LANGUAGE plpgsql;


-- Get Policies By Status
CREATE OR REPLACE FUNCTION sp_get_policies_by_status(
    p_status VARCHAR(20),
    p_agent_id UUID DEFAULT NULL
)
RETURNS TABLE (
    policy_id UUID,
    client_id UUID,
    policy_name VARCHAR(100),
    status VARCHAR(20),
    start_date DATE,
    end_date DATE,
    company_id UUID,
    company_name VARCHAR(100),
    type_id UUID,
    type_name VARCHAR(100),
    days_until_expiry INTEGER
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
        cp.company_id,
        ic.company_name,
        cp.type_id,
        pt.type_name,
        EXTRACT(DAYS FROM (cp.end_date - CURRENT_DATE))::INTEGER
    FROM client_policies cp
        LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
        LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
        LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE cp.is_active = TRUE
        AND cp.status = p_status
        AND (p_agent_id IS NULL OR pc.agent_id = p_agent_id)
    ORDER BY cp.end_date;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- POLICY MANAGEMENT ACTIONS
-- ============================================

-- Renew Policy
CREATE OR REPLACE FUNCTION sp_renew_policy(
    p_policy_id UUID,
    p_new_start_date DATE,
    p_new_end_date DATE,
    p_new_policy_name VARCHAR(100) DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE(new_policy_id UUID, rows_affected INTEGER) AS $$
DECLARE
    v_new_policy_id UUID := gen_random_uuid();
    v_client_id UUID;
    v_policy_name VARCHAR(100);
    v_policy_catalog_id UUID;
    v_type_id UUID;
    v_company_id UUID;
    v_rows_affected INTEGER;
BEGIN
    -- Mark old policy as renewed
    UPDATE client_policies 
    SET status = 'Renewed', modified_date = NOW()
    WHERE policy_id = p_policy_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    -- Copy details for renewal
    SELECT 
        client_id,
        COALESCE(p_new_policy_name, policy_name),
        policy_catalog_id,
        type_id,
        company_id
    INTO v_client_id, v_policy_name, v_policy_catalog_id, v_type_id, v_company_id
    FROM client_policies 
    WHERE policy_id = p_policy_id;
    
    -- Insert new active policy
    INSERT INTO client_policies (
        policy_id, client_id, policy_name, status, start_date, end_date,
        notes, policy_catalog_id, type_id, company_id, is_active, created_date
    )
    VALUES (
        v_new_policy_id, v_client_id, v_policy_name, 'Active', p_new_start_date, p_new_end_date,
        p_notes, v_policy_catalog_id, v_type_id, v_company_id, TRUE, NOW()
    );
    
    RETURN QUERY SELECT v_new_policy_id, v_rows_affected;
END;
$$ LANGUAGE plpgsql;


-- Bulk Update Policy Status
CREATE OR REPLACE FUNCTION sp_bulk_update_policy_status(
    p_policy_ids TEXT,
    p_new_status VARCHAR(20)
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
    policy_id_array UUID[];
BEGIN
    -- Convert CSV string to UUID array
    SELECT ARRAY(
        SELECT CAST(trim(unnest(string_to_array(p_policy_ids, ','))) AS UUID)
    ) INTO policy_id_array;
    
    UPDATE client_policies
    SET status = p_new_status, modified_date = NOW()
    WHERE policy_id = ANY(policy_id_array);
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- POLICY TEMPLATES FUNCTIONS
-- ============================================

-- Get Policy Templates
CREATE OR REPLACE FUNCTION sp_get_policy_templates(
    p_agent_id UUID DEFAULT NULL,
    p_category_id UUID DEFAULT NULL,
    p_type_id UUID DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    template_id UUID,
    agent_id UUID,
    template_name VARCHAR(100),
    default_term_months INTEGER,
    default_premium DECIMAL(18, 2),
    coverage_description TEXT,
    terms TEXT,
    is_active BOOLEAN,
    created_date TIMESTAMPTZ,
    category_id UUID,
    category_name VARCHAR(100),
    policy_catalog_id UUID,
    catalog_policy_name VARCHAR(100),
    type_id UUID,
    type_name VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.template_id,
        pt.agent_id,
        pt.template_name,
        pt.default_term_months,
        pt.default_premium,
        pt.coverage_description,
        pt.terms,
        pt.is_active,
        pt.created_date,
        pt.category_id,
        pc.category_name,
        pt.policy_catalog_id,
        pol.policy_name,
        pt.type_id,
        pty.type_name
    FROM policy_templates pt
        LEFT JOIN policy_categories pc ON pt.category_id = pc.category_id
        LEFT JOIN policy_catalog pol ON pt.policy_catalog_id = pol.policy_catalog_id
        LEFT JOIN policy_types pty ON pt.type_id = pty.type_id
    WHERE (p_agent_id IS NULL OR pt.agent_id = p_agent_id)
        AND (p_category_id IS NULL OR pt.category_id = p_category_id)
        AND (p_type_id IS NULL OR pt.type_id = p_type_id)
        AND (p_is_active IS NULL OR pt.is_active = p_is_active)
    ORDER BY pt.template_name;
END;
$$ LANGUAGE plpgsql;


-- Create Policy Template
CREATE OR REPLACE FUNCTION sp_create_policy_template(
    p_agent_id UUID,
    p_template_name VARCHAR(100),
    p_default_term_months INTEGER DEFAULT NULL,
    p_default_premium DECIMAL(18, 2) DEFAULT NULL,
    p_coverage_description TEXT DEFAULT NULL,
    p_terms TEXT DEFAULT NULL,
    p_category_id UUID DEFAULT NULL,
    p_policy_catalog_id UUID DEFAULT NULL,
    p_type_id UUID DEFAULT NULL
)
RETURNS TABLE(template_id UUID) AS $$
DECLARE
    v_template_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO policy_templates (
        template_id, agent_id, template_name, default_term_months, default_premium,
        coverage_description, terms, category_id, policy_catalog_id, type_id, is_active, created_date
    )
    VALUES (
        v_template_id, p_agent_id, p_template_name, p_default_term_months, p_default_premium,
        p_coverage_description, p_terms, p_category_id, p_policy_catalog_id, p_type_id, TRUE, NOW()
    );
    
    RETURN QUERY SELECT v_template_id;
END;
$$ LANGUAGE plpgsql;


-- Update Policy Template
CREATE OR REPLACE FUNCTION sp_update_policy_template(
    p_template_id UUID,
    p_template_name VARCHAR(100) DEFAULT NULL,
    p_default_term_months INTEGER DEFAULT NULL,
    p_default_premium DECIMAL(18, 2) DEFAULT NULL,
    p_coverage_description TEXT DEFAULT NULL,
    p_terms TEXT DEFAULT NULL,
    p_category_id UUID DEFAULT NULL,
    p_policy_catalog_id UUID DEFAULT NULL,
    p_type_id UUID DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE policy_templates
    SET 
        template_name = COALESCE(p_template_name, template_name),
        default_term_months = COALESCE(p_default_term_months, default_term_months),
        default_premium = COALESCE(p_default_premium, default_premium),
        coverage_description = COALESCE(p_coverage_description, coverage_description),
        terms = COALESCE(p_terms, terms),
        category_id = COALESCE(p_category_id, category_id),
        policy_catalog_id = COALESCE(p_policy_catalog_id, policy_catalog_id),
        type_id = COALESCE(p_type_id, type_id),
        is_active = COALESCE(p_is_active, is_active)
    WHERE template_id = p_template_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;


-- Delete Policy Template
CREATE OR REPLACE FUNCTION sp_delete_policy_template(
    p_template_id UUID,
    p_hard_delete BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    IF p_hard_delete THEN
        DELETE FROM policy_templates WHERE template_id = p_template_id;
    ELSE
        UPDATE policy_templates 
        SET is_active = FALSE
        WHERE template_id = p_template_id;
    END IF;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;
