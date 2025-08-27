
-- Create or Update Agent Profile
CREATE OR ALTER PROCEDURE sp_UpsertAgent
    @AgentId UNIQUEIDENTIFIER = NULL,
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Email NVARCHAR(100),
    @Phone NVARCHAR(20),
    @PasswordHash NVARCHAR(200),
    @Avatar NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @AgentId IS NULL
    BEGIN
        SET @AgentId = NEWID();

        INSERT INTO Agent (AgentId, FirstName, LastName, Email, Phone, PasswordHash, Avatar)
        VALUES (@AgentId, @FirstName, @LastName, @Email, @Phone, @PasswordHash, @Avatar);

        INSERT INTO AgentSettings (AgentId) VALUES (@AgentId);

        INSERT INTO ReminderSettings (AgentId, ReminderType, DaysBefore, TimeOfDay)
        VALUES 
            (@AgentId, 'Policy Expiry', 30, '09:00'),
            (@AgentId, 'Birthday', 1, '08:00'),
            (@AgentId, 'Appointment', 1, '18:00'),
            (@AgentId, 'Call', 0, '10:00');
    END
    ELSE
    BEGIN
        UPDATE Agent
        SET 
            FirstName = @FirstName,
            LastName = @LastName,
            Email = @Email,
            Phone = @Phone,
            PasswordHash = @PasswordHash,
            Avatar = @Avatar,
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId;
    END

    SELECT @AgentId AS AgentId;
END;

GO

-- Get Agent Profile
CREATE OR ALTER PROCEDURE sp_GetAgent
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        a.*,
        s.DarkMode,
        s.EmailNotifications,
        s.SmsNotifications,
        s.WhatsappNotifications,
        s.PushNotifications,
        s.SoundEnabled
    FROM Agent a
    LEFT JOIN AgentSettings s ON a.AgentId = s.AgentId
    WHERE a.AgentId = @AgentId AND a.IsActive = 1;
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
    
    -- Check if settings exist, create if not
    IF NOT EXISTS (SELECT 1 FROM AgentSettings WHERE AgentId = @AgentId)
    BEGIN
        INSERT INTO AgentSettings (AgentId) VALUES (@AgentId);
    END
    
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
END;
GO

-- Get Insurance Companies
CREATE OR ALTER PROCEDURE sp_GetInsuranceCompanies
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT CompanyId, CompanyName
    FROM InsuranceCompanies
    WHERE IsActive = 1
    ORDER BY CompanyName;
END;
GO

-- Get Policy Types
CREATE OR ALTER PROCEDURE sp_GetPolicyTypes
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TypeId, TypeName
    FROM PolicyTypes
    WHERE IsActive = 1
    ORDER BY TypeName;
END;
GO

CREATE OR ALTER PROCEDURE sp_AuthenticateAgent
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        AgentId,
        FirstName,
        LastName,
        Email,
        Phone,
        PasswordHash
    FROM Agent
    WHERE Email = @Email AND IsActive = 1;
END;

GO

-- 1. Login Authentication with Token Generation
CREATE OR ALTER PROCEDURE sp_LoginAgent
    @Email NVARCHAR(100),
    @Password NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @AgentId UNIQUEIDENTIFIER;
    DECLARE @StoredHash NVARCHAR(256);
    DECLARE @IsActive BIT;
    
    -- Get agent details
    SELECT 
        @AgentId = AgentId,
        @StoredHash = PasswordHash,
        @IsActive = IsActive
    FROM Agent 
    WHERE Email = @Email;
    
    -- Check if agent exists and is active
    IF @AgentId IS NULL
    BEGIN
        SELECT 
            0 as Success,
            'Invalid email or password' as Message,
            NULL as AgentId,
            NULL as Token,
            NULL as AgentProfile;
        RETURN;
    END
    
    IF @IsActive = 0
    BEGIN
        SELECT 
            0 as Success,
            'Account is deactivated' as Message,
            NULL as AgentId,
            NULL as Token,
            NULL as AgentProfile;
        RETURN;
    END
    
    -- Note: Password verification should be done in application layer
    -- This SP returns the stored hash for comparison
    SELECT 
        1 as Success,
        'Login successful' as Message,
        @AgentId as AgentId,
        @StoredHash as StoredPasswordHash,
        (
            SELECT 
                a.AgentId,
                a.FirstName,
                a.LastName,
                a.Email,
                a.Phone,
                a.Avatar,
                a.CreatedDate,
                a.IsActive,
                s.DarkMode,
                s.EmailNotifications,
                s.SmsNotifications,
                s.WhatsappNotifications,
                s.PushNotifications,
                s.SoundEnabled
            FROM Agent a
            LEFT JOIN AgentSettings s ON a.AgentId = s.AgentId
            WHERE a.AgentId = @AgentId
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) as AgentProfile;
END;
GO

