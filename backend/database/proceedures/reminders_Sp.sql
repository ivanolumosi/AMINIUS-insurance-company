-- ============================================
-- Reminders and Messaging Stored Procedures
-- ============================================

-- Create or Update Reminder
CREATE OR ALTER PROCEDURE sp_UpsertReminder
    @ReminderId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @AppointmentId UNIQUEIDENTIFIER = NULL,
    @AgentId UNIQUEIDENTIFIER,
    @ReminderType NVARCHAR(50),
    @Title NVARCHAR(200),
    @Description NVARCHAR(MAX) = NULL,
    @ReminderDate DATE,
    @ReminderTime TIME = NULL,
    @ClientName NVARCHAR(150) = NULL,
    @Priority NVARCHAR(10) = 'Medium',
    @EnableSMS BIT = 0,
    @EnableWhatsApp BIT = 0,
    @EnablePushNotification BIT = 1,
    @AdvanceNotice NVARCHAR(20) = '1 day',
    @CustomMessage NVARCHAR(MAX) = NULL,
    @AutoSend BIT = 0,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ReminderId IS NULL
    BEGIN
        -- Create new reminder
        SET @ReminderId = NEWID();
        
        INSERT INTO Reminders (
            ReminderId, ClientId, AppointmentId, AgentId, ReminderType, Title, Description,
            ReminderDate, ReminderTime, ClientName, Priority, EnableSMS, EnableWhatsApp,
            EnablePushNotification, AdvanceNotice, CustomMessage, AutoSend, Notes
        )
        VALUES (
            @ReminderId, @ClientId, @AppointmentId, @AgentId, @ReminderType, @Title, @Description,
            @ReminderDate, @ReminderTime, @ClientName, @Priority, @EnableSMS, @EnableWhatsApp,
            @EnablePushNotification, @AdvanceNotice, @CustomMessage, @AutoSend, @Notes
        );
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'reminder_created', 'reminder', @ReminderId, 
                'Reminder "' + @Title + '" created');
    END
    ELSE
    BEGIN
        -- Update existing reminder
        UPDATE Reminders 
        SET 
            ReminderType = @ReminderType,
            Title = @Title,
            Description = @Description,
            ReminderDate = @ReminderDate,
            ReminderTime = @ReminderTime,
            ClientName = @ClientName,
            Priority = @Priority,
            EnableSMS = @EnableSMS,
            EnableWhatsApp = @EnableWhatsApp,
            EnablePushNotification = @EnablePushNotification,
            AdvanceNotice = @AdvanceNotice,
            CustomMessage = @CustomMessage,
            AutoSend = @AutoSend,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE ReminderId = @ReminderId;
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'reminder_updated', 'reminder', @ReminderId, 
                'Reminder "' + @Title + '" updated');
    END
    
    SELECT @ReminderId AS ReminderId;
END;
GO

-- Get Reminders
CREATE OR ALTER PROCEDURE sp_GetReminders
    @AgentId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = 'Active', -- 'Active', 'Completed', 'Cancelled', 'All'
    @ReminderType NVARCHAR(50) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        r.*,
        c.FirstName + ' ' + c.Surname AS ComputedClientName,
        c.PhoneNumber AS ClientPhone,
        a.Title AS AppointmentTitle
    FROM Reminders r
    LEFT JOIN Clients c ON r.ClientId = c.ClientId
    LEFT JOIN Appointments a ON r.AppointmentId = a.AppointmentId
    WHERE 
        r.AgentId = @AgentId
        AND (@Status = 'All' OR r.Status = @Status)
        AND (@ReminderType IS NULL OR r.ReminderType = @ReminderType)
        AND (@StartDate IS NULL OR r.ReminderDate >= @StartDate)
        AND (@EndDate IS NULL OR r.ReminderDate <= @EndDate)
    ORDER BY r.ReminderDate ASC, r.ReminderTime ASC;
END;
GO

-- Get Today's Reminders
CREATE OR ALTER PROCEDURE sp_GetTodayReminders
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ReminderId,
        ReminderType,
        Title,
        Description,
        ReminderTime,
        ClientName,
        Priority,
        EnableSMS,
        EnableWhatsApp,
        EnablePushNotification,
        CustomMessage,
        Notes
    FROM Reminders
    WHERE 
        AgentId = @AgentId 
        AND Status = 'Active'
        AND ReminderDate = CAST(GETDATE() AS DATE)
    ORDER BY ReminderTime ASC;
END;
GO

