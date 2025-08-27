

-- ============================================
-- REFERENCE DATA FUNCTIONS
-- ============================================

-- Get Insurance Companies
CREATE OR REPLACE FUNCTION sp_get_insurance_companies(p_is_active BOOLEAN DEFAULT TRUE)
RETURNS TABLE(company_id UUID, company_name VARCHAR(100), is_active BOOLEAN, created_date TIMESTAMPTZ) AS $
BEGIN
    RETURN QUERY
    SELECT 
        ic.company_id,
        ic.company_name,
        ic.is_active,
        ic.created_date
    FROM insurance_companies ic
    WHERE (p_is_active IS NULL OR ic.is_active = p_is_active)
    ORDER BY ic.company_name;
END;
$ LANGUAGE plpgsql;

-- Get Policy Types
CREATE OR REPLACE FUNCTION sp_get_policy_types_list(p_is_active BOOLEAN DEFAULT TRUE)
RETURNS TABLE(type_id UUID, type_name VARCHAR(100), is_active BOOLEAN, created_date TIMESTAMPTZ) AS $
BEGIN
    RETURN QUERY
    SELECT 
        pt.type_id,
        pt.type_name,
        pt.is_active,
        pt.created_date
    FROM policy_types pt
    WHERE (p_is_active IS NULL OR pt.is_active = p_is_active)
    ORDER BY pt.type_name;
END;
$ LANGUAGE plpgsql;

-- Get Policy Categories
CREATE OR REPLACE FUNCTION sp_get_policy_categories_list(p_is_active BOOLEAN DEFAULT TRUE)
RETURNS TABLE(
    category_id UUID, 
    category_name VARCHAR(100), 
    description TEXT, 
    is_active BOOLEAN, 
    created_date TIMESTAMPTZ
) AS $
BEGIN
    RETURN QUERY
    SELECT 
        pc.category_id,
        pc.category_name,
        pc.description,
        pc.is_active,
        pc.created_date
    FROM policy_categories pc
    WHERE (p_is_active IS NULL OR pc.is_active = p_is_active)
    ORDER BY pc.category_name;
END;
$ LANGUAGE plpgsql;

-- Create Policy Category
CREATE OR REPLACE FUNCTION sp_create_policy_category(
    p_category_name VARCHAR(100),
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(category_id UUID) AS $
DECLARE
    v_category_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO policy_categories (
        category_id, category_name, description, is_active, created_date
    )
    VALUES (
        v_category_id, p_category_name, p_description, TRUE, NOW()
    );
    
    RETURN QUERY SELECT v_category_id;
END;
$ LANGUAGE plpgsql;

-- ============================================
-- ADDITIONAL RECOMMENDED FUNCTIONS
-- ============================================

-- Create Insurance Company
CREATE OR REPLACE FUNCTION sp_create_insurance_company(p_company_name VARCHAR(100))
RETURNS TABLE(company_id UUID) AS $
DECLARE
    v_company_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO insurance_companies (
        company_id, company_name, is_active, created_date
    )
    VALUES (
        v_company_id, p_company_name, TRUE, NOW()
    );
    
    RETURN QUERY SELECT v_company_id;
END;
$ LANGUAGE plpgsql;

-- Create Policy Type
CREATE OR REPLACE FUNCTION sp_create_policy_type_new(p_type_name VARCHAR(100))
RETURNS TABLE(type_id UUID) AS $
DECLARE
    v_type_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO policy_types (
        type_id, type_name, is_active, created_date
    )
    VALUES (
        v_type_id, p_type_name, TRUE, NOW()
    );
    
    RETURN QUERY SELECT v_type_id;
END;
$ LANGUAGE plpgsql;

-- Get Policy Renewal Candidates
CREATE OR REPLACE FUNCTION sp_get_policy_renewal_candidates(
    p_agent_id UUID DEFAULT NULL,
    p_days_ahead INTEGER DEFAULT 60
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
    days_until_expiry INTEGER,
    renewal_priority VARCHAR(10)
) AS $
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
        EXTRACT(DAYS FROM (cp.end_date - CURRENT_DATE))::INTEGER as days_until_expiry,
        CASE 
            WHEN EXTRACT(DAYS FROM (cp.end_date - CURRENT_DATE)) <= 30 THEN 'Urgent'
            WHEN EXTRACT(DAYS FROM (cp.end_date - CURRENT_DATE)) <= 45 THEN 'Soon'
            ELSE 'Upcoming'
        END::VARCHAR(10) as renewal_priority
    FROM client_policies cp
        LEFT JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
        LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
        LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE cp.is_active = TRUE
        AND cp.status = 'Active'
        AND cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '%s days')
        AND (p_agent_id IS NULL OR pc.agent_id = p_agent_id)
    ORDER BY cp.end_date, renewal_priority;
