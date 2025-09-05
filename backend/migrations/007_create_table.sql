DROP TABLE IF EXISTS activity_log CASCADE;

CREATE TABLE activity_log (
    activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    activity_type VARCHAR(50) NOT NULL, -- e.g. 'appointment_created', 'client_added'
    entity_type VARCHAR(50),            -- e.g. 'client', 'appointment', 'reminder'
    entity_id UUID,
    description VARCHAR(500),
    activity_date TIMESTAMPTZ DEFAULT NOW(), 
    created_date TIMESTAMPTZ DEFAULT NOW(), 
    additional_data JSONB,                 
    CONSTRAINT fk_activity_log_agent FOREIGN KEY (agent_id) 
        REFERENCES agent(agent_id) ON DELETE CASCADE
);