-- Complete Reminder
CREATE OR ALTER PROCEDURE sp_CompleteReminder
    @ReminderId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Title NVARCHAR(200);
    
    -- Get reminder title for logging
    SELECT @Title = Title FROM Reminders WHERE ReminderId = @ReminderId;
    
    UPDATE Reminders 
    SET 
        Status = 'Completed',
        CompletedDate = GETUTCDATE(),
        ModifiedDate = GETUTCDATE()
    WHERE ReminderId = @ReminderId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'reminder_completed', 'reminder', @ReminderId, 
            'Reminder "' + @Title + '" marked as completed');
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Reminder
CREATE OR ALTER PROCEDURE sp_DeleteReminder
    @ReminderId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Title NVARCHAR(200);
    
    -- Get reminder title for logging
    SELECT @Title = Title FROM Reminders WHERE ReminderId = @ReminderId;
    
    DELETE FROM Reminders 
    WHERE ReminderId = @ReminderId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'reminder_deleted', 'reminder', @ReminderId, 
            'Reminder "' + @Title + '" deleted');
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Update Reminder Settings
CREATE OR ALTER PROCEDURE sp_UpdateReminderSettings
    @AgentId UNIQUEIDENTIFIER,
    @ReminderType NVARCHAR(50),
    @IsEnabled BIT,
    @DaysBefore INT,
    @TimeOfDay TIME,
    @RepeatDaily BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if setting exists, create or update
    IF EXISTS (SELECT 1 FROM ReminderSettings WHERE AgentId = @AgentId AND ReminderType = @ReminderType)
    BEGIN
        UPDATE ReminderSettings 
        SET 
            IsEnabled = @IsEnabled,
            DaysBefore = @DaysBefore,
            TimeOfDay = @TimeOfDay,
            RepeatDaily = @RepeatDaily,
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND ReminderType = @ReminderType;
    END
    ELSE
    BEGIN
        INSERT INTO ReminderSettings (AgentId, ReminderType, IsEnabled, DaysBefore, TimeOfDay, RepeatDaily)
        VALUES (@AgentId, @ReminderType, @IsEnabled, @DaysBefore, @TimeOfDay, @RepeatDaily);
    END
END;
GO

-- Get Reminder Settings
CREATE OR ALTER PROCEDURE sp_GetReminderSettings
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ReminderSettingId,
        ReminderType,
        IsEnabled,
        DaysBefore,
        TimeOfDay,
        RepeatDaily,
        CreatedDate,
        ModifiedDate
    FROM ReminderSettings
    WHERE AgentId = @AgentId
    ORDER BY ReminderType;
END;
GO

-- Create Automated Message
CREATE OR ALTER PROCEDURE sp_CreateAutomatedMessage
    @AgentId UNIQUEIDENTIFIER,
    @MessageType NVARCHAR(50),
    @Title NVARCHAR(200),
    @Template NVARCHAR(MAX),
    @ScheduledDate DATETIME2,
    @DeliveryMethod NVARCHAR(20),
    @Recipients NVARCHAR(MAX) = NULL -- JSON array of phone numbers
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MessageId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO AutomatedMessages (
        MessageId, AgentId, MessageType, Title, Template,
        ScheduledDate, DeliveryMethod, Recipients
    )
    VALUES (
        @MessageId, @AgentId, @MessageType, @Title, @Template,
        @ScheduledDate, @DeliveryMethod, @Recipients
    );
    
    -- If recipients are provided, create individual recipient records
    IF @Recipients IS NOT NULL AND @Recipients != ''
    BEGIN
        -- Parse recipients JSON and create individual records
        -- This would require JSON parsing - simplified for now
        DECLARE @Phone NVARCHAR(20);
        DECLARE @Pos INT = 1;
        DECLARE @NextPos INT;
        
        -- Simple comma-separated parsing (in production, use JSON parsing)
        SET @Recipients = REPLACE(@Recipients, ' ', '');
        WHILE @Pos <= LEN(@Recipients)
        BEGIN
            SET @NextPos = CHARINDEX(',', @Recipients, @Pos);
            IF @NextPos = 0 SET @NextPos = LEN(@Recipients) + 1;
            
            SET @Phone = SUBSTRING(@Recipients, @Pos, @NextPos - @Pos);
            
            IF LEN(@Phone) > 0
            BEGIN
                INSERT INTO MessageRecipients (MessageId, PhoneNumber)
                VALUES (@MessageId, @Phone);
            END
            
            SET @Pos = @NextPos + 1;
        END
    END
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'automated_message_created', 'automated_message', @MessageId, 
            'Automated message "' + @Title + '" scheduled');
    
    SELECT @MessageId AS MessageId;
END;
GO

-- Get Automated Messages
CREATE OR ALTER PROCEDURE sp_GetAutomatedMessages
    @AgentId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = 'All' -- 'Scheduled', 'Sent', 'Failed', 'All'
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        am.*,
        COUNT(mr.RecipientId) AS RecipientCount,
        COUNT(CASE WHEN mr.DeliveryStatus = 'Delivered' THEN 1 END) AS DeliveredCount,
        COUNT(CASE WHEN mr.DeliveryStatus = 'Failed' THEN 1 END) AS FailedCount
    FROM AutomatedMessages am
    LEFT JOIN MessageRecipients mr ON am.MessageId = mr.MessageId
    WHERE 
        am.AgentId = @AgentId
        AND (@Status = 'All' OR am.Status = @Status)
    GROUP BY 
        am.MessageId, am.AgentId, am.MessageType, am.Title, am.Template,
        am.ScheduledDate, am.DeliveryMethod, am.Status, am.Recipients,
        am.CreatedDate, am.ModifiedDate, am.SentDate
    ORDER BY am.ScheduledDate DESC;
