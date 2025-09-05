-- Agent Notification Preferences Table (PostgreSQL)
CREATE TABLE agent_notification_preferences (
    preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- 'appointment', 'birthday', 'policy_expiry', etc.
    email_enabled BOOLEAN DEFAULT TRUE,
    sms_enabled BOOLEAN DEFAULT TRUE,
    whatsapp_enabled BOOLEAN DEFAULT TRUE,
    push_enabled BOOLEAN DEFAULT TRUE,
    sound_enabled BOOLEAN DEFAULT TRUE,
    advance_notice_minutes INT DEFAULT 60,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    modified_date TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_agent FOREIGN KEY (agent_id) REFERENCES agent(agent_id) ON DELETE CASCADE
);


-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_agent_notification_preferences_agent_id 
ON agent_notification_preferences(agent_id);
