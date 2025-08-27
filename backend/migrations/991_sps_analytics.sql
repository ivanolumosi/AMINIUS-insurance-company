
-- Get Dashboard Overview
CREATE OR REPLACE FUNCTION sp_get_dashboard_overview(p_agent_id UUID)
RETURNS TABLE (
    total_clients BIGINT,
    total_prospects BIGINT,
    active_policies BIGINT,
    today_appointments BIGINT,
    week_appointments BIGINT,
    month_appointments BIGINT,
    completed_appointments BIGINT,
    pending_reminders BIGINT,
    today_birthdays BIGINT,
    expiring_policies BIGINT
) AS $func$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_week_start DATE := DATE_TRUNC('week', v_today)::DATE;
    v_week_end DATE := v_week_start + INTERVAL '6 days';
    v_month_start DATE := DATE_TRUNC('month', v_today)::DATE;
    v_month_end DATE := (DATE_TRUNC('month', v_today) + INTERVAL '1 month - 1 day')::DATE;
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT CASE WHEN c.is_client = TRUE THEN c.client_id END) AS total_clients,
        COUNT(DISTINCT CASE WHEN c.is_client = FALSE THEN c.client_id END) AS total_prospects,

        COUNT(DISTINCT CASE WHEN cp.status = 'Active' THEN cp.policy_id END) AS active_policies,

        COUNT(DISTINCT CASE WHEN a.appointment_date = v_today THEN a.appointment_id END) AS today_appointments,
        COUNT(DISTINCT CASE WHEN a.appointment_date BETWEEN v_week_start AND v_week_end THEN a.appointment_id END) AS week_appointments,
        COUNT(DISTINCT CASE WHEN a.appointment_date BETWEEN v_month_start AND v_month_end THEN a.appointment_id END) AS month_appointments,
        COUNT(DISTINCT CASE WHEN a.status = 'Completed' THEN a.appointment_id END) AS completed_appointments,

        COUNT(DISTINCT CASE WHEN r.status = 'Active' AND r.reminder_date <= v_today THEN r.reminder_id END) AS pending_reminders,

        COUNT(DISTINCT CASE
            WHEN EXTRACT(DAY FROM c.date_of_birth) = EXTRACT(DAY FROM v_today)
             AND EXTRACT(MONTH FROM c.date_of_birth) = EXTRACT(MONTH FROM v_today)
            THEN c.client_id END) AS today_birthdays,

        COUNT(DISTINCT CASE
            WHEN cp.end_date BETWEEN v_today AND (v_today + INTERVAL '30 days')
             AND cp.status = 'Active'
            THEN cp.policy_id END) AS expiring_policies
    FROM clients c
    LEFT JOIN client_policies cp ON c.client_id = cp.client_id AND cp.is_active = TRUE
    LEFT JOIN appointments a ON c.client_id = a.client_id AND a.is_active = TRUE
    LEFT JOIN reminders r ON c.client_id = r.client_id
    WHERE c.agent_id = p_agent_id AND c.is_active = TRUE;
END;
$func$ LANGUAGE plpgsql;


-- Get Today's Activities
CREATE OR REPLACE FUNCTION sp_get_today_activities(p_agent_id UUID)
RETURNS TABLE (
    activity_type VARCHAR(20),
    entity_id UUID,
    client_name VARCHAR(255),
    title VARCHAR(255),
    time_range VARCHAR(50),
    location TEXT,
    type VARCHAR(50),
    status VARCHAR(20),
    notes TEXT,
    priority VARCHAR(10),
    client_phone VARCHAR(20)
) AS $func$
DECLARE
    v_today DATE := CURRENT_DATE;