END;
GO

-- Delete Automated Message
CREATE OR ALTER PROCEDURE sp_DeleteAutomatedMessage
    @MessageId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Title NVARCHAR(200);
    
    -- Get message title for logging
    SELECT @Title = Title FROM AutomatedMessages WHERE MessageId = @MessageId;
    
    -- Delete recipients first (cascade should handle this, but being explicit)
    DELETE FROM MessageRecipients WHERE MessageId = @MessageId;
    
    -- Delete message
    DELETE FROM AutomatedMessages 
    WHERE MessageId = @MessageId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'automated_message_deleted', 'automated_message', @MessageId, 
            'Automated message "' + @Title + '" deleted');
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Update/Save Daily Notes
CREATE OR ALTER PROCEDURE sp_SaveDailyNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE,
    @Notes NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if notes exist for this date
    IF EXISTS (SELECT 1 FROM DailyNotes WHERE AgentId = @AgentId AND NoteDate = @NoteDate)
    BEGIN
        UPDATE DailyNotes 
        SET Notes = @Notes, ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
    END
    ELSE
    BEGIN
        INSERT INTO DailyNotes (AgentId, NoteDate, Notes)
        VALUES (@AgentId, @NoteDate, @Notes);
    END
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'daily_notes_updated', 'daily_notes', NULL, 
            'Daily notes updated for ' + CONVERT(NVARCHAR, @NoteDate, 107));
END;
GO

-- Get Daily Notes
CREATE OR ALTER PROCEDURE sp_GetDailyNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        NoteId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
END;
GO


=========================================== -- Agent Management Tables -- ============================================ -- Agent Profile Table DROP TABLE IF EXISTS Agent; GO CREATE TABLE Agent ( AgentId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(), FirstName NVARCHAR(50) NOT NULL, LastN

pasted


-- ============================================ -- Analytics and Dashboard Stored Procedures -- ============================================ -- Get Dashboard Overview CREATE OR ALTER PROCEDURE sp_GetDashboardOverview @AgentId UNIQUEIDENTIFIER AS BEGIN SET NOCOUNT ON; DEC

pasted


-- ============================================ -- Settings Management Stored Procedures -- ============================================ -- Get Application Settings CREATE OR ALTER PROCEDURE sp_GetApplicationSettings AS BEGIN SET NOCOUNT ON; SELECT SettingKey,

pasted

-- ============================================
-- Client Management Tables
-- ============================================

-- Clients Table
CREATE TABLE Clients (
    ClientId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    Surname NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    PhoneNumber NVARCHAR(20) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    Address NVARCHAR(500) NOT NULL,
    NationalId NVARCHAR(20) NOT NULL,
    DateOfBirth DATE NOT NULL,
    IsClient BIT NOT NULL DEFAULT 0, -- 0 = Prospect, 1 = Client
    InsuranceType NVARCHAR(50) NOT NULL,
    Notes NVARCHAR(MAX),
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    IsActive BIT DEFAULT 1,
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);

-- Client Policies Table
CREATE TABLE ClientPolicies (
    PolicyId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    ClientId UNIQUEIDENTIFIER NOT NULL,
    PolicyName NVARCHAR(100) NOT NULL,
    PolicyType NVARCHAR(50) NOT NULL,
    CompanyName NVARCHAR(100) NOT NULL,
    Status NVARCHAR(20) NOT NULL CHECK (Status IN ('Active', 'Inactive', 'Expired', 'Lapsed')),
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    Notes NVARCHAR(MAX),
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    IsActive BIT DEFAULT 1,
    FOREIGN KEY (ClientId) REFERENCES Clients(ClientId) ON DELETE CASCADE
);
-- ============================================
-- Policy Catalog Management Tables
-- ============================================

-- Policy Catalog Table (Available policies from different companies)
CREATE TABLE PolicyCatalog (
    PolicyCatalogId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    PolicyName NVARCHAR(100) NOT NULL,
    PolicyType NVARCHAR(50) NOT NULL,
    CompanyId UNIQUEIDENTIFIER NOT NULL,
    CompanyName NVARCHAR(100) NOT NULL, -- Denormalized for quick access
    Notes NVARCHAR(MAX),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
    FOREIGN KEY (CompanyId) REFERENCES InsuranceCompanies(CompanyId)
);

-- Policy Templates Table (For common policy configurations)
CREATE TABLE PolicyTemplates (
    TemplateId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    TemplateName NVARCHAR(100) NOT NULL,
    PolicyType NVARCHAR(50) NOT NULL,
    DefaultTermMonths INT,
    DefaultPremium DECIMAL(10,2),
    CoverageDescription NVARCHAR(MAX),
    Terms NVARCHAR(MAX),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);
-- ============================================
-- Reminders and Messaging Tables
-- ============================================

-- Reminder Settings Table
CREATE TABLE ReminderSettings (
    ReminderSettingId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    ReminderType NVARCHAR(50) NOT NULL CHECK (ReminderType IN ('Policy Expiry', 'Birthday', 'Appointment', 'Call', 'Visit')),
    IsEnabled BIT DEFAULT 1,
    DaysBefore INT DEFAULT 1,
    TimeOfDay TIME DEFAULT '09:00',
    RepeatDaily BIT DEFAULT 0,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);

-- Reminders Table
CREATE TABLE Reminders (
    ReminderId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    ClientId UNIQUEIDENTIFIER,
    AppointmentId UNIQUEIDENTIFIER,
    AgentId UNIQUEIDENTIFIER NOT NULL,
    ReminderType NVARCHAR(50) NOT NULL CHECK (ReminderType IN ('Call', 'Visit', 'Policy Expiry', 'Birthday', 'Holiday', 'Custom')),
    Title NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX),
    ReminderDate DATE NOT NULL,
    ReminderTime TIME,
    ClientName NVARCHAR(150),
    Priority NVARCHAR(10) NOT NULL CHECK (Priority IN ('High', 'Medium', 'Low')) DEFAULT 'Medium',
    Status NVARCHAR(20) NOT NULL CHECK (Status IN ('Active', 'Completed', 'Cancelled')) DEFAULT 'Active',
    EnableSMS BIT DEFAULT 0,
    EnableWhatsApp BIT DEFAULT 0,
    EnablePushNotification BIT DEFAULT 1,
    AdvanceNotice NVARCHAR(20) DEFAULT '1 day',
    CustomMessage NVARCHAR(MAX),
    AutoSend BIT DEFAULT 0,
    Notes NVARCHAR(MAX),
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    CompletedDate DATETIME2,
    FOREIGN KEY (ClientId) REFERENCES Clients(ClientId),
    FOREIGN KEY (AppointmentId) REFERENCES Appointments(AppointmentId),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);