-- 2. Register New Agent
CREATE OR ALTER PROCEDURE sp_RegisterAgent
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Email NVARCHAR(100),
    @Phone NVARCHAR(20),
    @PasswordHash NVARCHAR(256),
    @Avatar NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @AgentId UNIQUEIDENTIFIER = NEWID();
    
    -- Check if email already exists
    IF EXISTS(SELECT 1 FROM Agent WHERE Email = @Email)
    BEGIN
        SELECT 
            0 as Success,
            'Email already exists' as Message,
            NULL as AgentId;
        RETURN;
    END
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Insert agent
        INSERT INTO Agent (AgentId, FirstName, LastName, Email, Phone, PasswordHash, Avatar)
        VALUES (@AgentId, @FirstName, @LastName, @Email, @Phone, @PasswordHash, @Avatar);
        
        -- Insert default agent settings
        INSERT INTO AgentSettings (AgentId)
        VALUES (@AgentId);
        
        -- Insert default reminder settings
        INSERT INTO ReminderSettings (AgentId, ReminderType, DaysBefore)
        VALUES 
            (@AgentId, 'Policy Expiry', 7),
            (@AgentId, 'Birthday', 1),
            (@AgentId, 'Appointment', 1);
        
        -- Insert default notification preferences
        INSERT INTO AgentNotificationPreferences (AgentId, NotificationType)
        VALUES 
            (@AgentId, 'appointment'),
            (@AgentId, 'birthday'),
            (@AgentId, 'policy_expiry');
        
        COMMIT TRANSACTION;
        
        SELECT 
            1 as Success,
            'Registration successful' as Message,
            @AgentId as AgentId;
            
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        SELECT 
            0 as Success,
            ERROR_MESSAGE() as Message,
            NULL as AgentId;
    END CATCH
END;
GO

-- 3. Change Password
CREATE OR ALTER PROCEDURE sp_ChangePassword
    @AgentId UNIQUEIDENTIFIER,
    @OldPasswordHash NVARCHAR(256),
    @NewPasswordHash NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StoredHash NVARCHAR(256);
    
    -- Get current password hash
    SELECT @StoredHash = PasswordHash
    FROM Agent 
    WHERE AgentId = @AgentId AND IsActive = 1;
    
    IF @StoredHash IS NULL
    BEGIN
        SELECT 
            0 as Success,
            'Agent not found or inactive' as Message;
        RETURN;
    END
    
    -- Note: Old password verification should be done in application layer
    -- Update password
    UPDATE Agent 
    SET 
        PasswordHash = @NewPasswordHash,
        ModifiedDate = GETUTCDATE()
    WHERE AgentId = @AgentId;
    
    SELECT 
        1 as Success,
        'Password changed successfully' as Message;
END;
GO

-- 4. Reset Password (Generate reset token)
CREATE OR ALTER PROCEDURE sp_RequestPasswordReset
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @AgentId UNIQUEIDENTIFIER;
    
    -- Check if agent exists
    SELECT @AgentId = AgentId
    FROM Agent 
    WHERE Email = @Email AND IsActive = 1;
    
    IF @AgentId IS NULL
    BEGIN
        SELECT 
            0 as Success,
            'Email not found' as Message,
            NULL as AgentId;
        RETURN;
    END
    
    -- Return agent ID for reset token generation in application
    SELECT 
        1 as Success,
        'Reset request valid' as Message,
        @AgentId as AgentId,
        @Email as Email;
END;
GO

-- 5. Complete Password Reset
CREATE OR ALTER PROCEDURE sp_ResetPassword
    @AgentId UNIQUEIDENTIFIER,
    @NewPasswordHash NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Update password
    UPDATE Agent 
    SET 
        PasswordHash = @NewPasswordHash,
        ModifiedDate = GETUTCDATE()
    WHERE AgentId = @AgentId AND IsActive = 1;
    
    IF @@ROWCOUNT = 0
    BEGIN
        SELECT 
            0 as Success,
            'Invalid reset request' as Message;
        RETURN;
    END
    
    SELECT 
        1 as Success,
        'Password reset successful' as Message;
END;
GO
