-- Ensure uuid generator exists (if you haven't already)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

BEGIN;


-- Drop all sp_get_policy_catalog variants
DROP FUNCTION IF EXISTS sp_get_policy_catalog(UUID, UUID, UUID, UUID, BOOLEAN);
DROP FUNCTION IF EXISTS sp_get_policy_catalog(UUID, VARCHAR, UUID, VARCHAR, VARCHAR, BOOLEAN);
DROP FUNCTION IF EXISTS sp_get_policy_catalog(UUID, UUID, UUID, VARCHAR, VARCHAR, BOOLEAN);

-- Drop all sp_create_policy_catalog_item variants
DROP FUNCTION IF EXISTS sp_create_policy_catalog_item(UUID, VARCHAR, UUID, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS sp_create_policy_catalog_item(UUID, VARCHAR, UUID, UUID, UUID, TEXT, BOOLEAN);

-- Drop all sp_update_policy_catalog_item variants
DROP FUNCTION IF EXISTS sp_update_policy_catalog_item(UUID, VARCHAR, UUID, TEXT, UUID, UUID, BOOLEAN);
DROP FUNCTION IF EXISTS sp_update_policy_catalog_item(UUID, VARCHAR, UUID, UUID, UUID, TEXT, BOOLEAN, UUID);

-- Drop all sp_delete_policy_catalog_item variants
DROP FUNCTION IF EXISTS sp_delete_policy_catalog_item(UUID, BOOLEAN);
DROP FUNCTION IF EXISTS sp_delete_policy_catalog_item(UUID, UUID);

-- Drop all sp_upsert_policy_catalog variants
DROP FUNCTION IF EXISTS sp_upsert_policy_catalog(UUID, UUID, VARCHAR, UUID, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS sp_upsert_policy_catalog(UUID, UUID, VARCHAR, UUID, UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS sp_upsert_policy_catalog(UUID, VARCHAR, UUID, UUID, UUID, TEXT);

-- ============================================================
-- CREATE: Get Policy Catalog (6 params)
-- Service call: sp_get_policy_catalog($1,$2,$3,$4,$5,$6)
-- [agentId, typeId, companyId, null, null, isActive]
-- ============================================================
CREATE OR REPLACE FUNCTION sp_get_policy_catalog(
    p_agent_id UUID,
    p_type_id UUID,
    p_company_id UUID,
    p_company_name VARCHAR(100) DEFAULT NULL,
    p_search_term VARCHAR(100) DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    policy_catalog_id UUID,
    agent_id UUID,
    policy_name VARCHAR(100),
    company_id UUID,
    company_name VARCHAR(100),
    notes TEXT,
    is_active BOOLEAN,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    category_id UUID,
    category_name VARCHAR(50),
    type_id UUID,
    type_name VARCHAR(50)
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
        cat.category_name,
        pc.type_id,
        pt.type_name
    FROM policy_catalog pc
    LEFT JOIN insurance_companies ic ON pc.company_id = ic.company_id
    LEFT JOIN policy_categories   cat ON pc.category_id = cat.category_id
    LEFT JOIN policy_types        pt  ON pc.type_id    = pt.type_id
    WHERE pc.agent_id = p_agent_id
      AND (p_type_id      IS NULL OR pc.type_id      = p_type_id)
      AND (p_company_id   IS NULL OR pc.company_id   = p_company_id)
      AND (p_company_name IS NULL OR ic.company_name ILIKE '%' || p_company_name || '%')
      AND (p_search_term  IS NULL OR pc.policy_name  ILIKE '%' || p_search_term  || '%')
      AND (p_is_active    IS NULL OR pc.is_active    = p_is_active)
    ORDER BY pc.policy_name ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- CREATE: Create Policy Catalog Item (7 params)
-- Service call: sp_create_policy_catalog_item($1,$2,$3,$4,$5,$6,$7)
-- [agentId, policyName, typeId, companyId, categoryId, notes, isActive]
-- ============================================================
CREATE OR REPLACE FUNCTION sp_create_policy_catalog_item(
    p_agent_id UUID,
    p_policy_name VARCHAR(100),
    p_type_id UUID,
    p_company_id UUID,
    p_category_id UUID,
    p_notes TEXT,
    p_is_active BOOLEAN
)
RETURNS TABLE(policy_catalog_id UUID, error_message TEXT) AS $$
DECLARE
    v_policy_catalog_id UUID := gen_random_uuid();
BEGIN
    -- Validate that company exists
    IF p_company_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM insurance_companies WHERE company_id = p_company_id AND is_active = TRUE) THEN
        RETURN QUERY SELECT NULL::UUID, 'Company not found'::TEXT;
        RETURN;
    END IF;

    -- Validate that type exists if provided
    IF p_type_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM policy_types WHERE type_id = p_type_id AND is_active = TRUE) THEN
        RETURN QUERY SELECT NULL::UUID, 'Policy type not found'::TEXT;
        RETURN;
    END IF;

    -- Validate that category exists if provided
    IF p_category_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM policy_categories WHERE category_id = p_category_id AND is_active = TRUE) THEN
        RETURN QUERY SELECT NULL::UUID, 'Policy category not found'::TEXT;
        RETURN;
    END IF;

    INSERT INTO policy_catalog (
        policy_catalog_id, agent_id, policy_name, company_id, type_id,
        category_id, notes, is_active, created_date
    )
    VALUES (
        v_policy_catalog_id, p_agent_id, p_policy_name, p_company_id, p_type_id,
        p_category_id, p_notes, p_is_active, NOW()
    );

    RETURN QUERY SELECT v_policy_catalog_id, NULL::TEXT;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT NULL::UUID, SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- CREATE: Update Policy Catalog Item (8 params)
-- Service call: sp_update_policy_catalog_item($1,$2,$3,$4,$5,$6,$7,$8)
-- [policyCatalogId, policyName, typeId, companyId, categoryId, notes, isActive, agentId]
-- ============================================================
CREATE OR REPLACE FUNCTION sp_update_policy_catalog_item(
    p_policy_catalog_id UUID,
    p_policy_name VARCHAR(100),
    p_type_id UUID,
    p_company_id UUID,
    p_category_id UUID,
    p_notes TEXT,
    p_is_active BOOLEAN,
    p_agent_id UUID
)
RETURNS TABLE(rows_affected INTEGER, error_message TEXT) AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    UPDATE policy_catalog
    SET policy_name   = COALESCE(p_policy_name, policy_name),
        type_id       = COALESCE(p_type_id, type_id),
        company_id    = COALESCE(p_company_id, company_id),
        category_id   = COALESCE(p_category_id, category_id),
        notes         = COALESCE(p_notes, notes),
        is_active     = COALESCE(p_is_active, is_active),
        modified_date = NOW()
    WHERE policy_catalog_id = p_policy_catalog_id
      AND (p_agent_id IS NULL OR agent_id = p_agent_id);

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows, NULL::TEXT;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 0, SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- CREATE: Delete Policy Catalog Item (2 params)
-- Service call: sp_delete_policy_catalog_item($1,$2)
-- [policyCatalogId, agentId]
-- ============================================================
CREATE OR REPLACE FUNCTION sp_delete_policy_catalog_item(
    p_policy_catalog_id UUID,
    p_agent_id UUID
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    UPDATE policy_catalog
    SET is_active = FALSE,
        modified_date = NOW()
    WHERE policy_catalog_id = p_policy_catalog_id
      AND agent_id = p_agent_id;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- CREATE: Upsert Policy Catalog (7 params)
-- Service call: sp_upsert_policy_catalog($1,$2,$3,$4,$5,$6,$7)
-- [policyCatalogId, agentId, policyName, companyId, typeId, categoryId, notes]
-- ============================================================
CREATE OR REPLACE FUNCTION sp_upsert_policy_catalog(
    p_policy_catalog_id UUID,
    p_agent_id UUID,
    p_policy_name VARCHAR(100),
    p_company_id UUID,
    p_type_id UUID,
    p_category_id UUID,
    p_notes TEXT
)
RETURNS TABLE(policy_catalog_id UUID, error_message TEXT) AS $$
DECLARE
    v_new_id UUID;
BEGIN
    -- Validate that company exists
    IF p_company_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM insurance_companies WHERE company_id = p_company_id AND is_active = TRUE) THEN
        RETURN QUERY SELECT NULL::UUID, 'Company not found'::TEXT;
        RETURN;
    END IF;

    IF p_policy_catalog_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM policy_catalog WHERE policy_catalog_id = p_policy_catalog_id) THEN
        -- Create new record
        v_new_id := gen_random_uuid();
        INSERT INTO policy_catalog (
            policy_catalog_id, agent_id, policy_name, company_id, type_id,
            category_id, notes, is_active, created_date
        )
        VALUES (
            v_new_id, p_agent_id, p_policy_name, p_company_id, p_type_id,
            p_category_id, p_notes, TRUE, NOW()
        );
        RETURN QUERY SELECT v_new_id, NULL::TEXT;
    ELSE
        -- Update existing record
        UPDATE policy_catalog
        SET policy_name   = p_policy_name,
            company_id    = p_company_id,
            type_id       = p_type_id,
            category_id   = p_category_id,
            notes         = p_notes,
            modified_date = NOW()
        WHERE policy_catalog_id = p_policy_catalog_id
          AND agent_id = p_agent_id;

        RETURN QUERY SELECT p_policy_catalog_id, NULL::TEXT;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT NULL::UUID, SQLERRM;
END;
$$ LANGUAGE plpgsql;