-- Automated Messages Table
CREATE TABLE AutomatedMessages (
    MessageId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    MessageType NVARCHAR(50) NOT NULL CHECK (MessageType IN ('Birthday', 'Holiday', 'Policy Expiry', 'Appointment', 'Custom')),
    Title NVARCHAR(200) NOT NULL,
    Template NVARCHAR(MAX) NOT NULL,
    ScheduledDate DATETIME2 NOT NULL,
    DeliveryMethod NVARCHAR(20) NOT NULL CHECK (DeliveryMethod IN ('SMS', 'WhatsApp', 'Both')),
    Status NVARCHAR(20) NOT NULL CHECK (Status IN ('Scheduled', 'Sent', 'Failed')) DEFAULT 'Scheduled',
    Recipients NVARCHAR(MAX), -- JSON array of phone numbers
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    SentDate DATETIME2,
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);
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
-- Message Recipients Table (For tracking individual message deliveries)
CREATE TABLE MessageRecipients (
    RecipientId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    MessageId UNIQUEIDENTIFIER NOT NULL,
    ClientId UNIQUEIDENTIFIER,
    PhoneNumber NVARCHAR(20) NOT NULL,
    DeliveryStatus NVARCHAR(20) DEFAULT 'Pending' CHECK (DeliveryStatus IN ('Pending', 'Sent', 'Delivered', 'Failed')),
    DeliveryDate DATETIME2,
    ErrorMessage NVARCHAR(500),
    FOREIGN KEY (MessageId) REFERENCES AutomatedMessages(MessageId) ON DELETE CASCADE,
    FOREIGN KEY (ClientId) REFERENCES Clients(ClientId)
);

-- Daily Notes Table
CREATE TABLE DailyNotes (
    NoteId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    NoteDate DATE NOT NULL,
    Notes NVARCHAR(MAX),
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
    UNIQUE(AgentId, NoteDate) -- One note per agent per day
);
-- Policy Categories Table (For organizing policies)
CREATE TABLE PolicyCategories (
    CategoryId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    CategoryName NVARCHAR(50) NOT NULL,
    Description NVARCHAR(200),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE()
);

-- Insert default categories
INSERT INTO PolicyCategories (CategoryName, Description) VALUES
('Individual', 'Personal insurance policies'),
('Corporate', 'Business and corporate policies'),
('Family', 'Family package policies'),
('Specialized', 'Specialized coverage policies');

