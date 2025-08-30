-- ============================================
-- Appointments PostgreSQL Stored Procedures
-- (Using lowercase 'appointments' table with $$ quoting)
-- ============================================
-- ============================================
-- Drop All Appointment Stored Procedures
-- ============================================

DROP FUNCTION IF EXISTS sp_get_appointment_statistics(UUID);
DROP FUNCTION IF EXISTS sp_get_all_appointments(UUID, DATE, DATE, VARCHAR(20), VARCHAR(50), VARCHAR(10), UUID, VARCHAR(200), INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_get_appointment_by_id(UUID, UUID);
DROP FUNCTION IF EXISTS sp_create_appointment(UUID, UUID, VARCHAR(200), TEXT, DATE, TIME, TIME, VARCHAR(200), VARCHAR(50), VARCHAR(20), VARCHAR(10), TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS sp_update_appointment(UUID, UUID, VARCHAR(200), TEXT, DATE, TIME, TIME, VARCHAR(200), VARCHAR(50), VARCHAR(10), TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS sp_check_time_conflicts(UUID, DATE, TIME, TIME, UUID);
DROP FUNCTION IF EXISTS sp_get_today_appointments(UUID);
DROP FUNCTION IF EXISTS sp_get_week_view_appointments(UUID, DATE);
DROP FUNCTION IF EXISTS sp_get_calendar_appointments(UUID, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_update_appointment_status(UUID, UUID, VARCHAR(20));
DROP FUNCTION IF EXISTS sp_delete_appointment(UUID, UUID);
DROP FUNCTION IF EXISTS sp_get_appointments(UUID, VARCHAR(20), VARCHAR(20), VARCHAR(50), VARCHAR(100), DATE, DATE);
DROP FUNCTION IF EXISTS sp_get_appointments_for_date(UUID, DATE);
DROP FUNCTION IF EXISTS sp_search_appointments(UUID, VARCHAR(200));
-- ===========================================================
-- Get Appointment Statistics
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_appointment_statistics(p_agent_id UUID)
RETURNS TABLE(
    today_appointments BIGINT,
    week_appointments BIGINT,
    month_appointments BIGINT,
    completed_appointments BIGINT,
    upcoming_appointments BIGINT,
    cancelled_appointments BIGINT
) AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_week_start DATE := v_today - EXTRACT(DOW FROM v_today)::INTEGER;
    v_week_end DATE := v_week_start + INTERVAL '6 days';
    v_month_start DATE := DATE_TRUNC('month', v_today)::DATE;
    v_month_end DATE := (DATE_TRUNC('month', v_today) + INTERVAL '1 month - 1 day')::DATE;
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(CASE WHEN appointment_date = v_today THEN 1 END) AS today_appointments,
        COUNT(CASE WHEN appointment_date BETWEEN v_week_start AND v_week_end THEN 1 END) AS week_appointments,
        COUNT(CASE WHEN appointment_date BETWEEN v_month_start AND v_month_end THEN 1 END) AS month_appointments,
        COUNT(CASE WHEN status = 'Completed' THEN 1 END) AS completed_appointments,
        COUNT(CASE WHEN status IN ('Scheduled', 'Confirmed') THEN 1 END) AS upcoming_appointments,
        COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) AS cancelled_appointments
    FROM appointments
    WHERE agent_id = p_agent_id AND is_active = TRUE;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get All Appointments with Filters
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_all_appointments(
    p_agent_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT NULL,
    p_type VARCHAR(50) DEFAULT NULL,
    p_priority VARCHAR(10) DEFAULT NULL,
    p_client_id UUID DEFAULT NULL,
    p_search_term VARCHAR(200) DEFAULT NULL,
    p_page_size INTEGER DEFAULT 50,
    p_page_number INTEGER DEFAULT 1
)
RETURNS TABLE(
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    client_phone VARCHAR(20),
    title VARCHAR(200),
    description TEXT,
    appointment_date DATE,
    start_time TIME,
    end_time TIME,
    location VARCHAR(200),
    type VARCHAR(50),
    status VARCHAR(20),
    priority VARCHAR(10),
    notes TEXT,
    reminder_set BOOLEAN,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    client_email VARCHAR(100),
    client_address TEXT,
    total_records BIGINT
) AS $$
DECLARE
    v_offset INTEGER := (p_page_number - 1) * p_page_size;
    v_total_records BIGINT;
BEGIN
    -- Get total count first
    SELECT COUNT(*)
    INTO v_total_records
    FROM appointments a
    WHERE a.agent_id = p_agent_id 
        AND a.is_active = TRUE
        AND (p_start_date IS NULL OR a.appointment_date >= p_start_date)
        AND (p_end_date IS NULL OR a.appointment_date <= p_end_date)
        AND (p_status IS NULL OR a.status = p_status)
        AND (p_type IS NULL OR a.type = p_type)
        AND (p_priority IS NULL OR a.priority = p_priority)
        AND (p_client_id IS NULL OR a.client_id = p_client_id)
        AND (p_search_term IS NULL OR 
             a.client_name ILIKE '%' || p_search_term || '%' OR 
             a.title ILIKE '%' || p_search_term || '%' OR
             a.description ILIKE '%' || p_search_term || '%' OR
             a.location ILIKE '%' || p_search_term || '%');

    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        a.client_name,
        a.client_phone,
        a.title,
        a.description,
        a.appointment_date,
        a.start_time,
        a.end_time,
        a.location,
        a.type,
        a.status,
        a.priority,
        a.notes,
        a.reminder_set,
        a.created_date,
        a.modified_date,
        c.email AS client_email,
        c.address AS client_address,
        v_total_records
    FROM appointments a
    LEFT JOIN clients c ON a.client_id = c.client_id
    WHERE a.agent_id = p_agent_id 
        AND a.is_active = TRUE
        AND (p_start_date IS NULL OR a.appointment_date >= p_start_date)
        AND (p_end_date IS NULL OR a.appointment_date <= p_end_date)
        AND (p_status IS NULL OR a.status = p_status)
        AND (p_type IS NULL OR a.type = p_type)
        AND (p_priority IS NULL OR a.priority = p_priority)
        AND (p_client_id IS NULL OR a.client_id = p_client_id)
        AND (p_search_term IS NULL OR 
             a.client_name ILIKE '%' || p_search_term || '%' OR 
             a.title ILIKE '%' || p_search_term || '%' OR
             a.description ILIKE '%' || p_search_term || '%' OR
             a.location ILIKE '%' || p_search_term || '%')
    ORDER BY a.appointment_date DESC, a.start_time DESC
    OFFSET v_offset
    LIMIT p_page_size;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Appointment By ID
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_appointment_by_id(
    p_appointment_id UUID,
    p_agent_id UUID
)
RETURNS TABLE(
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    client_phone VARCHAR(20),
    title VARCHAR(200),
    description TEXT,
    appointment_date DATE,
    start_time TIME,
    end_time TIME,
    location VARCHAR(200),
    type VARCHAR(50),
    status VARCHAR(20),
    priority VARCHAR(10),
    notes TEXT,
    reminder_set BOOLEAN,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    client_email VARCHAR(100),
    client_address TEXT,
    first_name VARCHAR(50),
    surname VARCHAR(50),
    last_name VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        a.client_name,
        a.client_phone,
        a.title,
        a.description,
        a.appointment_date,
        a.start_time,
        a.end_time,
        a.location,
        a.type,
        a.status,
        a.priority,
        a.notes,
        a.reminder_set,
        a.created_date,
        a.modified_date,
        c.email AS client_email,
        c.address AS client_address,
        c.first_name,
        c.surname,
        c.last_name
    FROM appointments a
    LEFT JOIN clients c ON a.client_id = c.client_id
    WHERE a.appointment_id = p_appointment_id 
        AND a.agent_id = p_agent_id 
        AND a.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Create Appointment
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_create_appointment(
    p_agent_id UUID,
    p_client_id UUID,
    p_title VARCHAR(200),
    p_description TEXT DEFAULT NULL,
    p_appointment_date DATE DEFAULT NULL,
    p_start_time TIME DEFAULT NULL,
    p_end_time TIME DEFAULT NULL,
    p_location VARCHAR(200) DEFAULT NULL,
    p_type VARCHAR(50) DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT 'Scheduled',
    p_priority VARCHAR(10) DEFAULT 'Medium',
    p_notes TEXT DEFAULT NULL,
    p_reminder_set BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(success INTEGER, message TEXT, appointment_id UUID) AS $$
DECLARE
    v_appointment_id UUID := gen_random_uuid();
    v_client_name VARCHAR(150);
    v_client_phone VARCHAR(20);
BEGIN
    -- Validate required parameters
    IF p_appointment_date IS NULL THEN
        RETURN QUERY SELECT 0, 'Appointment date is required'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    IF p_start_time IS NULL THEN
        RETURN QUERY SELECT 0, 'Start time is required'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    IF p_end_time IS NULL THEN
        RETURN QUERY SELECT 0, 'End time is required'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    IF p_type IS NULL THEN
        RETURN QUERY SELECT 0, 'Appointment type is required'::TEXT, NULL::UUID;
        RETURN;
    END IF;

    -- Validate time range
    IF p_end_time <= p_start_time THEN
        RETURN QUERY SELECT 0, 'End time must be after start time'::TEXT, NULL::UUID;
        RETURN;
    END IF;

    -- Get client details
    SELECT 
        first_name || ' ' || surname || ' ' || last_name,
        phone_number
    INTO v_client_name, v_client_phone
    FROM clients 
    WHERE client_id = p_client_id 
      AND agent_id = p_agent_id 
      AND is_active = TRUE;
    
    IF v_client_name IS NULL THEN
        RETURN QUERY SELECT 0, 'Client not found'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    -- Check for time conflicts
    IF EXISTS (
        SELECT 1 
        FROM appointments 
        WHERE agent_id = p_agent_id 
          AND appointment_date = p_appointment_date
          AND is_active = TRUE
          AND status NOT IN ('Cancelled')
          AND NOT (p_end_time <= start_time OR p_start_time >= end_time)
    ) THEN
        RETURN QUERY SELECT 0, 'Time conflict with existing appointment'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    -- Insert new appointment
    INSERT INTO appointments (
        appointment_id, client_id, agent_id, client_name, client_phone,
        title, description, appointment_date, start_time, end_time,
        location, type, status, priority, notes, reminder_set
    )
    VALUES (
        v_appointment_id, p_client_id, p_agent_id, v_client_name, v_client_phone,
        p_title, p_description, p_appointment_date, p_start_time, p_end_time,
        p_location, p_type, p_status, p_priority, p_notes, p_reminder_set
    );
    
    -- Log activity
    INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
    VALUES (p_agent_id, 'appointment_created', 'appointment', v_appointment_id, 
            'Appointment "' || p_title || '" created', NOW());
    
    RETURN QUERY SELECT 1, 'Appointment created successfully'::TEXT, v_appointment_id;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Update Appointment
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_update_appointment(
    p_appointment_id UUID,
    p_agent_id UUID,
    p_title VARCHAR(200) DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_appointment_date DATE DEFAULT NULL,
    p_start_time TIME DEFAULT NULL,
    p_end_time TIME DEFAULT NULL,
    p_location VARCHAR(200) DEFAULT NULL,
    p_type VARCHAR(50) DEFAULT NULL,
    p_priority VARCHAR(10) DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_reminder_set BOOLEAN DEFAULT NULL
)
RETURNS TABLE(success INTEGER, message TEXT) AS $$
BEGIN
    -- Check if appointment exists
    IF NOT EXISTS (SELECT 1 FROM appointments WHERE appointment_id = p_appointment_id AND agent_id = p_agent_id AND is_active = TRUE) THEN
        RETURN QUERY SELECT 0, 'Appointment not found'::TEXT;
        RETURN;
    END IF;
    
    -- If updating date/time, check for conflicts
    IF p_appointment_date IS NOT NULL AND p_start_time IS NOT NULL AND p_end_time IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM appointments 
            WHERE agent_id = p_agent_id 
                AND appointment_id <> p_appointment_id
                AND appointment_date = p_appointment_date
                AND is_active = TRUE
                AND status NOT IN ('Cancelled')
                AND NOT (p_end_time <= start_time OR p_start_time >= end_time)
        ) THEN
            RETURN QUERY SELECT 0, 'Time conflict with existing appointment'::TEXT;
            RETURN;
        END IF;
    END IF;
    
    UPDATE appointments 
    SET 
        title = COALESCE(p_title, title),
        description = COALESCE(p_description, description),
        appointment_date = COALESCE(p_appointment_date, appointment_date),
        start_time = COALESCE(p_start_time, start_time),
        end_time = COALESCE(p_end_time, end_time),
        location = COALESCE(p_location, location),
        type = COALESCE(p_type, type),
        priority = COALESCE(p_priority, priority),
        notes = COALESCE(p_notes, notes),
        reminder_set = COALESCE(p_reminder_set, reminder_set),
        modified_date = NOW()
    WHERE appointment_id = p_appointment_id AND agent_id = p_agent_id;
    
    -- Log activity
    INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
    VALUES (p_agent_id, 'appointment_updated', 'appointment', p_appointment_id, 
            'Appointment updated', NOW());
    
    RETURN QUERY SELECT 1, 'Appointment updated successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Check Time Conflicts
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_check_time_conflicts(
    p_agent_id UUID,
    p_appointment_date DATE,
    p_start_time TIME,
    p_end_time TIME,
    p_exclude_appointment_id UUID DEFAULT NULL
)
RETURNS TABLE(has_conflict INTEGER, conflict_count BIGINT) AS $$
DECLARE
    v_conflict_count BIGINT;
BEGIN
    SELECT COUNT(*)
    INTO v_conflict_count
    FROM appointments
    WHERE agent_id = p_agent_id
      AND appointment_date = p_appointment_date
      AND is_active = TRUE
      AND status NOT IN ('Cancelled')
      AND (p_exclude_appointment_id IS NULL OR appointment_id <> p_exclude_appointment_id)
      AND NOT (p_end_time <= start_time OR p_start_time >= end_time);

    RETURN QUERY
    SELECT 
        CASE WHEN v_conflict_count > 0 THEN 1 ELSE 0 END,
        v_conflict_count;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Today's Appointments
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_today_appointments(p_agent_id UUID)
RETURNS TABLE(
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    title VARCHAR(200),
    appointment_date DATE,
    start_time TIME,
    end_time TIME,
    location VARCHAR(200),
    type VARCHAR(50),
    status VARCHAR(20),
    priority VARCHAR(10),
    notes TEXT,
    time_range TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        a.client_name,
        a.title,
        a.appointment_date,
        a.start_time,
        a.end_time,
        a.location,
        a.type,
        a.status,
        a.priority,
        a.notes,
        a.start_time::TEXT || ' - ' || a.end_time::TEXT AS time_range
    FROM appointments a
    WHERE 
        a.agent_id = p_agent_id 
        AND a.is_active = TRUE
        AND a.appointment_date = CURRENT_DATE
        AND a.status NOT IN ('Cancelled')
    ORDER BY a.start_time;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Week View Appointments
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_week_view_appointments(
    p_agent_id UUID,
    p_week_start_date DATE DEFAULT NULL
)
RETURNS TABLE(
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    title VARCHAR(200),
    appointment_date DATE,
    start_time TIME,
    end_time TIME,
    location VARCHAR(200),
    type VARCHAR(50),
    status VARCHAR(20),
    priority VARCHAR(10),
    day_name TEXT,
    day_number INTEGER
) AS $$
DECLARE
    v_week_start_date DATE;
    v_week_end_date DATE;
BEGIN
    -- Default to current week if no date provided
    IF p_week_start_date IS NULL THEN
        v_week_start_date := CURRENT_DATE - EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
    ELSE
        v_week_start_date := p_week_start_date;
    END IF;
    
    v_week_end_date := v_week_start_date + INTERVAL '6 days';
    
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        a.client_name,
        a.title,
        a.appointment_date,
        a.start_time,
        a.end_time,
        a.location,
        a.type,
        a.status,
        a.priority,
        TO_CHAR(a.appointment_date, 'Day') AS day_name,
        EXTRACT(DAY FROM a.appointment_date)::INTEGER AS day_number
    FROM appointments a
    WHERE 
        a.agent_id = p_agent_id 
        AND a.is_active = TRUE
        AND a.appointment_date BETWEEN v_week_start_date AND v_week_end_date
        AND a.status NOT IN ('Cancelled')
    ORDER BY a.appointment_date, a.start_time;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Calendar Appointments
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_calendar_appointments(
    p_agent_id UUID,
    p_month INTEGER,
    p_year INTEGER
)
RETURNS TABLE(
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    title VARCHAR(200),
    appointment_date DATE,
    start_time TIME,
    type VARCHAR(50),
    status VARCHAR(20),
    priority VARCHAR(10),
    day_number INTEGER,
    appointments_on_day BIGINT
) AS $$
DECLARE
    v_start_date DATE;
    v_end_date DATE;
BEGIN
    v_start_date := DATE(p_year || '-' || p_month || '-01');
    v_end_date := (v_start_date + INTERVAL '1 month - 1 day')::DATE;
    
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        a.client_name,
        a.title,
        a.appointment_date,
        a.start_time,
        a.type,
        a.status,
        a.priority,
        EXTRACT(DAY FROM a.appointment_date)::INTEGER AS day_number,
        COUNT(*) OVER (PARTITION BY a.appointment_date) AS appointments_on_day
    FROM appointments a
    WHERE 
        a.agent_id = p_agent_id 
        AND a.is_active = TRUE
        AND a.appointment_date BETWEEN v_start_date AND v_end_date
        AND a.status NOT IN ('Cancelled')
    ORDER BY a.appointment_date, a.start_time;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Update Appointment Status
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_update_appointment_status(
    p_appointment_id UUID,
    p_agent_id UUID,
    p_status VARCHAR(20)
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_title VARCHAR(200);
    v_client_name VARCHAR(150);
    v_rows_affected INTEGER;
BEGIN
    -- Get appointment details for logging
    SELECT title, client_name
    INTO v_title, v_client_name
    FROM appointments 
    WHERE appointment_id = p_appointment_id;
    
    UPDATE appointments 
    SET status = p_status, modified_date = NOW()
    WHERE appointment_id = p_appointment_id AND agent_id = p_agent_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    -- Log activity
    IF v_rows_affected > 0 THEN
        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
        VALUES (p_agent_id, 'appointment_status_changed', 'appointment', p_appointment_id, 
                'Appointment "' || COALESCE(v_title, '') || '" status changed to ' || p_status, NOW());
    END IF;
    
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Delete Appointment (Soft Delete)
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_delete_appointment(
    p_appointment_id UUID,
    p_agent_id UUID
)
RETURNS TABLE(rows_affected INTEGER) AS $$
DECLARE
    v_title VARCHAR(200);
    v_client_name VARCHAR(150);
    v_rows_affected INTEGER;
BEGIN
    -- Get appointment details for logging
    SELECT title, client_name
    INTO v_title, v_client_name
    FROM appointments 
    WHERE appointment_id = p_appointment_id;
    
    -- Soft delete
    UPDATE appointments 
    SET is_active = FALSE, modified_date = NOW()
    WHERE appointment_id = p_appointment_id AND agent_id = p_agent_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    -- Also update related reminders
    IF v_rows_affected > 0 THEN
        UPDATE reminders 
        SET status = 'Cancelled'
        WHERE appointment_id = p_appointment_id;
        
        -- Log activity
        INSERT INTO activity_log (agent_id, activity_type, entity_type, entity_id, description, created_date)
        VALUES (p_agent_id, 'appointment_deleted', 'appointment', p_appointment_id, 
                'Appointment "' || COALESCE(v_title, '') || '" deleted', NOW());
    END IF;
    
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Appointments with Filters
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_appointments(
    p_agent_id UUID,
    p_date_range_filter VARCHAR(20) DEFAULT 'all',
    p_status_filter VARCHAR(20) DEFAULT 'all',
    p_type_filter VARCHAR(50) DEFAULT 'all',
    p_search_term VARCHAR(100) DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE(
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    client_phone VARCHAR(20),
    title VARCHAR(200),
    description TEXT,
    appointment_date DATE,
    start_time TIME,
    end_time TIME,
    location VARCHAR(200),
    type VARCHAR(50),
    status VARCHAR(20),
    priority VARCHAR(10),
    notes TEXT,
    reminder_set BOOLEAN,
    created_date TIMESTAMPTZ,
    modified_date TIMESTAMPTZ,
    computed_client_name TEXT,
    client_email VARCHAR(100),
    insurance_type VARCHAR(50)
) AS $$
DECLARE
    v_filter_start_date DATE;
    v_filter_end_date DATE;
BEGIN
    -- Calculate date range filters
    CASE p_date_range_filter
        WHEN 'today' THEN
            v_filter_start_date := CURRENT_DATE;
            v_filter_end_date := CURRENT_DATE;
        WHEN 'week' THEN
            v_filter_start_date := CURRENT_DATE - EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
            v_filter_end_date := v_filter_start_date + INTERVAL '6 days';
        WHEN 'month' THEN
            v_filter_start_date := DATE_TRUNC('month', CURRENT_DATE)::DATE;
            v_filter_end_date := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
        ELSE
            v_filter_start_date := COALESCE(p_start_date, '1900-01-01'::DATE);
            v_filter_end_date := COALESCE(p_end_date, '2100-12-31'::DATE);
    END CASE;
    
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        a.client_name,
        a.client_phone,
        a.title,
        a.description,
        a.appointment_date,
        a.start_time,
        a.end_time,
        a.location,
        a.type,
        a.status,
        a.priority,
        a.notes,
        a.reminder_set,
        a.created_date,
        a.modified_date,
        COALESCE(c.first_name || ' ' || c.surname, a.client_name) AS computed_client_name,
        c.email AS client_email,
        c.insurance_type
    FROM appointments a
    LEFT JOIN clients c ON a.client_id = c.client_id
    WHERE 
        a.agent_id = p_agent_id 
        AND a.is_active = TRUE
        AND a.appointment_date BETWEEN v_filter_start_date AND v_filter_end_date
        AND (p_status_filter = 'all' OR a.status = p_status_filter)
        AND (p_type_filter = 'all' OR a.type = p_type_filter)
        AND (p_search_term IS NULL OR 
             a.client_name ILIKE '%' || p_search_term || '%' OR
             a.title ILIKE '%' || p_search_term || '%')
    ORDER BY a.appointment_date DESC, a.start_time DESC;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Get Appointments for Specific Date
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_get_appointments_for_date(
    p_agent_id UUID,
    p_appointment_date DATE
)
RETURNS TABLE(
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    client_phone VARCHAR(20),
    title VARCHAR(200),
    description TEXT,
    start_time TIME,
    end_time TIME,
    location VARCHAR(200),
    type VARCHAR(50),
    status VARCHAR(20),
    priority VARCHAR(10),
    notes TEXT,
    reminder_set BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        a.client_name,
        a.client_phone,
        a.title,
        a.description,
        a.start_time,
        a.end_time,
        a.location,
        a.type,
        a.status,
        a.priority,
        a.notes,
        a.reminder_set
    FROM appointments a
    WHERE a.agent_id = p_agent_id 
        AND a.appointment_date = p_appointment_date
        AND a.is_active = TRUE
        AND a.status NOT IN ('Cancelled')
    ORDER BY a.start_time;
END;
$$ LANGUAGE plpgsql;


-- ===========================================================
-- Search Appointments
-- ===========================================================
CREATE OR REPLACE FUNCTION sp_search_appointments(
    p_agent_id UUID,
    p_search_term VARCHAR(200)
)
RETURNS TABLE(
    appointment_id UUID,
    client_id UUID,
    client_name VARCHAR(150),
    client_phone VARCHAR(20),
    title VARCHAR(200),
    description TEXT,
    appointment_date DATE,
    start_time TIME,
    end_time TIME,
    location VARCHAR(200),
    type VARCHAR(50),
    status VARCHAR(20),
    priority VARCHAR(10),
    notes TEXT,
    created_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.client_id,
        a.client_name,
        a.client_phone,
        a.title,
        a.description,
        a.appointment_date,
        a.start_time,
        a.end_time,
        a.location,
        a.type,
        a.status,
        a.priority,
        a.notes,
        a.created_date
    FROM appointments a
    WHERE a.agent_id = p_agent_id 
        AND a.is_active = TRUE
        AND (
            a.client_name ILIKE '%' || p_search_term || '%' OR 
            a.title ILIKE '%' || p_search_term || '%' OR
            a.description ILIKE '%' || p_search_term || '%' OR
            a.location ILIKE '%' || p_search_term || '%' OR
            a.type ILIKE '%' || p_search_term || '%'
        )
    ORDER BY a.appointment_date DESC, a.start_time DESC;
END;
$$ LANGUAGE plpgsql;