BEGIN
    -- Today's Appointments
    RETURN QUERY
    SELECT 
        'appointment'::VARCHAR(20),
        a.appointment_id,
        a.client_name,
        a.title,
        TO_CHAR(a.start_time, 'HH24:MI') || ' - ' || TO_CHAR(a.end_time, 'HH24:MI'),
        a.location,
        a.type,
        a.status,
        a.notes,
        a.priority,
        c.phone_number
    FROM appointments a
    LEFT JOIN clients c ON a.client_id = c.client_id
    WHERE a.agent_id = p_agent_id
      AND a.appointment_date = v_today
      AND a.is_active = TRUE
      AND a.status NOT IN ('Cancelled')
    ORDER BY a.start_time;

    -- Today's Reminders
    RETURN QUERY
    SELECT 
        'reminder'::VARCHAR(20),
        r.reminder_id,
        r.client_name,
        r.title,
        COALESCE(TO_CHAR(r.reminder_time, 'HH24:MI'), ''),
        ''::TEXT,
        r.reminder_type,
        r.status,
        r.notes,
        r.priority,
        c.phone_number
    FROM reminders r
    LEFT JOIN clients c ON r.client_id = c.client_id
    WHERE r.agent_id = p_agent_id
      AND r.reminder_date = v_today
      AND r.status = 'Active'
    ORDER BY r.reminder_time;

    -- Today's Birthdays
    RETURN QUERY
    SELECT 
        'birthday'::VARCHAR(20),
        c.client_id,
        c.first_name || ' ' || c.surname,
        'Birthday - ' || c.first_name || ' ' || c.surname,
        ''::VARCHAR(50),
        c.address,
        'Birthday'::VARCHAR(50),
        'Active'::VARCHAR(20),
        'Age: ' || EXTRACT(YEAR FROM AGE(c.date_of_birth))::TEXT,
        'Medium'::VARCHAR(10),
        c.phone_number
    FROM clients c
    WHERE c.agent_id = p_agent_id
      AND c.is_active = TRUE
      AND EXTRACT(DAY FROM c.date_of_birth) = EXTRACT(DAY FROM v_today)
      AND EXTRACT(MONTH FROM c.date_of_birth) = EXTRACT(MONTH FROM v_today);
END;
$func$ LANGUAGE plpgsql;


-- Get Performance Metrics
CREATE OR REPLACE FUNCTION sp_get_performance_metrics(
    p_agent_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_period VARCHAR(20) DEFAULT 'month'
)
RETURNS TABLE (
    period_start DATE,
    period_end DATE,
    period VARCHAR(20),
    new_clients_added BIGINT,
    prospects_converted BIGINT,
    total_appointments BIGINT,
    completed_appointments BIGINT,
    cancelled_appointments BIGINT,
    new_policies BIGINT,
    expired_policies BIGINT,
    reminders_created BIGINT,
    reminders_completed BIGINT,
    messages_scheduled BIGINT,
    messages_sent BIGINT
) AS $func$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_start_date DATE;
    v_end_date DATE;
BEGIN
    -- Determine default range when any bound is NULL
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        IF p_period = 'week' THEN
            v_start_date := DATE_TRUNC('week', v_today)::DATE;
            v_end_date   := v_start_date + INTERVAL '6 days';
        ELSIF p_period = 'month' THEN
            v_start_date := DATE_TRUNC('month', v_today)::DATE;
            v_end_date   := (DATE_TRUNC('month', v_today) + INTERVAL '1 month - 1 day')::DATE;
        ELSIF p_period = 'quarter' THEN
            v_start_date := DATE_TRUNC('quarter', v_today)::DATE;
            v_end_date   := (DATE_TRUNC('quarter', v_today) + INTERVAL '3 months - 1 day')::DATE;
        ELSIF p_period = 'year' THEN
            v_start_date := DATE_TRUNC('year', v_today)::DATE;
            v_end_date   := (DATE_TRUNC('year', v_today) + INTERVAL '1 year - 1 day')::DATE;
        ELSE
            -- fallback to month
            v_start_date := DATE_TRUNC('month', v_today)::DATE;
            v_end_date   := (DATE_TRUNC('month', v_today) + INTERVAL '1 month - 1 day')::DATE;
        END IF;
    ELSE
        v_start_date := p_start_date;
        v_end_date   := p_end_date;
    END IF;

    RETURN QUERY
    SELECT 
        v_start_date,
        v_end_date,
        p_period,

        -- Client Metrics
        COUNT(DISTINCT CASE WHEN c.created_date::DATE BETWEEN v_start_date AND v_end_date THEN c.client_id END),
        COUNT(DISTINCT CASE WHEN c.is_client = TRUE AND c.modified_date::DATE BETWEEN v_start_date AND v_end_date THEN c.client_id END),

        -- Appointment Metrics
        COUNT(CASE WHEN a.appointment_date BETWEEN v_start_date AND v_end_date THEN 1 END),
        COUNT(CASE WHEN a.appointment_date BETWEEN v_start_date AND v_end_date AND a.status = 'Completed' THEN 1 END),
        COUNT(CASE WHEN a.appointment_date BETWEEN v_start_date AND v_end_date AND a.status = 'Cancelled' THEN 1 END),

        -- Policy Metrics
        COUNT(CASE WHEN cp.created_date::DATE BETWEEN v_start_date AND v_end_date THEN 1 END),
        COUNT(CASE WHEN cp.end_date BETWEEN v_start_date AND v_end_date AND cp.status = 'Expired' THEN 1 END),

        -- Reminder Metrics
        COUNT(CASE WHEN r.created_date::DATE BETWEEN v_start_date AND v_end_date THEN 1 END),
        COUNT(CASE WHEN r.completed_date::DATE BETWEEN v_start_date AND v_end_date THEN 1 END),

        -- Message Metrics
        COUNT(CASE WHEN am.created_date::DATE BETWEEN v_start_date AND v_end_date THEN 1 END),
        COUNT(CASE WHEN am.sent_date::DATE BETWEEN v_start_date AND v_end_date THEN 1 END)
    FROM clients c
    LEFT JOIN client_policies cp ON c.client_id = cp.client_id AND cp.is_active = TRUE
    LEFT JOIN appointments a ON c.client_id = a.client_id AND a.is_active = TRUE
    LEFT JOIN reminders r ON c.client_id = r.client_id
    LEFT JOIN automated_messages am ON am.agent_id = c.agent_id
    WHERE c.agent_id = p_agent_id AND c.is_active = TRUE;