-- Policy Company Relationships (Many-to-many for policies offered by multiple companies)
CREATE TABLE PolicyCompanyRelationships (
    RelationshipId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    PolicyCatalogId UNIQUEIDENTIFIER NOT NULL,
    CompanyId UNIQUEIDENTIFIER NOT NULL,
    BasePremium DECIMAL(10,2),
    CommissionRate DECIMAL(5,2),
    IsPreferred BIT DEFAULT 0,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (PolicyCatalogId) REFERENCES PolicyCatalog(PolicyCatalogId) ON DELETE CASCADE,
    FOREIGN KEY (CompanyId) REFERENCES InsuranceCompanies(CompanyId) ON DELETE CASCADE
);
-- Appointments Table
CREATE TABLE Appointments (
    AppointmentId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    ClientId UNIQUEIDENTIFIER NOT NULL,
    AgentId UNIQUEIDENTIFIER NOT NULL,
    ClientName NVARCHAR(150) NOT NULL, -- Computed from client names
    ClientPhone NVARCHAR(20),
    Title NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX),
    AppointmentDate DATE NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    Location NVARCHAR(200),
    Type NVARCHAR(50) NOT NULL CHECK (Type IN ('Call', 'Meeting', 'Site Visit', 'Policy Review', 'Claim Processing')),
    Status NVARCHAR(20) NOT NULL CHECK (Status IN ('Scheduled', 'Confirmed', 'In Progress', 'Completed', 'Cancelled', 'Rescheduled')),
    Priority NVARCHAR(10) NOT NULL CHECK (Priority IN ('High', 'Medium', 'Low')),
    Notes NVARCHAR(MAX),
    ReminderSet BIT DEFAULT 0,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    IsActive BIT DEFAULT 1,
    FOREIGN KEY (ClientId) REFERENCES Clients(ClientId) ON DELETE NO ACTION ON UPDATE NO ACTION,

    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE NO ACTION ON UPDATE NO ACTION

);


-- ============================================
-- Missing Reminder Service Stored Procedures
-- ============================================

-- Get All Reminders with Filters
CREATE OR ALTER PROCEDURE sp_GetAllReminders
    @AgentId UNIQUEIDENTIFIER,
    @ReminderType NVARCHAR(50) = NULL,
    @Status NVARCHAR(20) = NULL,
    @Priority NVARCHAR(10) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @PageSize INT = 50,
    @PageNumber INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT 
        r.ReminderId,
        r.ClientId,
        r.AppointmentId,
        r.AgentId,
        r.ReminderType,
        r.Title,
        r.Description,
        r.ReminderDate,
        r.ReminderTime,
        r.ClientName,
        r.Priority,
        r.Status,
        r.EnableSMS,
        r.EnableWhatsApp,
        r.EnablePushNotification,
        r.AdvanceNotice,
        r.CustomMessage,
        r.AutoSend,
        r.Notes,
        r.CreatedDate,
        r.ModifiedDate,
        r.CompletedDate,
        c.PhoneNumber AS ClientPhone,
        c.Email AS ClientEmail
    FROM Reminders r
    LEFT JOIN Clients c ON r.ClientId = c.ClientId
    WHERE 
        r.AgentId = @AgentId
        AND (@ReminderType IS NULL OR r.ReminderType = @ReminderType)
        AND (@Status IS NULL OR r.Status = @Status)
        AND (@Priority IS NULL OR r.Priority = @Priority)
        AND (@StartDate IS NULL OR r.ReminderDate >= @StartDate)
        AND (@EndDate IS NULL OR r.ReminderDate <= @EndDate)
        AND (@ClientId IS NULL OR r.ClientId = @ClientId)
    ORDER BY r.ReminderDate ASC, r.ReminderTime ASC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
    -- Get total count
    SELECT COUNT(*) AS TotalRecords
    FROM Reminders r
    WHERE 
        r.AgentId = @AgentId
        AND (@ReminderType IS NULL OR r.ReminderType = @ReminderType)
        AND (@Status IS NULL OR r.Status = @Status)
        AND (@Priority IS NULL OR r.Priority = @Priority)
        AND (@StartDate IS NULL OR r.ReminderDate >= @StartDate)
        AND (@EndDate IS NULL OR r.ReminderDate <= @EndDate)
        AND (@ClientId IS NULL OR r.ClientId = @ClientId);
END;
GO

-- Get Reminder by ID
CREATE OR ALTER PROCEDURE sp_GetReminderById
    @ReminderId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        r.ReminderId,
        r.ClientId,
        r.AppointmentId,
        r.AgentId,
        r.ReminderType,
        r.Title,
        r.Description,
        r.ReminderDate,
        r.ReminderTime,
        r.ClientName,
        r.Priority,
        r.Status,
        r.EnableSMS,
        r.EnableWhatsApp,
        r.EnablePushNotification,
        r.AdvanceNotice,
        r.CustomMessage,
        r.AutoSend,
        r.Notes,
        r.CreatedDate,
        r.ModifiedDate,
        r.CompletedDate,
        c.PhoneNumber AS ClientPhone,
        c.Email AS ClientEmail,
        c.FirstName + ' ' + c.Surname AS FullClientName
    FROM Reminders r
    LEFT JOIN Clients c ON r.ClientId = c.ClientId
    WHERE r.ReminderId = @ReminderId AND r.AgentId = @AgentId;
