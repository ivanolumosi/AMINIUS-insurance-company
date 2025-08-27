-- ============================================
-- Reminders and Messaging PostgreSQL Functions
-- (Rewritten to use $$ quoting and corrected syntax)
-- ============================================

-- Note: Ensure extension "pgcrypto" is available for gen_random_uuid():
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ===========================================================
-- Create or Update Reminder
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_upsert_reminder(
    p_reminder_id UUID,
    p_client_id UUID,
    p_appointment_id UUID,
    p_agent_id UUID,
    p_reminder_type VARCHAR(50),
    p_title VARCHAR(200),
    p_description TEXT DEFAULT NULL,
    p_reminder_date DATE DEFAULT NULL,
    p_reminder_time TIME DEFAULT NULL,
    p_client_name VARCHAR(150) DEFAULT NULL,
    p_priority VARCHAR(10) DEFAULT 'Medium',
    p_enable_sms BOOLEAN DEFAULT FALSE,
    p_enable_whatsapp BOOLEAN DEFAULT FALSE,
    p_enable_push_notification BOOLEAN DEFAULT TRUE,
    p_advance_notice VARCHAR(20) DEFAULT '1 day',
    p_custom_message TEXT DEFAULT NULL,
    p_auto_send BOOLEAN DEFAULT FALSE,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_reminder_id UUID;
BEGIN
    IF p_reminder_id IS NULL THEN
        -- Create new reminder
        v_reminder_id := gen_random_uuid();
        
        INSERT INTO reminders (
            reminder_id, client_id, appointment_id, agent_id, reminder_type, title, description,
            reminder_date, reminder_time, client_name, priority, enable_sms, enable_whatsapp,
            enable_push_notification, advance_notice, custom_message, auto_send, notes, status, created_date, modified_date
        )
        VALUES (
            v_reminder_id, p_client_id, p_appointment_id, p_agent_id, p_reminder_type, p_title, p_description,
            p_reminder_date, p_reminder_time, p_client_name, p_priority, p_enable_sms, p_enable_whatsapp,
            p_enable_push_notification, p_advance_notice, p_custom_message, p_auto_send, p_notes, 'Active', NOW(), NOW()
        );
        
        -- Log activity
        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
        VALUES (p_agent_id, 'reminder_created', 'reminder', v_reminder_id, 
                'Reminder "' || p_title || '" created', NOW());
    ELSE
        -- Update existing reminder
        v_reminder_id := p_reminder_id;
        
        UPDATE reminders 
        SET 
            reminder_type = p_reminder_type,
            title = p_title,
            description = p_description,
            reminder_date = p_reminder_date,
            reminder_time = p_reminder_time,
            client_name = p_client_name,
            priority = p_priority,
            enable_sms = p_enable_sms,
            enable_whatsapp = p_enable_whatsapp,
            enable_push_notification = p_enable_push_notification,
            advance_notice = p_advance_notice,
            custom_message = p_custom_message,
            auto_send = p_auto_send,
            notes = p_notes,
            modified_date = NOW()
        WHERE reminder_id = p_reminder_id;
        
        -- Log activity
        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
        VALUES (p_agent_id, 'reminder_updated', 'reminder', v_reminder_id, 
                'Reminder "' || p_title || '" updated', NOW());
    END IF;
    
    RETURN v_reminder_id;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get All Reminders with Comprehensive Union
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_all_reminders(
    p_agent_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_page_number INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 20
)
RETURNS TABLE (
    reminder_id UUID,
    client_id UUID,
    appointment_id UUID,
    agent_id UUID,
    reminder_type VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    reminder_date DATE,
    reminder_time TIME,
    client_name VARCHAR(150),
    priority VARCHAR(10),
    status VARCHAR(20),
    enable_sms BOOLEAN,
    enable_whatsapp BOOLEAN,
    enable_push_notification BOOLEAN,
    advance_notice VARCHAR(20),
    custom_message TEXT,
    auto_send BOOLEAN,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    completed_date TIMESTAMPTZ
) AS $$
DECLARE
    v_offset INTEGER := (p_page_number - 1) * p_page_size;
BEGIN
    RETURN QUERY
    WITH all_reminders AS (
        -- 1. Manual Reminders from reminders table
        SELECT 
            r.reminder_id,
            r.client_id,
            r.appointment_id,
            r.agent_id,
            CASE WHEN r.reminder_type = 'Policy Expiry' THEN 'Maturing Policy' ELSE r.reminder_type END AS reminder_type,
            r.title,
            r.description,
            r.reminder_date,
            r.reminder_time,
            r.client_name,
            r.priority,
            r.status,
            r.enable_sms,
            r.enable_whatsapp,
            r.enable_push_notification,
            r.advance_notice,
            r.custom_message,
            r.auto_send,
            r.notes,
            r.created_date,
            r.modified_date,
            r.completed_date
        FROM reminders r
        WHERE r.agent_id = p_agent_id

        UNION ALL

        -- 2. Maturing Policies
        SELECT 
            gen_random_uuid() AS reminder_id,
            cp.client_id,
            NULL AS appointment_id,
            c.agent_id,
            'Maturing Policy' AS reminder_type,
            cp.policy_name AS title,
            ('Policy for ' || cp.policy_name || ' is maturing soon') AS description,
            cp.end_date AS reminder_date,
            NULL AS reminder_time,
            (c.first_name || ' ' || c.last_name) AS client_name,
            'High' AS priority,
            'Active' AS status,
            FALSE, FALSE, TRUE, '7 days', NULL, FALSE, NULL,
            NOW(), NOW(), NULL
        FROM client_policies cp
        INNER JOIN clients c ON c.client_id = cp.client_id
        WHERE c.agent_id = p_agent_id
          AND cp.is_active = TRUE
          AND (p_start_date IS NULL OR cp.end_date >= p_start_date)
          AND (p_end_date IS NULL OR cp.end_date <= p_end_date)

        UNION ALL

        -- 3. Birthdays (next 7 days)
        SELECT 
            gen_random_uuid() AS reminder_id,
            c.client_id,
            NULL AS appointment_id,
            c.agent_id,
            'Birthday' AS reminder_type,
            'Birthday Reminder' AS title,
            ('Wish ' || c.first_name || ' ' || c.last_name || ' a Happy Birthday!') AS description,
            -- Create this year's birthday date, handling Feb 29
            (
                CASE
                    WHEN EXTRACT(MONTH FROM c.date_of_birth)::INT = 2
                         AND EXTRACT(DAY FROM c.date_of_birth)::INT = 29
                         AND NOT (EXTRACT(ISODOW FROM make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT,1,1)) IS NOT NULL)  -- dummy check, replaced below with leap test
                    THEN
                        -- We'll compute robustly using leap-year test below
                        NULL
                    ELSE NULL
                END
            )::DATE AS reminder_date,
            NULL AS reminder_time,
            (c.first_name || ' ' || c.last_name) AS client_name,
            'Low' AS priority,
            'Active' AS status,
            FALSE, FALSE, TRUE, '1 day', NULL, FALSE, NULL,
            NOW(), NOW(), NULL
        FROM clients c
        WHERE c.agent_id = p_agent_id
          AND c.is_active = TRUE
          AND (
              -- We'll compute whether this client's birthday is within the next 7 days using a robust day-of-year comparison
              -- Convert client's birthday to day-of-year for current year, adjust for Feb 29 on non-leap years
              (
                  (
                      (CASE 
                        WHEN EXTRACT(MONTH FROM c.date_of_birth)::INT = 2
                             AND EXTRACT(DAY FROM c.date_of_birth)::INT = 29
                             AND NOT ( (EXTRACT(YEAR FROM CURRENT_DATE)::INT % 400 = 0) OR (EXTRACT(YEAR FROM CURRENT_DATE)::INT % 4 = 0 AND EXTRACT(YEAR FROM CURRENT_DATE)::INT % 100 != 0) )
                        THEN
                          -- If current year is NOT leap and birthday is Feb 29 -> treat as Feb 28 this year
                          to_char(make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, 2, 28), 'YYYY-MM-DD')::date
                        ELSE
                          to_char(make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM c.date_of_birth)::INT, EXTRACT(DAY FROM c.date_of_birth)::INT), 'YYYY-MM-DD')::date
                      END)
                  )
              ) BETWEEN CURRENT_DATE AND (CURRENT_DATE + (7 * INTERVAL '1 day'))
          )

        UNION ALL

        -- 4. Appointments
        SELECT 
            gen_random_uuid() AS reminder_id,
            a.client_id,
            a.appointment_id,
            a.agent_id,
            'Appointment' AS reminder_type,
            a.title,
            a.description,
            a.appointment_date AS reminder_date,
            a.start_time AS reminder_time,
            a.client_name,
            a.priority,
            a.status,
            FALSE, FALSE, TRUE, '1 day', NULL, FALSE, a.notes,
            a.created_date,
            a.modified_date,
            NULL
        FROM appointments a
        WHERE a.agent_id = p_agent_id
          AND a.is_active = TRUE
          AND (p_start_date IS NULL OR a.appointment_date >= p_start_date)
          AND (p_end_date IS NULL OR a.appointment_date <= p_end_date)
    )
    SELECT * FROM (
        SELECT 
            ROW_NUMBER() OVER (ORDER BY ar.reminder_date ASC NULLS LAST, ar.reminder_time ASC NULLS LAST) AS row_num,
            ar.*
        FROM all_reminders ar
    ) AS paged
    WHERE row_num BETWEEN (v_offset + 1) AND (v_offset + p_page_size)
    ORDER BY reminder_date ASC NULLS LAST, reminder_time ASC NULLS LAST;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Today's Reminders
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_today_reminders(p_agent_id UUID)
RETURNS TABLE (
    reminder_id UUID,
    reminder_type VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    reminder_time TIME,
    client_name VARCHAR(150),
    priority VARCHAR(10),
    enable_sms BOOLEAN,
    enable_whatsapp BOOLEAN,
    enable_push_notification BOOLEAN,
    custom_message TEXT,
    notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.reminder_id,
        r.reminder_type,
        r.title,
        r.description,
        r.reminder_time,
        r.client_name,
        r.priority,
        r.enable_sms,
        r.enable_whatsapp,
        r.enable_push_notification,
        r.custom_message,
        r.notes
    FROM reminders r
    WHERE 
        r.agent_id = p_agent_id 
        AND r.status = 'Active'
        AND r.reminder_date = CURRENT_DATE
    ORDER BY r.reminder_time ASC NULLS LAST;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Complete Reminder
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_complete_reminder(
    p_reminder_id UUID,
    p_agent_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_title VARCHAR(200);
    v_rows_affected INTEGER;
BEGIN
    -- Get reminder title for logging
    SELECT title INTO v_title FROM reminders WHERE reminder_id = p_reminder_id;
    
    UPDATE reminders 
    SET 
        status = 'Completed',
        completed_date = NOW(),
        modified_date = NOW(),
        notes = CASE WHEN p_notes IS NOT NULL THEN p_notes ELSE notes END
    WHERE reminder_id = p_reminder_id AND agent_id = p_agent_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    -- Log activity
    IF v_rows_affected > 0 THEN
        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
        VALUES (p_agent_id, 'reminder_completed', 'reminder', p_reminder_id, 
                'Reminder "' || COALESCE(v_title,'') || '" marked as completed', NOW());
    END IF;
    
    RETURN v_rows_affected;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Delete Reminder
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_delete_reminder(
    p_reminder_id UUID,
    p_agent_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    v_title VARCHAR(200);
    v_rows_affected INTEGER;
BEGIN
    -- Get reminder title for logging
    SELECT title INTO v_title FROM reminders WHERE reminder_id = p_reminder_id;
    
    DELETE FROM reminders 
    WHERE reminder_id = p_reminder_id AND agent_id = p_agent_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    -- Log activity
    IF v_rows_affected > 0 THEN
        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
        VALUES (p_agent_id, 'reminder_deleted', 'reminder', p_reminder_id, 
                'Reminder "' || COALESCE(v_title,'') || '" deleted', NOW());
    END IF;
    
    RETURN v_rows_affected;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Update Reminder Settings
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_update_reminder_settings(
    p_agent_id UUID,
    p_reminder_type VARCHAR(50),
    p_is_enabled BOOLEAN,
    p_days_before INTEGER,
    p_time_of_day TIME,
    p_repeat_daily BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
BEGIN
    -- Check if setting exists, create or update
    IF EXISTS (SELECT 1 FROM reminder_settings WHERE agent_id = p_agent_id AND reminder_type = p_reminder_type) THEN
        UPDATE reminder_settings 
        SET 
            is_enabled = p_is_enabled,
            days_before = p_days_before,
            time_of_day = p_time_of_day,
            repeat_daily = p_repeat_daily,
            modified_date = NOW()
        WHERE agent_id = p_agent_id AND reminder_type = p_reminder_type;
    ELSE
        INSERT INTO reminder_settings (reminder_setting_id, agent_id, reminder_type, is_enabled, days_before, time_of_day, repeat_daily, created_date, modified_date)
        VALUES (gen_random_uuid(), p_agent_id, p_reminder_type, p_is_enabled, p_days_before, p_time_of_day, p_repeat_daily, NOW(), NOW());
    END IF;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Reminder Statistics
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_reminder_statistics(p_agent_id UUID)
RETURNS TABLE(
    total_active INTEGER,
    total_completed INTEGER,
    today_reminders INTEGER,
    upcoming_reminders INTEGER,
    high_priority INTEGER,
    overdue INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM reminders WHERE agent_id = p_agent_id AND status = 'Active') AS total_active,
        (SELECT COUNT(*)::INTEGER FROM reminders WHERE agent_id = p_agent_id AND status = 'Completed') AS total_completed,
        (SELECT COUNT(*)::INTEGER FROM reminders WHERE agent_id = p_agent_id AND status = 'Active' AND reminder_date = CURRENT_DATE) AS today_reminders,
        (SELECT COUNT(*)::INTEGER FROM reminders WHERE agent_id = p_agent_id AND status = 'Active' AND reminder_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + (7 * INTERVAL '1 day'))) AS upcoming_reminders,
        (SELECT COUNT(*)::INTEGER FROM reminders WHERE agent_id = p_agent_id AND status = 'Active' AND priority = 'High') AS high_priority,
        (SELECT COUNT(*)::INTEGER FROM reminders WHERE agent_id = p_agent_id AND status = 'Active' AND reminder_date < CURRENT_DATE) AS overdue;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Reminder Settings
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_reminder_settings(p_agent_id UUID)
RETURNS TABLE (
    reminder_setting_id UUID,
    reminder_type VARCHAR(50),
    is_enabled BOOLEAN,
    days_before INTEGER,
    time_of_day TIME,
    repeat_daily BOOLEAN,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rs.reminder_setting_id,
        rs.reminder_type,
        rs.is_enabled,
        rs.days_before,
        rs.time_of_day,
        rs.repeat_daily,
        rs.created_date,
        rs.modified_date
    FROM reminder_settings rs
    WHERE rs.agent_id = p_agent_id
    ORDER BY rs.reminder_type;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get All Reminders with Filters
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_all_reminders_filtered(
    p_agent_id UUID,
    p_reminder_type VARCHAR(50) DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT NULL,
    p_priority VARCHAR(10) DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_client_id UUID DEFAULT NULL,
    p_page_size INTEGER DEFAULT 50,
    p_page_number INTEGER DEFAULT 1
)
RETURNS TABLE (
    reminder_id UUID,
    client_id UUID,
    appointment_id UUID,
    agent_id UUID,
    reminder_type VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    reminder_date DATE,
    reminder_time TIME,
    client_name VARCHAR(150),
    priority VARCHAR(10),
    status VARCHAR(20),
    enable_sms BOOLEAN,
    enable_whatsapp BOOLEAN,
    enable_push_notification BOOLEAN,
    advance_notice VARCHAR(20),
    custom_message TEXT,
    auto_send BOOLEAN,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    completed_date TIMESTAMPTZ,
    client_phone VARCHAR(20),
    client_email VARCHAR(100),
    total_records BIGINT
) AS $$
DECLARE
    v_offset INTEGER := (p_page_number - 1) * p_page_size;
BEGIN
    RETURN QUERY
    WITH filtered_reminders AS (
        SELECT 
            r.reminder_id,
            r.client_id,
            r.appointment_id,
            r.agent_id,
            r.reminder_type,
            r.title,
            r.description,
            r.reminder_date,
            r.reminder_time,
            r.client_name,
            r.priority,
            r.status,
            r.enable_sms,
            r.enable_whatsapp,
            r.enable_push_notification,
            r.advance_notice,
            r.custom_message,
            r.auto_send,
            r.notes,
            r.created_date,
            r.modified_date,
            r.completed_date,
            c.phone AS client_phone,
            c.email AS client_email
        FROM reminders r
        LEFT JOIN clients c ON r.client_id = c.client_id
        WHERE 
            r.agent_id = p_agent_id
            AND (p_reminder_type IS NULL OR r.reminder_type = p_reminder_type)
            AND (p_status IS NULL OR r.status = p_status)
            AND (p_priority IS NULL OR r.priority = p_priority)
            AND (p_start_date IS NULL OR r.reminder_date >= p_start_date)
            AND (p_end_date IS NULL OR r.reminder_date <= p_end_date)
            AND (p_client_id IS NULL OR r.client_id = p_client_id)
    ),
    total_count AS (
        SELECT COUNT(*) AS total_records FROM filtered_reminders
    )
    SELECT 
        fr.*,
        tc.total_records
    FROM filtered_reminders fr
    CROSS JOIN total_count tc
    ORDER BY fr.reminder_date ASC NULLS LAST, fr.reminder_time ASC NULLS LAST
    LIMIT p_page_size OFFSET v_offset;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Reminder by ID
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_reminder_by_id(
    p_reminder_id UUID,
    p_agent_id UUID
)
RETURNS TABLE (
    reminder_id UUID,
    client_id UUID,
    appointment_id UUID,
    agent_id UUID,
    reminder_type VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    reminder_date DATE,
    reminder_time TIME,
    client_name VARCHAR(150),
    priority VARCHAR(10),
    status VARCHAR(20),
    enable_sms BOOLEAN,
    enable_whatsapp BOOLEAN,
    enable_push_notification BOOLEAN,
    advance_notice VARCHAR(20),
    custom_message TEXT,
    auto_send BOOLEAN,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    completed_date TIMESTAMPTZ,
    client_phone VARCHAR(20),
    client_email VARCHAR(100),
    full_client_name VARCHAR(300)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.reminder_id,
        r.client_id,
        r.appointment_id,
        r.agent_id,
        r.reminder_type,
        r.title,
        r.description,
        r.reminder_date,
        r.reminder_time,
        r.client_name,
        r.priority,
        r.status,
        r.enable_sms,
        r.enable_whatsapp,
        r.enable_push_notification,
        r.advance_notice,
        r.custom_message,
        r.auto_send,
        r.notes,
        r.created_date,
        r.modified_date,
        r.completed_date,
        c.phone AS client_phone,
        c.email AS client_email,
        (c.first_name || ' ' || c.last_name) AS full_client_name
    FROM reminders r
    LEFT JOIN clients c ON r.client_id = c.client_id
    WHERE r.reminder_id = p_reminder_id AND r.agent_id = p_agent_id;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Create Reminder
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_create_reminder(
    p_agent_id UUID,
    p_client_id UUID DEFAULT NULL,
    p_appointment_id UUID DEFAULT NULL,
    p_reminder_type VARCHAR(50) DEFAULT 'Custom',
    p_title VARCHAR(200) DEFAULT 'New Reminder',
    p_description TEXT DEFAULT NULL,
    p_reminder_date DATE DEFAULT CURRENT_DATE,
    p_reminder_time TIME DEFAULT NULL,
    p_client_name VARCHAR(150) DEFAULT NULL,
    p_priority VARCHAR(10) DEFAULT 'Medium',
    p_enable_sms BOOLEAN DEFAULT FALSE,
    p_enable_whatsapp BOOLEAN DEFAULT FALSE,
    p_enable_push_notification BOOLEAN DEFAULT TRUE,
    p_advance_notice VARCHAR(20) DEFAULT '1 day',
    p_custom_message TEXT DEFAULT NULL,
    p_auto_send BOOLEAN DEFAULT FALSE,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_reminder_id UUID := gen_random_uuid();
    v_client_name VARCHAR(150) := p_client_name;
BEGIN
    -- Get client name if not provided but client_id is provided
    IF v_client_name IS NULL AND p_client_id IS NOT NULL THEN
        SELECT first_name || ' ' || last_name 
        INTO v_client_name
        FROM clients 
        WHERE client_id = p_client_id AND agent_id = p_agent_id;
    END IF;
    
    INSERT INTO reminders (
        reminder_id, client_id, appointment_id, agent_id, reminder_type, title, description,
        reminder_date, reminder_time, client_name, priority, status, enable_sms, enable_whatsapp,
        enable_push_notification, advance_notice, custom_message, auto_send, notes, created_date, modified_date
    )
    VALUES (
        v_reminder_id, p_client_id, p_appointment_id, p_agent_id, p_reminder_type, p_title, p_description,
        p_reminder_date, p_reminder_time, v_client_name, p_priority, 'Active', p_enable_sms, p_enable_whatsapp,
        p_enable_push_notification, p_advance_notice, p_custom_message, p_auto_send, p_notes, NOW(), NOW()
    );
    
    RETURN v_reminder_id;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Update Reminder
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_update_reminder(
    p_reminder_id UUID,
    p_agent_id UUID,
    p_title VARCHAR(200) DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_reminder_date DATE DEFAULT NULL,
    p_reminder_time TIME DEFAULT NULL,
    p_priority VARCHAR(10) DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT NULL,
    p_enable_sms BOOLEAN DEFAULT NULL,
    p_enable_whatsapp BOOLEAN DEFAULT NULL,
    p_enable_push_notification BOOLEAN DEFAULT NULL,
    p_advance_notice VARCHAR(20) DEFAULT NULL,
    p_custom_message TEXT DEFAULT NULL,
    p_auto_send BOOLEAN DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE reminders 
    SET 
        title = COALESCE(p_title, title),
        description = COALESCE(p_description, description),
        reminder_date = COALESCE(p_reminder_date, reminder_date),
        reminder_time = COALESCE(p_reminder_time, reminder_time),
        priority = COALESCE(p_priority, priority),
        status = COALESCE(p_status, status),
        enable_sms = COALESCE(p_enable_sms, enable_sms),
        enable_whatsapp = COALESCE(p_enable_whatsapp, enable_whatsapp),
        enable_push_notification = COALESCE(p_enable_push_notification, enable_push_notification),
        advance_notice = COALESCE(p_advance_notice, advance_notice),
        custom_message = COALESCE(p_custom_message, custom_message),
        auto_send = COALESCE(p_auto_send, auto_send),
        notes = COALESCE(p_notes, notes),
        modified_date = NOW(),
        completed_date = CASE WHEN p_status = 'Completed' THEN NOW() ELSE completed_date END
    WHERE reminder_id = p_reminder_id AND agent_id = p_agent_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    RETURN v_rows_affected;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Upcoming Reminders
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_upcoming_reminders(
    p_agent_id UUID,
    p_days_ahead INTEGER DEFAULT 7
)
RETURNS TABLE (
    reminder_id UUID,
    client_id UUID,
    reminder_type VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    reminder_date DATE,
    reminder_time TIME,
    client_name VARCHAR(150),
    priority VARCHAR(10),
    status VARCHAR(20),
    notes TEXT,
    client_phone VARCHAR(20)
) AS $$
DECLARE
    v_end_date DATE := CURRENT_DATE + (p_days_ahead * INTERVAL '1 day');
BEGIN
    RETURN QUERY
    SELECT 
        r.reminder_id,
        r.client_id,
        r.reminder_type,
        r.title,
        r.description,
        r.reminder_date,
        r.reminder_time,
        r.client_name,
        r.priority,
        r.status,
        r.notes,
        c.phone AS client_phone
    FROM reminders r
    LEFT JOIN clients c ON r.client_id = c.client_id
    WHERE 
        r.agent_id = p_agent_id 
        AND r.status = 'Active'
        AND r.reminder_date BETWEEN CURRENT_DATE AND v_end_date
    ORDER BY r.reminder_date ASC NULLS LAST, r.reminder_time ASC NULLS LAST;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Completed Reminders
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_completed_reminders(
    p_agent_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_page_size INTEGER DEFAULT 50,
    p_page_number INTEGER DEFAULT 1
)
RETURNS TABLE (
    reminder_id UUID,
    client_id UUID,
    reminder_type VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    reminder_date DATE,
    reminder_time TIME,
    client_name VARCHAR(150),
    priority VARCHAR(10),
    status VARCHAR(20),
    completed_date TIMESTAMPTZ,
    notes TEXT,
    client_phone VARCHAR(20)
) AS $$
DECLARE
    v_start_date DATE := COALESCE(p_start_date, CURRENT_DATE - (30 * INTERVAL '1 day'));
    v_end_date DATE := COALESCE(p_end_date, CURRENT_DATE);
    v_offset INTEGER := (p_page_number - 1) * p_page_size;
BEGIN
    RETURN QUERY
    SELECT 
        r.reminder_id,
        r.client_id,
        r.reminder_type,
        r.title,
        r.description,
        r.reminder_date,
        r.reminder_time,
        r.client_name,
        r.priority,
        r.status,
        r.completed_date,
        r.notes,
        c.phone AS client_phone
    FROM reminders r
    LEFT JOIN clients c ON r.client_id = c.client_id
    WHERE 
        r.agent_id = p_agent_id 
        AND r.status = 'Completed'
        AND r.completed_date BETWEEN v_start_date AND (v_end_date + INTERVAL '1 day')
    ORDER BY r.completed_date DESC
    LIMIT p_page_size OFFSET v_offset;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Today's Birthday Reminders
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_today_birthday_reminders(p_agent_id UUID)
RETURNS TABLE (
    client_id UUID,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    phone VARCHAR(20),
    email VARCHAR(100),
    date_of_birth DATE,
    age INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.client_id,
        c.first_name,
        c.last_name,
        c.phone,
        c.email,
        c.date_of_birth,
        (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM c.date_of_birth))::INTEGER AS age
    FROM clients c
    WHERE 
        c.agent_id = p_agent_id 
        AND c.is_active = TRUE
        AND (
            -- adjust for Feb 29: if client born on Feb 29 and current year not leap, use Feb 28
            (
                CASE
                    WHEN EXTRACT(MONTH FROM c.date_of_birth)::INT = 2
                         AND EXTRACT(DAY FROM c.date_of_birth)::INT = 29
                         AND NOT ( (EXTRACT(YEAR FROM CURRENT_DATE)::INT % 400 = 0) OR (EXTRACT(YEAR FROM CURRENT_DATE)::INT % 4 = 0 AND EXTRACT(YEAR FROM CURRENT_DATE)::INT % 100 != 0) )
                    THEN to_char(make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, 2, 28), 'MM-DD')
                    ELSE to_char(make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM c.date_of_birth)::INT, EXTRACT(DAY FROM c.date_of_birth)::INT), 'MM-DD')
                END
            ) = to_char(CURRENT_DATE, 'MM-DD')
        );
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Policy Expiry Reminders
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_policy_expiry_reminders(
    p_agent_id UUID,
    p_days_ahead INTEGER DEFAULT 30
)
RETURNS TABLE (
    policy_id UUID,
    client_id UUID,
    policy_name VARCHAR(100),
    policy_type VARCHAR(50),
    company_name VARCHAR(100),
    end_date DATE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    phone VARCHAR(20),
    email VARCHAR(100),
    days_until_expiry INTEGER
) AS $$
DECLARE
    v_start_date DATE := CURRENT_DATE;
    v_end_date DATE := CURRENT_DATE + (p_days_ahead * INTERVAL '1 day');
BEGIN
    RETURN QUERY
    SELECT 
        cp.policy_id,
        cp.client_id,
        cp.policy_name,
        cp.policy_type,
        cp.company_name,
        cp.end_date,
        c.first_name,
        c.last_name,
        c.phone,
        c.email,
        (cp.end_date - v_start_date)::INTEGER AS days_until_expiry
    FROM client_policies cp
    INNER JOIN clients c ON cp.client_id = c.client_id
    WHERE 
        c.agent_id = p_agent_id 
        AND cp.status = 'Active'
        AND cp.is_active = TRUE
        AND c.is_active = TRUE
        AND cp.end_date BETWEEN v_start_date AND v_end_date
    ORDER BY cp.end_date ASC;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Validate Phone Number Format
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_validate_phone_number(
    p_phone_number VARCHAR(50),
    p_country_code VARCHAR(5) DEFAULT '+254'
)
RETURNS TABLE(
    is_valid BOOLEAN,
    formatted_number VARCHAR(50),
    validation_message VARCHAR(200)
) AS $$
DECLARE
    v_clean_number VARCHAR(50);
    v_is_valid BOOLEAN := FALSE;
    v_formatted_number VARCHAR(50) := '';
    v_validation_message VARCHAR(200) := '';
BEGIN
    IF p_phone_number IS NULL THEN
        v_validation_message := 'Phone number is null';
        RETURN QUERY SELECT v_is_valid, v_formatted_number, v_validation_message;
    END IF;

    -- Remove everything except digits and leading +
    v_clean_number := REGEXP_REPLACE(p_phone_number, '[^0-9+]', '', 'g');

    -- Normalize: if starts with + then keep plus, else remove all non-digits
    IF LEFT(v_clean_number,1) = '+' THEN
        v_clean_number := v_clean_number; -- keep
    ELSE
        v_clean_number := REGEXP_REPLACE(v_clean_number, '[^0-9]', '', 'g');
    END IF;

    -- Now perform common Kenyan checks
    -- Cases handled:
    -- 1) 0XXXXXXXXX  (10 digits starting with 0) -> +2547XXXXXXXX
    -- 2) 7XXXXXXXX  (9 digits) -> +2547XXXXXXXX
    -- 3) 2547XXXXXXXX (12 digits starting with 254) -> +2547XXXXXXXX
    -- 4) +2547XXXXXXXX (13 chars starting with +254) -> +2547XXXXXXXX

    IF v_clean_number ~ '^[0][0-9]{9}$' THEN
        -- starts with 0 and 10 digits
        v_formatted_number := p_country_code || RIGHT(v_clean_number, 9);
        v_is_valid := TRUE;
        v_validation_message := 'Valid phone number';
    ELSIF v_clean_number ~ '^[0-9]{9}$' THEN
        -- 9 digits (starting with 7 or other local patterns)
        v_formatted_number := p_country_code || v_clean_number;
        v_is_valid := TRUE;
        v_validation_message := 'Valid phone number';
    ELSIF v_clean_number ~ '^254[0-9]{9}$' THEN
        v_formatted_number := '+' || v_clean_number;
        v_is_valid := TRUE;
        v_validation_message := 'Valid phone number';
    ELSIF v_clean_number ~ '^\+254[0-9]{9}$' THEN
        v_formatted_number := v_clean_number;
        v_is_valid := TRUE;
        v_validation_message := 'Valid phone number';
    ELSE
        v_validation_message := 'Invalid phone number format';
        v_is_valid := FALSE;
        v_formatted_number := '';
    END IF;

    RETURN QUERY SELECT v_is_valid, v_formatted_number, v_validation_message;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Reminders by Type
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_reminders_by_type(
    p_agent_id UUID,
    p_reminder_type VARCHAR(50)
)
RETURNS TABLE (
    reminder_id UUID,
    client_id UUID,
    appointment_id UUID,
    agent_id UUID,
    reminder_type VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    reminder_date DATE,
    reminder_time TIME,
    client_name VARCHAR(150),
    priority VARCHAR(10),
    status VARCHAR(20),
    enable_sms BOOLEAN,
    enable_whatsapp BOOLEAN,
    enable_push_notification BOOLEAN,
    advance_notice VARCHAR(20),
    custom_message TEXT,
    auto_send BOOLEAN,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    completed_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.reminder_id,
        r.client_id,
        r.appointment_id,
        r.agent_id,
        r.reminder_type,
        r.title,
        r.description,
        r.reminder_date,
        r.reminder_time,
        r.client_name,
        r.priority,
        r.status,
        r.enable_sms,
        r.enable_whatsapp,
        r.enable_push_notification,
        r.advance_notice,
        r.custom_message,
        r.auto_send,
        r.notes,
        r.created_date,
        r.modified_date,
        r.completed_date
    FROM reminders r
    WHERE r.agent_id = p_agent_id
      AND r.reminder_type = p_reminder_type
    ORDER BY r.reminder_date ASC NULLS LAST, r.reminder_time ASC NULLS LAST;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Reminders by Status
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_reminders_by_status(
    p_agent_id UUID,
    p_status VARCHAR(20)
)
RETURNS TABLE (
    reminder_id UUID,
    client_id UUID,
    appointment_id UUID,
    agent_id UUID,
    reminder_type VARCHAR(50),
    title VARCHAR(200),
    description TEXT,
    reminder_date DATE,
    reminder_time TIME,
    client_name VARCHAR(150),
    priority VARCHAR(10),
    status VARCHAR(20),
    enable_sms BOOLEAN,
    enable_whatsapp BOOLEAN,
    enable_push_notification BOOLEAN,
    advance_notice VARCHAR(20),
    custom_message TEXT,
    auto_send BOOLEAN,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    completed_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.reminder_id,
        r.client_id,
        r.appointment_id,
        r.agent_id,
        r.reminder_type,
        r.title,
        r.description,
        r.reminder_date,
        r.reminder_time,
        r.client_name,
        r.priority,
        r.status,
        r.enable_sms,
        r.enable_whatsapp,
        r.enable_push_notification,
        r.advance_notice,
        r.custom_message,
        r.auto_send,
        r.notes,
        r.created_date,
        r.modified_date,
        r.completed_date
    FROM reminders r
    WHERE r.agent_id = p_agent_id
      AND r.status = p_status
    ORDER BY r.reminder_date ASC NULLS LAST, r.reminder_time ASC NULLS LAST;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- Automated Messages Functions
-- ============================================

-- ===========================================================
-- Create Automated Message
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_create_automated_message(
    p_agent_id UUID,
    p_message_type VARCHAR(50),
    p_title VARCHAR(200),
    p_template TEXT,
    p_scheduled_date TIMESTAMPTZ,
    p_delivery_method VARCHAR(20),
    p_recipients TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_message_id UUID := gen_random_uuid();
    v_recipients_array TEXT[];
    v_recipient TEXT;
BEGIN
    INSERT INTO automated_messages (
        message_id, agent_id, message_type, title, template,
        scheduled_date, delivery_method, recipients, status, created_date, modified_date
    )
    VALUES (
        v_message_id, p_agent_id, p_message_type, p_title, p_template,
        p_scheduled_date, p_delivery_method, p_recipients, 'Scheduled', NOW(), NOW()
    );
    
    -- If recipients are provided, create individual recipient records
    IF p_recipients IS NOT NULL AND trim(p_recipients) != '' THEN
        -- Simple comma-separated parsing (strip spaces)
        v_recipients_array := string_to_array(REPLACE(p_recipients, ' ', ''), ',');
        
        FOREACH v_recipient IN ARRAY v_recipients_array
        LOOP
            IF LENGTH(v_recipient) > 0 THEN
                INSERT INTO message_recipients (recipient_id, message_id, phone_number, created_date)
                VALUES (gen_random_uuid(), v_message_id, v_recipient, NOW());
            END IF;
        END LOOP;
    END IF;
    
    -- Log activity
    INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
    VALUES (p_agent_id, 'automated_message_created', 'automated_message', v_message_id, 
            'Automated message "' || p_title || '" scheduled', NOW());
    
    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Automated Messages
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_automated_messages(
    p_agent_id UUID,
    p_status VARCHAR(20) DEFAULT 'All'
)
RETURNS TABLE (
    message_id UUID,
    agent_id UUID,
    message_type VARCHAR(50),
    title VARCHAR(200),
    template TEXT,
    scheduled_date TIMESTAMPTZ,
    delivery_method VARCHAR(20),
    status VARCHAR(20),
    recipients TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    sent_date TIMESTAMPTZ,
    recipient_count BIGINT,
    delivered_count BIGINT,
    failed_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        am.message_id,
        am.agent_id,
        am.message_type,
        am.title,
        am.template,
        am.scheduled_date,
        am.delivery_method,
        am.status,
        am.recipients,
        am.created_date,
        am.modified_date,
        am.sent_date,
        COUNT(mr.recipient_id) AS recipient_count,
        COUNT(CASE WHEN mr.delivery_status = 'Delivered' THEN 1 END) AS delivered_count,
        COUNT(CASE WHEN mr.delivery_status = 'Failed' THEN 1 END) AS failed_count
    FROM automated_messages am
    LEFT JOIN message_recipients mr ON am.message_id = mr.message_id
    WHERE 
        am.agent_id = p_agent_id
        AND (p_status = 'All' OR am.status = p_status)
    GROUP BY 
        am.message_id, am.agent_id, am.message_type, am.title, am.template,
        am.scheduled_date, am.delivery_method, am.status, am.recipients,
        am.created_date, am.modified_date, am.sent_date
    ORDER BY am.scheduled_date DESC;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Delete Automated Message
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_delete_automated_message(
    p_message_id UUID,
    p_agent_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    v_title VARCHAR(200);
    v_rows_affected INTEGER;
BEGIN
    -- Get message title for logging
    SELECT title INTO v_title FROM automated_messages WHERE message_id = p_message_id;
    
    -- Delete recipients first (cascade should handle this, but being explicit)
    DELETE FROM message_recipients WHERE message_id = p_message_id;
    
    -- Delete message
    DELETE FROM automated_messages 
    WHERE message_id = p_message_id AND agent_id = p_agent_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    -- Log activity
    IF v_rows_affected > 0 THEN
        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
        VALUES (p_agent_id, 'automated_message_deleted', 'automated_message', p_message_id, 
                'Automated message "' || COALESCE(v_title,'') || '" deleted', NOW());
    END IF;
    
    RETURN v_rows_affected;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- Daily Notes Functions
-- ============================================

-- ===========================================================
-- Get Daily Notes
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_daily_notes(
    p_agent_id UUID,
    p_note_date DATE
)
RETURNS TABLE (
    note_id UUID,
    agent_id UUID,
    note_date DATE,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dn.note_id,
        dn.agent_id,
        dn.note_date,
        dn.notes,
        dn.created_date,
        dn.modified_date
    FROM daily_notes dn
    WHERE dn.agent_id = p_agent_id AND dn.note_date = p_note_date;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Save Daily Notes
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_save_daily_notes(
    p_agent_id UUID,
    p_note_date DATE,
    p_notes TEXT
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM daily_notes WHERE agent_id = p_agent_id AND note_date = p_note_date) THEN
        UPDATE daily_notes 
        SET 
            notes = p_notes,
            modified_date = NOW()
        WHERE agent_id = p_agent_id AND note_date = p_note_date;
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    ELSE
        INSERT INTO daily_notes (note_id, agent_id, note_date, notes, created_date, modified_date)
        VALUES (gen_random_uuid(), p_agent_id, p_note_date, p_notes, NOW(), NOW());
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    END IF;
    
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get All Notes
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_all_notes(
    p_agent_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    note_id UUID,
    agent_id UUID,
    note_date DATE,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ
) AS $$
DECLARE
    v_start_date DATE;
    v_end_date DATE;
BEGIN
    v_start_date := COALESCE(p_start_date, CURRENT_DATE - (90 * INTERVAL '1 day'));
    v_end_date := COALESCE(p_end_date, CURRENT_DATE);
    
    RETURN QUERY
    SELECT 
        dn.note_id,
        dn.agent_id,
        dn.note_date,
        dn.notes,
        dn.created_date,
        dn.modified_date
    FROM daily_notes dn
    WHERE 
        dn.agent_id = p_agent_id 
        AND dn.note_date BETWEEN v_start_date AND v_end_date
    ORDER BY dn.note_date DESC;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Search Notes
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_search_notes(
    p_agent_id UUID,
    p_search_term VARCHAR(500)
)
RETURNS TABLE (
    note_id UUID,
    agent_id UUID,
    note_date DATE,
    notes TEXT,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dn.note_id,
        dn.agent_id,
        dn.note_date,
        dn.notes,
        dn.created_date,
        dn.modified_date
    FROM daily_notes dn
    WHERE 
        dn.agent_id = p_agent_id 
        AND dn.notes ILIKE '%' || p_search_term || '%'
    ORDER BY dn.note_date DESC;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Delete Notes
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_delete_notes(
    p_agent_id UUID,
    p_note_date DATE
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    DELETE FROM daily_notes 
    WHERE agent_id = p_agent_id AND note_date = p_note_date;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;
