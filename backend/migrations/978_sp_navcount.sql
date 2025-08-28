DROP FUNCTION IF EXISTS get_navbar_badge_counts(UUID);
DROP FUNCTION IF EXISTS sp_getnavbarbadgecounts(UUID);
CREATE OR REPLACE FUNCTION sp_getnavbarbadgecounts(
    p_agentid UUID
) RETURNS TABLE(
    clientscount BIGINT,
    policiescount BIGINT,
    reminderscount BIGINT,
    appointmentscount BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT CASE WHEN c.is_active = TRUE THEN c.client_id END) AS clientscount,
        COUNT(DISTINCT CASE WHEN p.is_active = TRUE THEN p.policy_id END) AS policiescount,
        COUNT(DISTINCT CASE WHEN r.status = 'Active' THEN r.reminder_id END) AS reminderscount,
        COUNT(DISTINCT CASE
            WHEN a.is_active = TRUE
            AND a.status NOT IN ('Completed', 'Cancelled')
            THEN a.appointment_id END) AS appointmentscount
    FROM (SELECT 1 AS dummy) d
    LEFT JOIN clients c ON c.agent_id = p_agentid
    LEFT JOIN client_policies p ON p.client_id = c.client_id
    LEFT JOIN reminders r ON r.agent_id = p_agentid
    LEFT JOIN appointments a ON a.agent_id = p_agentid;
END;
$$ LANGUAGE plpgsql;
