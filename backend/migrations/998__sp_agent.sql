
-- Drop existing functions that might be causing conflicts
DROP FUNCTION IF EXISTS sp_upsert_agent(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, UUID);
DROP FUNCTION IF EXISTS sp_upsert_agent(VARCHAR(50), VARCHAR(50), VARCHAR(100), VARCHAR(20), VARCHAR(200), TEXT, UUID);
DROP FUNCTION IF EXISTS sp_register_agent(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS sp_register_agent(VARCHAR(50), VARCHAR(50), VARCHAR(100), VARCHAR(20), VARCHAR(200), TEXT);

-- ===========================================================
-- FIXED: Create or Update Agent Profile
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_upsert_agent(
    p_first_name VARCHAR(50),
    p_last_name VARCHAR(50),
    p_email VARCHAR(100),
    p_phone VARCHAR(20),
    p_password_hash VARCHAR(200),
    p_avatar TEXT DEFAULT NULL,
    p_agent_id UUID DEFAULT NULL
)
RETURNS UUID AS $BODY$
DECLARE
    v_agent_id UUID;
BEGIN
    IF p_agent_id IS NULL THEN
        -- Create new agent
        v_agent_id := gen_random_uuid();

        INSERT INTO agent (agent_id, first_name, last_name, email, phone, password_hash, avatar)
        VALUES (v_agent_id, p_first_name, p_last_name, p_email, p_phone, p_password_hash, p_avatar);

        -- Create default settings
        INSERT INTO agent_settings (agent_id) VALUES (v_agent_id);

        -- Create default reminder settings
        INSERT INTO reminder_settings (agent_id, reminder_type, days_before, time_of_day)
        VALUES 
            (v_agent_id, 'Policy Expiry', 30, '09:00'::TIME),
            (v_agent_id, 'Birthday', 1, '08:00'::TIME),
            (v_agent_id, 'Appointment', 1, '18:00'::TIME),
            (v_agent_id, 'Call', 0, '10:00'::TIME);
    ELSE
        -- Update existing agent
        v_agent_id := p_agent_id;

        UPDATE agent
        SET first_name = p_first_name,
            last_name = p_last_name,
            email = p_email,
            phone = p_phone,
            password_hash = p_password_hash,
            avatar = COALESCE(p_avatar, avatar),
            modified_date = NOW()
        WHERE agent_id = p_agent_id;

        -- Ensure settings exist for updated agent
        IF NOT EXISTS (SELECT 1 FROM agent_settings WHERE agent_id = p_agent_id) THEN
            INSERT INTO agent_settings (agent_id) VALUES (p_agent_id);
        END IF;
    END IF;

    RETURN v_agent_id;
END;
$BODY$ LANGUAGE plpgsql;
-- ===========================================================
-- Get Agent Profile
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_agent(p_agent_id UUID)
RETURNS TABLE (
    agent_id UUID,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    password_hash VARCHAR(200),
    avatar TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    is_active BOOLEAN,
    dark_mode BOOLEAN,
    email_notifications BOOLEAN,
    sms_notifications BOOLEAN,
    whatsapp_notifications BOOLEAN,
    push_notifications BOOLEAN,
    sound_enabled BOOLEAN
) AS $BODY$
BEGIN
    RETURN QUERY
    SELECT 
        a.agent_id, a.first_name, a.last_name, a.email, a.phone, a.password_hash, a.avatar,
        a.created_date, a.modified_date, a.is_active,
        COALESCE(s.dark_mode, FALSE),
        COALESCE(s.email_notifications, TRUE),
        COALESCE(s.sms_notifications, TRUE),
        COALESCE(s.whatsapp_notifications, TRUE),
        COALESCE(s.push_notifications, TRUE),
        COALESCE(s.sound_enabled, TRUE)
    FROM agent a
    LEFT JOIN agent_settings s ON a.agent_id = s.agent_id
    WHERE a.agent_id = p_agent_id
      AND a.is_active = TRUE;
END;
$BODY$ LANGUAGE plpgsql;

-- ===========================================================
-- Update Agent Settings
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_update_agent_settings(
    p_agent_id UUID,
    p_dark_mode BOOLEAN DEFAULT NULL,
    p_email_notifications BOOLEAN DEFAULT NULL,
    p_sms_notifications BOOLEAN DEFAULT NULL,
    p_whatsapp_notifications BOOLEAN DEFAULT NULL,
    p_push_notifications BOOLEAN DEFAULT NULL,
    p_sound_enabled BOOLEAN DEFAULT NULL
)
RETURNS VOID AS $BODY$
BEGIN
    -- Ensure settings exist
    IF NOT EXISTS (SELECT 1 FROM agent_settings WHERE agent_id = p_agent_id) THEN
        INSERT INTO agent_settings (agent_id) VALUES (p_agent_id);
    END IF;

    UPDATE agent_settings
    SET dark_mode           = COALESCE(p_dark_mode, dark_mode),
        email_notifications = COALESCE(p_email_notifications, email_notifications),
        sms_notifications   = COALESCE(p_sms_notifications, sms_notifications),
        whatsapp_notifications = COALESCE(p_whatsapp_notifications, whatsapp_notifications),
        push_notifications  = COALESCE(p_push_notifications, push_notifications),
        sound_enabled       = COALESCE(p_sound_enabled, sound_enabled),
        modified_date       = NOW()
    WHERE agent_id = p_agent_id;
END;
$BODY$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Insurance Companies
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_insurance_companies()
RETURNS TABLE(company_id UUID, company_name VARCHAR(100)) AS $BODY$
BEGIN
    RETURN QUERY
    SELECT company_id, company_name
    FROM insurance_companies
    WHERE is_active = TRUE
    ORDER BY company_name;
END;
$BODY$ LANGUAGE plpgsql;

-- ===========================================================
-- Get Policy Types
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_policy_types()
RETURNS TABLE(type_id UUID, type_name VARCHAR(100)) AS $BODY$
BEGIN
    RETURN QUERY
    SELECT type_id, type_name
    FROM policy_types
    WHERE is_active = TRUE
    ORDER BY type_name;
END;
$BODY$ LANGUAGE plpgsql;

-- ===========================================================
-- Authenticate Agent
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_authenticate_agent(p_email VARCHAR(100))
RETURNS TABLE (
    agent_id UUID,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    password_hash VARCHAR(200)
) AS $BODY$
BEGIN
    RETURN QUERY
    SELECT agent_id, first_name, last_name, email, phone, password_hash
    FROM agent
    WHERE email = p_email
      AND is_active = TRUE;
END;
$BODY$ LANGUAGE plpgsql;

-- ===========================================================
-- Login Authentication
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_login_agent(
    p_email VARCHAR(100),
    p_password VARCHAR(200) DEFAULT NULL
)
RETURNS TABLE (
    success INTEGER,
    message TEXT,
    agent_id UUID,
    stored_password_hash VARCHAR(200),
    agent_profile JSONB
) AS $BODY$
DECLARE
    v_agent_id UUID;
    v_stored_hash VARCHAR(200);
    v_is_active BOOLEAN;
    v_agent_profile JSONB;
BEGIN
    -- Get agent details
    SELECT a.agent_id, a.password_hash, a.is_active
    INTO v_agent_id, v_stored_hash, v_is_active
    FROM agent a
    WHERE a.email = p_email;

    IF v_agent_id IS NULL THEN
        RETURN QUERY SELECT 0, 'Invalid email or password', NULL, NULL, NULL;
        RETURN;
    END IF;

    IF v_is_active = FALSE THEN
        RETURN QUERY SELECT 0, 'Account is deactivated', NULL, NULL, NULL;
        RETURN;
    END IF;

    SELECT jsonb_build_object(
        'agent_id', a.agent_id,
        'first_name', a.first_name,
        'last_name', a.last_name,
        'email', a.email,
        'phone', a.phone,
        'avatar', a.avatar,
        'created_date', a.created_date,
        'is_active', a.is_active,
        'dark_mode', COALESCE(s.dark_mode, FALSE),
        'email_notifications', COALESCE(s.email_notifications, TRUE),
        'sms_notifications', COALESCE(s.sms_notifications, TRUE),
        'whatsapp_notifications', COALESCE(s.whatsapp_notifications, TRUE),
        'push_notifications', COALESCE(s.push_notifications, TRUE),
        'sound_enabled', COALESCE(s.sound_enabled, TRUE)
    )
    INTO v_agent_profile
    FROM agent a
    LEFT JOIN agent_settings s ON a.agent_id = s.agent_id
    WHERE a.agent_id = v_agent_id;

    RETURN QUERY
    SELECT 1, 'Login successful', v_agent_id, v_stored_hash, v_agent_profile;
END;
$BODY$ LANGUAGE plpgsql;
-- ===========================================================
-- Register Agent
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_register_agent(
    p_first_name VARCHAR(50),
    p_last_name VARCHAR(50),
    p_email VARCHAR(100),
    p_phone VARCHAR(20),
    p_password_hash VARCHAR(200),
    p_avatar TEXT DEFAULT NULL
)
RETURNS TABLE(
    success INTEGER, 
    message TEXT, 
    agent_id UUID
) AS $BODY$
DECLARE
    v_agent_id UUID := gen_random_uuid();
BEGIN
    -- Check for duplicate email
    IF EXISTS(SELECT 1 FROM agent WHERE email = p_email) THEN
        RETURN QUERY SELECT 0::INTEGER, 'Email already exists'::TEXT, NULL::UUID;
        RETURN;
    END IF;

    BEGIN
        -- Insert new agent
        INSERT INTO agent (agent_id, first_name, last_name, email, phone, password_hash, avatar)
        VALUES (v_agent_id, p_first_name, p_last_name, p_email, p_phone, p_password_hash, p_avatar);

        -- Create default settings
        INSERT INTO agent_settings (agent_id) VALUES (v_agent_id);

        -- Create default reminder settings
        INSERT INTO reminder_settings (agent_id, reminder_type, days_before)
        VALUES 
            (v_agent_id, 'Policy Expiry', 7),
            (v_agent_id, 'Birthday', 1),
            (v_agent_id, 'Appointment', 1);

        -- Create default notification preferences (if table exists)
        INSERT INTO agent_notification_preferences (agent_id, notification_type)
        VALUES 
            (v_agent_id, 'appointment'),
            (v_agent_id, 'birthday'),
            (v_agent_id, 'policy_expiry')
        ON CONFLICT DO NOTHING; -- In case table doesn't exist yet

        RETURN QUERY SELECT 1::INTEGER, 'Registration successful'::TEXT, v_agent_id;
        
    EXCEPTION 
        WHEN unique_violation THEN
            RETURN QUERY SELECT 0::INTEGER, 'Email already exists'::TEXT, NULL::UUID;
        WHEN OTHERS THEN
            RETURN QUERY SELECT 0::INTEGER, ('Registration failed: ' || SQLERRM)::TEXT, NULL::UUID;
    END;
END;
$BODY$ LANGUAGE plpgsql;
-- ===========================================================
-- Change Password
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_change_password(
    p_agent_id UUID,
    p_new_password_hash VARCHAR(200),
    p_old_password_hash VARCHAR(200) DEFAULT NULL
)
RETURNS TABLE(success INTEGER, message TEXT) AS $$
DECLARE
    v_stored_hash VARCHAR(200);
BEGIN
    SELECT password_hash
    INTO v_stored_hash
    FROM agent
    WHERE agent_id = p_agent_id AND is_active = TRUE;

    IF v_stored_hash IS NULL THEN
        RETURN QUERY SELECT 0, 'Agent not found or inactive';
        RETURN;
    END IF;

    UPDATE agent
    SET password_hash = p_new_password_hash,
        modified_date = NOW()
    WHERE agent_id = p_agent_id;

    RETURN QUERY SELECT 1, 'Password changed successfully';
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Request Password Reset
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_request_password_reset(p_email VARCHAR(100))
RETURNS TABLE(success INTEGER, message TEXT, agent_id UUID, email VARCHAR(100)) AS $$
DECLARE
    v_agent_id UUID;
BEGIN
    SELECT agent_id
    INTO v_agent_id
    FROM agent
    WHERE email = p_email AND is_active = TRUE;

    IF v_agent_id IS NULL THEN
        RETURN QUERY SELECT 0, 'Email not found', NULL, NULL;
        RETURN;
    END IF;

    RETURN QUERY SELECT 1, 'Reset request valid', v_agent_id, p_email;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================
-- Reset Password
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_reset_password(
    p_agent_id UUID,
    p_new_password_hash VARCHAR(200)
)
RETURNS TABLE(success INTEGER, message TEXT) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE agent
    SET password_hash = p_new_password_hash,
        modified_date = NOW()
    WHERE agent_id = p_agent_id
      AND is_active = TRUE;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RETURN QUERY SELECT 0, 'Invalid reset request or agent not found';
        RETURN;
    END IF;

    RETURN QUERY SELECT 1, 'Password reset successful';
END;
$$ LANGUAGE plpgsql;


