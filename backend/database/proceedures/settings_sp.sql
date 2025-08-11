-- ============================================
-- Settings Management Stored Procedures
-- ============================================

-- Get Application Settings
CREATE OR ALTER PROCEDURE sp_GetApplicationSettings
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        SettingKey,
        SettingValue,
        Description,
        DataType,
        ModifiedDate
    FROM ApplicationSettings
    WHERE IsActive = 1
    ORDER BY SettingKey;
END;
GO

-- Update Application Setting
CREATE OR ALTER PROCEDURE sp_UpdateApplicationSetting
    @SettingKey NVARCHAR(100),
    @SettingValue NVARCHAR(MAX),
    @Description NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM ApplicationSettings WHERE SettingKey = @SettingKey)
    BEGIN
        UPDATE ApplicationSettings 
        SET 
            SettingValue = @SettingValue,
            Description = ISNULL(@Description, Description),
            ModifiedDate = GETUTCDATE()
        WHERE SettingKey = @SettingKey;
    END
    ELSE
    BEGIN
        INSERT INTO ApplicationSettings (SettingKey, SettingValue, Description)
        VALUES (@SettingKey, @SettingValue, @Description);
    END
END;
GO

-- Get Agent Notification Preferences
CREATE OR ALTER PROCEDURE sp_GetNotificationPreferences
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        PreferenceId,
        NotificationType,
        EmailEnabled,
        SmsEnabled,
        WhatsAppEnabled,
        PushEnabled,
        SoundEnabled,
        AdvanceNoticeMinutes,
        ModifiedDate
    FROM AgentNotificationPreferences
    WHERE AgentId = @AgentId
    ORDER BY NotificationType;
END;
GO

-- Update Notification Preferences
CREATE OR ALTER PROCEDURE sp_UpdateNotificationPreferences
    @AgentId UNIQUEIDENTIFIER,
    @NotificationType NVARCHAR(50),
    @EmailEnabled BIT = NULL,
    @SmsEnabled BIT = NULL,
    @WhatsAppEnabled BIT = NULL,
    @PushEnabled BIT = NULL,
    @SoundEnabled BIT = NULL,
    @AdvanceNoticeMinutes INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM AgentNotificationPreferences WHERE AgentId = @AgentId AND NotificationType = @NotificationType)
    BEGIN
        UPDATE AgentNotificationPreferences 
        SET 
            EmailEnabled = ISNULL(@EmailEnabled, EmailEnabled),
            SmsEnabled = ISNULL(@SmsEnabled, SmsEnabled),
            WhatsAppEnabled = ISNULL(@WhatsAppEnabled, WhatsAppEnabled),
            PushEnabled = ISNULL(@PushEnabled, PushEnabled),
            SoundEnabled = ISNULL(@SoundEnabled, SoundEnabled),
            AdvanceNoticeMinutes = ISNULL(@AdvanceNoticeMinutes, AdvanceNoticeMinutes),
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND NotificationType = @NotificationType;
    END
    ELSE
    BEGIN
        INSERT INTO AgentNotificationPreferences (
            AgentId, NotificationType, EmailEnabled, SmsEnabled, WhatsAppEnabled,
            PushEnabled, SoundEnabled, AdvanceNoticeMinutes
        )
        VALUES (
            @AgentId, @NotificationType, ISNULL(@EmailEnabled, 1), ISNULL(@SmsEnabled, 1), 
            ISNULL(@WhatsAppEnabled, 1), ISNULL(@PushEnabled, 1), ISNULL(@SoundEnabled, 1), 
            ISNULL(@AdvanceNoticeMinutes, 60)
        );
    END
END;
GO

-- Get System Preferences
CREATE OR ALTER PROCEDURE sp_GetSystemPreferences
    @AgentId UNIQUEIDENTIFIER,
    @PreferenceKey NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        PreferenceKey,
        PreferenceValue,
        ModifiedDate
    FROM SystemPreferences
    WHERE 
        AgentId = @AgentId
        AND (@PreferenceKey IS NULL OR PreferenceKey = @PreferenceKey)
    ORDER BY PreferenceKey;
