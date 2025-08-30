-- ============================================
-- Create New Client (PostgreSQL Version)
-- ============================================
CREATE OR REPLACE FUNCTION sp_create_client(
    p_agent_id UUID,
    p_first_name VARCHAR(50),
    p_surname VARCHAR(50),
    p_last_name VARCHAR(50),
    p_phone_number VARCHAR(20),
    p_email VARCHAR(100),
    p_address VARCHAR(500),
    p_national_id VARCHAR(20),
    p_date_of_birth DATE,
    p_insurance_type VARCHAR(50),
    p_is_client BOOLEAN DEFAULT FALSE,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE(
    success INT,
    message TEXT,
    client_id UUID
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_client_id UUID := gen_random_uuid(); -- requires pgcrypto extension
BEGIN
    -- Check for duplicate phone
    IF EXISTS (
        SELECT 1 FROM clients 
        WHERE phone_number = p_phone_number 
          AND agent_id = p_agent_id 
          AND is_active = TRUE
    ) THEN
        RETURN QUERY
        SELECT 0, 'Phone number already exists', NULL::UUID;
        RETURN;
    END IF;

    -- Check for duplicate email
    IF EXISTS (
        SELECT 1 FROM clients 
        WHERE email = p_email 
          AND agent_id = p_agent_id 
          AND is_active = TRUE
    ) THEN
        RETURN QUERY
        SELECT 0, 'Email already exists', NULL::UUID;
        RETURN;
    END IF;

    -- Insert into Clients
    INSERT INTO clients (
        client_id, agent_id, first_name, surname, last_name, phone_number,
        email, address, national_id, date_of_birth, is_client, insurance_type, notes
    ) VALUES (
        v_client_id, p_agent_id, p_first_name, p_surname, p_last_name, p_phone_number,
        p_email, p_address, p_national_id, p_date_of_birth, p_is_client, p_insurance_type, p_notes
    );

    -- Log activity
    INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description)
    VALUES (
        p_agent_id,
        CASE WHEN p_is_client THEN 'client_added' ELSE 'prospect_added' END,
        'client',
        v_client_id,
        'Added new ' || CASE WHEN p_is_client THEN 'client' ELSE 'prospect' END || ': ' || p_first_name || ' ' || p_surname
    );

    -- Return success
    RETURN QUERY
    SELECT 
        1,
        CASE WHEN p_is_client THEN 'Client created successfully' ELSE 'Prospect created successfully' END,
        v_client_id;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT 0, SQLERRM, NULL::UUID;
END;
$$;