END;
$ LANGUAGE plpgsql;

-- Get Agent Dashboard Summary
CREATE OR REPLACE FUNCTION sp_get_agent_dashboard_summary(p_agent_id UUID)
RETURNS TABLE (
    total_policies BIGINT,
    active_policies BIGINT,
    expiring_in_30_days BIGINT,
    expiring_in_60_days BIGINT,
    total_companies BIGINT,
    total_clients BIGINT,
    inactive_policies BIGINT
) AS $
DECLARE
    v_total_policies BIGINT := 0;
    v_active_policies BIGINT := 0;
    v_expiring_in_30_days BIGINT := 0;
    v_expiring_in_60_days BIGINT := 0;
    v_total_companies BIGINT := 0;
    v_total_clients BIGINT := 0;
BEGIN
    -- Get policy counts
    SELECT 
        COUNT(*),
        SUM(CASE WHEN cp.status = 'Active' AND cp.is_active = TRUE THEN 1 ELSE 0 END),
        SUM(CASE 
            WHEN cp.status = 'Active' 
                 AND cp.is_active = TRUE
                 AND cp.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days')
            THEN 1 ELSE 0 END),
        SUM(CASE 
            WHEN cp.status = 'Active' 
                 AND cp.is_active = TRUE
                 AND cp.end_date BETWEEN (CURRENT_DATE + INTERVAL '31 days') AND (CURRENT_DATE + INTERVAL '60 days')
            THEN 1 ELSE 0 END)
    INTO v_total_policies, v_active_policies, v_expiring_in_30_days, v_expiring_in_60_days
    FROM client_policies cp
        INNER JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    WHERE pc.agent_id = p_agent_id;

    -- Get company count (companies actually used in policies for this agent)
    SELECT COUNT(DISTINCT cp.company_id)
    INTO v_total_companies
    FROM client_policies cp
        INNER JOIN policy_catalog pc ON cp.policy_catalog_id = pc.policy_catalog_id
    WHERE pc.agent_id = p_agent_id
      AND cp.is_active = TRUE
      AND cp.company_id IS NOT NULL;

    -- Get client count (all clients of the agent, regardless of policy)
    SELECT COUNT(*)
    INTO v_total_clients
    FROM clients c
    WHERE c.agent_id = p_agent_id
      AND COALESCE(c.is_active, TRUE) = TRUE;

    RETURN QUERY
    SELECT 
        v_total_policies,
        v_active_policies,
        v_expiring_in_30_days,
        v_expiring_in_60_days,
        v_total_companies,
        v_total_clients,
        (v_total_policies - v_active_policies) as inactive_policies;
END;
$ LANGUAGE plpgsql;