END;
GO

-- Update System Preference
CREATE OR ALTER PROCEDURE sp_UpdateSystemPreference
    @AgentId UNIQUEIDENTIFIER,
    @PreferenceKey NVARCHAR(100),
    @PreferenceValue NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM SystemPreferences WHERE AgentId = @AgentId AND PreferenceKey = @PreferenceKey)
    BEGIN
        UPDATE SystemPreferences 
        SET 
            PreferenceValue = @PreferenceValue,
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND PreferenceKey = @PreferenceKey;
    END
    ELSE
    BEGIN
        INSERT INTO SystemPreferences (AgentId, PreferenceKey, PreferenceValue)
        VALUES (@AgentId, @PreferenceKey, @PreferenceValue);
    END
END;
GO

-- Get Backup Settings
CREATE OR ALTER PROCEDURE sp_GetBackupSettings
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        BackupFrequency,
        LastBackupDate,
        BackupLocation,
        AutoBackupEnabled,
        IncludeClientData,
        IncludeAppointments,
        IncludeReminders,
        IncludeSettings,
        ModifiedDate
    FROM BackupSettings
    WHERE AgentId = @AgentId;
END;
GO

-- Update Backup Settings
CREATE OR ALTER PROCEDURE sp_UpdateBackupSettings
    @AgentId UNIQUEIDENTIFIER,
    @BackupFrequency NVARCHAR(20) = NULL,
    @BackupLocation NVARCHAR(500) = NULL,
    @AutoBackupEnabled BIT = NULL,
    @IncludeClientData BIT = NULL,
    @IncludeAppointments BIT = NULL,
    @IncludeReminders BIT = NULL,
    @IncludeSettings BIT = NULL,
    @LastBackupDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM BackupSettings WHERE AgentId = @AgentId)
    BEGIN
        UPDATE BackupSettings 
        SET 
            BackupFrequency = ISNULL(@BackupFrequency, BackupFrequency),
            BackupLocation = ISNULL(@BackupLocation, BackupLocation),
            AutoBackupEnabled = ISNULL(@AutoBackupEnabled, AutoBackupEnabled),
            IncludeClientData = ISNULL(@IncludeClientData, IncludeClientData),
            IncludeAppointments = ISNULL(@IncludeAppointments, IncludeAppointments),
            IncludeReminders = ISNULL(@IncludeReminders, IncludeReminders),
            IncludeSettings = ISNULL(@IncludeSettings, IncludeSettings),
            LastBackupDate = ISNULL(@LastBackupDate, LastBackupDate),
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId;
    END
    ELSE
    BEGIN
        INSERT INTO BackupSettings (
            AgentId, BackupFrequency, BackupLocation, AutoBackupEnabled,
            IncludeClientData, IncludeAppointments, IncludeReminders, IncludeSettings,
            LastBackupDate
        )
        VALUES (
            @AgentId, ISNULL(@BackupFrequency, 'Weekly'), @BackupLocation, ISNULL(@AutoBackupEnabled, 1),
            ISNULL(@IncludeClientData, 1), ISNULL(@IncludeAppointments, 1), ISNULL(@IncludeReminders, 1), 
            ISNULL(@IncludeSettings, 1), @LastBackupDate
        );
    END
END;
GO

-- Create Message Template
CREATE OR ALTER PROCEDURE sp_CreateMessageTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @MessageType NVARCHAR(50),
    @Template NVARCHAR(MAX),
    @IsDefault BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TemplateId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO MessageTemplates (
        TemplateId, AgentId, TemplateName, MessageType, Template, IsDefault
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @MessageType, @Template, @IsDefault
    );
    
    SELECT @TemplateId AS TemplateId;
END;
GO