END;
GO

-- Create Reminder
CREATE OR ALTER PROCEDURE sp_CreateReminder
    @AgentId UNIQUEIDENTIFIER,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @AppointmentId UNIQUEIDENTIFIER = NULL,
    @ReminderType NVARCHAR(50),
    @Title NVARCHAR(200),
    @Description NVARCHAR(MAX) = NULL,
    @ReminderDate DATE,
    @ReminderTime TIME = NULL,
    @ClientName NVARCHAR(150) = NULL,
    @Priority NVARCHAR(10) = 'Medium',
    @EnableSMS BIT = 0,
    @EnableWhatsApp BIT = 0,
    @EnablePushNotification BIT = 1,
    @AdvanceNotice NVARCHAR(20) = '1 day',
    @CustomMessage NVARCHAR(MAX) = NULL,
    @AutoSend BIT = 0,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ReminderId UNIQUEIDENTIFIER = NEWID();
    
    -- Get client name if not provided but ClientId is provided
    IF @ClientName IS NULL AND @ClientId IS NOT NULL
    BEGIN
        SELECT @ClientName = FirstName + ' ' + Surname 
        FROM Clients 
        WHERE ClientId = @ClientId AND AgentId = @AgentId;
    END
    
    INSERT INTO Reminders (
        ReminderId, ClientId, AppointmentId, AgentId, ReminderType, Title, Description,
        ReminderDate, ReminderTime, ClientName, Priority, Status, EnableSMS, EnableWhatsApp,
        EnablePushNotification, AdvanceNotice, CustomMessage, AutoSend, Notes
    )
    VALUES (
        @ReminderId, @ClientId, @AppointmentId, @AgentId, @ReminderType, @Title, @Description,
        @ReminderDate, @ReminderTime, @ClientName, @Priority, 'Active', @EnableSMS, @EnableWhatsApp,
        @EnablePushNotification, @AdvanceNotice, @CustomMessage, @AutoSend, @Notes
    );
    
    SELECT @ReminderId AS ReminderId;
END;
GO

-- Update Reminder
CREATE OR ALTER PROCEDURE sp_UpdateReminder
    @ReminderId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @Title NVARCHAR(200) = NULL,
    @Description NVARCHAR(MAX) = NULL,
    @ReminderDate DATE = NULL,
    @ReminderTime TIME = NULL,
    @Priority NVARCHAR(10) = NULL,
    @Status NVARCHAR(20) = NULL,
    @EnableSMS BIT = NULL,
    @EnableWhatsApp BIT = NULL,
    @EnablePushNotification BIT = NULL,
    @AdvanceNotice NVARCHAR(20) = NULL,
    @CustomMessage NVARCHAR(MAX) = NULL,
    @AutoSend BIT = NULL,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE Reminders 
    SET 
        Title = ISNULL(@Title, Title),
        Description = ISNULL(@Description, Description),
        ReminderDate = ISNULL(@ReminderDate, ReminderDate),
        ReminderTime = ISNULL(@ReminderTime, ReminderTime),
        Priority = ISNULL(@Priority, Priority),
        Status = ISNULL(@Status, Status),
        EnableSMS = ISNULL(@EnableSMS, EnableSMS),
        EnableWhatsApp = ISNULL(@EnableWhatsApp, EnableWhatsApp),
        EnablePushNotification = ISNULL(@EnablePushNotification, EnablePushNotification),
        AdvanceNotice = ISNULL(@AdvanceNotice, AdvanceNotice),
        CustomMessage = ISNULL(@CustomMessage, CustomMessage),
        AutoSend = ISNULL(@AutoSend, AutoSend),
        Notes = ISNULL(@Notes, Notes),
        ModifiedDate = GETUTCDATE(),
        CompletedDate = CASE WHEN @Status = 'Completed' THEN GETUTCDATE() ELSE CompletedDate END
    WHERE ReminderId = @ReminderId AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Reminder
CREATE OR ALTER PROCEDURE sp_DeleteReminder
    @ReminderId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DELETE FROM Reminders 
    WHERE ReminderId = @ReminderId AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Complete Reminder
CREATE OR ALTER PROCEDURE sp_CompleteReminder
    @ReminderId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE Reminders 
    SET 
        Status = 'Completed',
        CompletedDate = GETUTCDATE(),
        Notes = CASE WHEN @Notes IS NOT NULL THEN @Notes ELSE Notes END,
        ModifiedDate = GETUTCDATE()
    WHERE ReminderId = @ReminderId AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Upcoming Reminders