-- Update Policy Category
CREATE OR REPLACE FUNCTION sp_update_policy_category_details(
    p_category_id UUID,
    p_category_name VARCHAR(100) DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS TABLE(rows_affected INTEGER) AS $
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE policy_categories
    SET 
        category_name = COALESCE(p_category_name, category_name),
        description = COALESCE(p_description, description),
        is_active = COALESCE(p_is_active, is_active)
    WHERE category_id = p_category_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$ LANGUAGE plpgsql;

-- Update Insurance Company
CREATE OR REPLACE FUNCTION sp_update_insurance_company(
    p_company_id UUID,
    p_company_name VARCHAR(100) DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS TABLE(rows_affected INTEGER) AS $
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE insurance_companies
    SET 
        company_name = COALESCE(p_company_name, company_name),
        is_active = COALESCE(p_is_active, is_active)
    WHERE company_id = p_company_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$ LANGUAGE plpgsql;

-- Update Policy Type
CREATE OR REPLACE FUNCTION sp_update_policy_type_details(
    p_type_id UUID,
    p_type_name VARCHAR(100) DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS TABLE(rows_affected INTEGER) AS $
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE policy_types
    SET 
        type_name = COALESCE(p_type_name, type_name),
        is_active = COALESCE(p_is_active, is_active)
    WHERE type_id = p_type_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$ LANGUAGE plpgsql;

-- Get Policy History for Client
CREATE OR REPLACE FUNCTION sp_get_policy_history_for_client(
    p_client_id UUID,
    p_include_inactive BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    policy_id UUID,
    client_id UUID,
    policy_name VARCHAR(100),
    status VARCHAR(20),
    start_date DATE,
    end_date DATE,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    company_id UUID,
    company_name VARCHAR(100),
    type_id UUID,
    type_name VARCHAR(100),
    policy_duration_days INTEGER,
    policy_state VARCHAR(20)
) AS $
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
        cp.company_id,
        ic.company_name,
        cp.type_id,
        pt.type_name,
        EXTRACT(DAYS FROM (cp.end_date - cp.start_date))::INTEGER as policy_duration_days,
        CASE 
            WHEN cp.status = 'Active' AND cp.end_date > CURRENT_DATE THEN 'Current'
            WHEN cp.status = 'Active' AND cp.end_date <= CURRENT_DATE THEN 'Expired'
            ELSE cp.status
        END::VARCHAR(20) as policy_state
    FROM client_policies cp
        LEFT JOIN policy_types pt ON cp.type_id = pt.type_id
        LEFT JOIN insurance_companies ic ON cp.company_id = ic.company_id
    WHERE cp.client_id = p_client_id
        AND (p_include_inactive = TRUE OR cp.is_active = TRUE)
    ORDER BY cp.start_date DESC, cp.created_date DESC;
END;
$ LANGUAGE plpgsql;

-- Batch Expire Policies
CREATE OR REPLACE FUNCTION sp_batch_expire_policies(p_as_of_date DATE DEFAULT NULL)
RETURNS TABLE(policies_expired INTEGER) AS $
DECLARE
    v_as_of_date DATE := COALESCE(p_as_of_date, CURRENT_DATE);
    v_rows_affected INTEGER;
BEGIN
    UPDATE client_policies
    SET status = 'Expired', modified_date = NOW()
    WHERE status = 'Active' 
        AND end_date < v_as_of_date
        AND is_active = TRUE;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN QUERY SELECT v_rows_affected;
END;
$ LANGUAGE plpgsql;

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Cleanup Soft Deleted Records
CREATE OR REPLACE FUNCTION sp_cleanup_soft_deleted_records(
    p_days_old INTEGER DEFAULT 365,
    p_dry_run BOOLEAN DEFAULT TRUE
)
RETURNS TABLE(table_name VARCHAR(50), records_to_delete BIGINT) AS $
DECLARE
    v_cutoff_date TIMESTAMPTZ := NOW() - INTERVAL '%s days';
    v_deleted_count INTEGER := 0;
BEGIN
    IF p_dry_run = TRUE THEN
        -- Show what would be deleted
        RETURN QUERY
        SELECT 'client_policies'::VARCHAR(50) as table_name, COUNT(*) as records_to_delete
        FROM client_policies 
        WHERE is_active = FALSE AND modified_date < v_cutoff_date
        
        UNION ALL
        
        SELECT 'policy_catalog'::VARCHAR(50) as table_name, COUNT(*) as records_to_delete
        FROM policy_catalog 
        WHERE is_active = FALSE AND modified_date < v_cutoff_date
        
        UNION ALL
        
        SELECT 'policy_templates'::VARCHAR(50) as table_name, COUNT(*) as records_to_delete
        FROM policy_templates 
        WHERE is_active = FALSE AND created_date < v_cutoff_date;
    ELSE
        -- Actually delete the records
        DELETE FROM client_policies 
        WHERE is_active = FALSE AND modified_date < v_cutoff_date;
        
        GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
        
        DELETE FROM policy_catalog 
        WHERE is_active = FALSE AND modified_date < v_cutoff_date;
        
        GET DIAGNOSTICS v_deleted_count = v_deleted_count + ROW_COUNT;
        
        DELETE FROM policy_templates 
        WHERE is_active = FALSE AND created_date < v_cutoff_date;
        
        GET DIAGNOSTICS v_deleted_count = v_deleted_count + ROW_COUNT;
        
        RETURN QUERY SELECT 'total_deleted'::VARCHAR(50), v_deleted_count::BIGINT;
    END IF;
END;
$ LANGUAGE plpgsql;

-- Get Clients With Policies
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
) AS $
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
        EXTRACT(DAYS FROM (cp.end_date - CURRENT_DATE))::INTEGER AS days_until_expiry
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
$ LANGUAGE plpgsql;

-- ============================================
-- SOFT DELETE FUNCTIONS
-- ============================================

-- Soft Delete Client Policy
CREATE OR REPLACE FUNCTION sp_soft_delete_client_policy(p_policy_id UUID)
RETURNS TABLE(success INTEGER, message TEXT) AS $
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
$ LANGUAGE plpgsql;

-- Soft Delete Insurance Company
CREATE OR REPLACE FUNCTION sp_soft_delete_insurance_company(p_company_id UUID)
RETURNS TABLE(success INTEGER, message TEXT) AS $
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE insurance_companies
    SET is_active = FALSE
    WHERE company_id = p_company_id AND COALESCE(is_active, TRUE) = TRUE;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected > 0 THEN
        RETURN QUERY SELECT 1, 'Insurance company soft deleted successfully';
    ELSE
        RETURN QUERY SELECT 0, 'Insurance company not found or already inactive';
    END IF;
END;
$ LANGUAGE plpgsql;

-- Soft Delete Policy Catalog
CREATE OR REPLACE FUNCTION sp_soft_delete_policy_catalog(p_policy_catalog_id UUID)
RETURNS TABLE(success INTEGER, message TEXT) AS $
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE policy_catalog
    SET is_active = FALSE,
        modified_date = NOW()
    WHERE policy_catalog_id = p_policy_catalog_id AND COALESCE(is_active, TRUE) = TRUE;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected > 0 THEN
        RETURN QUERY SELECT 1, 'Policy catalog soft deleted successfully';
    ELSE
        RETURN QUERY SELECT 0, 'Policy catalog not found or already inactive';
    END IF;
END;
$ LANGUAGE plpgsql;

-- Soft Delete Policy Category
CREATE OR REPLACE FUNCTION sp_soft_delete_policy_category(p_category_id UUID)
RETURNS TABLE(success INTEGER, message TEXT) AS $
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE policy_categories
    SET is_active = FALSE
    WHERE category_id = p_category_id AND COALESCE(is_active, TRUE) = TRUE;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected > 0 THEN
        RETURN QUERY SELECT 1, 'Policy category soft deleted successfully';
    ELSE
        RETURN QUERY SELECT 0, 'Policy category not found or already inactive';
    END IF;
END;
$ LANGUAGE plpgsql;

-- Soft Delete Policy Template
CREATE OR REPLACE FUNCTION sp_soft_delete_policy_template(p_template_id UUID)
RETURNS TABLE(success INTEGER, message TEXT) AS $
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE policy_templates
    SET is_active = FALSE
    WHERE template_id = p_template_id AND COALESCE(is_active, TRUE) = TRUE;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected > 0 THEN
        RETURN QUERY SELECT 1, 'Policy template soft deleted successfully';
    ELSE
        RETURN QUERY SELECT 0, 'Policy template not found or already inactive';
    END IF;
END;
$ LANGUAGE plpgsql;

-- Soft Delete Policy Type
CREATE OR REPLACE FUNCTION sp_soft_delete_policy_type(p_type_id UUID)
RETURNS TABLE(success INTEGER, message TEXT) AS $
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE policy_types
    SET is_active = FALSE
    WHERE type_id = p_type_id AND COALESCE(is_active, TRUE) = TRUE;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    IF v_rows_affected > 0 THEN
        RETURN QUERY SELECT 1, 'Policy type soft deleted successfully';
    ELSE
        RETURN QUERY SELECT 0, 'Policy type not found or already inactive';
    END IF;
END;
$ LANGUAGE plpgsql;