-- Get Message Templates
CREATE OR ALTER PROCEDURE sp_GetMessageTemplates
    @AgentId UNIQUEIDENTIFIER,
    @MessageType NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        TemplateId,
        TemplateName,
        MessageType,
        Template,
        IsDefault,
        UsageCount,
        CreatedDate,
        ModifiedDate
    FROM MessageTemplates
    WHERE 
        AgentId = @AgentId
        AND (@MessageType IS NULL OR MessageType = @MessageType)
    ORDER BY MessageType, IsDefault DESC, TemplateName;
END;
GO

-- Update Message Template
CREATE OR ALTER PROCEDURE sp_UpdateMessageTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @Template NVARCHAR(MAX),
    @IsDefault BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE MessageTemplates 
    SET 
        TemplateName = @TemplateName,
        Template = @Template,
        IsDefault = ISNULL(@IsDefault, IsDefault),
        ModifiedDate = GETUTCDATE()
    WHERE TemplateId = @TemplateId AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Message Template
CREATE OR ALTER PROCEDURE sp_DeleteMessageTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DELETE FROM MessageTemplates 
    WHERE TemplateId = @TemplateId AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Increment Template Usage
CREATE OR ALTER PROCEDURE sp_IncrementTemplateUsage
    @TemplateId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE MessageTemplates 
    SET UsageCount = UsageCount + 1
    WHERE TemplateId = @TemplateId;
END;
GO

-- Export Agent Data
CREATE OR ALTER PROCEDURE sp_ExportAgentData
    @AgentId UNIQUEIDENTIFIER,
    @IncludeClients BIT = 1,
    @IncludeAppointments BIT = 1,
    @IncludeReminders BIT = 1,
    @IncludePolicies BIT = 1,
    @IncludeSettings BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Agent Profile
    SELECT 'Agent' AS DataType, * FROM Agent WHERE AgentId = @AgentId;
    
    -- Agent Settings
    IF @IncludeSettings = 1
    BEGIN
        SELECT 'AgentSettings' AS DataType, * FROM AgentSettings WHERE AgentId = @AgentId;
        SELECT 'ReminderSettings' AS DataType, * FROM ReminderSettings WHERE AgentId = @AgentId;
        SELECT 'NotificationPreferences' AS DataType, * FROM AgentNotificationPreferences WHERE AgentId = @AgentId;
        SELECT 'SystemPreferences' AS DataType, * FROM SystemPreferences WHERE AgentId = @AgentId;
        SELECT 'BackupSettings' AS DataType, * FROM BackupSettings WHERE AgentId = @AgentId;
        SELECT 'MessageTemplates' AS DataType, * FROM MessageTemplates WHERE AgentId = @AgentId;
    END
    
    -- Clients
    IF @IncludeClients = 1
    BEGIN
        SELECT 'Clients' AS DataType, * FROM Clients WHERE AgentId = @AgentId AND IsActive = 1;
    END
    
    -- Appointments
    IF @IncludeAppointments = 1
    BEGIN
        SELECT 'Appointments' AS DataType, a.* 
        FROM Appointments a 
        INNER JOIN Clients c ON a.ClientId = c.ClientId
        WHERE c.AgentId = @AgentId AND a.IsActive = 1;
    END
    
    -- Reminders
    IF @IncludeReminders = 1
    BEGIN
        SELECT 'Reminders' AS DataType, * FROM Reminders WHERE AgentId = @AgentId;
        SELECT 'AutomatedMessages' AS DataType, * FROM AutomatedMessages WHERE AgentId = @AgentId;
    END
    
    -- Policies
    IF @IncludePolicies = 1
    BEGIN
        SELECT 'PolicyCatalog' AS DataType, * FROM PolicyCatalog WHERE AgentId = @AgentId AND IsActive = 1;
        SELECT 'ClientPolicies' AS DataType, cp.* 
        FROM ClientPolicies cp
        INNER JOIN Clients c ON cp.ClientId = c.ClientId
        WHERE c.AgentId = @AgentId AND cp.IsActive = 1;
    END
END;
GO