END;
$func$ LANGUAGE plpgsql;


-- Update Dashboard Statistics Cache
CREATE OR REPLACE FUNCTION sp_update_dashboard_statistics(
    p_agent_id UUID,
    p_stat_date DATE DEFAULT NULL
)
RETURNS VOID AS $func$
DECLARE
    v_stat_date   DATE := COALESCE(p_stat_date, CURRENT_DATE);
    v_week_start  DATE := DATE_TRUNC('week', v_stat_date)::DATE;
    v_week_end    DATE := v_week_start + INTERVAL '6 days';
    v_month_start DATE := DATE_TRUNC('month', v_stat_date)::DATE;
    v_month_end   DATE := (DATE_TRUNC('month', v_stat_date) + INTERVAL '1 month - 1 day')::DATE;

    v_total_clients INTEGER := 0;
    v_total_prospects INTEGER := 0;
    v_active_policies INTEGER := 0;
    v_today_appointments INTEGER := 0;
    v_week_appointments INTEGER := 0;
    v_month_appointments INTEGER := 0;
    v_completed_appointments INTEGER := 0;
    v_pending_reminders INTEGER := 0;
    v_today_birthdays INTEGER := 0;
    v_expiring_policies INTEGER := 0;
BEGIN
    -- Clients
    SELECT 
        COUNT(CASE WHEN is_client = TRUE THEN 1 END)::INTEGER,
        COUNT(CASE WHEN is_client = FALSE THEN 1 END)::INTEGER,
        COUNT(CASE WHEN EXTRACT(DAY FROM date_of_birth) = EXTRACT(DAY FROM v_stat_date)
                    AND EXTRACT(MONTH FROM date_of_birth) = EXTRACT(MONTH FROM v_stat_date) THEN 1 END)::INTEGER
    INTO v_total_clients, v_total_prospects, v_today_birthdays
    FROM clients 
    WHERE agent_id = p_agent_id AND is_active = TRUE;

    -- Active policies
    SELECT COUNT(DISTINCT cp.policy_id)::INTEGER
    INTO v_active_policies
    FROM client_policies cp
    INNER JOIN clients c ON cp.client_id = c.client_id
    WHERE c.agent_id = p_agent_id AND cp.status = 'Active' AND cp.is_active = TRUE AND c.is_active = TRUE;

    -- Appointments
    SELECT 
        COUNT(CASE WHEN appointment_date = v_stat_date THEN 1 END)::INTEGER,
        COUNT(CASE WHEN appointment_date BETWEEN v_week_start AND v_week_end THEN 1 END)::INTEGER,
        COUNT(CASE WHEN appointment_date BETWEEN v_month_start AND v_month_end THEN 1 END)::INTEGER,
        COUNT(CASE WHEN status = 'Completed' THEN 1 END)::INTEGER
    INTO v_today_appointments, v_week_appointments, v_month_appointments, v_completed_appointments
    FROM appointments a
    INNER JOIN clients c ON a.client_id = c.client_id
    WHERE c.agent_id = p_agent_id AND a.is_active = TRUE AND c.is_active = TRUE;

    -- Pending reminders
    SELECT COUNT(*)::INTEGER
    INTO v_pending_reminders
    FROM reminders 
    WHERE agent_id = p_agent_id AND status = 'Active' AND reminder_date <= v_stat_date;

    -- Expiring policies
    SELECT COUNT(DISTINCT cp.policy_id)::INTEGER
    INTO v_expiring_policies
    FROM client_policies cp
    INNER JOIN clients c ON cp.client_id = c.client_id
    WHERE c.agent_id = p_agent_id 
      AND cp.status = 'Active'
      AND cp.end_date BETWEEN v_stat_date AND (v_stat_date + INTERVAL '30 days')
      AND cp.is_active = TRUE AND c.is_active = TRUE;

    -- Upsert into dashboard_statistics
    IF EXISTS (SELECT 1 FROM dashboard_statistics WHERE agent_id = p_agent_id AND stat_date = v_stat_date) THEN
        UPDATE dashboard_statistics 
        SET 
            total_clients = v_total_clients,
            total_prospects = v_total_prospects,
            active_policies = v_active_policies,
            today_appointments = v_today_appointments,
            week_appointments = v_week_appointments,
            month_appointments = v_month_appointments,
            completed_appointments = v_completed_appointments,
            pending_reminders = v_pending_reminders,
            today_birthdays = v_today_birthdays,
            expiring_policies = v_expiring_policies,
            updated_date = NOW()
        WHERE agent_id = p_agent_id AND stat_date = v_stat_date;
    ELSE
        INSERT INTO dashboard_statistics (
            agent_id, stat_date, total_clients, total_prospects, active_policies,
            today_appointments, week_appointments, month_appointments, completed_appointments,
            pending_reminders, today_birthdays, expiring_policies
        )
        VALUES (
            p_agent_id, v_stat_date, v_total_clients, v_total_prospects, v_active_policies,
            v_today_appointments, v_week_appointments, v_month_appointments, v_completed_appointments,
            v_pending_reminders, v_today_birthdays, v_expiring_policies
        );
    END IF;
