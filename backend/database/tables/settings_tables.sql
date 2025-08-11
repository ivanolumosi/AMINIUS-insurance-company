-- ============================================
-- Settings Management Tables
-- ============================================

-- Application Settings Table (System-wide settings)
CREATE TABLE ApplicationSettings (
    SettingId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    SettingKey NVARCHAR(100) NOT NULL UNIQUE,
    SettingValue NVARCHAR(MAX),
    Description NVARCHAR(200),
    DataType NVARCHAR(20) DEFAULT 'string' CHECK (DataType IN ('string', 'number', 'boolean', 'json')),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE()
);

-- Insert default application settings
INSERT INTO ApplicationSettings (SettingKey, SettingValue, Description, DataType) VALUES
('app_version', '1.0.0', 'Application version', 'string'),
('app_build', '2025.01.001', 'Application build number', 'string'),
('default_reminder_time', '09:00', 'Default time for reminders', 'string'),
('max_appointments_per_day', '10', 'Maximum appointments per day', 'number'),
('auto_backup_enabled', 'true', 'Enable automatic backups', 'boolean');

-- Agent Notification Preferences Table (Detailed notification settings per agent)
CREATE TABLE AgentNotificationPreferences (
    PreferenceId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    NotificationType NVARCHAR(50) NOT NULL, -- 'appointment', 'birthday', 'policy_expiry', etc.
    EmailEnabled BIT DEFAULT 1,
    SmsEnabled BIT DEFAULT 1,
    WhatsAppEnabled BIT DEFAULT 1,
    PushEnabled BIT DEFAULT 1,
    SoundEnabled BIT DEFAULT 1,
    AdvanceNoticeMinutes INT DEFAULT 60,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);

-- System Preferences Table (User interface and system preferences)
CREATE TABLE SystemPreferences (
    PreferenceId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    PreferenceKey NVARCHAR(100) NOT NULL,
    PreferenceValue NVARCHAR(MAX),
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
    UNIQUE(AgentId, PreferenceKey)
);

-- Backup Settings Table
CREATE TABLE BackupSettings (
    BackupId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    BackupFrequency NVARCHAR(20) DEFAULT 'Weekly' CHECK (BackupFrequency IN ('Daily', 'Weekly', 'Monthly')),
    LastBackupDate DATETIME2,
    BackupLocation NVARCHAR(500),
    AutoBackupEnabled BIT DEFAULT 1,
    IncludeClientData BIT DEFAULT 1,
    IncludeAppointments BIT DEFAULT 1,
    IncludeReminders BIT DEFAULT 1,
    IncludeSettings BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);

-- Template Messages Table (Pre-defined message templates)
CREATE TABLE MessageTemplates (
    TemplateId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    TemplateName NVARCHAR(100) NOT NULL,
    MessageType NVARCHAR(50) NOT NULL,
    Template NVARCHAR(MAX) NOT NULL,
    IsDefault BIT DEFAULT 0,
    UsageCount INT DEFAULT 0,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);

-- Insert default message templates
INSERT INTO MessageTemplates (AgentId, TemplateName, MessageType, Template, IsDefault) 
SELECT 
    a.AgentId,
    'Birthday Greeting',
    'Birthday',
    'Happy Birthday {name}! Wishing you health, happiness and prosperity in the year ahead. Best regards, {agent_name} - Aminius Insurance.',
    1
FROM Agent a;

INSERT INTO MessageTemplates (AgentId, TemplateName, MessageType, Template, IsDefault)
SELECT 
    a.AgentId,
    'Policy Expiry Reminder',
    'Policy Expiry',
    'Dear {name}, your {policy_type} policy is expiring on {expiry_date}. Please contact me to discuss renewal options. Regards, {agent_name}',
    1
FROM Agent a;