-- Import Agent Data (This would be used with careful validation in real implementation)
CREATE OR ALTER PROCEDURE sp_ValidateImportData
    @AgentId UNIQUEIDENTIFIER,
    @DataType NVARCHAR(50),
    @JsonData NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- This is a placeholder for data validation logic
    -- In a real implementation, you would parse the JSON and validate each record
    -- before allowing the import
    
    DECLARE @IsValid BIT = 1;
    DECLARE @ValidationMessage NVARCHAR(500) = 'Data validation passed';
    
    -- Basic validation logic would go here
    IF @JsonData IS NULL OR LEN(@JsonData) = 0
    BEGIN
        SET @IsValid = 0;
        SET @ValidationMessage = 'No data provided for import';
    END
    
    SELECT @IsValid AS IsValid, @ValidationMessage AS ValidationMessage;
END;
GO



-- Get Agent Settings
CREATE OR ALTER PROCEDURE sp_GetAgentSettings
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        AgentId,
        DarkMode,
        EmailNotifications,
        SmsNotifications,
        WhatsappNotifications,
        PushNotifications,
        SoundEnabled,
        CreatedDate,
        ModifiedDate
    FROM AgentSettings
    WHERE AgentId = @AgentId;
    
    -- If no settings exist, create default ones
    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO AgentSettings (AgentId)
        VALUES (@AgentId);
        
        SELECT 
            AgentId,
            DarkMode,
            EmailNotifications,
            SmsNotifications,
            WhatsappNotifications,
            PushNotifications,
            SoundEnabled,
            CreatedDate,
            ModifiedDate
        FROM AgentSettings
        WHERE AgentId = @AgentId;
    END
END;
GO

-- Update Agent Settings
CREATE OR ALTER PROCEDURE sp_UpdateAgentSettings
    @AgentId UNIQUEIDENTIFIER,
    @DarkMode BIT = NULL,
    @EmailNotifications BIT = NULL,
    @SmsNotifications BIT = NULL,
    @WhatsappNotifications BIT = NULL,
    @PushNotifications BIT = NULL,
    @SoundEnabled BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM AgentSettings WHERE AgentId = @AgentId)
    BEGIN
        UPDATE AgentSettings 
        SET 
            DarkMode = ISNULL(@DarkMode, DarkMode),
            EmailNotifications = ISNULL(@EmailNotifications, EmailNotifications),
            SmsNotifications = ISNULL(@SmsNotifications, SmsNotifications),
            WhatsappNotifications = ISNULL(@WhatsappNotifications, WhatsappNotifications),
            PushNotifications = ISNULL(@PushNotifications, PushNotifications),
            SoundEnabled = ISNULL(@SoundEnabled, SoundEnabled),
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId;
    END
    ELSE
    BEGIN
        INSERT INTO AgentSettings (
            AgentId, DarkMode, EmailNotifications, SmsNotifications, 
            WhatsappNotifications, PushNotifications, SoundEnabled
        )
        VALUES (
            @AgentId, ISNULL(@DarkMode, 0), ISNULL(@EmailNotifications, 1), 
            ISNULL(@SmsNotifications, 1), ISNULL(@WhatsappNotifications, 1), 
            ISNULL(@PushNotifications, 1), ISNULL(@SoundEnabled, 1)
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Toggle Dark Mode
CREATE OR ALTER PROCEDURE sp_ToggleDarkMode
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentMode BIT;
    
    SELECT @CurrentMode = DarkMode FROM AgentSettings WHERE AgentId = @AgentId;
    
    IF @CurrentMode IS NULL
    BEGIN
        -- Create settings if they don't exist
        INSERT INTO AgentSettings (AgentId, DarkMode) VALUES (@AgentId, 1);
        SELECT 1 AS NewDarkModeValue;
    END
    ELSE
    BEGIN
        UPDATE AgentSettings 
        SET DarkMode = CASE WHEN @CurrentMode = 1 THEN 0 ELSE 1 END,
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId;
        
        SELECT CASE WHEN @CurrentMode = 1 THEN 0 ELSE 1 END AS NewDarkModeValue;
    END
END;
GO