END;
$func$ LANGUAGE plpgsql;


-- Log Activity  (FIXED PARAM ORDER)
-- Required params first, then all optionals with defaults
CREATE OR REPLACE FUNCTION sp_log_activity(
    p_agent_id UUID,
    p_activity_type VARCHAR(50),
    p_description VARCHAR(500),
    p_entity_type VARCHAR(50) DEFAULT NULL,
    p_entity_id UUID DEFAULT NULL,
    p_additional_data TEXT DEFAULT NULL
)
RETURNS VOID AS $func$
DECLARE
    v_today DATE := CURRENT_DATE;
BEGIN
    INSERT INTO activity_log (
        agent_id, activity_type, entity_type, entity_id, description, additional_data
    )
    VALUES (
        p_agent_id, p_activity_type, p_entity_type, p_entity_id, p_description, p_additional_data
    );

    -- Update daily performance metrics when applicable
    IF p_activity_type IN ('client_created', 'appointment_completed', 'reminder_completed', 'policy_created') THEN
        IF EXISTS (SELECT 1 FROM performance_metrics WHERE agent_id = p_agent_id AND metric_date = v_today) THEN
            UPDATE performance_metrics 
            SET 
                new_clients_added      = new_clients_added      + CASE WHEN p_activity_type = 'client_created'        THEN 1 ELSE 0 END,
                appointments_completed = appointments_completed + CASE WHEN p_activity_type = 'appointment_completed' THEN 1 ELSE 0 END,
                reminders_completed    = reminders_completed    + CASE WHEN p_activity_type = 'reminder_completed'    THEN 1 ELSE 0 END,
                policies_sold          = policies_sold          + CASE WHEN p_activity_type = 'policy_created'        THEN 1 ELSE 0 END
            WHERE agent_id = p_agent_id AND metric_date = v_today;
        ELSE
            INSERT INTO performance_metrics (
                agent_id, metric_date, new_clients_added, appointments_completed, reminders_completed, policies_sold
            )
            VALUES (
                p_agent_id, v_today,
                CASE WHEN p_activity_type = 'client_created'        THEN 1 ELSE 0 END,
                CASE WHEN p_activity_type = 'appointment_completed' THEN 1 ELSE 0 END,
                CASE WHEN p_activity_type = 'reminder_completed'    THEN 1 ELSE 0 END,
                CASE WHEN p_activity_type = 'policy_created'        THEN 1 ELSE 0 END
            );
        END IF;
    END IF;