CREATE OR ALTER PROCEDURE sp_GetUpcomingReminders
    @AgentId UNIQUEIDENTIFIER,
    @DaysAhead INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @EndDate DATE = DATEADD(DAY, @DaysAhead, GETDATE());
    
    SELECT 
        r.ReminderId,
        r.ClientId,
        r.ReminderType,
        r.Title,
        r.Description,
        r.ReminderDate,
        r.ReminderTime,
        r.ClientName,
        r.Priority,
        r.Status,
        r.Notes,
        c.PhoneNumber AS ClientPhone
    FROM Reminders r
    LEFT JOIN Clients c ON r.ClientId = c.ClientId
    WHERE 
        r.AgentId = @AgentId 
        AND r.Status = 'Active'
        AND r.ReminderDate BETWEEN CAST(GETDATE() AS DATE) AND @EndDate
    ORDER BY r.ReminderDate ASC, r.ReminderTime ASC;
END;
GO

-- Get Completed Reminders
CREATE OR ALTER PROCEDURE sp_GetCompletedReminders
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @PageSize INT = 50,
    @PageNumber INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(DAY, -30, GETDATE()); -- Last 30 days default
    
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT 
        r.ReminderId,
        r.ClientId,
        r.ReminderType,
        r.Title,
        r.Description,
        r.ReminderDate,
        r.ReminderTime,
        r.ClientName,
        r.Priority,
        r.Status,
        r.CompletedDate,
        r.Notes,
        c.PhoneNumber AS ClientPhone
    FROM Reminders r
    LEFT JOIN Clients c ON r.ClientId = c.ClientId
    WHERE 
        r.AgentId = @AgentId 
        AND r.Status = 'Completed'
        AND r.CompletedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)
    ORDER BY r.CompletedDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO



-- ============================================
-- Missing Message Service Stored Procedures
-- ============================================

-- Create Automated Message
CREATE OR ALTER PROCEDURE sp_CreateAutomatedMessage
    @AgentId UNIQUEIDENTIFIER,
    @MessageType NVARCHAR(50),
    @Title NVARCHAR(200),
    @Template NVARCHAR(MAX),
    @ScheduledDate DATETIME2,
    @DeliveryMethod NVARCHAR(20),
    @Recipients NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MessageId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO AutomatedMessages (
        MessageId, AgentId, MessageType, Title, Template, ScheduledDate, DeliveryMethod, Recipients
    )
    VALUES (
        @MessageId, @AgentId, @MessageType, @Title, @Template, @ScheduledDate, @DeliveryMethod, @Recipients
    );
    
    SELECT @MessageId AS MessageId;
END;
GO

-- Get Automated Messages
CREATE OR ALTER PROCEDURE sp_GetAutomatedMessages
    @AgentId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = NULL,
    @MessageType NVARCHAR(50) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        MessageId,
        MessageType,
        Title,
        Template,
        ScheduledDate,
        DeliveryMethod,
        Status,
        Recipients,
        CreatedDate,
        ModifiedDate,
        SentDate
    FROM AutomatedMessages
    WHERE 
        AgentId = @AgentId
        AND (@Status IS NULL OR Status = @Status)
        AND (@MessageType IS NULL OR MessageType = @MessageType)
        AND (@StartDate IS NULL OR CAST(ScheduledDate AS DATE) >= @StartDate)
        AND (@EndDate IS NULL OR CAST(ScheduledDate AS DATE) <= @EndDate)
    ORDER BY ScheduledDate DESC;
END;
GO

-- Delete Automated Message
CREATE OR ALTER PROCEDURE sp_DeleteAutomatedMessage
    @MessageId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DELETE FROM AutomatedMessages 
    WHERE MessageId = @MessageId AND AgentId = @AgentId AND Status = 'Scheduled';
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Send Message (Update status to Sent)
CREATE OR ALTER PROCEDURE sp_SendMessage
    @MessageId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE AutomatedMessages 
    SET 
        Status = 'Sent',
        SentDate = GETUTCDATE(),
        ModifiedDate = GETUTCDATE()
    WHERE MessageId = @MessageId AND Status = 'Scheduled';
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Process Scheduled Messages (Get messages ready to send)
CREATE OR ALTER PROCEDURE sp_GetScheduledMessages
    @CurrentDateTime DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @CurrentDateTime IS NULL
        SET @CurrentDateTime = GETUTCDATE();
    
    SELECT 
        MessageId,
        AgentId,
        MessageType,
        Title,
        Template,
        ScheduledDate,
        DeliveryMethod,
        Recipients
    FROM AutomatedMessages
    WHERE 
        Status = 'Scheduled'
        AND ScheduledDate <= @CurrentDateTime
    ORDER BY ScheduledDate ASC;
END;
GO

-- Update Message Status (for failed sends)
CREATE OR ALTER PROCEDURE sp_UpdateMessageStatus
    @MessageId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20),
    @ErrorMessage NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE AutomatedMessages 
    SET 
        Status = @Status,
        ModifiedDate = GETUTCDATE()
    WHERE MessageId = @MessageId;
    
    -- If there's an error message, we might want to store it somewhere
    -- For now, just return the status update result
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Track Message Recipients
CREATE OR ALTER PROCEDURE sp_TrackMessageRecipient
    @MessageId UNIQUEIDENTIFIER,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @PhoneNumber NVARCHAR(20),
    @DeliveryStatus NVARCHAR(20) = 'Pending',
    @ErrorMessage NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO MessageRecipients (
        MessageId, ClientId, PhoneNumber, DeliveryStatus, DeliveryDate, ErrorMessage
    )
    VALUES (
        @MessageId, @ClientId, @PhoneNumber, @DeliveryStatus, 
        CASE WHEN @DeliveryStatus IN ('Sent', 'Delivered') THEN GETUTCDATE() ELSE NULL END,
        @ErrorMessage
    );