END;
$func$ LANGUAGE plpgsql;


-- Get Activity Log
CREATE OR REPLACE FUNCTION sp_get_activity_log(
    p_agent_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_activity_type VARCHAR(50) DEFAULT NULL,
    p_page_size INTEGER DEFAULT 50,
    p_page_number INTEGER DEFAULT 1
)
RETURNS TABLE (
    activity_id UUID,
    activity_type VARCHAR(50),
    entity_type VARCHAR(50),
    entity_id UUID,
    description VARCHAR(500),
    activity_date TIMESTAMPTZ,
    additional_data TEXT,
    row_num BIGINT,
    total_records BIGINT
) AS $func$
DECLARE
    v_start_date DATE := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
    v_end_date   DATE := COALESCE(p_end_date, CURRENT_DATE);
    v_offset     INTEGER := (p_page_number - 1) * p_page_size;
    v_total_records BIGINT;
BEGIN
    -- total count
    SELECT COUNT(*)
    INTO v_total_records
    FROM activity_log
    WHERE 
        agent_id = p_agent_id
        AND activity_date::DATE BETWEEN v_start_date AND v_end_date
        AND (p_activity_type IS NULL OR activity_type = p_activity_type);

    RETURN QUERY
    SELECT 
        al.activity_id,
        al.activity_type,
        al.entity_type,
        al.entity_id,
        al.description,
        al.activity_date,
        al.additional_data,
        ROW_NUMBER() OVER (ORDER BY al.activity_date DESC) AS row_num,
        v_total_records AS total_records
    FROM activity_log al
    WHERE 
        al.agent_id = p_agent_id
        AND al.activity_date::DATE BETWEEN v_start_date AND v_end_date
        AND (p_activity_type IS NULL OR al.activity_type = p_activity_type)
    ORDER BY al.activity_date DESC
    OFFSET v_offset
    LIMIT p_page_size;
END;
$func$ LANGUAGE plpgsql;


-- Generate Monthly Report
CREATE OR REPLACE FUNCTION sp_generate_monthly_report(
    p_agent_id UUID,
    p_report_month DATE
)
RETURNS TABLE (
    agent_id UUID,
    report_month DATE,
    total_clients_added INTEGER,
    total_prospects_added INTEGER,
    prospects_converted INTEGER,
    total_appointments INTEGER,
    completed_appointments INTEGER,
    cancelled_appointments INTEGER,
    total_reminders INTEGER,
    completed_reminders INTEGER,
    messages_sent INTEGER,
    new_policies INTEGER,
    renewed_policies INTEGER,
    expired_policies INTEGER,
    generated_date TIMESTAMPTZ
) AS $func$
DECLARE
    v_month_start DATE := DATE_TRUNC('month', p_report_month)::DATE;
    v_month_end   DATE := (DATE_TRUNC('month', p_report_month) + INTERVAL '1 month - 1 day')::DATE;

    v_total_clients_added INTEGER := 0;
    v_total_prospects_added INTEGER := 0;
    v_prospects_converted INTEGER := 0;
    v_total_appointments INTEGER := 0;
    v_completed_appointments INTEGER := 0;
    v_cancelled_appointments INTEGER := 0;
    v_total_reminders INTEGER := 0;
    v_completed_reminders INTEGER := 0;
    v_messages_sent INTEGER := 0;
    v_new_policies INTEGER := 0;
    v_renewed_policies INTEGER := 0;
    v_expired_policies INTEGER := 0;