END;
GO

-- Update Recipient Delivery Status
CREATE OR ALTER PROCEDURE sp_UpdateRecipientStatus
    @MessageId UNIQUEIDENTIFIER,
    @PhoneNumber NVARCHAR(20),
    @DeliveryStatus NVARCHAR(20),
    @ErrorMessage NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE MessageRecipients 
    SET 
        DeliveryStatus = @DeliveryStatus,
        DeliveryDate = CASE WHEN @DeliveryStatus IN ('Sent', 'Delivered') THEN GETUTCDATE() ELSE DeliveryDate END,
        ErrorMessage = @ErrorMessage
    WHERE MessageId = @MessageId AND PhoneNumber = @PhoneNumber;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Message Delivery Report
CREATE OR ALTER PROCEDURE sp_GetMessageDeliveryReport
    @MessageId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        mr.RecipientId,
        mr.ClientId,
        mr.PhoneNumber,
        mr.DeliveryStatus,
        mr.DeliveryDate,
        mr.ErrorMessage,
        c.FirstName + ' ' + c.Surname AS ClientName
    FROM MessageRecipients mr
    LEFT JOIN Clients c ON mr.ClientId = c.ClientId
    WHERE mr.MessageId = @MessageId
    ORDER BY mr.DeliveryDate DESC;
END;
GO

-- Get Birthday Reminders for Today
CREATE OR ALTER PROCEDURE sp_GetTodayBirthdayReminders
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.DateOfBirth,
        DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) AS Age
    FROM Clients c
    WHERE 
        c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND DAY(c.DateOfBirth) = DAY(@Today)
        AND MONTH(c.DateOfBirth) = MONTH(@Today);
END;
GO

-- Get Policy Expiry Reminders
CREATE OR ALTER PROCEDURE sp_GetPolicyExpiryReminders
    @AgentId UNIQUEIDENTIFIER,
    @DaysAhead INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @EndDate DATE = DATEADD(DAY, @DaysAhead, @StartDate);
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.PolicyType,
        cp.CompanyName,
        cp.EndDate,
        c.FirstName,
        c.Surname,
        c.PhoneNumber,
        c.Email,
        DATEDIFF(DAY, @StartDate, cp.EndDate) AS DaysUntilExpiry
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE 
        c.AgentId = @AgentId 
        AND cp.Status = 'Active'
        AND cp.IsActive = 1
        AND c.IsActive = 1
        AND cp.EndDate BETWEEN @StartDate AND @EndDate
    ORDER BY cp.EndDate ASC;
END;
GO

-- Validate Phone Number Format
CREATE OR ALTER PROCEDURE sp_ValidatePhoneNumber
    @PhoneNumber NVARCHAR(20),
    @CountryCode NVARCHAR(5) = '+254' -- Default Kenya
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IsValid BIT = 0;
    DECLARE @FormattedNumber NVARCHAR(20) = '';
    DECLARE @ValidationMessage NVARCHAR(200) = '';
    
    -- Remove spaces, dashes, and other formatting
    SET @PhoneNumber = REPLACE(REPLACE(REPLACE(@PhoneNumber, ' ', ''), '-', ''), '(', '');
    SET @PhoneNumber = REPLACE(REPLACE(@PhoneNumber, ')', ''), '+', '');
    
    -- Basic validation for Kenyan numbers
    IF LEN(@PhoneNumber) = 10 AND LEFT(@PhoneNumber, 1) = '0'
    BEGIN
        SET @FormattedNumber = @CountryCode + RIGHT(@PhoneNumber, 9);
        SET @IsValid = 1;
        SET @ValidationMessage = 'Valid phone number';
    END
    ELSE IF LEN(@PhoneNumber) = 9
    BEGIN
        SET @FormattedNumber = @CountryCode + @PhoneNumber;
        SET @IsValid = 1;
        SET @ValidationMessage = 'Valid phone number';
    END
    ELSE IF LEN(@PhoneNumber) = 13 AND LEFT(@PhoneNumber, 3) = '254'
    BEGIN
        SET @FormattedNumber = '+' + @PhoneNumber;
        SET @IsValid = 1;
        SET @ValidationMessage = 'Valid phone number';
    END
    ELSE
    BEGIN
        SET @ValidationMessage = 'Invalid phone number format';
    END
    
    SELECT 
        @IsValid AS IsValid,
        @FormattedNumber AS FormattedNumber,
        @ValidationMessage AS ValidationMessage;
END;
GO