BEGIN
    -- Client metrics
    SELECT 
        COUNT(CASE WHEN is_client = TRUE  AND created_date::DATE BETWEEN v_month_start AND v_month_end THEN 1 END)::INTEGER,
        COUNT(CASE WHEN is_client = FALSE AND created_date::DATE BETWEEN v_month_start AND v_month_end THEN 1 END)::INTEGER,
        COUNT(CASE WHEN is_client = TRUE  AND modified_date::DATE BETWEEN v_month_start AND v_month_end THEN 1 END)::INTEGER
    INTO v_total_clients_added, v_total_prospects_added, v_prospects_converted
    FROM clients 
    WHERE agent_id = p_agent_id;

    -- Appointment metrics
    SELECT 
        COUNT(*)::INTEGER,
        COUNT(CASE WHEN status = 'Completed' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN status = 'Cancelled' THEN 1 END)::INTEGER
    INTO v_total_appointments, v_completed_appointments, v_cancelled_appointments
    FROM appointments a
    INNER JOIN clients c ON a.client_id = c.client_id
    WHERE c.agent_id = p_agent_id 
      AND a.appointment_date BETWEEN v_month_start AND v_month_end;

    -- Reminder metrics
    SELECT 
        COUNT(*)::INTEGER,
        COUNT(CASE WHEN status = 'Completed' THEN 1 END)::INTEGER
    INTO v_total_reminders, v_completed_reminders
    FROM reminders 
    WHERE agent_id = p_agent_id 
      AND reminder_date BETWEEN v_month_start AND v_month_end;

    -- Message metrics
    SELECT COUNT(*)::INTEGER
    INTO v_messages_sent
    FROM automated_messages 
    WHERE agent_id = p_agent_id 
      AND sent_date::DATE BETWEEN v_month_start AND v_month_end;

    -- Policy metrics
    SELECT 
        COUNT(CASE WHEN start_date BETWEEN v_month_start AND v_month_end THEN 1 END)::INTEGER,
        COUNT(CASE WHEN end_date   BETWEEN v_month_start AND v_month_end THEN 1 END)::INTEGER
    INTO v_new_policies, v_expired_policies
    FROM client_policies cp
    INNER JOIN clients c ON cp.client_id = c.client_id
    WHERE c.agent_id = p_agent_id;

    v_renewed_policies := 0; -- Placeholder for future renewal logic

    -- Upsert into monthly_reports
    IF EXISTS (SELECT 1 FROM monthly_reports WHERE agent_id = p_agent_id AND report_month = v_month_start) THEN
        UPDATE monthly_reports 
        SET 
            total_clients_added   = v_total_clients_added,
            total_prospects_added = v_total_prospects_added,
            prospects_converted   = v_prospects_converted,
            total_appointments    = v_total_appointments,
            completed_appointments= v_completed_appointments,
            cancelled_appointments= v_cancelled_appointments,
            total_reminders       = v_total_reminders,
            completed_reminders   = v_completed_reminders,
            messages_sent         = v_messages_sent,
            new_policies          = v_new_policies,
            renewed_policies      = v_renewed_policies,
            expired_policies      = v_expired_policies,
            generated_date        = NOW()
        WHERE agent_id = p_agent_id AND report_month = v_month_start;
    ELSE
        INSERT INTO monthly_reports (
            agent_id, report_month, total_clients_added, total_prospects_added, prospects_converted,
            total_appointments, completed_appointments, cancelled_appointments,
            total_reminders, completed_reminders, messages_sent,
            new_policies, renewed_policies, expired_policies
        )
        VALUES (
            p_agent_id, v_month_start, v_total_clients_added, v_total_prospects_added, v_prospects_converted,
            v_total_appointments, v_completed_appointments, v_cancelled_appointments,
            v_total_reminders, v_completed_reminders, v_messages_sent,
            v_new_policies, v_renewed_policies, v_expired_policies
        );
    END IF;

    RETURN QUERY
    SELECT * FROM monthly_reports 
    WHERE agent_id = p_agent_id AND report_month = v_month_start;
END;
$func$ LANGUAGE plpgsql;
