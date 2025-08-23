
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
-- ============================================
-- Analytics and Dashboard Stored Procedures
-- ============================================

-- Get Dashboard Overview
CREATE OR ALTER PROCEDURE sp_GetDashboardOverview
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @WeekStart DATE = DATEADD(DAY, 1-DATEPART(WEEKDAY, @Today), @Today);
    DECLARE @WeekEnd DATE = DATEADD(DAY, 6, @WeekStart);
    DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
    DECLARE @MonthEnd DATE = EOMONTH(@Today);
    
    -- Summary Statistics
    SELECT 
        -- Client Statistics
        COUNT(DISTINCT CASE WHEN c.IsClient = 1 THEN c.ClientId END) AS TotalClients,
        COUNT(DISTINCT CASE WHEN c.IsClient = 0 THEN c.ClientId END) AS TotalProspects,
        
        -- Policy Statistics
        COUNT(DISTINCT CASE WHEN cp.Status = 'Active' THEN cp.PolicyId END) AS ActivePolicies,
        
        -- Appointment Statistics
        COUNT(DISTINCT CASE WHEN a.AppointmentDate = @Today THEN a.AppointmentId END) AS TodayAppointments,
        COUNT(DISTINCT CASE WHEN a.AppointmentDate BETWEEN @WeekStart AND @WeekEnd THEN a.AppointmentId END) AS WeekAppointments,
        COUNT(DISTINCT CASE WHEN a.AppointmentDate BETWEEN @MonthStart AND @MonthEnd THEN a.AppointmentId END) AS MonthAppointments,
        COUNT(DISTINCT CASE WHEN a.Status = 'Completed' THEN a.AppointmentId END) AS CompletedAppointments,
        
        -- Reminder Statistics
        COUNT(DISTINCT CASE WHEN r.Status = 'Active' AND r.ReminderDate <= @Today THEN r.ReminderId END) AS PendingReminders,
        
        -- Birthday Statistics
        COUNT(DISTINCT CASE WHEN DAY(c.DateOfBirth) = DAY(@Today) AND MONTH(c.DateOfBirth) = MONTH(@Today) THEN c.ClientId END) AS TodayBirthdays,
        
        -- Expiring Policies
        COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 30, @Today) AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringPolicies
        
    FROM Clients c
    LEFT JOIN ClientPolicies cp ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    LEFT JOIN Appointments a ON c.ClientId = a.ClientId AND a.IsActive = 1
    LEFT JOIN Reminders r ON c.ClientId = r.ClientId
    WHERE c.AgentId = @AgentId AND c.IsActive = 1;
    
END;
GO

-- Get Today's Activities
CREATE OR ALTER PROCEDURE sp_GetTodayActivities
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    
    -- Today's Appointments
    SELECT 
        'appointment' AS ActivityType,
        a.AppointmentId AS EntityId,
        a.ClientName,
        a.Title,
        CONVERT(VARCHAR(5), a.StartTime, 108) + ' - ' + CONVERT(VARCHAR(5), a.EndTime, 108) AS TimeRange,
        a.Location,
        a.Type,
        a.Status,
        a.Notes,
        a.Priority,
        c.PhoneNumber AS ClientPhone
    FROM Appointments a
    LEFT JOIN Clients c ON a.ClientId = c.ClientId
    WHERE a.AgentId = @AgentId 
        AND a.AppointmentDate = @Today 
        AND a.IsActive = 1
        AND a.Status NOT IN ('Cancelled')
    ORDER BY a.StartTime;
    
    -- Today's Reminders
    SELECT 
        'reminder' AS ActivityType,
        r.ReminderId AS EntityId,
        r.ClientName,
        r.Title,
        ISNULL(CONVERT(VARCHAR(5), r.ReminderTime, 108), '') AS TimeRange,
        '' AS Location,
        r.ReminderType AS Type,
        r.Status,
        r.Notes,
        r.Priority,
        c.PhoneNumber AS ClientPhone
    FROM Reminders r
    LEFT JOIN Clients c ON r.ClientId = c.ClientId
    WHERE r.AgentId = @AgentId 
        AND r.ReminderDate = @Today 
        AND r.Status = 'Active'
    ORDER BY r.ReminderTime;
    
    -- Today's Birthdays
    SELECT 
        'birthday' AS ActivityType,
        c.ClientId AS EntityId,
        c.FirstName + ' ' + c.Surname AS ClientName,
        'Birthday - ' + c.FirstName + ' ' + c.Surname AS Title,
        '' AS TimeRange,
        c.Address AS Location,
        'Birthday' AS Type,
        'Active' AS Status,
        'Age: ' + CAST(DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) AS VARCHAR) AS Notes,
        'Medium' AS Priority,
        c.PhoneNumber AS ClientPhone
    FROM Clients c
    WHERE c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND DAY(c.DateOfBirth) = DAY(@Today)
        AND MONTH(c.DateOfBirth) = MONTH(@Today);
        
END;
GO

-- Get Performance Metrics
CREATE OR ALTER PROCEDURE sp_GetPerformanceMetrics
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @Period NVARCHAR(20) = 'month' -- 'week', 'month', 'quarter', 'year'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Set default date range based on period
    IF @StartDate IS NULL OR @EndDate IS NULL
    BEGIN
        DECLARE @Today DATE = CAST(GETDATE() AS DATE);
        
        IF @Period = 'week'
        BEGIN
            SET @StartDate = DATEADD(DAY, 1-DATEPART(WEEKDAY, @Today), @Today);
            SET @EndDate = DATEADD(DAY, 6, @StartDate);
        END
        ELSE IF @Period = 'month'
        BEGIN
            SET @StartDate = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
            SET @EndDate = EOMONTH(@Today);
        END
        ELSE IF @Period = 'quarter'
        BEGIN
            SET @StartDate = DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @Today), 0);
            SET @EndDate = DATEADD(DAY, -1, DATEADD(QUARTER, 1, @StartDate));
        END
        ELSE IF @Period = 'year'
        BEGIN
            SET @StartDate = DATEFROMPARTS(YEAR(@Today), 1, 1);
            SET @EndDate = DATEFROMPARTS(YEAR(@Today), 12, 31);
        END
    END
    
    SELECT 
        @StartDate AS PeriodStart,
        @EndDate AS PeriodEnd,
        @Period AS Period,
        
        -- Client Metrics
        COUNT(DISTINCT CASE WHEN c.CreatedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate) THEN c.ClientId END) AS NewClientsAdded,
        COUNT(DISTINCT CASE WHEN c.IsClient = 1 AND c.ModifiedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate) THEN c.ClientId END) AS ProspectsConverted,
        
        -- Appointment Metrics
        COUNT(CASE WHEN a.AppointmentDate BETWEEN @StartDate AND @EndDate THEN 1 END) AS TotalAppointments,
        COUNT(CASE WHEN a.AppointmentDate BETWEEN @StartDate AND @EndDate AND a.Status = 'Completed' THEN 1 END) AS CompletedAppointments,
        COUNT(CASE WHEN a.AppointmentDate BETWEEN @StartDate AND @EndDate AND a.Status = 'Cancelled' THEN 1 END) AS CancelledAppointments,
        
        -- Policy Metrics
        COUNT(CASE WHEN cp.CreatedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate) THEN 1 END) AS NewPolicies,
        COUNT(CASE WHEN cp.EndDate BETWEEN @StartDate AND @EndDate AND cp.Status = 'Expired' THEN 1 END) AS ExpiredPolicies,
        
        -- Reminder Metrics
        COUNT(CASE WHEN r.CreatedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate) THEN 1 END) AS RemindersCreated,
        COUNT(CASE WHEN r.CompletedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate) THEN 1 END) AS RemindersCompleted,
        
        -- Message Metrics
        COUNT(CASE WHEN am.CreatedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate) THEN 1 END) AS MessagesScheduled,
        COUNT(CASE WHEN am.SentDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate) THEN 1 END) AS MessagesSent
        
    FROM Clients c
    LEFT JOIN ClientPolicies cp ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    LEFT JOIN Appointments a ON c.ClientId = a.ClientId AND a.IsActive = 1
    LEFT JOIN Reminders r ON c.ClientId = r.ClientId
    LEFT JOIN AutomatedMessages am ON am.AgentId = c.AgentId
    WHERE c.AgentId = @AgentId AND c.IsActive = 1;
    
END;
GO

-- Update Dashboard Statistics Cache
CREATE OR ALTER PROCEDURE sp_UpdateDashboardStatistics
    @AgentId UNIQUEIDENTIFIER,
    @StatDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StatDate IS NULL
        SET @StatDate = CAST(GETDATE() AS DATE);
    
    DECLARE @WeekStart DATE = DATEADD(DAY, 1-DATEPART(WEEKDAY, @StatDate), @StatDate);
    DECLARE @WeekEnd DATE = DATEADD(DAY, 6, @WeekStart);
    DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@StatDate), MONTH(@StatDate), 1);
    DECLARE @MonthEnd DATE = EOMONTH(@StatDate);
    
    -- Calculate statistics
    DECLARE @TotalClients INT, @TotalProspects INT, @ActivePolicies INT;
    DECLARE @TodayAppointments INT, @WeekAppointments INT, @MonthAppointments INT, @CompletedAppointments INT;
    DECLARE @PendingReminders INT, @TodayBirthdays INT, @ExpiringPolicies INT;
    
    SELECT 
        @TotalClients = COUNT(CASE WHEN IsClient = 1 THEN 1 END),
        @TotalProspects = COUNT(CASE WHEN IsClient = 0 THEN 1 END),
        @TodayBirthdays = COUNT(CASE WHEN DAY(DateOfBirth) = DAY(@StatDate) AND MONTH(DateOfBirth) = MONTH(@StatDate) THEN 1 END)
    FROM Clients 
    WHERE AgentId = @AgentId AND IsActive = 1;
    
    SELECT @ActivePolicies = COUNT(DISTINCT cp.PolicyId)
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE c.AgentId = @AgentId AND cp.Status = 'Active' AND cp.IsActive = 1 AND c.IsActive = 1;
    
    SELECT 
        @TodayAppointments = COUNT(CASE WHEN AppointmentDate = @StatDate THEN 1 END),
        @WeekAppointments = COUNT(CASE WHEN AppointmentDate BETWEEN @WeekStart AND @WeekEnd THEN 1 END),
        @MonthAppointments = COUNT(CASE WHEN AppointmentDate BETWEEN @MonthStart AND @MonthEnd THEN 1 END),
        @CompletedAppointments = COUNT(CASE WHEN Status = 'Completed' THEN 1 END)
    FROM Appointments a
    INNER JOIN Clients c ON a.ClientId = c.ClientId
    WHERE c.AgentId = @AgentId AND a.IsActive = 1 AND c.IsActive = 1;
    
    SELECT @PendingReminders = COUNT(*)
    FROM Reminders 
    WHERE AgentId = @AgentId AND Status = 'Active' AND ReminderDate <= @StatDate;
    
    SELECT @ExpiringPolicies = COUNT(DISTINCT cp.PolicyId)
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE c.AgentId = @AgentId 
        AND cp.Status = 'Active' 
        AND cp.EndDate BETWEEN @StatDate AND DATEADD(DAY, 30, @StatDate)
        AND cp.IsActive = 1 AND c.IsActive = 1;
    
    -- Update or insert statistics
    IF EXISTS (SELECT 1 FROM DashboardStatistics WHERE AgentId = @AgentId AND StatDate = @StatDate)
    BEGIN
        UPDATE DashboardStatistics 
        SET 
            TotalClients = @TotalClients,
            TotalProspects = @TotalProspects,
            ActivePolicies = @ActivePolicies,
            TodayAppointments = @TodayAppointments,
            WeekAppointments = @WeekAppointments,
            MonthAppointments = @MonthAppointments,
            CompletedAppointments = @CompletedAppointments,
            PendingReminders = @PendingReminders,
            TodayBirthdays = @TodayBirthdays,
            ExpiringPolicies = @ExpiringPolicies,
            UpdatedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND StatDate = @StatDate;
    END
    ELSE
    BEGIN
        INSERT INTO DashboardStatistics (
            AgentId, StatDate, TotalClients, TotalProspects, ActivePolicies,
            TodayAppointments, WeekAppointments, MonthAppointments, CompletedAppointments,
            PendingReminders, TodayBirthdays, ExpiringPolicies
        )
        VALUES (
            @AgentId, @StatDate, @TotalClients, @TotalProspects, @ActivePolicies,
            @TodayAppointments, @WeekAppointments, @MonthAppointments, @CompletedAppointments,
            @PendingReminders, @TodayBirthdays, @ExpiringPolicies
        );
    END
END;
GO

-- Log Activity
CREATE OR ALTER PROCEDURE sp_LogActivity
    @AgentId UNIQUEIDENTIFIER,
    @ActivityType NVARCHAR(50),
    @EntityType NVARCHAR(50) = NULL,
    @EntityId UNIQUEIDENTIFIER = NULL,
    @Description NVARCHAR(500),
    @AdditionalData NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO ActivityLog (
        AgentId, ActivityType, EntityType, EntityId, Description, AdditionalData
    )
    VALUES (
        @AgentId, @ActivityType, @EntityType, @EntityId, @Description, @AdditionalData
    );
    
    -- Update performance metrics if applicable
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    
    IF @ActivityType IN ('client_created', 'appointment_completed', 'reminder_completed', 'policy_created')
    BEGIN
        -- Update or create performance metrics for today
        IF EXISTS (SELECT 1 FROM PerformanceMetrics WHERE AgentId = @AgentId AND MetricDate = @Today)
        BEGIN
            UPDATE PerformanceMetrics 
            SET 
                NewClientsAdded = NewClientsAdded + CASE WHEN @ActivityType = 'client_created' THEN 1 ELSE 0 END,
                AppointmentsCompleted = AppointmentsCompleted + CASE WHEN @ActivityType = 'appointment_completed' THEN 1 ELSE 0 END,
                RemindersCompleted = RemindersCompleted + CASE WHEN @ActivityType = 'reminder_completed' THEN 1 ELSE 0 END,
                PoliciesSold = PoliciesSold + CASE WHEN @ActivityType = 'policy_created' THEN 1 ELSE 0 END
            WHERE AgentId = @AgentId AND MetricDate = @Today;
        END
        ELSE
        BEGIN
            INSERT INTO PerformanceMetrics (
                AgentId, MetricDate, NewClientsAdded, AppointmentsCompleted, RemindersCompleted, PoliciesSold
            )
            VALUES (
                @AgentId, @Today,
                CASE WHEN @ActivityType = 'client_created' THEN 1 ELSE 0 END,
                CASE WHEN @ActivityType = 'appointment_completed' THEN 1 ELSE 0 END,
                CASE WHEN @ActivityType = 'reminder_completed' THEN 1 ELSE 0 END,
                CASE WHEN @ActivityType = 'policy_created' THEN 1 ELSE 0 END
            );
        END
    END
END;
GO

-- Get Activity Log
CREATE OR ALTER PROCEDURE sp_GetActivityLog
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @ActivityType NVARCHAR(50) = NULL,
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
        ActivityId,
        ActivityType,
        EntityType,
        EntityId,
        Description,
        ActivityDate,
        AdditionalData,
        ROW_NUMBER() OVER (ORDER BY ActivityDate DESC) AS RowNum
    FROM ActivityLog
    WHERE 
        AgentId = @AgentId
        AND ActivityDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)
        AND (@ActivityType IS NULL OR ActivityType = @ActivityType)
    ORDER BY ActivityDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
    -- Get total count
    SELECT COUNT(*) AS TotalRecords
    FROM ActivityLog
    WHERE 
        AgentId = @AgentId
        AND ActivityDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)
        AND (@ActivityType IS NULL OR ActivityType = @ActivityType);
        
END;
GO

-- Generate Monthly Report
CREATE OR ALTER PROCEDURE sp_GenerateMonthlyReport
    @AgentId UNIQUEIDENTIFIER,
    @ReportMonth DATE -- First day of the month
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MonthStart DATE = @ReportMonth;
    DECLARE @MonthEnd DATE = EOMONTH(@ReportMonth);
    
    -- Calculate metrics
    DECLARE @TotalClientsAdded INT, @TotalProspectsAdded INT, @ProspectsConverted INT;
    DECLARE @TotalAppointments INT, @CompletedAppointments INT, @CancelledAppointments INT;
    DECLARE @TotalReminders INT, @CompletedReminders INT;
    DECLARE @MessagesSent INT, @NewPolicies INT, @RenewedPolicies INT, @ExpiredPolicies INT;
    
    -- Client metrics
    SELECT 
        @TotalClientsAdded = COUNT(CASE WHEN IsClient = 1 AND CreatedDate BETWEEN @MonthStart AND DATEADD(DAY, 1, @MonthEnd) THEN 1 END),
        @TotalProspectsAdded = COUNT(CASE WHEN IsClient = 0 AND CreatedDate BETWEEN @MonthStart AND DATEADD(DAY, 1, @MonthEnd) THEN 1 END),
        @ProspectsConverted = COUNT(CASE WHEN IsClient = 1 AND ModifiedDate BETWEEN @MonthStart AND DATEADD(DAY, 1, @MonthEnd) THEN 1 END)
    FROM Clients 
    WHERE AgentId = @AgentId;
    
    -- Appointment metrics
    SELECT 
        @TotalAppointments = COUNT(*),
        @CompletedAppointments = COUNT(CASE WHEN Status = 'Completed' THEN 1 END),
        @CancelledAppointments = COUNT(CASE WHEN Status = 'Cancelled' THEN 1 END)
    FROM Appointments a
    INNER JOIN Clients c ON a.ClientId = c.ClientId
    WHERE c.AgentId = @AgentId 
        AND a.AppointmentDate BETWEEN @MonthStart AND @MonthEnd;
    
    -- Reminder metrics
    SELECT 
        @TotalReminders = COUNT(*),
        @CompletedReminders = COUNT(CASE WHEN Status = 'Completed' THEN 1 END)
    FROM Reminders 
    WHERE AgentId = @AgentId 
        AND ReminderDate BETWEEN @MonthStart AND @MonthEnd;
    
    -- Message metrics
    SELECT @MessagesSent = COUNT(*)
    FROM AutomatedMessages 
    WHERE AgentId = @AgentId 
        AND SentDate BETWEEN @MonthStart AND DATEADD(DAY, 1, @MonthEnd);
    
    -- Policy metrics
    SELECT 
        @NewPolicies = COUNT(CASE WHEN StartDate BETWEEN @MonthStart AND @MonthEnd THEN 1 END),
        @ExpiredPolicies = COUNT(CASE WHEN EndDate BETWEEN @MonthStart AND @MonthEnd THEN 1 END)
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE c.AgentId = @AgentId;
    
    SET @RenewedPolicies = 0; -- This would require more complex logic to track renewals
    
    -- Update or insert report
    IF EXISTS (SELECT 1 FROM MonthlyReports WHERE AgentId = @AgentId AND ReportMonth = @MonthStart)
    BEGIN
        UPDATE MonthlyReports 
        SET 
            TotalClientsAdded = @TotalClientsAdded,
            TotalProspectsAdded = @TotalProspectsAdded,
            ProspectsConverted = @ProspectsConverted,
            TotalAppointments = @TotalAppointments,
            CompletedAppointments = @CompletedAppointments,
            CancelledAppointments = @CancelledAppointments,
            TotalReminders = @TotalReminders,
            CompletedReminders = @CompletedReminders,
            MessagesSent = @MessagesSent,
            NewPolicies = @NewPolicies,
            RenewedPolicies = @RenewedPolicies,
            ExpiredPolicies = @ExpiredPolicies,
            GeneratedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND ReportMonth = @MonthStart;
    END
    ELSE
    BEGIN
        INSERT INTO MonthlyReports (
            AgentId, ReportMonth, TotalClientsAdded, TotalProspectsAdded, ProspectsConverted,
            TotalAppointments, CompletedAppointments, CancelledAppointments,
            TotalReminders, CompletedReminders, MessagesSent,
            NewPolicies, RenewedPolicies, ExpiredPolicies
        )
        VALUES (
            @AgentId, @MonthStart, @TotalClientsAdded, @TotalProspectsAdded, @ProspectsConverted,
            @TotalAppointments, @CompletedAppointments, @CancelledAppointments,
            @TotalReminders, @CompletedReminders, @MessagesSent,
            @NewPolicies, @RenewedPolicies, @ExpiredPolicies
        );
    END
    
    SELECT * FROM MonthlyReports 
    WHERE AgentId = @AgentId AND ReportMonth = @MonthStart;
    
END;
GO

-- ============================================
-- Missing Policy Service Stored Procedures
-- ============================================

-- Get Policy Catalog with Filters
CREATE OR ALTER PROCEDURE sp_GetPolicyCatalog
    @AgentId UNIQUEIDENTIFIER,
    @PolicyType NVARCHAR(50) = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CompanyName NVARCHAR(100) = NULL,
    @SearchTerm NVARCHAR(100) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pc.PolicyCatalogId,
        pc.AgentId,
        pc.PolicyName,
        pc.PolicyType,
        pc.CompanyId,
        pc.CompanyName,
        pc.Notes,
        pc.IsActive,
        pc.CreatedDate,
        pc.ModifiedDate,
        ic.IsActive AS CompanyActive
    FROM PolicyCatalog pc
    LEFT JOIN InsuranceCompanies ic ON pc.CompanyId = ic.CompanyId
    WHERE 
        pc.AgentId = @AgentId
        AND (@PolicyType IS NULL OR pc.PolicyType = @PolicyType)
        AND (@CompanyId IS NULL OR pc.CompanyId = @CompanyId)
        AND (@CompanyName IS NULL OR pc.CompanyName LIKE '%' + @CompanyName + '%')
        AND (@SearchTerm IS NULL OR pc.PolicyName LIKE '%' + @SearchTerm + '%')
        AND (@IsActive IS NULL OR pc.IsActive = @IsActive)
    ORDER BY pc.PolicyName ASC;
END;
GO

-- Create Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_CreatePolicyCatalogItem
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @CompanyId UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyCatalogId UNIQUEIDENTIFIER = NEWID();
    DECLARE @CompanyName NVARCHAR(100);
    
    -- Get company name
    SELECT @CompanyName = CompanyName 
    FROM InsuranceCompanies 
    WHERE CompanyId = @CompanyId;
    
    IF @CompanyName IS NULL
    BEGIN
        SELECT 'Company not found' AS ErrorMessage;
        RETURN;
    END
    
    INSERT INTO PolicyCatalog (
        PolicyCatalogId, AgentId, PolicyName, PolicyType, CompanyId, CompanyName, Notes
    )
    VALUES (
        @PolicyCatalogId, @AgentId, @PolicyName, @PolicyType, @CompanyId, @CompanyName, @Notes
    );
    
    SELECT @PolicyCatalogId AS PolicyCatalogId;
END;
GO

-- Update Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_UpdatePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @PolicyType NVARCHAR(50) = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CompanyName NVARCHAR(100);
    
    -- Get company name if CompanyId is provided
    IF @CompanyId IS NOT NULL
    BEGIN
        SELECT @CompanyName = CompanyName 
        FROM InsuranceCompanies 
        WHERE CompanyId = @CompanyId;
        
        IF @CompanyName IS NULL
        BEGIN
            SELECT 'Company not found' AS ErrorMessage;
            RETURN;
        END
    END
    
    UPDATE PolicyCatalog 
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        PolicyType = ISNULL(@PolicyType, PolicyType),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        CompanyName = ISNULL(@CompanyName, CompanyName),
        Notes = ISNULL(@Notes, Notes),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_DeletePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Soft delete by setting IsActive to 0
    UPDATE PolicyCatalog 
    SET 
        IsActive = 0,
        ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Client Policies
CREATE OR ALTER PROCEDURE sp_GetClientPolicies
    @ClientId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = NULL,
    @PolicyType NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.PolicyType,
        cp.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.IsActive,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry,
        c.FirstName + ' ' + c.Surname AS ClientName,
        c.PhoneNumber AS ClientPhone
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE 
        cp.ClientId = @ClientId
        AND cp.IsActive = 1
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@PolicyType IS NULL OR cp.PolicyType = @PolicyType)
    ORDER BY cp.StartDate DESC;
END;
GO

-- Create Client Policy
CREATE OR ALTER PROCEDURE sp_CreateClientPolicy
    @ClientId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @CompanyName NVARCHAR(100),
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO ClientPolicies (
        PolicyId, ClientId, PolicyName, PolicyType, CompanyName, Status, StartDate, EndDate, Notes
    )
    VALUES (
        @PolicyId, @ClientId, @PolicyName, @PolicyType, @CompanyName, @Status, @StartDate, @EndDate, @Notes
    );
    
    SELECT @PolicyId AS PolicyId;
END;
GO

-- Update Client Policy
CREATE OR ALTER PROCEDURE sp_UpdateClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @PolicyType NVARCHAR(50) = NULL,
    @CompanyName NVARCHAR(100) = NULL,
    @Status NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE ClientPolicies 
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        PolicyType = ISNULL(@PolicyType, PolicyType),
        CompanyName = ISNULL(@CompanyName, CompanyName),
        Status = ISNULL(@Status, Status),
        StartDate = ISNULL(@StartDate, StartDate),
        EndDate = ISNULL(@EndDate, EndDate),
        Notes = ISNULL(@Notes, Notes),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETUTCDATE()
    WHERE PolicyId = @PolicyId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Expiring Policies
CREATE OR ALTER PROCEDURE sp_GetExpiringPolicies
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
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        c.FirstName + ' ' + c.Surname AS ClientName,
        c.PhoneNumber AS ClientPhone,
        c.Email AS ClientEmail,
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

-- Get Policy Statistics
CREATE OR ALTER PROCEDURE sp_GetPolicyStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
    DECLARE @MonthEnd DATE = EOMONTH(@Today);
    
    SELECT 
        -- Total Policies
        COUNT(DISTINCT cp.PolicyId) AS TotalPolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Active' THEN cp.PolicyId END) AS ActivePolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Expired' THEN cp.PolicyId END) AS ExpiredPolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Lapsed' THEN cp.PolicyId END) AS LapsedPolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Inactive' THEN cp.PolicyId END) AS InactivePolicies,
        
        -- Expiring Soon (next 30 days)
        COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 30, @Today) AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn30Days,
        COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 7, @Today) AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn7Days,
        
        -- New Policies This Month
        COUNT(DISTINCT CASE WHEN cp.StartDate BETWEEN @MonthStart AND @MonthEnd THEN cp.PolicyId END) AS NewPoliciesThisMonth,
        
        -- Policies by Type
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Motor' THEN cp.PolicyId END) AS MotorPolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Life' THEN cp.PolicyId END) AS LifePolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Health' THEN cp.PolicyId END) AS HealthPolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Travel' THEN cp.PolicyId END) AS TravelPolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Property' THEN cp.PolicyId END) AS PropertyPolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Marine' THEN cp.PolicyId END) AS MarinePolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Business' THEN cp.PolicyId END) AS BusinessPolicies,
        
        -- Catalog Statistics
        COUNT(DISTINCT pc.PolicyCatalogId) AS CatalogPolicies
        
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyCatalog pc ON pc.AgentId = c.AgentId AND pc.IsActive = 1
    WHERE c.AgentId = @AgentId AND cp.IsActive = 1 AND c.IsActive = 1;
END;
GO

-- Get Insurance Companies
CREATE OR ALTER PROCEDURE sp_GetInsuranceCompanies
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CompanyId,
        CompanyName,
        IsActive,
        CreatedDate
    FROM InsuranceCompanies
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY CompanyName ASC;
END;
GO

-- Get Policy Types
CREATE OR ALTER PROCEDURE sp_GetPolicyTypes
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        TypeId,
        TypeName,
        IsActive,
        CreatedDate
    FROM PolicyTypes
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY TypeName ASC;
END;
GO

-- Get Policy Templates
CREATE OR ALTER PROCEDURE sp_GetPolicyTemplates
    @AgentId UNIQUEIDENTIFIER,
    @PolicyType NVARCHAR(50) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        TemplateId,
        AgentId,
        TemplateName,
        PolicyType,
        DefaultTermMonths,
        DefaultPremium,
        CoverageDescription,
        Terms,
        IsActive,
        CreatedDate
    FROM PolicyTemplates
    WHERE 
        AgentId = @AgentId
        AND (@PolicyType IS NULL OR PolicyType = @PolicyType)
        AND (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY TemplateName ASC;
END;
GO

-- Create Policy Template
CREATE OR ALTER PROCEDURE sp_CreatePolicyTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(10,2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TemplateId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO PolicyTemplates (
        TemplateId, AgentId, TemplateName, PolicyType, DefaultTermMonths, DefaultPremium, CoverageDescription, Terms
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @PolicyType, @DefaultTermMonths, @DefaultPremium, @CoverageDescription, @Terms
    );
    
    SELECT @TemplateId AS TemplateId;
END;
GO

-- Validate Policy Data
CREATE OR ALTER PROCEDURE sp_ValidatePolicyData
    @PolicyName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IsValid BIT = 1;
    DECLARE @ValidationErrors NVARCHAR(MAX) = '';
    
    -- Validate Policy Name
    IF @PolicyName IS NULL OR LEN(TRIM(@PolicyName)) = 0
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Policy name is required. ';
    END
    
    -- Validate Policy Type
    IF @PolicyType IS NULL OR NOT EXISTS (SELECT 1 FROM PolicyTypes WHERE TypeName = @PolicyType AND IsActive = 1)
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Valid policy type is required. ';
    END
    
    -- Validate Company
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompanies WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Valid insurance company is required. ';
    END
    
    -- Validate Dates
    IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate >= @EndDate
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'End date must be after start date. ';
    END
    
    SELECT 
        @IsValid AS IsValid,
        RTRIM(@ValidationErrors) AS ValidationErrors;
END;
GO
-- ============================================
-- Appointments Management Stored Procedures
-- ============================================

-- Create or Update Appointment
CREATE OR ALTER PROCEDURE sp_UpsertAppointment
    @AppointmentId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @ClientName NVARCHAR(150),
    @ClientPhone NVARCHAR(20) = NULL,
    @Title NVARCHAR(200),
    @Description NVARCHAR(MAX) = NULL,
    @AppointmentDate DATE,
    @StartTime TIME,
    @EndTime TIME,
    @Location NVARCHAR(200) = NULL,
    @Type NVARCHAR(50),
    @Status NVARCHAR(20) = 'Scheduled',
    @Priority NVARCHAR(10) = 'Medium',
    @Notes NVARCHAR(MAX) = NULL,
    @ReminderSet BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @AppointmentId IS NULL
    BEGIN
        -- Create new appointment
        SET @AppointmentId = NEWID();
        
        INSERT INTO Appointments (
            AppointmentId, ClientId, AgentId, ClientName, ClientPhone, Title, Description,
            AppointmentDate, StartTime, EndTime, Location, Type, Status, Priority, Notes, ReminderSet
        )
        VALUES (
            @AppointmentId, @ClientId, @AgentId, @ClientName, @ClientPhone, @Title, @Description,
            @AppointmentDate, @StartTime, @EndTime, @Location, @Type, @Status, @Priority, @Notes, @ReminderSet
        );
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'appointment_created', 'appointment', @AppointmentId, 'Appointment "' + @Title + '" scheduled with ' + @ClientName);
        
        -- Create automatic reminder if ReminderSet is true
        IF @ReminderSet = 1
        BEGIN
            INSERT INTO Reminders (
                ClientId, AppointmentId, AgentId, ReminderType, Title, Description,
                ReminderDate, ReminderTime, ClientName, Priority, EnablePushNotification
            )
            VALUES (
                @ClientId, @AppointmentId, @AgentId, 'Appointment', 'Appointment Reminder: ' + @Title,
                'Reminder for appointment with ' + @ClientName,
                DATEADD(DAY, -1, @AppointmentDate), @StartTime, @ClientName, @Priority, 1
            );
        END
    END
    ELSE
    BEGIN
        -- Update existing appointment
        UPDATE Appointments 
        SET 
            ClientName = @ClientName,
            ClientPhone = @ClientPhone,
            Title = @Title,
            Description = @Description,
            AppointmentDate = @AppointmentDate,
            StartTime = @StartTime,
            EndTime = @EndTime,
            Location = @Location,
            Type = @Type,
            Status = @Status,
            Priority = @Priority,
            Notes = @Notes,
            ReminderSet = @ReminderSet,
            ModifiedDate = GETUTCDATE()
        WHERE AppointmentId = @AppointmentId;
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'appointment_updated', 'appointment', @AppointmentId, 'Appointment "' + @Title + '" updated');
    END
    
    SELECT @AppointmentId AS AppointmentId;
END;
GO
EXEC sp_helpconstraint 'Appointments';
go
SELECT 
    con.name AS ConstraintName,
    con.definition
FROM sys.check_constraints con
INNER JOIN sys.objects obj ON con.parent_object_id = obj.object_id
WHERE obj.name = 'Appointments';
go
-- Get Appointments with Filters
CREATE OR ALTER PROCEDURE sp_GetAppointments
    @AgentId UNIQUEIDENTIFIER,
    @DateRangeFilter NVARCHAR(20) = 'all', -- 'all', 'today', 'week', 'month'
    @StatusFilter NVARCHAR(20) = 'all',
    @TypeFilter NVARCHAR(50) = 'all',
    @SearchTerm NVARCHAR(100) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FilterStartDate DATE;
    DECLARE @FilterEndDate DATE;
    
    -- Calculate date range filters
    IF @DateRangeFilter = 'today'
    BEGIN
        SET @FilterStartDate = CAST(GETDATE() AS DATE);
        SET @FilterEndDate = CAST(GETDATE() AS DATE);
    END
    ELSE IF @DateRangeFilter = 'week'
    BEGIN
        SET @FilterStartDate = DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
        SET @FilterEndDate = DATEADD(DAY, 6, @FilterStartDate);
    END
    ELSE IF @DateRangeFilter = 'month'
    BEGIN
        SET @FilterStartDate = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
        SET @FilterEndDate = EOMONTH(GETDATE());
    END
    ELSE
    BEGIN
        SET @FilterStartDate = ISNULL(@StartDate, '1900-01-01');
        SET @FilterEndDate = ISNULL(@EndDate, '2100-12-31');
    END
    
    SELECT 
        a.*,
        c.FirstName + ' ' + c.Surname AS ComputedClientName,
        c.Email AS ClientEmail,
        c.InsuranceType
    FROM Appointments a
    LEFT JOIN Clients c ON a.ClientId = c.ClientId
    WHERE 
        a.AgentId = @AgentId 
        AND a.IsActive = 1
        AND a.AppointmentDate BETWEEN @FilterStartDate AND @FilterEndDate
        AND (@StatusFilter = 'all' OR a.Status = @StatusFilter)
        AND (@TypeFilter = 'all' OR a.Type = @TypeFilter)
        AND (@SearchTerm IS NULL OR 
             a.ClientName LIKE '%' + @SearchTerm + '%' OR
             a.Title LIKE '%' + @SearchTerm + '%')
    ORDER BY a.AppointmentDate DESC, a.StartTime DESC;
END;
GO

-- Get Today's Appointments
CREATE OR ALTER PROCEDURE sp_GetTodayAppointments
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        AppointmentId,
        ClientId,
        ClientName,
        Title,
        AppointmentDate,
        StartTime,
        EndTime,
        Location,
        Type,
        Status,
        Priority,
        Notes,
        CONVERT(VARCHAR(5), StartTime, 108) + ' - ' + CONVERT(VARCHAR(5), EndTime, 108) AS TimeRange
    FROM Appointments
    WHERE 
        AgentId = @AgentId 
        AND IsActive = 1
        AND AppointmentDate = CAST(GETDATE() AS DATE)
        AND Status NOT IN ('Cancelled')
    ORDER BY StartTime;
END;
GO

-- Get Week View Data
CREATE OR ALTER PROCEDURE sp_GetWeekViewAppointments
    @AgentId UNIQUEIDENTIFIER,
    @WeekStartDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current week if no date provided
    IF @WeekStartDate IS NULL
        SET @WeekStartDate = DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), CAST(GETDATE() AS DATE));
    
    DECLARE @WeekEndDate DATE = DATEADD(DAY, 6, @WeekStartDate);
    
    SELECT 
        AppointmentId,
        ClientId,
        ClientName,
        Title,
        AppointmentDate,
        StartTime,
        EndTime,
        Location,
        Type,
        Status,
        Priority,
        DATENAME(WEEKDAY, AppointmentDate) AS DayName,
        DAY(AppointmentDate) AS DayNumber
    FROM Appointments
    WHERE 
        AgentId = @AgentId 
        AND IsActive = 1
        AND AppointmentDate BETWEEN @WeekStartDate AND @WeekEndDate
        AND Status NOT IN ('Cancelled')
    ORDER BY AppointmentDate, StartTime;
END;
GO

-- Get Calendar View Data
CREATE OR ALTER PROCEDURE sp_GetCalendarAppointments
    @AgentId UNIQUEIDENTIFIER,
    @Month INT,
    @Year INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @EndDate DATE = EOMONTH(@StartDate);
    
    SELECT 
        AppointmentId,
        ClientId,
        ClientName,
        Title,
        AppointmentDate,
        StartTime,
        Type,
        Status,
        Priority,
        DAY(AppointmentDate) AS DayNumber,
        COUNT(*) OVER (PARTITION BY AppointmentDate) AS AppointmentsOnDay
    FROM Appointments
    WHERE 
        AgentId = @AgentId 
        AND IsActive = 1
        AND AppointmentDate BETWEEN @StartDate AND @EndDate
        AND Status NOT IN ('Cancelled')
    ORDER BY AppointmentDate, StartTime;
END;
GO

-- Update Appointment Status
CREATE OR ALTER PROCEDURE sp_UpdateAppointmentStatus
    @AppointmentId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Title NVARCHAR(200);
    DECLARE @ClientName NVARCHAR(150);
    
    -- Get appointment details for logging
    SELECT @Title = Title, @ClientName = ClientName
    FROM Appointments 
    WHERE AppointmentId = @AppointmentId;
    
    UPDATE Appointments 
    SET Status = @Status, ModifiedDate = GETUTCDATE()
    WHERE AppointmentId = @AppointmentId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'appointment_status_changed', 'appointment', @AppointmentId, 
            'Appointment "' + @Title + '" status changed to ' + @Status);
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Appointment
CREATE OR ALTER PROCEDURE sp_DeleteAppointment
    @AppointmentId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Title NVARCHAR(200);
    DECLARE @ClientName NVARCHAR(150);
    
    -- Get appointment details for logging
    SELECT @Title = Title, @ClientName = ClientName
    FROM Appointments 
    WHERE AppointmentId = @AppointmentId;
    
    -- Soft delete
    UPDATE Appointments 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE AppointmentId = @AppointmentId AND AgentId = @AgentId;
    
    -- Also delete related reminders
    UPDATE Reminders 
    SET Status = 'Cancelled'
    WHERE AppointmentId = @AppointmentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'appointment_deleted', 'appointment', @AppointmentId, 
            'Appointment "' + @Title + '" deleted');
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Appointment Statistics
CREATE OR ALTER PROCEDURE sp_GetAppointmentStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @WeekStart DATE = DATEADD(DAY, 1-DATEPART(WEEKDAY, @Today), @Today);
    DECLARE @WeekEnd DATE = DATEADD(DAY, 6, @WeekStart);
    DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
    DECLARE @MonthEnd DATE = EOMONTH(@Today);
    
    SELECT 
        COUNT(CASE WHEN AppointmentDate = @Today THEN 1 END) AS TodayAppointments,
        COUNT(CASE WHEN AppointmentDate BETWEEN @WeekStart AND @WeekEnd THEN 1 END) AS WeekAppointments,
        COUNT(CASE WHEN AppointmentDate BETWEEN @MonthStart AND @MonthEnd THEN 1 END) AS MonthAppointments,
        COUNT(CASE WHEN Status = 'Completed' THEN 1 END) AS CompletedAppointments,
        COUNT(CASE WHEN Status = 'Scheduled' OR Status = 'Confirmed' THEN 1 END) AS UpcomingAppointments,
        COUNT(CASE WHEN Status = 'Cancelled' THEN 1 END) AS CancelledAppointments
    FROM Appointments
    WHERE AgentId = @AgentId AND IsActive = 1;
END;
GO

-- ============================================
-- Missing Appointment Service Stored Procedures
-- ============================================

-- Get All Appointments with Filters
CREATE OR ALTER PROCEDURE sp_GetAllAppointments
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @Status NVARCHAR(20) = NULL,
    @Type NVARCHAR(50) = NULL,
    @Priority NVARCHAR(10) = NULL,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @SearchTerm NVARCHAR(200) = NULL,
    @PageSize INT = 50,
    @PageNumber INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT 
        a.AppointmentId,
        a.ClientId,
        a.ClientName,
        a.ClientPhone,
        a.Title,
        a.Description,
        a.AppointmentDate,
        a.StartTime,
        a.EndTime,
        a.Location,
        a.Type,
        a.Status,
        a.Priority,
        a.Notes,
        a.ReminderSet,
        a.CreatedDate,
        a.ModifiedDate,
        c.Email AS ClientEmail,
        c.Address AS ClientAddress
    FROM Appointments a
    LEFT JOIN Clients c ON a.ClientId = c.ClientId
    WHERE a.AgentId = @AgentId 
        AND a.IsActive = 1
        AND (@StartDate IS NULL OR a.AppointmentDate >= @StartDate)
        AND (@EndDate IS NULL OR a.AppointmentDate <= @EndDate)
        AND (@Status IS NULL OR a.Status = @Status)
        AND (@Type IS NULL OR a.Type = @Type)
        AND (@Priority IS NULL OR a.Priority = @Priority)
        AND (@ClientId IS NULL OR a.ClientId = @ClientId)
        AND (@SearchTerm IS NULL OR 
             a.ClientName LIKE '%' + @SearchTerm + '%' OR 
             a.Title LIKE '%' + @SearchTerm + '%' OR
             a.Description LIKE '%' + @SearchTerm + '%' OR
             a.Location LIKE '%' + @SearchTerm + '%')
    ORDER BY a.AppointmentDate DESC, a.StartTime DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
    -- Return total count
    SELECT COUNT(*) AS TotalRecords
    FROM Appointments a
    WHERE a.AgentId = @AgentId 
        AND a.IsActive = 1
        AND (@StartDate IS NULL OR a.AppointmentDate >= @StartDate)
        AND (@EndDate IS NULL OR a.AppointmentDate <= @EndDate)
        AND (@Status IS NULL OR a.Status = @Status)
        AND (@Type IS NULL OR a.Type = @Type)
        AND (@Priority IS NULL OR a.Priority = @Priority)
        AND (@ClientId IS NULL OR a.ClientId = @ClientId)
        AND (@SearchTerm IS NULL OR 
             a.ClientName LIKE '%' + @SearchTerm + '%' OR 
             a.Title LIKE '%' + @SearchTerm + '%' OR
             a.Description LIKE '%' + @SearchTerm + '%' OR
             a.Location LIKE '%' + @SearchTerm + '%');
END;
GO

-- Get Appointment By ID
CREATE OR ALTER PROCEDURE sp_GetAppointmentById
    @AppointmentId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        a.AppointmentId,
        a.ClientId,
        a.ClientName,
        a.ClientPhone,
        a.Title,
        a.Description,
        a.AppointmentDate,
        a.StartTime,
        a.EndTime,
        a.Location,
        a.Type,
        a.Status,
        a.Priority,
        a.Notes,
        a.ReminderSet,
        a.CreatedDate,
        a.ModifiedDate,
        c.Email AS ClientEmail,
        c.Address AS ClientAddress,
        c.FirstName,
        c.Surname,
        c.LastName
    FROM Appointments a
    LEFT JOIN Clients c ON a.ClientId = c.ClientId
    WHERE a.AppointmentId = @AppointmentId 
        AND a.AgentId = @AgentId 
        AND a.IsActive = 1;
END;
GO

-- Create Appointment
CREATE OR ALTER PROCEDURE sp_CreateAppointment
    @AgentId UNIQUEIDENTIFIER,
    @ClientId UNIQUEIDENTIFIER,
    @Title NVARCHAR(200),
    @Description NVARCHAR(MAX) = NULL,
    @AppointmentDate DATE,
    @StartTime TIME,
    @EndTime TIME,
    @Location NVARCHAR(200) = NULL,
    @Type NVARCHAR(50),
    @Status NVARCHAR(20) = 'Scheduled',   -- ✅ allow status from backend
    @Priority NVARCHAR(10) = 'Medium',
    @Notes NVARCHAR(MAX) = NULL,
    @ReminderSet BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @AppointmentId UNIQUEIDENTIFIER = NEWID();
    DECLARE @ClientName NVARCHAR(150);
    DECLARE @ClientPhone NVARCHAR(20);
    
    -- ✅ Validate time range
    IF @EndTime <= @StartTime
    BEGIN
        SELECT 0 AS Success, 'End time must be after start time' AS Message;
        RETURN;
    END

    -- ✅ Get client details
    SELECT 
        @ClientName = FirstName + ' ' + Surname,
        @ClientPhone = PhoneNumber
    FROM Clients 
    WHERE ClientId = @ClientId 
      AND AgentId = @AgentId 
      AND IsActive = 1;
    
    IF @ClientName IS NULL
    BEGIN
        SELECT 0 AS Success, 'Client not found' AS Message;
        RETURN;
    END
    
    -- ✅ Improved time conflict check
    -- Detects any overlapping interval properly
    IF EXISTS (
        SELECT 1 
        FROM Appointments 
        WHERE AgentId = @AgentId 
          AND AppointmentDate = @AppointmentDate
          AND IsActive = 1
          AND Status NOT IN ('Cancelled')
          AND (
              -- Overlap if one starts before the other ends AND ends after the other starts
              (@StartTime < EndTime AND @EndTime > StartTime)
          )
    )
    BEGIN
        SELECT 0 AS Success, 'Time conflict with existing appointment' AS Message;
        RETURN;
    END
    
    -- ✅ Insert new appointment
    INSERT INTO Appointments (
        AppointmentId, ClientId, AgentId, ClientName, ClientPhone,
        Title, Description, AppointmentDate, StartTime, EndTime,
        Location, Type, Status, Priority, Notes, ReminderSet
    )
    VALUES (
        @AppointmentId, @ClientId, @AgentId, @ClientName, @ClientPhone,
        @Title, @Description, @AppointmentDate, @StartTime, @EndTime,
        @Location, @Type, @Status, @Priority, @Notes, @ReminderSet
    );
    
    SELECT 1 AS Success, 'Appointment created successfully' AS Message, @AppointmentId AS AppointmentId;
END;
GO

-- Update Appointment
CREATE OR ALTER PROCEDURE sp_UpdateAppointment
    @AppointmentId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @Title NVARCHAR(200) = NULL,
    @Description NVARCHAR(MAX) = NULL,
    @AppointmentDate DATE = NULL,
    @StartTime TIME = NULL,
    @EndTime TIME = NULL,
    @Location NVARCHAR(200) = NULL,
    @Type NVARCHAR(50) = NULL,
    @Priority NVARCHAR(10) = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @ReminderSet BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if appointment exists
    IF NOT EXISTS (SELECT 1 FROM Appointments WHERE AppointmentId = @AppointmentId AND AgentId = @AgentId AND IsActive = 1)
    BEGIN
        SELECT 0 AS Success, 'Appointment not found' AS Message;
        RETURN;
    END
    
    -- If updating date/time, check for conflicts
    IF @AppointmentDate IS NOT NULL AND @StartTime IS NOT NULL AND @EndTime IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1 FROM Appointments 
            WHERE AgentId = @AgentId 
                AND AppointmentId <> @AppointmentId
                AND AppointmentDate = @AppointmentDate
                AND IsActive = 1
                AND Status NOT IN ('Cancelled')
                AND (
                    (@StartTime >= StartTime AND @StartTime < EndTime) OR
                    (@EndTime > StartTime AND @EndTime <= EndTime) OR
                    (@StartTime <= StartTime AND @EndTime >= EndTime)
                )
        )
        BEGIN
            SELECT 0 AS Success, 'Time conflict with existing appointment' AS Message;
            RETURN;
        END
    END
    
    UPDATE Appointments 
    SET 
        Title = ISNULL(@Title, Title),
        Description = ISNULL(@Description, Description),
        AppointmentDate = ISNULL(@AppointmentDate, AppointmentDate),
        StartTime = ISNULL(@StartTime, StartTime),
        EndTime = ISNULL(@EndTime, EndTime),
        Location = ISNULL(@Location, Location),
        Type = ISNULL(@Type, Type),
        Priority = ISNULL(@Priority, Priority),
        Notes = ISNULL(@Notes, Notes),
        ReminderSet = ISNULL(@ReminderSet, ReminderSet),
        ModifiedDate = GETUTCDATE()
    WHERE AppointmentId = @AppointmentId AND AgentId = @AgentId;
    
    SELECT 1 AS Success, 'Appointment updated successfully' AS Message;
END;
GO

-- Get Appointments for Specific Date
CREATE OR ALTER PROCEDURE sp_GetAppointmentsForDate
    @AgentId UNIQUEIDENTIFIER,
    @AppointmentDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        a.AppointmentId,
        a.ClientId,
        a.ClientName,
        a.ClientPhone,
        a.Title,
        a.Description,
        a.StartTime,
        a.EndTime,
        a.Location,
        a.Type,
        a.Status,
        a.Priority,
        a.Notes,
        a.ReminderSet
    FROM Appointments a
    WHERE a.AgentId = @AgentId 
        AND a.AppointmentDate = @AppointmentDate
        AND a.IsActive = 1
        AND a.Status NOT IN ('Cancelled')
    ORDER BY a.StartTime;
END;
GO

-- Search Appointments
CREATE OR ALTER PROCEDURE sp_SearchAppointments
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        a.AppointmentId,
        a.ClientId,
        a.ClientName,
        a.ClientPhone,
        a.Title,
        a.Description,
        a.AppointmentDate,
        a.StartTime,
        a.EndTime,
        a.Location,
        a.Type,
        a.Status,
        a.Priority,
        a.Notes,
        a.CreatedDate
    FROM Appointments a
    WHERE a.AgentId = @AgentId 
        AND a.IsActive = 1
        AND (
            a.ClientName LIKE '%' + @SearchTerm + '%' OR 
            a.Title LIKE '%' + @SearchTerm + '%' OR
            a.Description LIKE '%' + @SearchTerm + '%' OR
            a.Location LIKE '%' + @SearchTerm + '%' OR
            a.Type LIKE '%' + @SearchTerm + '%'
        )
    ORDER BY a.AppointmentDate DESC, a.StartTime DESC;
END;
GO
CREATE OR ALTER PROCEDURE sp_CheckTimeConflicts
    @AgentId UNIQUEIDENTIFIER,
    @AppointmentDate DATE,
    @StartTime TIME,
    @EndTime TIME,
    @ExcludeAppointmentId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ConflictCount INT;

    SELECT @ConflictCount = COUNT(*)
    FROM Appointments
    WHERE AgentId = @AgentId   -- ✅ restrict to same agent
      AND AppointmentDate = @AppointmentDate
      AND IsActive = 1
      AND Status NOT IN ('Cancelled')
      AND (@ExcludeAppointmentId IS NULL OR AppointmentId <> @ExcludeAppointmentId)
      AND (
            -- real overlap check (simpler form)
            NOT (@EndTime <= StartTime OR @StartTime >= EndTime)
          );

    SELECT 
        CASE WHEN @ConflictCount > 0 THEN 1 ELSE 0 END AS HasConflict,
        @ConflictCount AS ConflictCount;
END;
GO


-- ============================================
-- Missing Reminder Service Stored Procedures
-- ============================================

-- Get All Reminders with Filters
CREATE OR ALTER PROCEDURE sp_GetAllReminders
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @ReminderType NVARCHAR(50) = NULL,
    @Status NVARCHAR(20) = NULL,
    @Priority NVARCHAR(10) = NULL,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @SearchTerm NVARCHAR(200) = NULL,
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
    WHERE r.AgentId = @AgentId 
        AND (@StartDate IS NULL OR r.ReminderDate >= @StartDate)
        AND (@EndDate IS NULL OR r.ReminderDate <= @EndDate)
        AND (@ReminderType IS NULL OR r.ReminderType = @ReminderType)
        AND (@Status IS NULL OR r.Status = @Status)
        AND (@Priority IS NULL OR r.Priority = @Priority)
        AND (@ClientId IS NULL OR r.ClientId = @ClientId)
        AND (@SearchTerm IS NULL OR 
             r.ClientName LIKE '%' + @SearchTerm + '%' OR 
             r.Title LIKE '%' + @SearchTerm + '%' OR
             r.Description LIKE '%' + @SearchTerm + '%' OR
             r.Notes LIKE '%' + @SearchTerm + '%')
    ORDER BY r.ReminderDate DESC, r.ReminderTime DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
    -- Return total count
    SELECT COUNT(*) AS TotalRecords
    FROM Reminders r
    WHERE r.AgentId = @AgentId 
        AND (@StartDate IS NULL OR r.ReminderDate >= @StartDate)
        AND (@EndDate IS NULL OR r.ReminderDate <= @EndDate)
        AND (@ReminderType IS NULL OR r.ReminderType = @ReminderType)
        AND (@Status IS NULL OR r.Status = @Status)
        AND (@Priority IS NULL OR r.Priority = @Priority)
        AND (@ClientId IS NULL OR r.ClientId = @ClientId)
        AND (@SearchTerm IS NULL OR 
             r.ClientName LIKE '%' + @SearchTerm + '%' OR 
             r.Title LIKE '%' + @SearchTerm + '%' OR
             r.Description LIKE '%' + @SearchTerm + '%' OR
             r.Notes LIKE '%' + @SearchTerm + '%');
END;
GO

-- Get Reminder By ID
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
        c.FirstName,
        c.Surname,
        c.LastName
    FROM Reminders r
    LEFT JOIN Clients c ON r.ClientId = c.ClientId
    WHERE r.ReminderId = @ReminderId 
        AND r.AgentId = @AgentId;
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
    DECLARE @ClientName NVARCHAR(150);
    
    -- Get client name if ClientId is provided
    IF @ClientId IS NOT NULL
    BEGIN
        SELECT @ClientName = FirstName + ' ' + Surname
        FROM Clients 
        WHERE ClientId = @ClientId AND AgentId = @AgentId AND IsActive = 1;
    END
    
    INSERT INTO Reminders (
        ReminderId, ClientId, AppointmentId, AgentId, ReminderType,
        Title, Description, ReminderDate, ReminderTime, ClientName,
        Priority, Status, EnableSMS, EnableWhatsApp, EnablePushNotification,
        AdvanceNotice, CustomMessage, AutoSend, Notes
    )
    VALUES (
        @ReminderId, @ClientId, @AppointmentId, @AgentId, @ReminderType,
        @Title, @Description, @ReminderDate, @ReminderTime, @ClientName,
        @Priority, 'Active', @EnableSMS, @EnableWhatsApp, @EnablePushNotification,
        @AdvanceNotice, @CustomMessage, @AutoSend, @Notes
    );
    
    SELECT 1 AS Success, 'Reminder created successfully' AS Message, @ReminderId AS ReminderId;
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
    
    -- Check if reminder exists
    IF NOT EXISTS (SELECT 1 FROM Reminders WHERE ReminderId = @ReminderId AND AgentId = @AgentId)
    BEGIN
        SELECT 0 AS Success, 'Reminder not found' AS Message;
        RETURN;
    END
    
    UPDATE Reminders 
    SET 
        Title = ISNULL(@Title, Title),
        Description = ISNULL(@Description, Description),
        ReminderDate = ISNULL(@ReminderDate, ReminderDate),
        ReminderTime = ISNULL(@ReminderTime, ReminderTime),
        Priority = ISNULL(@Priority, Priority),
        EnableSMS = ISNULL(@EnableSMS, EnableSMS),
        EnableWhatsApp = ISNULL(@EnableWhatsApp, EnableWhatsApp),
        EnablePushNotification = ISNULL(@EnablePushNotification, EnablePushNotification),
        AdvanceNotice = ISNULL(@AdvanceNotice, AdvanceNotice),
        CustomMessage = ISNULL(@CustomMessage, CustomMessage),
        AutoSend = ISNULL(@AutoSend, AutoSend),
        Notes = ISNULL(@Notes, Notes),
        ModifiedDate = GETUTCDATE()
    WHERE ReminderId = @ReminderId AND AgentId = @AgentId;
    
    SELECT 1 AS Success, 'Reminder updated successfully' AS Message;
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
    WHERE r.AgentId = @AgentId 
        AND r.Status = 'Active'
        AND r.ReminderDate BETWEEN CAST(GETDATE() AS DATE) AND @EndDate
    ORDER BY r.ReminderDate, r.ReminderTime;
END;
GO

-- Get Completed Reminders
CREATE OR ALTER PROCEDURE sp_GetCompletedReminders
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(DAY, -30, GETDATE()); -- Last 30 days default
    
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
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
    WHERE r.AgentId = @AgentId 
        AND r.Status = 'Completed'
        AND r.CompletedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)
    ORDER BY r.CompletedDate DESC;
END;
GO

-- Update Reminder Setting
CREATE OR ALTER PROCEDURE sp_UpdateReminderSetting
    @AgentId UNIQUEIDENTIFIER,
    @ReminderType NVARCHAR(50),
    @IsEnabled BIT = NULL,
    @DaysBefore INT = NULL,
    @TimeOfDay TIME = NULL,
    @RepeatDaily BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM ReminderSettings WHERE AgentId = @AgentId AND ReminderType = @ReminderType)
    BEGIN
        UPDATE ReminderSettings 
        SET 
            IsEnabled = ISNULL(@IsEnabled, IsEnabled),
            DaysBefore = ISNULL(@DaysBefore, DaysBefore),
            TimeOfDay = ISNULL(@TimeOfDay, TimeOfDay),
            RepeatDaily = ISNULL(@RepeatDaily, RepeatDaily),
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND ReminderType = @ReminderType;
    END
    ELSE
    BEGIN
        INSERT INTO ReminderSettings (
            AgentId, ReminderType, IsEnabled, DaysBefore, TimeOfDay, RepeatDaily
        )
        VALUES (
            @AgentId, @ReminderType, ISNULL(@IsEnabled, 1), ISNULL(@DaysBefore, 1), 
            ISNULL(@TimeOfDay, '09:00'), ISNULL(@RepeatDaily, 0)
        );
    END
    
    SELECT 1 AS Success, 'Reminder setting updated successfully' AS Message;
END;
GO-- ============================================
-- Create or Update Client (Trigger manages InsuranceType)
-- ============================================
CREATE OR ALTER PROCEDURE sp_UpsertClient
    @ClientId UNIQUEIDENTIFIER = NULL,
    @AgentId UNIQUEIDENTIFIER,
    @FirstName NVARCHAR(50),
    @Surname NVARCHAR(50),
    @LastName NVARCHAR(50),
    @PhoneNumber NVARCHAR(20),
    @Email NVARCHAR(100),
    @Address NVARCHAR(500),
    @NationalId NVARCHAR(20),
    @DateOfBirth DATE,
    @IsClient BIT,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ClientId IS NULL
    BEGIN
        -- Create new client
        SET @ClientId = NEWID();
        
        INSERT INTO Clients (
            ClientId, AgentId, FirstName, Surname, LastName, PhoneNumber, 
            Email, Address, NationalId, DateOfBirth, IsClient, Notes
        )
        VALUES (
            @ClientId, @AgentId, @FirstName, @Surname, @LastName, @PhoneNumber,
            @Email, @Address, @NationalId, @DateOfBirth, @IsClient, @Notes
        );
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'client_created', 'client', @ClientId, 
                @FirstName + ' ' + @Surname + ' added as ' + CASE WHEN @IsClient = 1 THEN 'client' ELSE 'prospect' END);
    END
    ELSE
    BEGIN
        -- Update existing client
        UPDATE Clients 
        SET 
            FirstName = @FirstName,
            Surname = @Surname,
            LastName = @LastName,
            PhoneNumber = @PhoneNumber,
            Email = @Email,
            Address = @Address,
            NationalId = @NationalId,
            DateOfBirth = @DateOfBirth,
            IsClient = @IsClient,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE ClientId = @ClientId;
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'client_updated', 'client', @ClientId, @FirstName + ' ' + @Surname + ' updated');
    END
    
    SELECT @ClientId AS ClientId;
END;
GO


CREATE OR ALTER PROCEDURE sp_GetClients
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(100) = NULL,
    @FilterType NVARCHAR(20) = 'all', -- 'all', 'clients', 'prospects'
    @InsuranceType NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.NationalId,
        c.DateOfBirth,
        c.IsClient,
        c.InsuranceType,   -- ✅ always reliable now (trigger keeps it synced)
        c.Notes,
        c.CreatedDate,
        c.ModifiedDate,

        -- Policy Info from related tables
        cp.PolicyId,
        cp.PolicyName,
        pt.TypeName AS PolicyType,
        ic.CompanyName AS PolicyCompany,
        cp.Status AS PolicyStatus,
        cp.StartDate AS PolicyStartDate,
        cp.EndDate AS PolicyEndDate,
        cp.Notes AS PolicyNotes
    FROM Clients c
    LEFT JOIN ClientPolicies cp 
        ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    LEFT JOIN PolicyCatalog pc
        ON cp.PolicyCatalogId = pc.PolicyCatalogId
    LEFT JOIN PolicyTypes pt
        ON pc.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompanies ic
        ON pc.CompanyId = ic.CompanyId
    WHERE 
        c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND (
            @SearchTerm IS NULL OR 
            c.FirstName LIKE '%' + @SearchTerm + '%' OR
            c.Surname LIKE '%' + @SearchTerm + '%' OR
            c.LastName LIKE '%' + @SearchTerm + '%' OR
            c.PhoneNumber LIKE '%' + @SearchTerm + '%' OR
            c.Email LIKE '%' + @SearchTerm + '%'
        )
        AND (
            @FilterType = 'all' OR 
            (@FilterType = 'clients' AND c.IsClient = 1) OR
            (@FilterType = 'prospects' AND c.IsClient = 0)
        )
        AND (@InsuranceType IS NULL OR c.InsuranceType = @InsuranceType)
    ORDER BY c.FirstName, c.Surname;
END;
GO
CREATE OR ALTER PROCEDURE sp_GetClient
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Main client details with linked policy info
    SELECT 
        c.*,
        cp.PolicyId,
        cp.PolicyName,
        pt.TypeName AS PolicyType,
        ic.CompanyName AS PolicyCompany,
        cp.Status AS PolicyStatus,
        cp.StartDate AS PolicyStartDate,
        cp.EndDate AS PolicyEndDate,
        cp.Notes AS PolicyNotes
    FROM Clients c
    LEFT JOIN ClientPolicies cp 
        ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    LEFT JOIN PolicyCatalog pc 
        ON cp.PolicyCatalogId = pc.PolicyCatalogId
    LEFT JOIN PolicyTypes pt 
        ON pc.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompanies ic 
        ON pc.CompanyId = ic.CompanyId
    WHERE 
        c.ClientId = @ClientId 
        AND c.AgentId = @AgentId 
        AND c.IsActive = 1;
    
    -- Appointments for the client
    SELECT 
        AppointmentId,
        Title,
        AppointmentDate,
        StartTime,
        EndTime,
        Type,
        Status,
        Location
    FROM Appointments
    WHERE 
        ClientId = @ClientId 
        AND AgentId = @AgentId 
        AND IsActive = 1
    ORDER BY AppointmentDate DESC, StartTime DESC;
END;
GO

-- Delete Client
CREATE OR ALTER PROCEDURE sp_DeleteClient
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ClientName NVARCHAR(150);
    
    -- Get client name for logging
    SELECT @ClientName = FirstName + ' ' + Surname FROM Clients WHERE ClientId = @ClientId;
    
    -- Soft delete - set IsActive to 0
    UPDATE Clients 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE ClientId = @ClientId AND AgentId = @AgentId;
    
    -- Also soft delete related appointments
    UPDATE Appointments 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE ClientId = @ClientId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'client_deleted', 'client', @ClientId, @ClientName + ' deleted');
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Client Statistics
CREATE OR ALTER PROCEDURE sp_GetClientStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        COUNT(*) AS TotalContacts,
        SUM(CASE WHEN IsClient = 1 THEN 1 ELSE 0 END) AS TotalClients,
        SUM(CASE WHEN IsClient = 0 THEN 1 ELSE 0 END) AS TotalProspects,
        COUNT(CASE WHEN DAY(DateOfBirth) = DAY(GETDATE()) AND MONTH(DateOfBirth) = MONTH(GETDATE()) THEN 1 END) AS TodayBirthdays
    FROM Clients
    WHERE AgentId = @AgentId AND IsActive = 1;
END;
GO

-- Get Today's Birthdays
CREATE OR ALTER PROCEDURE sp_GetTodayBirthdays
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ClientId,
        FirstName,
        Surname,
        LastName,
        PhoneNumber,
        Email,
        InsuranceType,
        DateOfBirth,
        DATEDIFF(YEAR, DateOfBirth, GETDATE()) AS Age
    FROM Clients
    WHERE 
        AgentId = @AgentId 
        AND IsActive = 1
        AND DAY(DateOfBirth) = DAY(GETDATE())
        AND MONTH(DateOfBirth) = MONTH(GETDATE())
    ORDER BY FirstName, Surname;
END;
GO

-- 1. Get All Clients with Advanced Filters
CREATE OR ALTER PROCEDURE sp_GetAllClients
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(100) = NULL,
    @InsuranceType NVARCHAR(50) = NULL,
    @IsClient BIT = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.NationalId,
        c.DateOfBirth,
        DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) as Age,
        c.IsClient,
        c.InsuranceType,
        c.Notes,
        c.CreatedDate,
        c.ModifiedDate,
        COUNT(cp.PolicyId) as PolicyCount,
        MAX(cp.EndDate) as NextExpiryDate
    FROM Clients c
    LEFT JOIN ClientPolicies cp ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    WHERE 
        c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND (@SearchTerm IS NULL OR 
             c.FirstName LIKE '%' + @SearchTerm + '%' OR 
             c.Surname LIKE '%' + @SearchTerm + '%' OR
             c.LastName LIKE '%' + @SearchTerm + '%' OR
             c.PhoneNumber LIKE '%' + @SearchTerm + '%' OR
             c.Email LIKE '%' + @SearchTerm + '%')
        AND (@InsuranceType IS NULL OR c.InsuranceType = @InsuranceType)
        AND (@IsClient IS NULL OR c.IsClient = @IsClient)
    GROUP BY 
        c.ClientId, c.FirstName, c.Surname, c.LastName, c.PhoneNumber,
        c.Email, c.Address, c.NationalId, c.DateOfBirth, c.IsClient,
        c.InsuranceType, c.Notes, c.CreatedDate, c.ModifiedDate
    ORDER BY c.CreatedDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- 2. Search Clients
CREATE OR ALTER PROCEDURE sp_SearchClients
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.IsClient,
        c.InsuranceType,
        DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) as Age
    FROM Clients c
    WHERE 
        c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND (
            c.FirstName LIKE '%' + @SearchTerm + '%' OR 
            c.Surname LIKE '%' + @SearchTerm + '%' OR
            c.LastName LIKE '%' + @SearchTerm + '%' OR
            c.PhoneNumber LIKE '%' + @SearchTerm + '%' OR
            c.Email LIKE '%' + @SearchTerm + '%' OR
            c.NationalId LIKE '%' + @SearchTerm + '%'
        )
    ORDER BY c.FirstName, c.Surname;
END;
GO

-- 3. Get Clients by Insurance Type
CREATE OR ALTER PROCEDURE sp_GetClientsByInsuranceType
    @AgentId UNIQUEIDENTIFIER,
    @InsuranceType NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.DateOfBirth,
        DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) as Age,
        c.IsClient,
        c.InsuranceType,
        c.CreatedDate,
        COUNT(cp.PolicyId) as PolicyCount
    FROM Clients c
    LEFT JOIN ClientPolicies cp ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    WHERE 
        c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND c.InsuranceType = @InsuranceType
    GROUP BY 
        c.ClientId, c.FirstName, c.Surname, c.LastName, c.PhoneNumber,
        c.Email, c.Address, c.DateOfBirth, c.IsClient, c.InsuranceType, c.CreatedDate
    ORDER BY c.FirstName, c.Surname;
END;
GO

-- 4. Get Client with Full Details (including policies)
CREATE OR ALTER PROCEDURE sp_GetClientWithPolicies
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Client details
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.NationalId,
        c.DateOfBirth,
        DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) as Age,
        c.IsClient,
        c.InsuranceType,
        c.Notes,
        c.CreatedDate,
        c.ModifiedDate
    FROM Clients c
    WHERE c.ClientId = @ClientId AND c.AgentId = @AgentId AND c.IsActive = 1;
    
    -- Client policies
    SELECT 
        cp.PolicyId,
        cp.PolicyName,
        cp.PolicyType,
        cp.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysToExpiry,
        cp.Notes,
        cp.CreatedDate
    FROM ClientPolicies cp
    WHERE cp.ClientId = @ClientId AND cp.IsActive = 1
    ORDER BY cp.EndDate DESC;
    
    -- Recent appointments
    SELECT TOP 5
        a.AppointmentId,
        a.Title,
        a.AppointmentDate,
        a.StartTime,
        a.Type,
        a.Status
    FROM Appointments a
    WHERE a.ClientId = @ClientId AND a.IsActive = 1
    ORDER BY a.AppointmentDate DESC, a.StartTime DESC;
    
    -- Active reminders
    SELECT 
        r.ReminderId,
        r.Title,
        r.ReminderDate,
        r.ReminderTime,
        r.ReminderType,
        r.Priority,
        r.Status
    FROM Reminders r
    WHERE r.ClientId = @ClientId AND r.Status = 'Active'
    ORDER BY r.ReminderDate, r.ReminderTime;
END;
GO

-- 5. Create New Client
CREATE OR ALTER PROCEDURE sp_CreateClient
    @AgentId UNIQUEIDENTIFIER,
    @FirstName NVARCHAR(50),
    @Surname NVARCHAR(50),
    @LastName NVARCHAR(50),
    @PhoneNumber NVARCHAR(20),
    @Email NVARCHAR(100),
    @Address NVARCHAR(500),
    @NationalId NVARCHAR(20),
    @DateOfBirth DATE,
    @IsClient BIT = 0,
    @InsuranceType NVARCHAR(50),
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ClientId UNIQUEIDENTIFIER = NEWID();
    
    -- Check for duplicate phone or email
    IF EXISTS(SELECT 1 FROM Clients WHERE PhoneNumber = @PhoneNumber AND AgentId = @AgentId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Phone number already exists' as Message,
            NULL as ClientId;
        RETURN;
    END
    
    IF EXISTS(SELECT 1 FROM Clients WHERE Email = @Email AND AgentId = @AgentId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Email already exists' as Message,
            NULL as ClientId;
        RETURN;
    END
    
    BEGIN TRY
        INSERT INTO Clients (
            ClientId, AgentId, FirstName, Surname, LastName, PhoneNumber,
            Email, Address, NationalId, DateOfBirth, IsClient, InsuranceType, Notes
        )
        VALUES (
            @ClientId, @AgentId, @FirstName, @Surname, @LastName, @PhoneNumber,
            @Email, @Address, @NationalId, @DateOfBirth, @IsClient, @InsuranceType, @Notes
        );
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 
            CASE WHEN @IsClient = 1 THEN 'client_added' ELSE 'prospect_added' END,
            'client', 
            @ClientId, 
            'Added new ' + CASE WHEN @IsClient = 1 THEN 'client' ELSE 'prospect' END + ': ' + @FirstName + ' ' + @Surname
        );
        
        SELECT 
            1 as Success,
            CASE WHEN @IsClient = 1 THEN 'Client created successfully' ELSE 'Prospect created successfully' END as Message,
            @ClientId as ClientId;
            
    END TRY
    BEGIN CATCH
        SELECT 
            0 as Success,
            ERROR_MESSAGE() as Message,
            NULL as ClientId;
    END CATCH
END;
GO

-- 6. Update Client
CREATE OR ALTER PROCEDURE sp_UpdateClient
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @FirstName NVARCHAR(50),
    @Surname NVARCHAR(50),
    @LastName NVARCHAR(50),
    @PhoneNumber NVARCHAR(20),
    @Email NVARCHAR(100),
    @Address NVARCHAR(500),
    @NationalId NVARCHAR(20),
    @DateOfBirth DATE,
    @InsuranceType NVARCHAR(50),
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if client exists and belongs to agent
    IF NOT EXISTS(SELECT 1 FROM Clients WHERE ClientId = @ClientId AND AgentId = @AgentId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Client not found' as Message;
        RETURN;
    END
    
    -- Check for duplicate phone or email (excluding current client)
    IF EXISTS(SELECT 1 FROM Clients WHERE PhoneNumber = @PhoneNumber AND AgentId = @AgentId AND ClientId != @ClientId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Phone number already exists for another client' as Message;
        RETURN;
    END
    
    IF EXISTS(SELECT 1 FROM Clients WHERE Email = @Email AND AgentId = @AgentId AND ClientId != @ClientId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Email already exists for another client' as Message;
        RETURN;
    END
    
    BEGIN TRY
        UPDATE Clients 
        SET 
            FirstName = @FirstName,
            Surname = @Surname,
            LastName = @LastName,
            PhoneNumber = @PhoneNumber,
            Email = @Email,
            Address = @Address,
            NationalId = @NationalId,
            DateOfBirth = @DateOfBirth,
            InsuranceType = @InsuranceType,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE ClientId = @ClientId AND AgentId = @AgentId;
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 
            'client_updated',
            'client', 
            @ClientId, 
            'Updated client: ' + @FirstName + ' ' + @Surname
        );
        
        SELECT 
            1 as Success,
            'Client updated successfully' as Message;
            
    END TRY
    BEGIN CATCH
        SELECT 
            0 as Success,
            ERROR_MESSAGE() as Message;
    END CATCH
END;
GO

-- 7. Get Enhanced Client Statistics
CREATE OR ALTER PROCEDURE sp_GetEnhancedClientStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        -- Client counts
        COUNT(CASE WHEN IsClient = 1 THEN 1 END) as TotalClients,
        COUNT(CASE WHEN IsClient = 0 THEN 1 END) as TotalProspects,
        COUNT(*) as TotalContacts,
        
        -- Policy statistics
        (SELECT COUNT(*) FROM ClientPolicies cp 
         INNER JOIN Clients c ON cp.ClientId = c.ClientId 
         WHERE c.AgentId = @AgentId AND cp.IsActive = 1 AND cp.Status = 'Active') as ActivePolicies,
        
        (SELECT COUNT(*) FROM ClientPolicies cp 
         INNER JOIN Clients c ON cp.ClientId = c.ClientId 
         WHERE c.AgentId = @AgentId AND cp.IsActive = 1 
         AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE())) as ExpiringPolicies,
        
        -- Birthday statistics
        COUNT(CASE WHEN MONTH(DateOfBirth) = MONTH(GETDATE()) 
                   AND DAY(DateOfBirth) = DAY(GETDATE()) THEN 1 END) as TodayBirthdays,
        
        COUNT(CASE WHEN MONTH(DateOfBirth) = MONTH(GETDATE()) THEN 1 END) as MonthBirthdays,
        
        -- Recent additions
        COUNT(CASE WHEN CreatedDate >= DATEADD(DAY, -7, GETDATE()) THEN 1 END) as NewThisWeek,
        COUNT(CASE WHEN CreatedDate >= DATEADD(DAY, -30, GETDATE()) THEN 1 END) as NewThisMonth,
        
        -- Insurance type breakdown
        (SELECT 
            InsuranceType,
            COUNT(*) as Count,
            COUNT(CASE WHEN IsClient = 1 THEN 1 END) as ClientCount,
            COUNT(CASE WHEN IsClient = 0 THEN 1 END) as ProspectCount
         FROM Clients 
         WHERE AgentId = @AgentId AND IsActive = 1
         GROUP BY InsuranceType
         FOR JSON PATH) as InsuranceTypeBreakdown
         
    FROM Clients 
    WHERE AgentId = @AgentId AND IsActive = 1;
END;
GO


-- ============================================
-- Updated Stored Procedures for Policy Management
-- Matching the updated table schema with foreign keys
-- ============================================

-- Get Policy Statistics
CREATE OR ALTER PROCEDURE sp_GetPolicyStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        COUNT(CASE WHEN cp.Status = 'Active' THEN 1 END) AS ActivePolicies,
        COUNT(CASE WHEN cp.Status = 'Expired' THEN 1 END) AS ExpiredPolicies,
        COUNT(CASE WHEN cp.Status = 'Lapsed' THEN 1 END) AS LapsedPolicies,
        COUNT(CASE WHEN cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE()) THEN 1 END) AS ExpiringPolicies,
        COUNT(DISTINCT pt.TypeId) AS PolicyTypes,
        COUNT(DISTINCT ic.CompanyId) AS InsuranceCompanies
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE c.AgentId = @AgentId AND cp.IsActive = 1 AND c.IsActive = 1;
END;
GO

-- Create Policy Template
CREATE OR ALTER PROCEDURE sp_CreatePolicyTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(18,2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TemplateId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO PolicyTemplate (
        TemplateId, AgentId, TemplateName, TypeId, CategoryId,
        DefaultTermMonths, DefaultPremium, CoverageDescription, Terms
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @TypeId, @CategoryId,
        @DefaultTermMonths, @DefaultPremium, @CoverageDescription, @Terms
    );
    
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (
        @AgentId, 'policy_template_created', 'policy_template', @TemplateId, 
        'Policy template "' + @TemplateName + '" created'
    );

    SELECT @TemplateId AS TemplateId;
END;
GO

-- Get Policy Templates
CREATE OR ALTER PROCEDURE sp_GetPolicyTemplates
    @AgentId UNIQUEIDENTIFIER,
    @TypeId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pt.TemplateId,
        pt.TemplateName,
        pt.TypeId,
        ptype.TypeName,
        pt.DefaultTermMonths,
        pt.DefaultPremium,
        pt.CoverageDescription,
        pt.Terms,
        pt.CategoryId,
        pc.CategoryName,
        pt.CreatedDate
    FROM PolicyTemplate pt
    LEFT JOIN PolicyType ptype ON pt.TypeId = ptype.TypeId
    LEFT JOIN PolicyCategory pc ON pt.CategoryId = pc.CategoryId
    WHERE 
        pt.AgentId = @AgentId 
        AND pt.IsActive = 1
        AND (@TypeId IS NULL OR pt.TypeId = @TypeId)
    ORDER BY ptype.TypeName, pt.TemplateName;
END;
GO

-- Delete Policy Template
CREATE OR ALTER PROCEDURE sp_DeletePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyTemplate 
    SET IsActive = 0
    WHERE TemplateId = @TemplateId AND AgentId = @AgentId;
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'policy_template_deleted', 'policy_template', @TemplateId, 
            'Policy template deleted'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Policy Catalog for Agent
CREATE OR ALTER PROCEDURE sp_GetPolicyCatalog
    @AgentId UNIQUEIDENTIFIER,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pc.PolicyCatalogId,
        pc.PolicyName,
        pc.TypeId,
        pt.TypeName,
        pc.CompanyId,
        ic.CompanyName,
        pc.CategoryId,
        pcat.CategoryName,
        pc.Notes,
        pc.CreatedDate,
        pc.ModifiedDate
    FROM PolicyCatalog pc
    LEFT JOIN PolicyType pt ON pc.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON pc.CompanyId = ic.CompanyId
    LEFT JOIN PolicyCategory pcat ON pc.CategoryId = pcat.CategoryId
    WHERE 
        pc.AgentId = @AgentId 
        AND pc.IsActive = 1
        AND (@TypeId IS NULL OR pc.TypeId = @TypeId)
        AND (@CompanyId IS NULL OR pc.CompanyId = @CompanyId)
    ORDER BY pt.TypeName, pc.PolicyName;
END;
GO

-- Create Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_CreatePolicyCatalogItem
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyCatalogId UNIQUEIDENTIFIER = NEWID();
    
    -- Validate TypeId exists
    IF NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    INSERT INTO PolicyCatalog (
        PolicyCatalogId, AgentId, PolicyName, TypeId, 
        CompanyId, CategoryId, Notes, IsActive, CreatedDate
    )
    VALUES (
        @PolicyCatalogId, @AgentId, @PolicyName, @TypeId, 
        @CompanyId, @CategoryId, @Notes, 1, GETUTCDATE()
    );
    
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'policy_catalog_created', 'policy_catalog', @PolicyCatalogId, 
            'Policy "' + @PolicyName + '" added to catalog');
    
    SELECT @PolicyCatalogId AS PolicyCatalogId;
END;
GO

-- Update Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_UpdatePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate TypeId if provided
    IF @TypeId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    UPDATE PolicyCatalog 
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        TypeId = ISNULL(@TypeId, TypeId),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        CategoryId = ISNULL(@CategoryId, CategoryId),
        Notes = ISNULL(@Notes, Notes),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId 
      AND AgentId = @AgentId;
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'policy_catalog_updated', 'policy_catalog', @PolicyCatalogId, 
                'Policy catalog item updated');
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Policy from Catalog
CREATE OR ALTER PROCEDURE sp_DeletePolicyCatalog
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyName NVARCHAR(100);
    
    -- Get policy name for logging
    SELECT @PolicyName = PolicyName FROM PolicyCatalog WHERE PolicyCatalogId = @PolicyCatalogId;
    
    -- Soft delete
    UPDATE PolicyCatalog 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'policy_catalog_deleted', 'policy_catalog', @PolicyCatalogId, 
            'Policy "' + @PolicyName + '" removed from catalog');
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Create or Update Client Policy
CREATE OR ALTER PROCEDURE sp_UpsertClientPolicy
    @PolicyId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @Status NVARCHAR(20),
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AgentId UNIQUEIDENTIFIER;

    -- Get agent ID from client
    SELECT @AgentId = AgentId FROM Clients WHERE ClientId = @ClientId;

    -- Validate TypeId
    IF NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END

    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END

    IF @PolicyId IS NULL
    BEGIN
        -- Create new client policy
        SET @PolicyId = NEWID();

        INSERT INTO ClientPolicies (
            PolicyId, ClientId, PolicyName, TypeId, CompanyId, PolicyCatalogId,
            Status, StartDate, EndDate, Notes
        )
        VALUES (
            @PolicyId, @ClientId, @PolicyName, @TypeId, @CompanyId, @PolicyCatalogId,
            @Status, @StartDate, @EndDate, @Notes
        );

        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_created', 'client_policy', @PolicyId, 
            'Policy "' + @PolicyName + '" assigned to client'
        );
    END
    ELSE
    BEGIN
        -- Update existing client policy
        UPDATE ClientPolicies 
        SET 
            PolicyName = @PolicyName,
            TypeId = @TypeId,
            CompanyId = @CompanyId,
            PolicyCatalogId = @PolicyCatalogId,
            Status = @Status,
            StartDate = @StartDate,
            EndDate = @EndDate,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE PolicyId = @PolicyId;

        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_updated', 'client_policy', @PolicyId, 
            'Policy "' + @PolicyName + '" updated for client'
        );
    END

    -- Return the policy ID
    SELECT @PolicyId AS PolicyId;
END;
GO

-- Get Client Policies
CREATE OR ALTER PROCEDURE sp_GetClientPolicies
    @ClientId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyCatalogId,
        cp.PolicyName,
        cp.TypeId,
        pt.TypeName,
        cp.CompanyId,
        ic.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.IsActive,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry,
        c.FirstName + ' ' + c.Surname AS ClientName,
        c.PhoneNumber AS ClientPhone
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        cp.ClientId = @ClientId
        AND cp.IsActive = 1
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@TypeId IS NULL OR cp.TypeId = @TypeId)
    ORDER BY cp.StartDate DESC;
END;
GO

-- Create Client Policy (using PolicyCatalog)
CREATE OR ALTER PROCEDURE sp_CreateClientPolicy
    @ClientId UNIQUEIDENTIFIER,
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PolicyId UNIQUEIDENTIFIER = NEWID();
    DECLARE @PolicyName NVARCHAR(100);
    DECLARE @TypeId UNIQUEIDENTIFIER;
    DECLARE @CompanyId UNIQUEIDENTIFIER;
    DECLARE @AgentId UNIQUEIDENTIFIER;

    -- Get policy details from PolicyCatalog
    SELECT 
        @PolicyName = pc.PolicyName,
        @TypeId = pc.TypeId,
        @CompanyId = pc.CompanyId
    FROM PolicyCatalog pc
    WHERE pc.PolicyCatalogId = @PolicyCatalogId AND pc.IsActive = 1;

    IF @PolicyName IS NULL
    BEGIN
        SELECT 'Policy Catalog item not found or inactive' AS ErrorMessage;
        RETURN;
    END

    -- Get agent ID
    SELECT @AgentId = AgentId FROM Clients WHERE ClientId = @ClientId;

    INSERT INTO ClientPolicies (
        PolicyId, ClientId, PolicyCatalogId, PolicyName, TypeId, CompanyId, 
        Status, StartDate, EndDate, Notes, IsActive, CreatedDate
    )
    VALUES (
        @PolicyId, @ClientId, @PolicyCatalogId, @PolicyName, @TypeId, @CompanyId,
        @Status, @StartDate, @EndDate, @Notes, 1, GETUTCDATE()
    );
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (
        @AgentId, 'client_policy_created', 'client_policy', @PolicyId, 
        'Policy "' + @PolicyName + '" assigned to client from catalog'
    );
    
    SELECT @PolicyId AS PolicyId;
END;
GO

-- Get Expiring Policies
CREATE OR ALTER PROCEDURE sp_GetExpiringPolicies
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
        pt.TypeName,
        ic.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        c.FirstName + ' ' + c.Surname AS ClientName,
        c.PhoneNumber AS ClientPhone,
        c.Email AS ClientEmail,
        DATEDIFF(DAY, @StartDate, cp.EndDate) AS DaysUntilExpiry
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        c.AgentId = @AgentId 
        AND cp.Status = 'Active'
        AND cp.IsActive = 1
        AND c.IsActive = 1
        AND cp.EndDate BETWEEN @StartDate AND @EndDate
    ORDER BY cp.EndDate ASC;
END;
GO

-- Get Insurance Companies
CREATE OR ALTER PROCEDURE sp_GetInsuranceCompanies
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CompanyId,
        CompanyName,
        IsActive,
        CreatedDate
    FROM InsuranceCompany
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY CompanyName ASC;
END;
GO

-- Get Policy Types
CREATE OR ALTER PROCEDURE sp_GetPolicyTypes
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        TypeId,
        TypeName,
        IsActive,
        CreatedDate
    FROM PolicyType
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY TypeName ASC;
END;
GO

-- Get Policy Categories
CREATE OR ALTER PROCEDURE sp_GetPolicyCategories
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CategoryId,
        CategoryName,
        Description,
        IsActive,
        CreatedDate
    FROM PolicyCategory
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY CategoryName ASC;
END;
GO

-- Validate Policy Data
CREATE OR ALTER PROCEDURE sp_ValidatePolicyData
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IsValid BIT = 1;
    DECLARE @ValidationErrors NVARCHAR(MAX) = '';
    
    -- Validate Policy Name
    IF @PolicyName IS NULL OR LEN(TRIM(@PolicyName)) = 0
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Policy name is required. ';
    END
    
    -- Validate Policy Type ID
    IF @TypeId IS NULL OR NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Valid policy type is required. ';
    END
    
    -- Validate Company
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Valid insurance company is required. ';
    END
    
    -- Validate Dates
    IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate >= @EndDate
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'End date must be after start date. ';
    END
    
    SELECT 
        @IsValid AS IsValid,
        RTRIM(@ValidationErrors) AS ValidationErrors;
END;
GO
-- ============================================
-- Updated Stored Procedures for Policy Management
-- Matching the updated table schema with foreign keys
-- ============================================

-- Get Policy Statistics
CREATE OR ALTER PROCEDURE sp_GetPolicyStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        COUNT(CASE WHEN cp.Status = 'Active' THEN 1 END) AS ActivePolicies,
        COUNT(CASE WHEN cp.Status = 'Expired' THEN 1 END) AS ExpiredPolicies,
        COUNT(CASE WHEN cp.Status = 'Lapsed' THEN 1 END) AS LapsedPolicies,
        COUNT(CASE WHEN cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE()) THEN 1 END) AS ExpiringPolicies,
        COUNT(DISTINCT pt.TypeId) AS PolicyTypes,
        COUNT(DISTINCT ic.CompanyId) AS InsuranceCompanies
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE c.AgentId = @AgentId AND cp.IsActive = 1 AND c.IsActive = 1;
END;
GO

-- Create Policy Template
CREATE OR ALTER PROCEDURE sp_CreatePolicyTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(18,2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TemplateId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO PolicyTemplate (
        TemplateId, AgentId, TemplateName, TypeId, CategoryId,
        DefaultTermMonths, DefaultPremium, CoverageDescription, Terms
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @TypeId, @CategoryId,
        @DefaultTermMonths, @DefaultPremium, @CoverageDescription, @Terms
    );
    
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (
        @AgentId, 'policy_template_created', 'policy_template', @TemplateId, 
        'Policy template "' + @TemplateName + '" created'
    );

    SELECT @TemplateId AS TemplateId;
END;
GO

-- Get Policy Templates
CREATE OR ALTER PROCEDURE sp_GetPolicyTemplates
    @AgentId UNIQUEIDENTIFIER,
    @TypeId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pt.TemplateId,
        pt.TemplateName,
        pt.TypeId,
        ptype.TypeName,
        pt.DefaultTermMonths,
        pt.DefaultPremium,
        pt.CoverageDescription,
        pt.Terms,
        pt.CategoryId,
        pc.CategoryName,
        pt.CreatedDate
    FROM PolicyTemplate pt
    LEFT JOIN PolicyType ptype ON pt.TypeId = ptype.TypeId
    LEFT JOIN PolicyCategory pc ON pt.CategoryId = pc.CategoryId
    WHERE 
        pt.AgentId = @AgentId 
        AND pt.IsActive = 1
        AND (@TypeId IS NULL OR pt.TypeId = @TypeId)
    ORDER BY ptype.TypeName, pt.TemplateName;
END;
GO

-- Delete Policy Template
CREATE OR ALTER PROCEDURE sp_DeletePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyTemplate 
    SET IsActive = 0
    WHERE TemplateId = @TemplateId AND AgentId = @AgentId;
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'policy_template_deleted', 'policy_template', @TemplateId, 
            'Policy template deleted'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Policy Catalog for Agent
CREATE OR ALTER PROCEDURE sp_GetPolicyCatalog
    @AgentId UNIQUEIDENTIFIER,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pc.PolicyCatalogId,
        pc.PolicyName,
        pc.TypeId,
        pt.TypeName,
        pc.CompanyId,
        ic.CompanyName,
        pc.CategoryId,
        pcat.CategoryName,
        pc.Notes,
        pc.CreatedDate,
        pc.ModifiedDate
    FROM PolicyCatalog pc
    LEFT JOIN PolicyType pt ON pc.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON pc.CompanyId = ic.CompanyId
    LEFT JOIN PolicyCategory pcat ON pc.CategoryId = pcat.CategoryId
    WHERE 
        pc.AgentId = @AgentId 
        AND pc.IsActive = 1
        AND (@TypeId IS NULL OR pc.TypeId = @TypeId)
        AND (@CompanyId IS NULL OR pc.CompanyId = @CompanyId)
    ORDER BY pt.TypeName, pc.PolicyName;
END;
GO

-- Create Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_CreatePolicyCatalogItem
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyCatalogId UNIQUEIDENTIFIER = NEWID();
    
    -- Validate TypeId exists
    IF NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    INSERT INTO PolicyCatalog (
        PolicyCatalogId, AgentId, PolicyName, TypeId, 
        CompanyId, CategoryId, Notes, IsActive, CreatedDate
    )
    VALUES (
        @PolicyCatalogId, @AgentId, @PolicyName, @TypeId, 
        @CompanyId, @CategoryId, @Notes, 1, GETUTCDATE()
    );
    
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'policy_catalog_created', 'policy_catalog', @PolicyCatalogId, 
            'Policy "' + @PolicyName + '" added to catalog');
    
    SELECT @PolicyCatalogId AS PolicyCatalogId;
END;
GO

-- Update Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_UpdatePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate TypeId if provided
    IF @TypeId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    UPDATE PolicyCatalog 
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        TypeId = ISNULL(@TypeId, TypeId),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        CategoryId = ISNULL(@CategoryId, CategoryId),
        Notes = ISNULL(@Notes, Notes),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId 
      AND AgentId = @AgentId;
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'policy_catalog_updated', 'policy_catalog', @PolicyCatalogId, 
                'Policy catalog item updated');
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Policy from Catalog
CREATE OR ALTER PROCEDURE sp_DeletePolicyCatalog
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyName NVARCHAR(100);
    
    -- Get policy name for logging
    SELECT @PolicyName = PolicyName FROM PolicyCatalog WHERE PolicyCatalogId = @PolicyCatalogId;
    
    -- Soft delete
    UPDATE PolicyCatalog 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'policy_catalog_deleted', 'policy_catalog', @PolicyCatalogId, 
            'Policy "' + @PolicyName + '" removed from catalog');
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Create or Update Client Policy
CREATE OR ALTER PROCEDURE sp_UpsertClientPolicy
    @PolicyId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @Status NVARCHAR(20),
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AgentId UNIQUEIDENTIFIER;

    -- Get agent ID from client
    SELECT @AgentId = AgentId FROM Clients WHERE ClientId = @ClientId;

    -- Validate TypeId
    IF NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END

    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END

    IF @PolicyId IS NULL
    BEGIN
        -- Create new client policy
        SET @PolicyId = NEWID();

        INSERT INTO ClientPolicies (
            PolicyId, ClientId, PolicyName, TypeId, CompanyId, PolicyCatalogId,
            Status, StartDate, EndDate, Notes
        )
        VALUES (
            @PolicyId, @ClientId, @PolicyName, @TypeId, @CompanyId, @PolicyCatalogId,
            @Status, @StartDate, @EndDate, @Notes
        );

        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_created', 'client_policy', @PolicyId, 
            'Policy "' + @PolicyName + '" assigned to client'
        );
    END
    ELSE
    BEGIN
        -- Update existing client policy
        UPDATE ClientPolicies 
        SET 
            PolicyName = @PolicyName,
            TypeId = @TypeId,
            CompanyId = @CompanyId,
            PolicyCatalogId = @PolicyCatalogId,
            Status = @Status,
            StartDate = @StartDate,
            EndDate = @EndDate,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE PolicyId = @PolicyId;

        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_updated', 'client_policy', @PolicyId, 
            'Policy "' + @PolicyName + '" updated for client'
        );
    END

    -- Return the policy ID
    SELECT @PolicyId AS PolicyId;
END;
GO

-- Get Client Policies
CREATE OR ALTER PROCEDURE sp_GetClientPolicies
    @ClientId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyCatalogId,
        cp.PolicyName,
        cp.TypeId,
        pt.TypeName,
        cp.CompanyId,
        ic.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.IsActive,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry,
        c.FirstName + ' ' + c.Surname AS ClientName,
        c.PhoneNumber AS ClientPhone
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        cp.ClientId = @ClientId
        AND cp.IsActive = 1
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@TypeId IS NULL OR cp.TypeId = @TypeId)
    ORDER BY cp.StartDate DESC;
END;
GO

-- Create Client Policy (using PolicyCatalog)
CREATE OR ALTER PROCEDURE sp_CreateClientPolicy
    @ClientId UNIQUEIDENTIFIER,
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PolicyId UNIQUEIDENTIFIER = NEWID();
    DECLARE @PolicyName NVARCHAR(100);
    DECLARE @TypeId UNIQUEIDENTIFIER;
    DECLARE @CompanyId UNIQUEIDENTIFIER;
    DECLARE @AgentId UNIQUEIDENTIFIER;

    -- Get policy details from PolicyCatalog
    SELECT 
        @PolicyName = pc.PolicyName,
        @TypeId = pc.TypeId,
        @CompanyId = pc.CompanyId
    FROM PolicyCatalog pc
    WHERE pc.PolicyCatalogId = @PolicyCatalogId AND pc.IsActive = 1;

    IF @PolicyName IS NULL
    BEGIN
        SELECT 'Policy Catalog item not found or inactive' AS ErrorMessage;
        RETURN;
    END

    -- Get agent ID
    SELECT @AgentId = AgentId FROM Clients WHERE ClientId = @ClientId;

    INSERT INTO ClientPolicies (
        PolicyId, ClientId, PolicyCatalogId, PolicyName, TypeId, CompanyId, 
        Status, StartDate, EndDate, Notes, IsActive, CreatedDate
    )
    VALUES (
        @PolicyId, @ClientId, @PolicyCatalogId, @PolicyName, @TypeId, @CompanyId,
        @Status, @StartDate, @EndDate, @Notes, 1, GETUTCDATE()
    );
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (
        @AgentId, 'client_policy_created', 'client_policy', @PolicyId, 
        'Policy "' + @PolicyName + '" assigned to client from catalog'
    );
    
    SELECT @PolicyId AS PolicyId;
END;
GO

-- Get Expiring Policies
CREATE OR ALTER PROCEDURE sp_GetExpiringPolicies
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
        pt.TypeName,
        ic.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        c.FirstName + ' ' + c.Surname AS ClientName,
        c.PhoneNumber AS ClientPhone,
        c.Email AS ClientEmail,
        DATEDIFF(DAY, @StartDate, cp.EndDate) AS DaysUntilExpiry
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        c.AgentId = @AgentId 
        AND cp.Status = 'Active'
        AND cp.IsActive = 1
        AND c.IsActive = 1
        AND cp.EndDate BETWEEN @StartDate AND @EndDate
    ORDER BY cp.EndDate ASC;
END;
GO

-- Get Insurance Companies
CREATE OR ALTER PROCEDURE sp_GetInsuranceCompanies
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CompanyId,
        CompanyName,
        IsActive,
        CreatedDate
    FROM InsuranceCompany
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY CompanyName ASC;
END;
GO

-- Get Policy Types
CREATE OR ALTER PROCEDURE sp_GetPolicyTypes
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        TypeId,
        TypeName,
        IsActive,
        CreatedDate
    FROM PolicyType
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY TypeName ASC;
END;
GO

-- Get Policy Categories
CREATE OR ALTER PROCEDURE sp_GetPolicyCategories
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CategoryId,
        CategoryName,
        Description,
        IsActive,
        CreatedDate
    FROM PolicyCategory
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY CategoryName ASC;
END;
GO

-- Validate Policy Data
CREATE OR ALTER PROCEDURE sp_ValidatePolicyData
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IsValid BIT = 1;
    DECLARE @ValidationErrors NVARCHAR(MAX) = '';
    
    -- Validate Policy Name
    IF @PolicyName IS NULL OR LEN(TRIM(@PolicyName)) = 0
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Policy name is required. ';
    END
    
    -- Validate Policy Type ID
    IF @TypeId IS NULL OR NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Valid policy type is required. ';
    END
    
    -- Validate Company
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Valid insurance company is required. ';
    END
    
    -- Validate Dates
    IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate >= @EndDate
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'End date must be after start date. ';
    END
    
    SELECT 
        @IsValid AS IsValid,
        RTRIM(@ValidationErrors) AS ValidationErrors;
END;
GO

-- ============================================
-- MISSING PROCEDURES FROM ORIGINAL CODE
-- ============================================

-- Update Client Policy
CREATE OR ALTER PROCEDURE sp_UpdateClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @PolicyName NVARCHAR(100) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @Status NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AgentId UNIQUEIDENTIFIER;

    -- Get agent ID from the client associated with this policy
    SELECT @AgentId = c.AgentId 
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE cp.PolicyId = @PolicyId;

    -- Validate PolicyCatalogId if provided
    IF @PolicyCatalogId IS NOT NULL
    BEGIN
        IF NOT EXISTS (
            SELECT 1 
            FROM PolicyCatalog 
            WHERE PolicyCatalogId = @PolicyCatalogId 
              AND IsActive = 1
        )
        BEGIN
            SELECT 'Policy Catalog item not found or inactive' AS ErrorMessage;
            RETURN;
        END
    END

    -- Validate TypeId if provided
    IF @TypeId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END

    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END

    UPDATE ClientPolicies 
    SET 
        PolicyCatalogId = ISNULL(@PolicyCatalogId, PolicyCatalogId),
        PolicyName = ISNULL(@PolicyName, PolicyName),
        TypeId = ISNULL(@TypeId, TypeId),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        Status = ISNULL(@Status, Status),
        StartDate = ISNULL(@StartDate, StartDate),
        EndDate = ISNULL(@EndDate, EndDate),
        Notes = ISNULL(@Notes, Notes),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETUTCDATE()
    WHERE PolicyId = @PolicyId;
    
    IF @@ROWCOUNT > 0 AND @AgentId IS NOT NULL
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_updated', 'client_policy', @PolicyId, 
            'Client policy updated'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Policy Statistics (Enhanced Version)
CREATE OR ALTER PROCEDURE sp_GetPolicyStatisticsDetailed
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
    DECLARE @MonthEnd DATE = EOMONTH(@Today);

    SELECT 
        -- Total Policies
        COUNT(DISTINCT cp.PolicyId) AS TotalPolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Active' THEN cp.PolicyId END) AS ActivePolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Expired' THEN cp.PolicyId END) AS ExpiredPolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Lapsed' THEN cp.PolicyId END) AS LapsedPolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Inactive' THEN cp.PolicyId END) AS InactivePolicies,

        -- Expiring Soon (next 30 days)
        COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 30, @Today) 
                             AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn30Days,
        COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 7, @Today) 
                             AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn7Days,

        -- New Policies This Month
        COUNT(DISTINCT CASE WHEN cp.StartDate BETWEEN @MonthStart AND @MonthEnd THEN cp.PolicyId END) AS NewPoliciesThisMonth,

        -- Policies by Type (using joins to get actual type names)
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Motor' THEN cp.PolicyId END) AS MotorPolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Life' THEN cp.PolicyId END) AS LifePolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Health' THEN cp.PolicyId END) AS HealthPolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Travel' THEN cp.PolicyId END) AS TravelPolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Property' THEN cp.PolicyId END) AS PropertyPolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Marine' THEN cp.PolicyId END) AS MarinePolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Business' THEN cp.PolicyId END) AS BusinessPolicies,

        -- Catalog Statistics
        COUNT(DISTINCT pc.PolicyCatalogId) AS CatalogPolicies,
        COUNT(DISTINCT pt.TypeId) AS PolicyTypes,
        COUNT(DISTINCT ic.CompanyId) AS InsuranceCompanies
        
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE c.AgentId = @AgentId 
      AND cp.IsActive = 1 
      AND c.IsActive = 1;
END;
GO

-- Get Expiring Policies with Period Parameter
CREATE OR ALTER PROCEDURE sp_GetExpiringPoliciesByPeriod
    @AgentId UNIQUEIDENTIFIER = NULL,
    @Period NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Days INT;

    SET @Days = CASE UPPER(@Period)
                    WHEN '1D' THEN 1
                    WHEN '1W' THEN 7
                    WHEN '1M' THEN 30
                    WHEN '1Y' THEN 365
                    WHEN '2Y' THEN 730
                    WHEN '3Y' THEN 1095
                    ELSE NULL
                END;

    IF @Days IS NULL
    BEGIN
        RAISERROR('Invalid period specified. Use 1D, 1W, 1M, 1Y, 2Y, or 3Y.', 16, 1);
        RETURN;
    END

    SELECT 
        cp.PolicyId,
        cp.ClientId,
        CONCAT(c.FirstName, ' ', c.Surname) AS ClientName,
        c.PhoneNumber AS ClientPhone,
        c.Email AS ClientEmail,
        cp.PolicyName,
        pt.TypeName AS PolicyType,
        ic.CompanyName,
        cp.StartDate,
        cp.EndDate,
        cp.Status,
        cp.Notes,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        cp.IsActive = 1
        AND cp.Status = 'Active'
        AND c.IsActive = 1
        AND (@AgentId IS NULL OR c.AgentId = @AgentId)
        AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, @Days, GETDATE())
    ORDER BY cp.EndDate ASC;
END;
GO

-- Create Policy Category
CREATE OR ALTER PROCEDURE sp_CreatePolicyCategory
    @CategoryName NVARCHAR(50),
    @Description NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM PolicyCategory WHERE CategoryName = @CategoryName AND IsActive = 1)
    BEGIN
        SELECT 'Category already exists' AS ErrorMessage;
        RETURN;
    END

    DECLARE @CategoryId UNIQUEIDENTIFIER = NEWID();

    INSERT INTO PolicyCategory (CategoryId, CategoryName, Description, IsActive, CreatedDate)
    VALUES (@CategoryId, @CategoryName, @Description, 1, GETUTCDATE());

    SELECT @CategoryId AS CategoryId;
END;
GO

-- Update Policy Template
CREATE OR ALTER PROCEDURE sp_UpdatePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(18,2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate TypeId if provided
    IF @TypeId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CategoryId if provided
    IF @CategoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PolicyCategory WHERE CategoryId = @CategoryId AND IsActive = 1)
    BEGIN
        SELECT 'Policy category not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    UPDATE PolicyTemplate 
    SET 
        TemplateName = ISNULL(@TemplateName, TemplateName),
        TypeId = ISNULL(@TypeId, TypeId),
        DefaultTermMonths = ISNULL(@DefaultTermMonths, DefaultTermMonths),
        DefaultPremium = ISNULL(@DefaultPremium, DefaultPremium),
        CoverageDescription = ISNULL(@CoverageDescription, CoverageDescription),
        Terms = ISNULL(@Terms, Terms),
        CategoryId = ISNULL(@CategoryId, CategoryId),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE TemplateId = @TemplateId 
      AND AgentId = @AgentId;
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'policy_template_updated', 'policy_template', @TemplateId, 
            'Policy template updated'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Client Policy (Soft Delete)
CREATE OR ALTER PROCEDURE sp_DeleteClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyName NVARCHAR(100);
    
    -- Get policy name for logging
    SELECT @PolicyName = cp.PolicyName 
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE cp.PolicyId = @PolicyId AND c.AgentId = @AgentId;
    
    -- Soft delete
    UPDATE ClientPolicies 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE PolicyId = @PolicyId 
      AND EXISTS (
          SELECT 1 FROM Clients c 
          WHERE c.ClientId = ClientPolicies.ClientId 
            AND c.AgentId = @AgentId
      );
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_deleted', 'client_policy', @PolicyId, 
            'Policy "' + ISNULL(@PolicyName, 'Unknown') + '" deleted for client'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO
-- ============================================
-- Indexes and Performance Optimization
-- ============================================

-- Agent Table Indexes
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Agent_Email' AND object_id = OBJECT_ID('Agent')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Agent_Email ON Agent(Email);
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_Agent_IsActive' AND object_id = OBJECT_ID('Agent')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Agent_IsActive ON Agent(IsActive);
END;

-- Clients Table Indexes
CREATE NONCLUSTERED INDEX IX_Clients_AgentId ON Clients(AgentId);
CREATE NONCLUSTERED INDEX IX_Clients_IsActive ON Clients(IsActive);
CREATE NONCLUSTERED INDEX IX_Clients_IsClient ON Clients(IsClient);
CREATE NONCLUSTERED INDEX IX_Clients_PhoneNumber ON Clients(PhoneNumber);
CREATE NONCLUSTERED INDEX IX_Clients_Email ON Clients(Email);
CREATE NONCLUSTERED INDEX IX_Clients_DateOfBirth ON Clients(DateOfBirth);
CREATE NONCLUSTERED INDEX IX_Clients_InsuranceType ON Clients(InsuranceType);
CREATE NONCLUSTERED INDEX IX_Clients_Search ON Clients(AgentId, IsActive) INCLUDE (FirstName, Surname, LastName, PhoneNumber, Email);

-- Appointments Table Indexes
CREATE NONCLUSTERED INDEX IX_Appointments_AgentId ON Appointments(AgentId);
CREATE NONCLUSTERED INDEX IX_Appointments_ClientId ON Appointments(ClientId);
CREATE NONCLUSTERED INDEX IX_Appointments_Date ON Appointments(AppointmentDate);
CREATE NONCLUSTERED INDEX IX_Appointments_Status ON Appointments(Status);
CREATE NONCLUSTERED INDEX IX_Appointments_Type ON Appointments(Type);
CREATE NONCLUSTERED INDEX IX_Appointments_IsActive ON Appointments(IsActive);
CREATE NONCLUSTERED INDEX IX_Appointments_Dashboard ON Appointments(AgentId, AppointmentDate, IsActive) INCLUDE (ClientName, Title, StartTime, EndTime, Status);

-- Client Policies Indexes
CREATE NONCLUSTERED INDEX IX_ClientPolicies_ClientId ON ClientPolicies(ClientId);
CREATE NONCLUSTERED INDEX IX_ClientPolicies_Status ON ClientPolicies(Status);
CREATE NONCLUSTERED INDEX IX_ClientPolicies_EndDate ON ClientPolicies(EndDate);
CREATE NONCLUSTERED INDEX IX_ClientPolicies_IsActive ON ClientPolicies(IsActive);
CREATE NONCLUSTERED INDEX IX_ClientPolicies_Expiring ON ClientPolicies(Status, EndDate, IsActive);

-- Reminders Table Indexes
CREATE NONCLUSTERED INDEX IX_Reminders_AgentId ON Reminders(AgentId);
CREATE NONCLUSTERED INDEX IX_Reminders_ClientId ON Reminders(ClientId);
CREATE NONCLUSTERED INDEX IX_Reminders_Date ON Reminders(ReminderDate);
CREATE NONCLUSTERED INDEX IX_Reminders_Status ON Reminders(Status);
CREATE NONCLUSTERED INDEX IX_Reminders_Type ON Reminders(ReminderType);
CREATE NONCLUSTERED INDEX IX_Reminders_Active ON Reminders(AgentId, Status, ReminderDate);

-- Policy Catalog Indexes
CREATE NONCLUSTERED INDEX IX_PolicyCatalog_AgentId ON PolicyCatalog(AgentId);
CREATE NONCLUSTERED INDEX IX_PolicyCatalog_Type ON PolicyCatalog(PolicyType);
CREATE NONCLUSTERED INDEX IX_PolicyCatalog_Company ON PolicyCatalog(CompanyId);
CREATE NONCLUSTERED INDEX IX_PolicyCatalog_IsActive ON PolicyCatalog(IsActive);

-- Automated Messages Indexes
CREATE NONCLUSTERED INDEX IX_AutomatedMessages_AgentId ON AutomatedMessages(AgentId);
CREATE NONCLUSTERED INDEX IX_AutomatedMessages_Status ON AutomatedMessages(Status);
CREATE NONCLUSTERED INDEX IX_AutomatedMessages_ScheduledDate ON AutomatedMessages(ScheduledDate);

-- Activity Log Indexes
CREATE NONCLUSTERED INDEX IX_ActivityLog_AgentId ON ActivityLog(AgentId);
CREATE NONCLUSTERED INDEX IX_ActivityLog_Date ON ActivityLog(ActivityDate);
CREATE NONCLUSTERED INDEX IX_ActivityLog_Type ON ActivityLog(ActivityType);
CREATE NONCLUSTERED INDEX IX_ActivityLog_Entity ON ActivityLog(EntityType, EntityId);

-- Dashboard Statistics Indexes
CREATE NONCLUSTERED INDEX IX_DashboardStatistics_AgentDate ON DashboardStatistics(AgentId, StatDate);

-- Performance Metrics Indexes
CREATE NONCLUSTERED INDEX IX_PerformanceMetrics_AgentDate ON PerformanceMetrics(AgentId, MetricDate);

-- Monthly Reports Indexes
CREATE NONCLUSTERED INDEX IX_MonthlyReports_AgentMonth ON MonthlyReports(AgentId, ReportMonth);

-- Settings Tables Indexes
CREATE NONCLUSTERED INDEX IX_ReminderSettings_AgentId ON ReminderSettings(AgentId);
CREATE NONCLUSTERED INDEX IX_AgentNotificationPreferences_AgentId ON AgentNotificationPreferences(AgentId);
CREATE NONCLUSTERED INDEX IX_SystemPreferences_AgentId ON SystemPreferences(AgentId);
CREATE NONCLUSTERED INDEX IX_MessageTemplates_AgentId ON MessageTemplates(AgentId);
CREATE NONCLUSTERED INDEX IX_MessageTemplates_Type ON MessageTemplates(MessageType);

-- Daily Notes Indexes
CREATE NONCLUSTERED INDEX IX_DailyNotes_AgentDate ON DailyNotes(AgentId, NoteDate);

-- Message Recipients Indexes
CREATE NONCLUSTERED INDEX IX_MessageRecipients_MessageId ON MessageRecipients(MessageId);
CREATE NONCLUSTERED INDEX IX_MessageRecipients_ClientId ON MessageRecipients(ClientId);
CREATE NONCLUSTERED INDEX IX_MessageRecipients_Status ON MessageRecipients(DeliveryStatus);

-- ============================================
-- Additional Constraints and Validations
-- ============================================

-- Ensure email uniqueness across active agents
CREATE UNIQUE INDEX UX_Agent_Email_Active 
ON Agent(Email) 
WHERE IsActive = 1;

-- Ensure phone number format validation (basic constraint)
ALTER TABLE Clients 
ADD CONSTRAINT CK_Clients_PhoneFormat 
CHECK (PhoneNumber LIKE '+254[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' 
       OR PhoneNumber LIKE '07[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
       OR PhoneNumber LIKE '01[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');

-- Ensure appointment end time is after start time
ALTER TABLE Appointments 
ADD CONSTRAINT CK_Appointments_TimeOrder 
CHECK (EndTime > StartTime);

-- Ensure policy end date is after start date
ALTER TABLE ClientPolicies 
ADD CONSTRAINT CK_ClientPolicies_DateOrder 
CHECK (EndDate > StartDate);

-- Ensure reminder date is not in the past (for new reminders)
ALTER TABLE Reminders 
ADD CONSTRAINT CK_Reminders_FutureDate 
CHECK (ReminderDate >= CAST(GETDATE() AS DATE) OR Status != 'Active');

-- Ensure scheduled message date is in the future
ALTER TABLE AutomatedMessages 
ADD CONSTRAINT CK_AutomatedMessages_ScheduledDate 
CHECK (ScheduledDate > GETUTCDATE() OR Status != 'Scheduled');
GO
-- ============================================
-- Views for Common Queries
-- ============================================

-- Active Clients View
CREATE OR ALTER VIEW vw_ActiveClients AS
SELECT 
    c.*,
    cp.PolicyId,
    cp.PolicyName,
    cp.PolicyType,
    cp.CompanyName AS PolicyCompany,
    cp.Status AS PolicyStatus,
    cp.StartDate AS PolicyStartDate,
    cp.EndDate AS PolicyEndDate,
    DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) AS Age
FROM Clients c
LEFT JOIN ClientPolicies cp ON c.ClientId = cp.ClientId AND cp.IsActive = 1
WHERE c.IsActive = 1;
GO

-- Today's Dashboard View
CREATE OR ALTER VIEW vw_TodayDashboard AS
SELECT 
    c.AgentId,
    -- Today's Appointments
    COUNT(DISTINCT CASE WHEN a.AppointmentDate = CAST(GETDATE() AS DATE) AND a.Status NOT IN ('Cancelled') THEN a.AppointmentId END) AS TodayAppointments,
    -- Today's Reminders
    COUNT(DISTINCT CASE WHEN r.ReminderDate = CAST(GETDATE() AS DATE) AND r.Status = 'Active' THEN r.ReminderId END) AS TodayReminders,
    -- Today's Birthdays
    COUNT(DISTINCT CASE WHEN DAY(c.DateOfBirth) = DAY(GETDATE()) AND MONTH(c.DateOfBirth) = MONTH(GETDATE()) THEN c.ClientId END) AS TodayBirthdays,
    -- Expiring Policies (next 30 days)
    COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE()) AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringPolicies
FROM Clients c
LEFT JOIN Appointments a ON c.ClientId = a.ClientId AND a.IsActive = 1
LEFT JOIN Reminders r ON c.ClientId = r.ClientId
LEFT JOIN ClientPolicies cp ON c.ClientId = cp.ClientId AND cp.IsActive = 1
WHERE c.IsActive = 1
GROUP BY c.AgentId;
GO

-- Expiring Policies View
CREATE OR ALTER VIEW vw_ExpiringPolicies AS
SELECT 
    c.AgentId,
    cp.PolicyId,
    cp.PolicyName,
    cp.PolicyType,
    cp.CompanyName,
    cp.EndDate,
    c.ClientId,
    c.FirstName + ' ' + c.Surname AS ClientName,
    c.PhoneNumber,
    c.Email,
    DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
FROM ClientPolicies cp
INNER JOIN Clients c ON cp.ClientId = c.ClientId
WHERE 
    cp.Status = 'Active' 
    AND cp.IsActive = 1 
    AND c.IsActive = 1
    AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, 60, GETDATE())
;
GO

-- ============================================
-- Triggers for Audit and Business Logic
-- ============================================

-- Trigger to update ModifiedDate on Clients table
CREATE OR ALTER TRIGGER tr_Clients_UpdateModifiedDate
ON Clients
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE c
    SET ModifiedDate = GETUTCDATE()
    FROM Clients c
    INNER JOIN inserted i ON c.ClientId = i.ClientId;
END;
GO

-- Trigger to update ModifiedDate on Appointments table
CREATE OR ALTER TRIGGER tr_Appointments_UpdateModifiedDate
ON Appointments
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE a
    SET ModifiedDate = GETUTCDATE()
    FROM Appointments a
    INNER JOIN inserted i ON a.AppointmentId = i.AppointmentId;
END;
GO

-- Trigger to log appointment status changes
CREATE OR ALTER TRIGGER tr_Appointments_StatusChange
ON Appointments
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    SELECT 
        i.AgentId,
        'appointment_status_changed',
        'appointment',
        i.AppointmentId,
        'Appointment "' + i.Title + '" status changed from ' + d.Status + ' to ' + i.Status
    FROM inserted i
    INNER JOIN deleted d ON i.AppointmentId = d.AppointmentId
    WHERE i.Status != d.Status;
END;
GO

-- Trigger to auto-create reminders for policy expiry
CREATE OR ALTER TRIGGER tr_ClientPolicies_ExpiryReminder
ON ClientPolicies
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Reminders (
        ClientId, AgentId, ReminderType, Title, Description, ReminderDate, Priority, EnablePushNotification
    )
    SELECT 
        i.ClientId,
        c.AgentId,
        'Policy Expiry',
        'Policy Expiring: ' + i.PolicyName,
        'Policy expires on ' + CONVERT(VARCHAR, i.EndDate, 107),
        DATEADD(DAY, -30, i.EndDate),
        'High',
        1
    FROM inserted i
    INNER JOIN Clients c ON i.ClientId = c.ClientId
    WHERE 
        i.Status = 'Active'
        AND i.EndDate > DATEADD(DAY, 30, GETDATE())
        AND NOT EXISTS (
            SELECT 1 FROM Reminders r 
            WHERE r.ClientId = i.ClientId 
            AND r.ReminderType = 'Policy Expiry' 
            AND r.ReminderDate = DATEADD(DAY, -30, i.EndDate)
            AND r.Status = 'Active'
        );
END;
GO

-- ============================================
-- Functions for Common Calculations
-- ============================================

-- Function to calculate client age
CREATE OR ALTER FUNCTION fn_CalculateAge(@DateOfBirth DATE)
RETURNS INT
AS
BEGIN
    DECLARE @Age INT;
    
    SET @Age = DATEDIFF(YEAR, @DateOfBirth, GETDATE());
    
    -- Adjust if birthday hasn't occurred this year
    IF (MONTH(@DateOfBirth) > MONTH(GETDATE())) 
       OR (MONTH(@DateOfBirth) = MONTH(GETDATE()) AND DAY(@DateOfBirth) > DAY(GETDATE()))
    BEGIN
        SET @Age = @Age - 1;
    END
    
    RETURN @Age;
END;
GO

-- Function to get days until expiry
CREATE OR ALTER FUNCTION fn_DaysUntilExpiry(@ExpiryDate DATE)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(DAY, CAST(GETDATE() AS DATE), @ExpiryDate);
END;
GO

-- Function to format client full name
CREATE OR ALTER FUNCTION fn_FormatClientName(@FirstName NVARCHAR(50), @Surname NVARCHAR(50), @LastName NVARCHAR(50))
RETURNS NVARCHAR(152)
AS
BEGIN
    RETURN LTRIM(RTRIM(@FirstName + ' ' + @Surname + ' ' + ISNULL(@LastName, '')));
END;
GO
-- ============================================
-- Aminius Insurance Management System
-- Stored Procedures for Policy Management
-- ============================================

-- ============================================
-- POLICY CATALOG PROCEDURES
-- ============================================

-- Get Policy Catalog
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyCatalog')
    DROP PROCEDURE GetPolicyCatalog;
GO

CREATE PROCEDURE GetPolicyCatalog
    @AgentId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pc.PolicyCatalogId,
        pc.AgentId,
        pc.PolicyName,
        pc.CompanyId,
        ic.CompanyName,
        pc.Notes,
        pc.IsActive,
        pc.CreatedDate,
        pc.ModifiedDate,
        pc.CategoryId,
        pcat.CategoryName,
        pc.TypeId,
        pt.TypeName
    FROM PolicyCatalog pc
        LEFT JOIN InsuranceCompanies ic ON pc.CompanyId = ic.CompanyId
        LEFT JOIN PolicyCategories pcat ON pc.CategoryId = pcat.CategoryId
        LEFT JOIN PolicyTypes pt ON pc.TypeId = pt.TypeId
    WHERE (@AgentId IS NULL OR pc.AgentId = @AgentId)
        AND (@CompanyId IS NULL OR pc.CompanyId = @CompanyId)
        AND (@CategoryId IS NULL OR pc.CategoryId = @CategoryId)
        AND (@TypeId IS NULL OR pc.TypeId = @TypeId)
        AND (@IsActive IS NULL OR pc.IsActive = @IsActive)
    ORDER BY pc.PolicyName;
END
GO

-- Create Policy Catalog Item
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreatePolicyCatalogItem')
    DROP PROCEDURE CreatePolicyCatalogItem;
GO

CREATE PROCEDURE CreatePolicyCatalogItem
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @PolicyCatalogId = NEWID();
    
    INSERT INTO PolicyCatalog (
        PolicyCatalogId, AgentId, PolicyName, CompanyId, 
        Notes, CategoryId, TypeId, IsActive, CreatedDate
    )
    VALUES (
        @PolicyCatalogId, @AgentId, @PolicyName, @CompanyId,
        @Notes, @CategoryId, @TypeId, 1, GETDATE()
    );
    
    SELECT @PolicyCatalogId as PolicyCatalogId;
END
GO

-- Update Policy Catalog Item
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdatePolicyCatalogItem')
    DROP PROCEDURE UpdatePolicyCatalogItem;
GO

CREATE PROCEDURE UpdatePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyCatalog
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        Notes = ISNULL(@Notes, Notes),
        CategoryId = ISNULL(@CategoryId, CategoryId),
        TypeId = ISNULL(@TypeId, TypeId),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Delete Policy Catalog Item
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'DeletePolicyCatalogItem')
    DROP PROCEDURE DeletePolicyCatalogItem;
GO

CREATE PROCEDURE DeletePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @HardDelete = 1
    BEGIN
        DELETE FROM PolicyCatalog WHERE PolicyCatalogId = @PolicyCatalogId;
    END
    ELSE
    BEGIN
        UPDATE PolicyCatalog 
        SET IsActive = 0, ModifiedDate = GETDATE()
        WHERE PolicyCatalogId = @PolicyCatalogId;
    END
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Upsert Policy Catalog
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpsertPolicyCatalog')
    DROP PROCEDURE UpsertPolicyCatalog;
GO

CREATE PROCEDURE UpsertPolicyCatalog
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @PolicyCatalogId IS NULL OR NOT EXISTS (SELECT 1 FROM PolicyCatalog WHERE PolicyCatalogId = @PolicyCatalogId)
    BEGIN
        -- Insert new record
        SET @PolicyCatalogId = NEWID();
        INSERT INTO PolicyCatalog (
            PolicyCatalogId, AgentId, PolicyName, CompanyId, 
            Notes, CategoryId, TypeId, IsActive, CreatedDate
        )
        VALUES (
            @PolicyCatalogId, @AgentId, @PolicyName, @CompanyId,
            @Notes, @CategoryId, @TypeId, 1, GETDATE()
        );
    END
    ELSE
    BEGIN
        -- Update existing record
        UPDATE PolicyCatalog
        SET 
            PolicyName = @PolicyName,
            CompanyId = @CompanyId,
            Notes = @Notes,
            CategoryId = @CategoryId,
            TypeId = @TypeId,
            ModifiedDate = GETDATE()
        WHERE PolicyCatalogId = @PolicyCatalogId;
    END
    
    SELECT @PolicyCatalogId as PolicyCatalogId;
END
GO

-- ============================================
-- CLIENT POLICIES PROCEDURES
-- ============================================

-- Get Client Policies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetClientPolicies')
    DROP PROCEDURE GetClientPolicies;
GO

CREATE PROCEDURE GetClientPolicies
    @ClientId UNIQUEIDENTIFIER = NULL,
    @AgentId UNIQUEIDENTIFIER = NULL,
    @Status NVARCHAR(20) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.IsActive,
        cp.PolicyCatalogId,
        pc.PolicyName as CatalogPolicyName,
        cp.TypeId,
        pt.TypeName,
        cp.CompanyId,
        ic.CompanyName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE (@ClientId IS NULL OR cp.ClientId = @ClientId)
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@IsActive IS NULL OR cp.IsActive = @IsActive)
    ORDER BY cp.EndDate DESC;
END
GO
EXEC GetClientPolicies
-- Get Policy By ID
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyById')
    DROP PROCEDURE GetPolicyById;
GO

CREATE PROCEDURE GetPolicyById
    @PolicyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.IsActive,
        cp.PolicyCatalogId,
        pc.PolicyName as CatalogPolicyName,
        cp.TypeId,
        pt.TypeName,
        cp.CompanyId,
        ic.CompanyName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.PolicyId = @PolicyId;
END
GO

-- Create Client Policy
ALTER PROCEDURE CreateClientPolicy
    @ClientId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @PolicyId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @PolicyId = NEWID();

    DECLARE @CompanyId UNIQUEIDENTIFIER;
    DECLARE @TypeId UNIQUEIDENTIFIER;

    -- Pull CompanyId and TypeId from PolicyCatalog
    SELECT 
        @CompanyId = CompanyId,
        @TypeId = TypeId
    FROM PolicyCatalog
    WHERE PolicyCatalogId = @PolicyCatalogId;

    INSERT INTO ClientPolicies (
        PolicyId, ClientId, PolicyName, Status, StartDate, EndDate,
        Notes, PolicyCatalogId, TypeId, CompanyId, IsActive, CreatedDate
    )
    VALUES (
        @PolicyId, @ClientId, @PolicyName, @Status, @StartDate, @EndDate,
        @Notes, @PolicyCatalogId, @TypeId, @CompanyId, 1, GETDATE()
    );
    
    SELECT @PolicyId as PolicyId;
END
go

-- Update Client Policy
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdateClientPolicy')
    DROP PROCEDURE UpdateClientPolicy;
GO

CREATE PROCEDURE UpdateClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @Status NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE ClientPolicies
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        Status = ISNULL(@Status, Status),
        StartDate = ISNULL(@StartDate, StartDate),
        EndDate = ISNULL(@EndDate, EndDate),
        Notes = ISNULL(@Notes, Notes),
        PolicyCatalogId = ISNULL(@PolicyCatalogId, PolicyCatalogId),
        TypeId = ISNULL(@TypeId, TypeId),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETDATE()
    WHERE PolicyId = @PolicyId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Delete Client Policy
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'DeleteClientPolicy')
    DROP PROCEDURE DeleteClientPolicy;
GO

CREATE PROCEDURE DeleteClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @HardDelete = 1
    BEGIN
        DELETE FROM ClientPolicies WHERE PolicyId = @PolicyId;
    END
    ELSE
    BEGIN
        UPDATE ClientPolicies 
        SET IsActive = 0, Status = 'Cancelled', ModifiedDate = GETDATE()
        WHERE PolicyId = @PolicyId;
    END
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Upsert Client Policy
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpsertClientPolicy')
    DROP PROCEDURE UpsertClientPolicy;
GO

CREATE PROCEDURE UpsertClientPolicy
    @PolicyId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @PolicyId IS NULL OR NOT EXISTS (SELECT 1 FROM ClientPolicies WHERE PolicyId = @PolicyId)
    BEGIN
        -- Insert new record
        SET @PolicyId = NEWID();
        INSERT INTO ClientPolicies (
            PolicyId, ClientId, PolicyName, Status, StartDate, EndDate,
            Notes, PolicyCatalogId, TypeId, CompanyId, IsActive, CreatedDate
        )
        VALUES (
            @PolicyId, @ClientId, @PolicyName, @Status, @StartDate, @EndDate,
            @Notes, @PolicyCatalogId, @TypeId, @CompanyId, 1, GETDATE()
        );
    END
    ELSE
    BEGIN
        -- Update existing record
        UPDATE ClientPolicies
        SET 
            PolicyName = @PolicyName,
            Status = @Status,
            StartDate = @StartDate,
            EndDate = @EndDate,
            Notes = @Notes,
            PolicyCatalogId = @PolicyCatalogId,
            TypeId = @TypeId,
            CompanyId = @CompanyId,
            ModifiedDate = GETDATE()
        WHERE PolicyId = @PolicyId;
    END
    
    SELECT @PolicyId as PolicyId;
END
GO

-- Get Expiring Policies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetExpiringPolicies')
    DROP PROCEDURE GetExpiringPolicies;
GO

CREATE PROCEDURE GetExpiringPolicies
    @AgentId UNIQUEIDENTIFIER = NULL,
    @DaysAhead INT = 30,
    @Status NVARCHAR(20) = 'Active'
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.IsActive = 1
        AND cp.Status = @Status
        AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, @DaysAhead, GETDATE())
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    ORDER BY cp.EndDate;
END
GO
exec GetPolicyStatistics
-- Get Policy Statistics
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyStatistics')
    DROP PROCEDURE GetPolicyStatistics;
GO

CREATE PROCEDURE GetPolicyStatistics
    @AgentId UNIQUEIDENTIFIER = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @StartDate = ISNULL(@StartDate, DATEADD(YEAR, -1, GETDATE()));
    SET @EndDate = ISNULL(@EndDate, GETDATE());
    
    SELECT 
        COUNT(*) as TotalPolicies,
        SUM(CASE WHEN Status = 'Active' THEN 1 ELSE 0 END) as ActivePolicies,
        SUM(CASE WHEN Status = 'Expired' THEN 1 ELSE 0 END) as ExpiredPolicies,
        SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) as CancelledPolicies,
        SUM(CASE WHEN EndDate BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE()) THEN 1 ELSE 0 END) as ExpiringIn30Days,
        SUM(CASE WHEN EndDate BETWEEN GETDATE() AND DATEADD(DAY, 60, GETDATE()) THEN 1 ELSE 0 END) as ExpiringIn60Days
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE cp.IsActive = 1
        AND cp.CreatedDate BETWEEN @StartDate AND @EndDate
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId);
END
GO

-- Get Policy Statistics Detailed
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyStatisticsDetailed')
    DROP PROCEDURE GetPolicyStatisticsDetailed;
GO

CREATE PROCEDURE GetPolicyStatisticsDetailed
    @AgentId UNIQUEIDENTIFIER = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @StartDate = ISNULL(@StartDate, DATEADD(YEAR, -1, GETDATE()));
    SET @EndDate = ISNULL(@EndDate, GETDATE());
    
    -- By Company
    SELECT 
        'By Company' as GroupType,
        ic.CompanyName as GroupName,
        COUNT(*) as PolicyCount,
        SUM(CASE WHEN cp.Status = 'Active' THEN 1 ELSE 0 END) as ActiveCount
    FROM ClientPolicies cp
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE cp.IsActive = 1
        AND cp.CreatedDate BETWEEN @StartDate AND @EndDate
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    GROUP BY ic.CompanyName
    
    UNION ALL
    
    -- By Type
    SELECT 
        'By Type' as GroupType,
        pt.TypeName as GroupName,
        COUNT(*) as PolicyCount,
        SUM(CASE WHEN cp.Status = 'Active' THEN 1 ELSE 0 END) as ActiveCount
    FROM ClientPolicies cp
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE cp.IsActive = 1
        AND cp.CreatedDate BETWEEN @StartDate AND @EndDate
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    GROUP BY pt.TypeName
    
    ORDER BY GroupType, PolicyCount DESC;
END
GO

-- ============================================
-- POLICY SEARCH AND FILTERING PROCEDURES
-- ============================================

-- Search Policies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'SearchPolicies')
    DROP PROCEDURE SearchPolicies;
GO

CREATE PROCEDURE SearchPolicies
    @SearchTerm NVARCHAR(100) = NULL,
    @AgentId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @Status NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @PageSize INT = 50,
    @PageNumber INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        cp.PolicyCatalogId,
        pc.PolicyName as CatalogPolicyName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.IsActive = 1
        AND (@SearchTerm IS NULL OR cp.PolicyName LIKE '%' + @SearchTerm + '%' OR cp.Notes LIKE '%' + @SearchTerm + '%')
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
        AND (@ClientId IS NULL OR cp.ClientId = @ClientId)
        AND (@CompanyId IS NULL OR cp.CompanyId = @CompanyId)
        AND (@TypeId IS NULL OR cp.TypeId = @TypeId)
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@StartDate IS NULL OR cp.StartDate >= @StartDate)
        AND (@EndDate IS NULL OR cp.EndDate <= @EndDate)
    ORDER BY cp.CreatedDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- Get Policies By Status
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPoliciesByStatus')
    DROP PROCEDURE GetPoliciesByStatus;
GO

CREATE PROCEDURE GetPoliciesByStatus
    @Status NVARCHAR(20),
    @AgentId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.IsActive = 1
        AND cp.Status = @Status
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    ORDER BY cp.EndDate;
END
GO

-- ============================================
-- POLICY MANAGEMENT ACTIONS
-- ============================================

-- Renew Policy
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'RenewPolicy')
    DROP PROCEDURE RenewPolicy;
GO

CREATE PROCEDURE RenewPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @NewStartDate DATE,
    @NewEndDate DATE,
    @NewPolicyName NVARCHAR(100) = NULL,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Update old policy status
        UPDATE ClientPolicies 
        SET Status = 'Renewed', ModifiedDate = GETDATE()
        WHERE PolicyId = @PolicyId;
        
        -- Get policy details for renewal
        DECLARE @ClientId UNIQUEIDENTIFIER, @PolicyName NVARCHAR(100), 
                @PolicyCatalogId UNIQUEIDENTIFIER, @TypeId UNIQUEIDENTIFIER, 
                @CompanyId UNIQUEIDENTIFIER;
        
        SELECT 
            @ClientId = ClientId,
            @PolicyName = ISNULL(@NewPolicyName, PolicyName),
            @PolicyCatalogId = PolicyCatalogId,
            @TypeId = TypeId,
            @CompanyId = CompanyId
        FROM ClientPolicies 
        WHERE PolicyId = @PolicyId;
        
        -- Create new policy
        DECLARE @NewPolicyId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO ClientPolicies (
            PolicyId, ClientId, PolicyName, Status, StartDate, EndDate,
            Notes, PolicyCatalogId, TypeId, CompanyId, IsActive, CreatedDate
        )
        VALUES (
            @NewPolicyId, @ClientId, @PolicyName, 'Active', @NewStartDate, @NewEndDate,
            @Notes, @PolicyCatalogId, @TypeId, @CompanyId, 1, GETDATE()
        );
        
        COMMIT TRANSACTION;
        
        SELECT @NewPolicyId as NewPolicyId, @@ROWCOUNT as RowsAffected;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Bulk Update Policy Status
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'BulkUpdatePolicyStatus')
    DROP PROCEDURE BulkUpdatePolicyStatus;
GO

CREATE PROCEDURE BulkUpdatePolicyStatus
    @PolicyIds NVARCHAR(MAX), -- Comma-separated list of GUIDs
    @NewStatus NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create temp table for policy IDs
    CREATE TABLE #PolicyIdList (PolicyId UNIQUEIDENTIFIER);
    
    -- Parse the comma-separated list
    INSERT INTO #PolicyIdList (PolicyId)
    SELECT TRY_CAST(value AS UNIQUEIDENTIFIER)
    FROM STRING_SPLIT(@PolicyIds, ',')
    WHERE TRY_CAST(value AS UNIQUEIDENTIFIER) IS NOT NULL;
    
    -- Update policies
    UPDATE cp
    SET Status = @NewStatus, ModifiedDate = GETDATE()
    FROM ClientPolicies cp
    INNER JOIN #PolicyIdList pil ON cp.PolicyId = pil.PolicyId;
    
    SELECT @@ROWCOUNT as RowsAffected;
    
    DROP TABLE #PolicyIdList;
END
GO

-- ============================================
-- POLICY TEMPLATES PROCEDURES
-- ============================================

-- Get Policy Templates
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyTemplates')
    DROP PROCEDURE GetPolicyTemplates;
GO

CREATE PROCEDURE GetPolicyTemplates
    @AgentId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pt.TemplateId,
        pt.AgentId,
        pt.TemplateName,
        pt.DefaultTermMonths,
        pt.DefaultPremium,
        pt.CoverageDescription,
        pt.Terms,
        pt.IsActive,
        pt.CreatedDate,
        pt.CategoryId,
        pc.CategoryName,
        pt.PolicyCatalogId,
        pol.PolicyName as CatalogPolicyName,
        pt.TypeId,
        pty.TypeName
    FROM PolicyTemplates pt
        LEFT JOIN PolicyCategories pc ON pt.CategoryId = pc.CategoryId
        LEFT JOIN PolicyCatalog pol ON pt.PolicyCatalogId = pol.PolicyCatalogId
        LEFT JOIN PolicyTypes pty ON pt.TypeId = pty.TypeId
    WHERE (@AgentId IS NULL OR pt.AgentId = @AgentId)
        AND (@CategoryId IS NULL OR pt.CategoryId = @CategoryId)
        AND (@TypeId IS NULL OR pt.TypeId = @TypeId)
        AND (@IsActive IS NULL OR pt.IsActive = @IsActive)
    ORDER BY pt.TemplateName;
END
GO

-- Create Policy Template
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreatePolicyTemplate')
    DROP PROCEDURE CreatePolicyTemplate;
GO

CREATE PROCEDURE CreatePolicyTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(18, 2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @TemplateId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @TemplateId = NEWID();
    
    INSERT INTO PolicyTemplates (
        TemplateId, AgentId, TemplateName, DefaultTermMonths, DefaultPremium,
        CoverageDescription, Terms, CategoryId, PolicyCatalogId, TypeId, IsActive, CreatedDate
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @DefaultTermMonths, @DefaultPremium,
        @CoverageDescription, @Terms, @CategoryId, @PolicyCatalogId, @TypeId, 1, GETDATE()
    );
    
    SELECT @TemplateId as TemplateId;
END
GO

-- Update Policy Template
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdatePolicyTemplate')
    DROP PROCEDURE UpdatePolicyTemplate;
GO

CREATE PROCEDURE UpdatePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100) = NULL,
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(18, 2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyTemplates
    SET 
        TemplateName = ISNULL(@TemplateName, TemplateName),
        DefaultTermMonths = ISNULL(@DefaultTermMonths, DefaultTermMonths),
        DefaultPremium = ISNULL(@DefaultPremium, DefaultPremium),
        CoverageDescription = ISNULL(@CoverageDescription, CoverageDescription),
        Terms = ISNULL(@Terms, Terms),
        CategoryId = ISNULL(@CategoryId, CategoryId),
        PolicyCatalogId = ISNULL(@PolicyCatalogId, PolicyCatalogId),
        TypeId = ISNULL(@TypeId, TypeId),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE TemplateId = @TemplateId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Delete Policy Template
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'DeletePolicyTemplate')
    DROP PROCEDURE DeletePolicyTemplate;
GO

CREATE PROCEDURE DeletePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @HardDelete = 1
    BEGIN
        DELETE FROM PolicyTemplates WHERE TemplateId = @TemplateId;
    END
    ELSE
    BEGIN
        UPDATE PolicyTemplates 
        SET IsActive = 0
        WHERE TemplateId = @TemplateId;
    END
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- ============================================
-- REFERENCE DATA PROCEDURES
-- ============================================

-- Get Insurance Companies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetInsuranceCompanies')
    DROP PROCEDURE GetInsuranceCompanies;
GO

CREATE PROCEDURE GetInsuranceCompanies
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CompanyId,
        CompanyName,
        IsActive,
        CreatedDate
    FROM InsuranceCompanies
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY CompanyName;
END
GO

-- Get Policy Types
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyTypes')
    DROP PROCEDURE GetPolicyTypes;
GO

CREATE PROCEDURE GetPolicyTypes
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        TypeId,
        TypeName,
        IsActive,
        CreatedDate
    FROM PolicyTypes
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY TypeName;
END
GO

-- Get Policy Categories
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyCategories')
    DROP PROCEDURE GetPolicyCategories;
GO

CREATE PROCEDURE GetPolicyCategories
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CategoryId,
        CategoryName,
        Description,
        IsActive,
        CreatedDate
    FROM PolicyCategories
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY CategoryName;
END
GO

-- Create Policy Category
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreatePolicyCategory')
    DROP PROCEDURE CreatePolicyCategory;
GO

CREATE PROCEDURE CreatePolicyCategory
    @CategoryName NVARCHAR(50),
    @Description NVARCHAR(200) = NULL,
    @CategoryId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @CategoryId = NEWID();
    
    INSERT INTO PolicyCategories (
        CategoryId, CategoryName, Description, IsActive, CreatedDate
    )
    VALUES (
        @CategoryId, @CategoryName, @Description, 1, GETDATE()
    );
    
    SELECT @CategoryId as CategoryId;
END
GO

-- ============================================
-- ADDITIONAL RECOMMENDED PROCEDURES
-- ============================================

-- Create Insurance Company
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreateInsuranceCompany')
    DROP PROCEDURE CreateInsuranceCompany;
GO

CREATE PROCEDURE CreateInsuranceCompany
    @CompanyName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @CompanyId = NEWID();
    
    INSERT INTO InsuranceCompanies (
        CompanyId, CompanyName, IsActive, CreatedDate
    )
    VALUES (
        @CompanyId, @CompanyName, 1, GETDATE()
    );
    
    SELECT @CompanyId as CompanyId;
END
GO

-- Create Policy Type
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreatePolicyType')
    DROP PROCEDURE CreatePolicyType;
GO

CREATE PROCEDURE CreatePolicyType
    @TypeName NVARCHAR(50),
    @TypeId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @TypeId = NEWID();
    
    INSERT INTO PolicyTypes (
        TypeId, TypeName, IsActive, CreatedDate
    )
    VALUES (
        @TypeId, @TypeName, 1, GETDATE()
    );
    
    SELECT @TypeId as TypeId;
END
GO

-- Get Policy Renewal Candidates
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyRenewalCandidates')
    DROP PROCEDURE GetPolicyRenewalCandidates;
GO

CREATE PROCEDURE GetPolicyRenewalCandidates
    @AgentId UNIQUEIDENTIFIER = NULL,
    @DaysAhead INT = 60
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry,
        CASE 
            WHEN DATEDIFF(DAY, GETDATE(), cp.EndDate) <= 30 THEN 'Urgent'
            WHEN DATEDIFF(DAY, GETDATE(), cp.EndDate) <= 45 THEN 'Soon'
            ELSE 'Upcoming'
        END as RenewalPriority
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.IsActive = 1
        AND cp.Status = 'Active'
        AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, @DaysAhead, GETDATE())
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    ORDER BY cp.EndDate, RenewalPriority;
END
GO

-- Get Agent Dashboard Summary
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetAgentDashboardSummary')
    DROP PROCEDURE GetAgentDashboardSummary;
GO

ALTER PROCEDURE GetAgentDashboardSummary
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalPolicies INT = 0, 
            @ActivePolicies INT = 0, 
            @ExpiringIn30Days INT = 0, 
            @ExpiringIn60Days INT = 0, 
            @TotalCompanies INT = 0, 
            @TotalClients INT = 0;
    
    -- Get policy counts
    SELECT 
        @TotalPolicies = COUNT(*),
        @ActivePolicies = SUM(CASE WHEN cp.Status = 'Active' AND cp.IsActive = 1 THEN 1 ELSE 0 END),
        @ExpiringIn30Days = SUM(
            CASE 
                WHEN cp.Status = 'Active' 
                     AND cp.IsActive = 1
                     AND cp.EndDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 30, CAST(GETDATE() AS DATE)) 
                THEN 1 ELSE 0 END),
        @ExpiringIn60Days = SUM(
            CASE 
                WHEN cp.Status = 'Active' 
                     AND cp.IsActive = 1
                     AND cp.EndDate BETWEEN DATEADD(DAY, 31, CAST(GETDATE() AS DATE)) AND DATEADD(DAY, 60, CAST(GETDATE() AS DATE)) 
                THEN 1 ELSE 0 END)
    FROM ClientPolicies cp
        INNER JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE pc.AgentId = @AgentId;

    -- Get company count (companies actually used in policies for this agent)
    SELECT @TotalCompanies = COUNT(DISTINCT cp.CompanyId)
    FROM ClientPolicies cp
        INNER JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE pc.AgentId = @AgentId
      AND cp.IsActive = 1
      AND cp.CompanyId IS NOT NULL;

    -- Get client count (all clients of the agent, regardless of policy)
    SELECT @TotalClients = COUNT(*)
    FROM Clients c
    WHERE c.AgentId = @AgentId
      AND c.IsActive = 1;

    -- Final result
    SELECT 
        @TotalPolicies as TotalPolicies,
        @ActivePolicies as ActivePolicies,
        @ExpiringIn30Days as ExpiringIn30Days,
        @ExpiringIn60Days as ExpiringIn60Days,
        @TotalCompanies as TotalCompanies,
        @TotalClients as TotalClients,
        (@TotalPolicies - @ActivePolicies) as InactivePolicies;
END
GO

-- Update Policy Category
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdatePolicyCategory')
    DROP PROCEDURE UpdatePolicyCategory;
GO

CREATE PROCEDURE UpdatePolicyCategory
    @CategoryId UNIQUEIDENTIFIER,
    @CategoryName NVARCHAR(50) = NULL,
    @Description NVARCHAR(200) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyCategories
    SET 
        CategoryName = ISNULL(@CategoryName, CategoryName),
        Description = ISNULL(@Description, Description),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE CategoryId = @CategoryId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Update Insurance Company
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdateInsuranceCompany')
    DROP PROCEDURE UpdateInsuranceCompany;
GO

CREATE PROCEDURE UpdateInsuranceCompany
    @CompanyId UNIQUEIDENTIFIER,
    @CompanyName NVARCHAR(100) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE InsuranceCompanies
    SET 
        CompanyName = ISNULL(@CompanyName, CompanyName),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE CompanyId = @CompanyId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Update Policy Type
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdatePolicyType')
    DROP PROCEDURE UpdatePolicyType;
GO

CREATE PROCEDURE UpdatePolicyType
    @TypeId UNIQUEIDENTIFIER,
    @TypeName NVARCHAR(50) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyTypes
    SET 
        TypeName = ISNULL(@TypeName, TypeName),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE TypeId = @TypeId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Get Policy History for Client
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyHistoryForClient')
    DROP PROCEDURE GetPolicyHistoryForClient;
GO

CREATE PROCEDURE GetPolicyHistoryForClient
    @ClientId UNIQUEIDENTIFIER,
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        DATEDIFF(DAY, cp.StartDate, cp.EndDate) as PolicyDurationDays,
        CASE 
            WHEN cp.Status = 'Active' AND cp.EndDate > GETDATE() THEN 'Current'
            WHEN cp.Status = 'Active' AND cp.EndDate <= GETDATE() THEN 'Expired'
            ELSE cp.Status
        END as PolicyState
    FROM ClientPolicies cp
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.ClientId = @ClientId
        AND (@IncludeInactive = 1 OR cp.IsActive = 1)
    ORDER BY cp.StartDate DESC, cp.CreatedDate DESC;
END
GO

-- Batch Expire Policies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'BatchExpirePolicies')
    DROP PROCEDURE BatchExpirePolicies;
GO

CREATE PROCEDURE BatchExpirePolicies
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @AsOfDate = ISNULL(@AsOfDate, GETDATE());
    
    UPDATE ClientPolicies
    SET Status = 'Expired', ModifiedDate = GETDATE()
    WHERE Status = 'Active' 
        AND EndDate < @AsOfDate
        AND IsActive = 1;
    
    SELECT @@ROWCOUNT as PoliciesExpired;
END
GO

-- ============================================
-- UTILITY PROCEDURES
-- ============================================

-- Cleanup Soft Deleted Records
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CleanupSoftDeletedRecords')
    DROP PROCEDURE CleanupSoftDeletedRecords;
GO

CREATE PROCEDURE CleanupSoftDeletedRecords
    @DaysOld INT = 365,
    @DryRun BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@DaysOld, GETDATE());
    
    IF @DryRun = 1
    BEGIN
        -- Show what would be deleted
        SELECT 'ClientPolicies' as TableName, COUNT(*) as RecordsToDelete
        FROM ClientPolicies 
        WHERE IsActive = 0 AND ModifiedDate < @CutoffDate
        
        UNION ALL
        
        SELECT 'PolicyCatalog' as TableName, COUNT(*) as RecordsToDelete
        FROM PolicyCatalog 
        WHERE IsActive = 0 AND ModifiedDate < @CutoffDate
        
        UNION ALL
        
        SELECT 'PolicyTemplates' as TableName, COUNT(*) as RecordsToDelete
        FROM PolicyTemplates 
        WHERE IsActive = 0 AND CreatedDate < @CutoffDate;
    END
    ELSE
    BEGIN
        -- Actually delete the records
        DECLARE @DeletedCount INT = 0;
        
        DELETE FROM ClientPolicies 
        WHERE IsActive = 0 AND ModifiedDate < @CutoffDate;
        SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
        
        DELETE FROM PolicyCatalog 
        WHERE IsActive = 0 AND ModifiedDate < @CutoffDate;
        SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
        
        DELETE FROM PolicyTemplates 
        WHERE IsActive = 0 AND CreatedDate < @CutoffDate;
        SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
        
        SELECT @DeletedCount as TotalRecordsDeleted;
    END
END
GO

-- ============================================
-- END OF STORED PROCEDURES
-- ============================================

PRINT 'All Aminius Insurance Management stored procedures have been created successfully!';
GO

-- ============================================
-- 1. Create Insurance Company
-- ============================================
CREATE OR ALTER PROCEDURE sp_CreateInsuranceCompany
    @CompanyName NVARCHAR(100),
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO InsuranceCompanies (CompanyId, CompanyName, IsActive, CreatedDate)
    VALUES (NEWID(), @CompanyName, @IsActive, GETDATE());
END
GO

-- ============================================
-- 2. Get All Insurance Companies
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetInsuranceCompanies
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CompanyId, CompanyName, IsActive, CreatedDate
    FROM InsuranceCompanies
    ORDER BY CompanyName;
END
GO

-- ============================================
-- 3. Get Insurance Company by ID
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetInsuranceCompanyById
    @CompanyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CompanyId, CompanyName, IsActive, CreatedDate
    FROM InsuranceCompanies
    WHERE CompanyId = @CompanyId;
END
GO

-- ============================================
-- 4. Update Insurance Company
-- ============================================
CREATE OR ALTER PROCEDURE sp_UpdateInsuranceCompany
    @CompanyId UNIQUEIDENTIFIER,
    @CompanyName NVARCHAR(100),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE InsuranceCompanies
    SET CompanyName = @CompanyName,
        IsActive = @IsActive
    WHERE CompanyId = @CompanyId;
END
GO

-- ============================================
-- 5. Delete Insurance Company (Soft Delete)
-- ============================================
CREATE OR ALTER PROCEDURE sp_DeleteInsuranceCompany
    @CompanyId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @HardDelete = 1
    BEGIN
        DELETE FROM InsuranceCompanies
        WHERE CompanyId = @CompanyId;
    END
    ELSE
    BEGIN
        UPDATE InsuranceCompanies
        SET IsActive = 0
        WHERE CompanyId = @CompanyId;
    END
END
GO
-- ============================================
-- 1. Create Policy Category
-- ============================================
CREATE OR ALTER PROCEDURE sp_CreatePolicyCategory
    @CategoryName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO PolicyCategories (CategoryId, CategoryName, CompanyId, IsActive, CreatedDate)
    VALUES (NEWID(), @CategoryName, @CompanyId, @IsActive, GETDATE());
END
GO

-- ============================================
-- 2. Get All Policy Categories
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetPolicyCategories
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CategoryId, c.CategoryName, c.CompanyId, ic.CompanyName, c.IsActive, c.CreatedDate
    FROM PolicyCategories c
    INNER JOIN InsuranceCompanies ic ON c.CompanyId = ic.CompanyId
    ORDER BY ic.CompanyName, c.CategoryName;
END
GO

-- ============================================
-- 3. Get Policy Category by ID
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetPolicyCategoryById
    @CategoryId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CategoryId, c.CategoryName, c.CompanyId, ic.CompanyName, c.IsActive, c.CreatedDate
    FROM PolicyCategories c
    INNER JOIN InsuranceCompanies ic ON c.CompanyId = ic.CompanyId
    WHERE c.CategoryId = @CategoryId;
END
GO

-- ============================================
-- 4. Update Policy Category
-- ============================================
CREATE OR ALTER PROCEDURE sp_UpdatePolicyCategory
    @CategoryId UNIQUEIDENTIFIER,
    @CategoryName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER,
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCategories
    SET CategoryName = @CategoryName,
        CompanyId = @CompanyId,
        IsActive = @IsActive
    WHERE CategoryId = @CategoryId;
END
GO

-- ============================================
-- 5. Delete Policy Category (Soft Delete)
-- ============================================
CREATE OR ALTER PROCEDURE sp_DeletePolicyCategory
    @CategoryId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @HardDelete = 1
    BEGIN
        DELETE FROM PolicyCategories
        WHERE CategoryId = @CategoryId;
    END
    ELSE
    BEGIN
        UPDATE PolicyCategories
        SET IsActive = 0
        WHERE CategoryId = @CategoryId;
    END
END
GO
-- ============================================
-- Create Policy Type (GUID Primary Key)
-- ============================================
CREATE OR ALTER PROCEDURE sp_CreatePolicyType
    @TypeName NVARCHAR(50),
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewId UNIQUEIDENTIFIER = NEWID();

    INSERT INTO PolicyTypes (TypeId, TypeName, IsActive)
    VALUES (@NewId, @TypeName, @IsActive);

    SELECT * FROM PolicyTypes WHERE TypeId = @NewId;
END
GO


-- ============================================
-- Get All Policy Types
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetPolicyTypes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM PolicyTypes
    ORDER BY CreatedDate DESC;
END
GO

-- ============================================
-- Get Policy Type By Id
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetPolicyTypeById
    @TypeId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM PolicyTypes
    WHERE TypeId = @TypeId;
END
GO

-- ============================================
-- Update Policy Type
-- ============================================
CREATE OR ALTER PROCEDURE sp_UpdatePolicyType
    @TypeId UNIQUEIDENTIFIER,
    @TypeName NVARCHAR(50),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyTypes
    SET TypeName = @TypeName,
        IsActive = @IsActive
    WHERE TypeId = @TypeId;
END
GO

-- ============================================
-- Delete Policy Type
-- ============================================
CREATE OR ALTER PROCEDURE sp_DeletePolicyType
    @TypeId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM PolicyTypes
    WHERE TypeId = @TypeId;
END
GO



CREATE OR ALTER PROCEDURE sp_SoftDeletePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyTemplates
    SET IsActive = 0
    WHERE TemplateId = @TemplateId;
END

GO

CREATE OR ALTER PROCEDURE sp_SoftDeletePolicyCatalog
    @PolicyCatalogId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCatalog
    SET IsActive = 0,
        ModifiedDate = GETDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId;
END

GO

CREATE OR ALTER PROCEDURE sp_SoftDeletePolicyCategory
    @CategoryId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCategories
    SET IsActive = 0
    WHERE CategoryId = @CategoryId;
END

GO

CREATE OR ALTER PROCEDURE sp_SoftDeleteInsuranceCompany
    @CompanyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE InsuranceCompanies
    SET IsActive = 0
    WHERE CompanyId = @CompanyId;
END

GO

CREATE OR ALTER PROCEDURE sp_SoftDeleteClientPolicy
    @PolicyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ClientPolicies
    SET IsActive = 0,
        ModifiedDate = GETDATE()
    WHERE PolicyId = @PolicyId;
END
GO


CREATE PROCEDURE ClientPolicies_SoftDelete
    @PolicyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ClientPolicies
    SET IsActive = 0,
        ModifiedDate = GETDATE()
    WHERE PolicyId = @PolicyId AND IsActive = 1;
END;
go
CREATE PROCEDURE InsuranceCompanies_SoftDelete
    @CompanyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE InsuranceCompanies
    SET IsActive = 0,
        CreatedDate = CreatedDate -- keep original
    WHERE CompanyId = @CompanyId AND IsActive = 1;
END;
go
CREATE PROCEDURE PolicyCatalog_SoftDelete
    @PolicyCatalogId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCatalog
    SET IsActive = 0,
        ModifiedDate = GETDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId AND IsActive = 1;
END;
go
CREATE PROCEDURE PolicyCategories_SoftDelete
    @CategoryId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCategories
    SET IsActive = 0
    WHERE CategoryId = @CategoryId AND IsActive = 1;
END;
go 
CREATE PROCEDURE PolicyTemplates_SoftDelete
    @TemplateId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyTemplates
    SET IsActive = 0,
        CreatedDate = CreatedDate -- preserve
    WHERE TemplateId = @TemplateId AND IsActive = 1;
END;
go 
CREATE PROCEDURE PolicyTypes_SoftDelete
    @TypeId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyTypes
    SET IsActive = 0
    WHERE TypeId = @TypeId AND IsActive = 1;
END;
go
exec GetClientsWithPolicies
go
ALTER PROCEDURE GetClientsWithPolicies
    @AgentId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        c.ClientId,
        c.AgentId,
        c.FirstName,
        c.Surname,
        c.LastName,
        (c.FirstName + ' ' + c.Surname + ' ' + c.LastName) AS FullName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.NationalId,
        c.DateOfBirth,
        c.IsClient,
        c.InsuranceType,
        c.Notes AS ClientNotes,
        c.CreatedDate AS ClientCreatedDate,
        c.ModifiedDate AS ClientModifiedDate,
        c.IsActive AS ClientIsActive,

        cp.PolicyId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes AS PolicyNotes,
        cp.CreatedDate AS PolicyCreatedDate,
        cp.ModifiedDate AS PolicyModifiedDate,
        cp.IsActive AS PolicyIsActive,
        cp.PolicyCatalogId,
        pc.PolicyName AS CatalogPolicyName,
        cp.TypeId,
        pt.TypeName,
        cp.CompanyId,
        ic.CompanyName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
    FROM Clients c
        INNER JOIN ClientPolicies cp 
            ON c.ClientId = cp.ClientId
           AND cp.PolicyId IS NOT NULL
           AND cp.CompanyId IS NOT NULL
           AND cp.TypeId IS NOT NULL  -- ✅ ensure valid policy only
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        (@AgentId IS NULL OR c.AgentId = @AgentId)
        AND (@ClientId IS NULL OR c.ClientId = @ClientId)
        AND (
            @IncludeInactive = 1 
            OR (c.IsActive = 1 AND cp.IsActive = 1)
        )
    ORDER BY c.CreatedDate DESC, cp.EndDate DESC;
END;
GO


exec GetClientsWithPolicies
go
ALTER PROCEDURE GetAgentDashboardSummary
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalPolicies INT = 0,
            @ActivePolicies INT = 0,
            @ExpiringIn30Days INT = 0,
            @ExpiringIn60Days INT = 0,
            @TotalCompanies INT = 0,
            @TotalClients INT = 0;

    ;WITH AgentPolicies AS (
        SELECT
            cp.PolicyId,
            cp.ClientId,
            cp.CompanyId,
            cp.StartDate,
            cp.EndDate,
            -- normalize status once
            UPPER(LTRIM(RTRIM(cp.Status))) AS NormStatus,
            -- treat NULL as active
            CASE WHEN ISNULL(cp.IsActive, 1) = 1 THEN 1 ELSE 0 END AS IsActiveFlag
        FROM ClientPolicies cp
        INNER JOIN Clients c
            ON c.ClientId = cp.ClientId
        WHERE c.AgentId = @AgentId
          -- policy considered present in the dashboard only if (NULL -> active) or explicitly active
          AND ISNULL(cp.IsActive, 1) = 1
    )
    SELECT
        @TotalPolicies =
            COUNT(*),
        @ActivePolicies =
            SUM(CASE
                    WHEN NormStatus = 'ACTIVE'
                         AND EndDate >= CAST(GETDATE() AS DATE)
                    THEN 1 ELSE 0
                END),
        @ExpiringIn30Days =
            SUM(CASE
                    WHEN NormStatus = 'ACTIVE'
                         AND EndDate BETWEEN CAST(GETDATE() AS DATE)
                                         AND DATEADD(DAY, 30, CAST(GETDATE() AS DATE))
                    THEN 1 ELSE 0
                END),
        @ExpiringIn60Days =
            SUM(CASE
                    WHEN NormStatus = 'ACTIVE'
                         AND EndDate BETWEEN DATEADD(DAY, 31, CAST(GETDATE() AS DATE))
                                         AND DATEADD(DAY, 60, CAST(GETDATE() AS DATE))
                    THEN 1 ELSE 0
                END),
        @TotalCompanies =
            COUNT(DISTINCT CASE WHEN CompanyId IS NOT NULL THEN CompanyId END)
    FROM AgentPolicies;

    -- Count all active clients for this agent (not only those with policies)
    SELECT @TotalClients = COUNT(*)
    FROM Clients c
    WHERE c.AgentId = @AgentId
      AND ISNULL(c.IsActive, 1) = 1;

    SELECT
        @TotalPolicies      AS TotalPolicies,
        @ActivePolicies     AS ActivePolicies,
        @ExpiringIn30Days   AS ExpiringIn30Days,
        @ExpiringIn60Days   AS ExpiringIn60Days,
        @TotalCompanies     AS TotalCompanies,
        @TotalClients       AS TotalClients,
        (@TotalPolicies - @ActivePolicies) AS InactivePolicies;
END
GO
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
CREATE OR ALTER PROCEDURE sp_GetAllReminders
(
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 20
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AllReminders AS
    (
        -- 1. Manual Reminders from Reminders table
        SELECT 
            r.ReminderId,
            r.ClientId,
            r.AppointmentId,
            r.AgentId,
            CASE WHEN r.ReminderType = 'Policy Expiry' THEN 'Maturing Policy' ELSE r.ReminderType END AS ReminderType,
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
            r.CompletedDate
        FROM Reminders r
        WHERE r.AgentId = @AgentId

        UNION ALL

        -- 2. Maturing Policies (fix: join Clients to get AgentId)
        SELECT 
            NEWID() AS ReminderId,
            cp.ClientId,
            NULL AS AppointmentId,
            c.AgentId,  -- <-- get AgentId from Clients table
            'Maturing Policy' AS ReminderType,
            cp.PolicyName AS Title,
            CONCAT('Policy for ', cp.PolicyName, ' is maturing soon') AS Description,
            cp.EndDate AS ReminderDate,
            NULL AS ReminderTime,
            CONCAT(c.FirstName, ' ', c.LastName) AS ClientName,
            'High' AS Priority,
            'Active' AS Status,
            0, 0, 1, '7 days', NULL, 0, NULL,
            GETDATE(), GETDATE(), NULL
        FROM ClientPolicies cp
        INNER JOIN Clients c ON c.ClientId = cp.ClientId
        WHERE c.AgentId = @AgentId
          AND cp.IsActive = 1
          AND (@StartDate IS NULL OR cp.EndDate >= @StartDate)
          AND (@EndDate IS NULL OR cp.EndDate <= @EndDate)

        UNION ALL

        -- 3. Birthdays (next 7 days)
        SELECT 
            NEWID() AS ReminderId,
            c.ClientId,
            NULL AS AppointmentId,
            c.AgentId,
            'Birthday' AS ReminderType,
            'Birthday Reminder' AS Title,
            CONCAT('Wish ', c.FirstName, ' ', c.LastName, ' a Happy Birthday!') AS Description,
            DATEFROMPARTS(YEAR(GETDATE()), MONTH(c.DateOfBirth), DAY(c.DateOfBirth)) AS ReminderDate,
            NULL AS ReminderTime,
            CONCAT(c.FirstName, ' ', c.LastName) AS ClientName,
            'Low' AS Priority,
            'Active' AS Status,
            0, 0, 1, '1 day', NULL, 0, NULL,
            GETDATE(), GETDATE(), NULL
        FROM Clients c
        WHERE c.AgentId = @AgentId
          AND c.IsActive = 1
          AND DATEFROMPARTS(YEAR(GETDATE()), MONTH(c.DateOfBirth), DAY(c.DateOfBirth))
              BETWEEN GETDATE() AND DATEADD(DAY, 7, GETDATE())

        UNION ALL

        -- 4. Appointments
        SELECT 
            NEWID() AS ReminderId,
            a.ClientId,
            a.AppointmentId,
            a.AgentId,
            'Appointment' AS ReminderType,
            a.Title,
            a.Description,
            a.AppointmentDate AS ReminderDate,
            a.StartTime AS ReminderTime,
            a.ClientName,
            a.Priority,
            a.Status,
            0, 0, 1, '1 day', NULL, 0, a.Notes,
            a.CreatedDate,
            a.ModifiedDate,
            NULL
        FROM Appointments a
        WHERE a.AgentId = @AgentId
          AND a.IsActive = 1
          AND (@StartDate IS NULL OR a.AppointmentDate >= @StartDate)
          AND (@EndDate IS NULL OR a.AppointmentDate <= @EndDate)
    )

    -- Pagination
    SELECT *
    FROM (
        SELECT 
            ROW_NUMBER() OVER (ORDER BY ReminderDate ASC, ReminderTime ASC) AS RowNum,
            *
        FROM AllReminders
    ) AS Paged
    WHERE RowNum BETWEEN ((@PageNumber - 1) * @PageSize + 1) AND (@PageNumber * @PageSize)
    ORDER BY ReminderDate ASC, ReminderTime ASC;
END;
GO

go

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
CREATE OR ALTER PROCEDURE sp_GetReminderStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        (SELECT COUNT(*) FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active') AS TotalActive,
        (SELECT COUNT(*) FROM Reminders WHERE AgentId = @AgentId AND Status = 'Completed') AS TotalCompleted,
        (SELECT COUNT(*) FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active' AND ReminderDate = CAST(GETDATE() AS DATE)) AS TodayReminders,
        (SELECT COUNT(*) FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active' AND ReminderDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 7, CAST(GETDATE() AS DATE))) AS UpcomingReminders,
        (SELECT COUNT(*) FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active' AND Priority = 'High') AS HighPriority,
        (SELECT COUNT(*) FROM Reminders WHERE AgentId = @AgentId AND Status = 'Active' AND ReminderDate < CAST(GETDATE() AS DATE)) AS Overdue;
END;
go
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

CREATE OR ALTER PROCEDURE spGetRemindersByType
    @AgentId UNIQUEIDENTIFIER,
    @ReminderType NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        R.ReminderId,
        R.ClientId,
        R.AppointmentId,
        R.AgentId,
        R.ReminderType,
        R.Title,
        R.Description,
        R.ReminderDate,
        R.ReminderTime,
        R.ClientName,
        R.Priority,
        R.Status,
        R.EnableSMS,
        R.EnableWhatsApp,
        R.EnablePushNotification,
        R.AdvanceNotice,
        R.CustomMessage,
        R.AutoSend,
        R.Notes,
        R.CreatedDate,
        R.ModifiedDate,
        R.CompletedDate
    FROM Reminders R
    WHERE R.AgentId = @AgentId
      AND R.ReminderType = @ReminderType
    ORDER BY R.ReminderDate, R.ReminderTime;
END;
go
CREATE OR ALTER PROCEDURE spGetRemindersByStatus
    @AgentId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        R.ReminderId,
        R.ClientId,
        R.AppointmentId,
        R.AgentId,
        R.ReminderType,
        R.Title,
        R.Description,
        R.ReminderDate,
        R.ReminderTime,
        R.ClientName,
        R.Priority,
        R.Status,
        R.EnableSMS,
        R.EnableWhatsApp,
        R.EnablePushNotification,
        R.AdvanceNotice,
        R.CustomMessage,
        R.AutoSend,
        R.Notes,
        R.CreatedDate,
        R.ModifiedDate,
        R.CompletedDate
    FROM Reminders R
    WHERE R.AgentId = @AgentId
      AND R.Status = @Status
    ORDER BY R.ReminderDate, R.ReminderTime;
END;
go

-- Get Daily Notes
CREATE OR ALTER PROCEDURE sp_GetDailyNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
END;
GO

-- Save Daily Notes
CREATE OR ALTER PROCEDURE sp_SaveDailyNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE,
    @Notes NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM DailyNotes WHERE AgentId = @AgentId AND NoteDate = @NoteDate)
    BEGIN
        UPDATE DailyNotes 
        SET 
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
    END
    ELSE
    BEGIN
        INSERT INTO DailyNotes (AgentId, NoteDate, Notes)
        VALUES (@AgentId, @NoteDate, @Notes);
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get All Notes
CREATE OR ALTER PROCEDURE sp_GetAllNotes
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(MONTH, -3, GETDATE()); -- Last 3 months default
    
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE 
        AgentId = @AgentId 
        AND NoteDate BETWEEN @StartDate AND @EndDate
    ORDER BY NoteDate DESC;
END;
GO

-- Search Notes
CREATE OR ALTER PROCEDURE sp_SearchNotes
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE 
        AgentId = @AgentId 
        AND Notes LIKE '%' + @SearchTerm + '%'
    ORDER BY NoteDate DESC;
END;
GO

-- Delete Notes
CREATE OR ALTER PROCEDURE sp_DeleteNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DELETE FROM DailyNotes 
    WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
    
    SELECT @@ROWCOUNT AS RowsAffected;
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
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
END;
GO

-- Save Daily Notes
CREATE OR ALTER PROCEDURE sp_SaveDailyNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE,
    @Notes NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM DailyNotes WHERE AgentId = @AgentId AND NoteDate = @NoteDate)
    BEGIN
        UPDATE DailyNotes 
        SET 
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
    END
    ELSE
    BEGIN
        INSERT INTO DailyNotes (AgentId, NoteDate, Notes)
        VALUES (@AgentId, @NoteDate, @Notes);
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get All Notes
CREATE OR ALTER PROCEDURE sp_GetAllNotes
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(MONTH, -3, GETDATE()); -- Last 3 months default
    
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE 
        AgentId = @AgentId 
        AND NoteDate BETWEEN @StartDate AND @EndDate
    ORDER BY NoteDate DESC;
END;
GO

-- Search Notes
CREATE OR ALTER PROCEDURE sp_SearchNotes
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE 
        AgentId = @AgentId 
        AND Notes LIKE '%' + @SearchTerm + '%'
    ORDER BY NoteDate DESC;
END;
GO

-- Delete Notes
CREATE OR ALTER PROCEDURE sp_DeleteNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DELETE FROM DailyNotes 
    WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

CREATE PROCEDURE GetNavbarBadgeCounts
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        -- Clients (only active ones)
        ClientsCount = COUNT(DISTINCT CASE WHEN c.IsActive = 1 THEN c.ClientId END),

        -- Policies (only active)
        PoliciesCount = COUNT(DISTINCT CASE WHEN p.IsActive = 1 THEN p.PolicyId END),

        -- Reminders (pending/active)
        RemindersCount = COUNT(DISTINCT CASE WHEN r.Status = 'Active' THEN r.ReminderId END),

        -- Appointments (upcoming or active)
        AppointmentsCount = COUNT(DISTINCT CASE 
                            WHEN a.IsActive = 1 
                                 AND a.Status NOT IN ('Completed', 'Cancelled') 
                            THEN a.AppointmentId END)
    FROM (SELECT 1 AS dummy) d
    LEFT JOIN Clients c 
        ON c.AgentId = @AgentId
    LEFT JOIN ClientPolicies p 
        ON p.ClientId = c.ClientId
    LEFT JOIN Reminders r 
        ON r.AgentId = @AgentId
    LEFT JOIN Appointments a 
        ON a.AgentId = @AgentId;
END;
GO

-- Global Search
CREATE OR ALTER PROCEDURE sp_GlobalSearch
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Search Clients
    SELECT 
        'Client' AS EntityType,
        ClientId AS EntityId,
        FirstName + ' ' + Surname AS Title,
        Email AS Subtitle,
        PhoneNumber AS Detail1,
        Address AS Detail2,
        CASE WHEN IsClient = 1 THEN 'Client' ELSE 'Prospect' END AS Status
    FROM Clients
    WHERE AgentId = @AgentId 
        AND IsActive = 1
        AND (
            FirstName LIKE '%' + @SearchTerm + '%' OR
            Surname LIKE '%' + @SearchTerm + '%' OR
            LastName LIKE '%' + @SearchTerm + '%' OR
            Email LIKE '%' + @SearchTerm + '%' OR
            PhoneNumber LIKE '%' + @SearchTerm + '%' OR
            NationalId LIKE '%' + @SearchTerm + '%'
        )
    
    UNION ALL
    
    -- Search Appointments
    SELECT 
        'Appointment' AS EntityType,
        AppointmentId AS EntityId,
        Title,
        ClientName AS Subtitle,
        CAST(AppointmentDate AS NVARCHAR) AS Detail1,
        Location AS Detail2,
        Status
    FROM Appointments a
    INNER JOIN Clients c ON a.ClientId = c.ClientId
    WHERE c.AgentId = @AgentId 
        AND a.IsActive = 1
        AND (
            a.Title LIKE '%' + @SearchTerm + '%' OR
            a.ClientName LIKE '%' + @SearchTerm + '%' OR
            a.Description LIKE '%' + @SearchTerm + '%' OR
            a.Location LIKE '%' + @SearchTerm + '%'
        )
    
    UNION ALL
    
    -- Search Policies
    SELECT 
        'Policy' AS EntityType,
        PolicyCatalogId AS EntityId,
        PolicyName AS Title,
        PolicyType AS Subtitle,
        CompanyName AS Detail1,
        '' AS Detail2,
        CASE WHEN IsActive = 1 THEN 'Active' ELSE 'Inactive' END AS Status
    FROM PolicyCatalog
    WHERE AgentId = @AgentId
        AND (
            PolicyName LIKE '%' + @SearchTerm + '%' OR
            PolicyType LIKE '%' + @SearchTerm + '%' OR
            CompanyName LIKE '%' + @SearchTerm + '%' OR
            Notes LIKE '%' + @SearchTerm + '%'
        )
    
    UNION ALL
    
    -- Search Reminders
    SELECT 
        'Reminder' AS EntityType,
        ReminderId AS EntityId,
        Title,
        ClientName AS Subtitle,
        CAST(ReminderDate AS NVARCHAR) AS Detail1,
        ReminderType AS Detail2,
        Status
    FROM Reminders
    WHERE AgentId = @AgentId
        AND (
            Title LIKE '%' + @SearchTerm + '%' OR
            ClientName LIKE '%' + @SearchTerm + '%' OR
            Description LIKE '%' + @SearchTerm + '%' OR
            ReminderType LIKE '%' + @SearchTerm + '%'
        )
    ORDER BY EntityType, Title;
END;
GO

-- Search Clients
CREATE OR ALTER PROCEDURE sp_SearchClients
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ClientId,
        FirstName,
        Surname,
        LastName,
        PhoneNumber,
        Email,
        Address,
        NationalId,
        DateOfBirth,
        IsClient,
        InsuranceType,
        Notes,
        CreatedDate,
        ModifiedDate,
        CASE WHEN IsClient = 1 THEN 'Client' ELSE 'Prospect' END AS ClientType
    FROM Clients
    WHERE AgentId = @AgentId 
        AND IsActive = 1
        AND (
            FirstName LIKE '%' + @SearchTerm + '%' OR
            Surname LIKE '%' + @SearchTerm + '%' OR
            LastName LIKE '%' + @SearchTerm + '%' OR
            Email LIKE '%' + @SearchTerm + '%' OR
            PhoneNumber LIKE '%' + @SearchTerm + '%' OR
            NationalId LIKE '%' + @SearchTerm + '%' OR
            Address LIKE '%' + @SearchTerm + '%' OR
            InsuranceType LIKE '%' + @SearchTerm + '%'
        )
    ORDER BY IsClient DESC, FirstName, Surname;
END;
GO

-- Search Appointments
CREATE OR ALTER PROCEDURE sp_SearchAppointments
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        a.AppointmentId,
        a.ClientId,
        a.ClientName,
        a.ClientPhone,
        a.Title,
        a.Description,
        a.AppointmentDate,
        a.StartTime,
        a.EndTime,
        a.Location,
        a.Type,
        a.Status,
        a.Priority,
        a.Notes,
        a.CreatedDate
    FROM Appointments a
    INNER JOIN Clients c ON a.ClientId = c.ClientId
    WHERE c.AgentId = @AgentId 
        AND a.IsActive = 1
        AND (
            a.Title LIKE '%' + @SearchTerm + '%' OR
            a.ClientName LIKE '%' + @SearchTerm + '%' OR
            a.Description LIKE '%' + @SearchTerm + '%' OR
            a.Location LIKE '%' + @SearchTerm + '%' OR
            a.Type LIKE '%' + @SearchTerm + '%'
        )
    ORDER BY a.AppointmentDate DESC, a.StartTime;
END;
GO

-- Search Policies
CREATE OR ALTER PROCEDURE sp_SearchPolicies
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        PolicyCatalogId,
        PolicyName,
        PolicyType,
        CompanyId,
        CompanyName,
        Notes,
        IsActive,
        CreatedDate,
        ModifiedDate
    FROM PolicyCatalog
    WHERE AgentId = @AgentId
        AND (
            PolicyName LIKE '%' + @SearchTerm + '%' OR
            PolicyType LIKE '%' + @SearchTerm + '%' OR
            CompanyName LIKE '%' + @SearchTerm + '%' OR
            Notes LIKE '%' + @SearchTerm + '%'
        )
    ORDER BY PolicyName;
END;
GO

-- Search Reminders
CREATE OR ALTER PROCEDURE sp_SearchReminders
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ReminderId,
        ClientId,
        AppointmentId,
        ReminderType,
        Title,
        Description,
        ReminderDate,
        ReminderTime,
        ClientName,
        Priority,
        Status,
        Notes,
        CreatedDate
    FROM Reminders
    WHERE AgentId = @AgentId
        AND (
            Title LIKE '%' + @SearchTerm + '%' OR
            ClientName LIKE '%' + @SearchTerm + '%' OR
            Description LIKE '%' + @SearchTerm + '%' OR
            ReminderType LIKE '%' + @SearchTerm + '%' OR
            Notes LIKE '%' + @SearchTerm + '%'
        )
    ORDER BY ReminderDate DESC;
END;
GO

-- Get Search Suggestions
CREATE OR ALTER PROCEDURE sp_GetSearchSuggestions
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500),
    @MaxResults INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@MaxResults) DISTINCT Suggestion
    FROM (
        SELECT FirstName AS Suggestion FROM Clients WHERE AgentId = @AgentId AND FirstName LIKE @SearchTerm + '%'
        UNION
        SELECT Surname FROM Clients WHERE AgentId = @AgentId AND Surname LIKE @SearchTerm + '%'
        UNION
        SELECT Email FROM Clients WHERE AgentId = @AgentId AND Email LIKE @SearchTerm + '%'
        UNION
        SELECT InsuranceType FROM Clients WHERE AgentId = @AgentId AND InsuranceType LIKE @SearchTerm + '%'
        UNION
        SELECT PolicyName FROM PolicyCatalog WHERE AgentId = @AgentId AND PolicyName LIKE @SearchTerm + '%'
        UNION
        SELECT PolicyType FROM PolicyCatalog WHERE AgentId = @AgentId AND PolicyType LIKE @SearchTerm + '%'
        UNION
        SELECT CompanyName FROM PolicyCatalog WHERE AgentId = @AgentId AND CompanyName LIKE @SearchTerm + '%'
    ) AS Suggestions
    ORDER BY Suggestion;
END;
GO

-- Save Search History
CREATE OR ALTER PROCEDURE sp_SaveSearchHistory
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create search history table if it doesn't exist
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SearchHistory]') AND type in (N'U'))
    BEGIN
        CREATE TABLE SearchHistory (
            HistoryId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
            AgentId UNIQUEIDENTIFIER NOT NULL,
            SearchTerm NVARCHAR(500) NOT NULL,
            SearchCount INT DEFAULT 1,
            LastSearched DATETIME2 DEFAULT GETUTCDATE(),
            FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
        );
    END
    
    IF EXISTS (SELECT 1 FROM SearchHistory WHERE AgentId = @AgentId AND SearchTerm = @SearchTerm)
    BEGIN
        UPDATE SearchHistory 
        SET 
            SearchCount = SearchCount + 1,
            LastSearched = GETUTCDATE()
        WHERE AgentId = @AgentId AND SearchTerm = @SearchTerm;
    END
    ELSE
    BEGIN
        INSERT INTO SearchHistory (AgentId, SearchTerm)
        VALUES (@AgentId, @SearchTerm);
    END
END;
GO

-- Get Search History
CREATE OR ALTER PROCEDURE sp_GetSearchHistory
    @AgentId UNIQUEIDENTIFIER,
    @MaxResults INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@MaxResults)
        SearchTerm,
        SearchCount,
        LastSearched
    FROM SearchHistory
    WHERE AgentId = @AgentId
    ORDER BY LastSearched DESC;
END;
GO
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

-- ============================================
-- Validation Service Stored Procedures
-- ============================================

-- Validate Email
CREATE OR ALTER PROCEDURE sp_ValidateEmail
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IsValid BIT = 0;
    DECLARE @ValidationMessage NVARCHAR(200) = '';
    
    IF @Email IS NULL OR @Email = ''
    BEGIN
        SET @ValidationMessage = 'Email cannot be empty';
    END
    ELSE IF CHARINDEX('@', @Email) = 0 OR CHARINDEX('.', @Email) = 0
    BEGIN
        SET @ValidationMessage = 'Invalid email format';
    END
    ELSE IF LEN(@Email) > 100
    BEGIN
        SET @ValidationMessage = 'Email too long (max 100 characters)';
    END
    ELSE
    BEGIN
        SET @IsValid = 1;
        SET @ValidationMessage = 'Valid email';
    END
    
    SELECT 
        @IsValid AS IsValid,
        @ValidationMessage AS ValidationMessage;
END;
GO

-- Validate National ID (Kenya format)
CREATE OR ALTER PROCEDURE sp_ValidateNationalId
    @NationalId NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IsValid BIT = 0;
    DECLARE @ValidationMessage NVARCHAR(200) = '';
    
    -- Remove spaces and convert to upper case
    SET @NationalId = UPPER(REPLACE(@NationalId, ' ', ''));
    
    IF @NationalId IS NULL OR @NationalId = ''
    BEGIN
        SET @ValidationMessage = 'National ID cannot be empty';
    END
    ELSE IF LEN(@NationalId) < 7 OR LEN(@NationalId) > 8
    BEGIN
        SET @ValidationMessage = 'National ID must be 7-8 characters long';
    END
    ELSE IF @NationalId NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' AND @NationalId NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
    BEGIN
        SET @ValidationMessage = 'National ID must contain only numbers';
    END
    ELSE
    BEGIN
        SET @IsValid = 1;
        SET @ValidationMessage = 'Valid National ID';
    END
    
    SELECT 
        @IsValid AS IsValid,
        @ValidationMessage AS ValidationMessage,
        @NationalId AS FormattedNationalId;
END;
GO

-- Validate Date
CREATE OR ALTER PROCEDURE sp_ValidateDate
    @DateValue DATE,
    @MinDate DATE = NULL,
    @MaxDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IsValid BIT = 0;
    DECLARE @ValidationMessage NVARCHAR(200) = '';
    
    IF @MinDate IS NULL
        SET @MinDate = '1900-01-01';
    
    IF @MaxDate IS NULL
        SET @MaxDate = '2100-12-31';
    
    IF @DateValue IS NULL
    BEGIN
        SET @ValidationMessage = 'Date cannot be null';
    END
    ELSE IF @DateValue < @MinDate
    BEGIN
        SET @ValidationMessage = 'Date is too early (minimum: ' + CAST(@MinDate AS NVARCHAR) + ')';
    END
    ELSE IF @DateValue > @MaxDate
    BEGIN
        SET @ValidationMessage = 'Date is too late (maximum: ' + CAST(@MaxDate AS NVARCHAR) + ')';
    END
    ELSE
    BEGIN
        SET @IsValid = 1;
        SET @ValidationMessage = 'Valid date';
    END
    
    SELECT 
        @IsValid AS IsValid,
        @ValidationMessage AS ValidationMessage;
END;
GO

-- Validate Time Range
CREATE OR ALTER PROCEDURE sp_ValidateTimeRange
    @StartTime TIME,
    @EndTime TIME
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IsValid BIT = 0;
    DECLARE @ValidationMessage NVARCHAR(200) = '';
    
    IF @StartTime IS NULL OR @EndTime IS NULL
    BEGIN
        SET @ValidationMessage = 'Start time and end time cannot be null';
    END
    ELSE IF @StartTime >= @EndTime
    BEGIN
        SET @ValidationMessage = 'Start time must be before end time';
    END
    ELSE IF DATEDIFF(MINUTE, @StartTime, @EndTime) < 15
    BEGIN
        SET @ValidationMessage = 'Time range must be at least 15 minutes';
    END
    ELSE IF DATEDIFF(HOUR, @StartTime, @EndTime) > 12
    BEGIN
        SET @ValidationMessage = 'Time range cannot exceed 12 hours';
    END
    ELSE
    BEGIN
        SET @IsValid = 1;
        SET @ValidationMessage = 'Valid time range';
    END
    
    SELECT 
        @IsValid AS IsValid,
        @ValidationMessage AS ValidationMessage;
END;
GO

-- Check Data Integrity
CREATE OR ALTER PROCEDURE sp_CheckDataIntegrity
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check for orphaned records and data inconsistencies
    SELECT 
        'OrphanedAppointments' AS IssueType,
        COUNT(*) AS IssueCount,
        'Appointments without valid clients' AS Description
    FROM Appointments a
    LEFT JOIN Clients c ON a.ClientId = c.ClientId
    WHERE c.ClientId IS NULL
    
    UNION ALL
    
    SELECT 
        'OrphanedPolicies' AS IssueType,
        COUNT(*) AS IssueCount,
        'Client policies without valid clients' AS Description
    FROM ClientPolicies cp
    LEFT JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE c.ClientId IS NULL
    
    UNION ALL
    
    SELECT 
        'OrphanedReminders' AS IssueType,
        COUNT(*) AS IssueCount,
        'Reminders without valid clients' AS Description
    FROM Reminders r
    LEFT JOIN Clients c ON r.ClientId = c.ClientId
    WHERE r.ClientId IS NOT NULL AND c.ClientId IS NULL
    
    UNION ALL
    
    SELECT 
        'DuplicateEmails' AS IssueType,
        COUNT(*) - COUNT(DISTINCT Email) AS IssueCount,
        'Clients with duplicate email addresses' AS Description
    FROM Clients
    WHERE AgentId = @AgentId AND IsActive = 1
    
    UNION ALL
    
    SELECT 
        'DuplicatePhones' AS IssueType,
        COUNT(*) - COUNT(DISTINCT PhoneNumber) AS IssueCount,
        'Clients with duplicate phone numbers' AS Description
    FROM Clients
    WHERE AgentId = @AgentId AND IsActive = 1
    
    UNION ALL
    
    SELECT 
        'DuplicateNationalIds' AS IssueType,
        COUNT(*) - COUNT(DISTINCT NationalId) AS IssueCount,
        'Clients with duplicate national IDs' AS Description
    FROM Clients
    WHERE AgentId = @AgentId AND IsActive = 1
    
    UNION ALL
    
    SELECT 
        'FutureAppointments' AS IssueType,
        COUNT(*) AS IssueCount,
        'Appointments scheduled more than 1 year in future' AS Description
    FROM Appointments a
    INNER JOIN Clients c ON a.ClientId = c.ClientId
    WHERE c.AgentId = @AgentId 
        AND a.AppointmentDate > DATEADD(YEAR, 1, GETDATE())
    
    UNION ALL
    
    SELECT 
        'ExpiredActiveReminders' AS IssueType,
        COUNT(*) AS IssueCount,
        'Active reminders with past dates' AS Description
    FROM Reminders r
    WHERE r.AgentId = @AgentId 
        AND r.Status = 'Active'
        AND r.ReminderDate < CAST(GETDATE() AS DATE);
END;
GO

-- ============================================
-- Utility Service Stored Procedures & Functions
-- ============================================

-- Calculate Age Function
CREATE OR ALTER FUNCTION fn_CalculateAge(@DateOfBirth DATE)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(YEAR, @DateOfBirth, GETDATE()) - 
           CASE 
               WHEN MONTH(@DateOfBirth) > MONTH(GETDATE()) OR 
                    (MONTH(@DateOfBirth) = MONTH(GETDATE()) AND DAY(@DateOfBirth) > DAY(GETDATE()))
               THEN 1 
               ELSE 0 
           END;
END;
GO

-- Calculate Days Until Expiry Function
CREATE OR ALTER FUNCTION fn_DaysUntilExpiry(@ExpiryDate DATE)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(DAY, GETDATE(), @ExpiryDate);
END;
GO

-- Format Client Name Function
CREATE OR ALTER FUNCTION fn_FormatClientName(
    @FirstName NVARCHAR(50),
    @Surname NVARCHAR(50),
    @LastName NVARCHAR(50)
)
RETURNS NVARCHAR(152)
AS
BEGIN
    RETURN LTRIM(RTRIM(@FirstName)) + ' ' + 
           LTRIM(RTRIM(@Surname)) + 
           CASE 
               WHEN @LastName IS NOT NULL AND @LastName != '' 
               THEN ' ' + LTRIM(RTRIM(@LastName))
               ELSE ''
           END;
END;
GO

-- Format Phone Number
CREATE OR ALTER PROCEDURE sp_FormatPhoneNumber
    @PhoneNumber NVARCHAR(20),
    @CountryCode NVARCHAR(5) = '+254'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FormattedNumber NVARCHAR(20) = '';
    
    -- Remove spaces, dashes, and other formatting
    SET @PhoneNumber = REPLACE(REPLACE(REPLACE(@PhoneNumber, ' ', ''), '-', ''), '(', '');
    SET @PhoneNumber = REPLACE(REPLACE(@PhoneNumber, ')', ''), '+', '');
    
    -- Format for Kenya
    IF LEN(@PhoneNumber) = 10 AND LEFT(@PhoneNumber, 1) = '0'
    BEGIN
        SET @FormattedNumber = @CountryCode + RIGHT(@PhoneNumber, 9);
    END
    ELSE IF LEN(@PhoneNumber) = 9
    BEGIN
        SET @FormattedNumber = @CountryCode + @PhoneNumber;
    END
    ELSE IF LEN(@PhoneNumber) = 13 AND LEFT(@PhoneNumber, 3) = '254'
    BEGIN
        SET @FormattedNumber = '+' + @PhoneNumber;
    END
    ELSE
    BEGIN
        SET @FormattedNumber = @PhoneNumber;
    END
    
    SELECT @FormattedNumber AS FormattedPhoneNumber;
END;
GO

-- Format Currency
CREATE OR ALTER FUNCTION fn_FormatCurrency(@Amount DECIMAL(10,2))
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN 'KSH ' + FORMAT(@Amount, 'N2');
END;
GO

-- Generate ID
CREATE OR ALTER FUNCTION fn_GenerateId()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
    RETURN NEWID();
END;
GO

-- Get Greeting
CREATE OR ALTER PROCEDURE sp_GetGreeting
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentHour INT = DATEPART(HOUR, GETDATE());
    DECLARE @Greeting NVARCHAR(20);
    
    SET @Greeting = CASE 
        WHEN @CurrentHour < 12 THEN 'Good Morning'
        WHEN @CurrentHour < 17 THEN 'Good Afternoon'
        ELSE 'Good Evening'
    END;
    
    SELECT @Greeting AS Greeting;
END;
GO

-- Get Status Color
CREATE OR ALTER FUNCTION fn_GetStatusColor(@Status NVARCHAR(20))
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN CASE @Status
        WHEN 'Active' THEN 'success'
        WHEN 'Completed' THEN 'success'
        WHEN 'Confirmed' THEN 'info'
        WHEN 'Scheduled' THEN 'primary'
        WHEN 'In Progress' THEN 'warning'
        WHEN 'Cancelled' THEN 'danger'
        WHEN 'Expired' THEN 'danger'
        WHEN 'Inactive' THEN 'secondary'
        WHEN 'Lapsed' THEN 'danger'
        ELSE 'secondary'
    END;
END;
GO

-- Get Priority Color
CREATE OR ALTER FUNCTION fn_GetPriorityColor(@Priority NVARCHAR(10))
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN CASE @Priority
        WHEN 'High' THEN 'danger'
        WHEN 'Medium' THEN 'warning'
        WHEN 'Low' THEN 'info'
        ELSE 'secondary'
    END;
END;
GO

-- Get Appointment Type Icon
CREATE OR ALTER FUNCTION fn_GetAppointmentTypeIcon(@Type NVARCHAR(50))
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN CASE @Type
        WHEN 'Call' THEN 'phone'
        WHEN 'Meeting' THEN 'users'
        WHEN 'Site Visit' THEN 'map-pin'
        WHEN 'Policy Review' THEN 'file-text'
        WHEN 'Claim Processing' THEN 'clipboard'
        ELSE 'calendar'
    END;
END;
GO

-- Parse Template
CREATE OR ALTER PROCEDURE sp_ParseTemplate
    @Template NVARCHAR(MAX),
    @ClientName NVARCHAR(150) = NULL,
    @AgentName NVARCHAR(100) = NULL,
    @PolicyType NVARCHAR(50) = NULL,
    @ExpiryDate DATE = NULL,
    @CompanyName NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ParsedTemplate NVARCHAR(MAX) = @Template;
    
    -- Replace common placeholders
    SET @ParsedTemplate = REPLACE(@ParsedTemplate, '{name}', ISNULL(@ClientName, '{name}'));
    SET @ParsedTemplate = REPLACE(@ParsedTemplate, '{client_name}', ISNULL(@ClientName, '{client_name}'));
    SET @ParsedTemplate = REPLACE(@ParsedTemplate, '{agent_name}', ISNULL(@AgentName, '{agent_name}'));
    SET @ParsedTemplate = REPLACE(@ParsedTemplate, '{policy_type}', ISNULL(@PolicyType, '{policy_type}'));
    SET @ParsedTemplate = REPLACE(@ParsedTemplate, '{expiry_date}', ISNULL(CAST(@ExpiryDate AS NVARCHAR), '{expiry_date}'));
    SET @ParsedTemplate = REPLACE(@ParsedTemplate, '{company_name}', ISNULL(@CompanyName, '{company_name}'));
    SET @ParsedTemplate = REPLACE(@ParsedTemplate, '{current_date}', CAST(GETDATE() AS NVARCHAR));
    SET @ParsedTemplate = REPLACE(@ParsedTemplate, '{current_year}', CAST(YEAR(GETDATE()) AS NVARCHAR));
    
    SELECT @ParsedTemplate AS ParsedTemplate;
END;
GO

-- Generate Random Password
CREATE OR ALTER PROCEDURE sp_GenerateRandomPassword
    @Length INT = 12
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Password NVARCHAR(50) = '';
    DECLARE @Characters NVARCHAR(100) = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
    DECLARE @CharLength INT = LEN(@Characters);
    DECLARE @Counter INT = 0;
    
    WHILE @Counter < @Length
    BEGIN
        SET @Password = @Password + SUBSTRING(@Characters, ABS(CHECKSUM(NEWID())) % @CharLength + 1, 1);
        SET @Counter = @Counter + 1;
    END
    
    SELECT @Password AS RandomPassword;
END;
GO

-- ============================================
-- Notification Service Stored Procedures
-- ============================================

-- Create Notifications Table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Notifications]') AND type in (N'U'))
BEGIN
    CREATE TABLE Notifications (
        NotificationId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        AgentId UNIQUEIDENTIFIER NOT NULL,
        NotificationType NVARCHAR(20) NOT NULL CHECK (NotificationType IN ('Email', 'SMS', 'WhatsApp', 'Push')),
        Recipient NVARCHAR(200) NOT NULL,
        Subject NVARCHAR(200),
        Body NVARCHAR(MAX) NOT NULL,
        Status NVARCHAR(20) DEFAULT 'Pending' CHECK (Status IN ('Pending', 'Sent', 'Failed', 'Cancelled')),
        ScheduledTime DATETIME2,
        SentTime DATETIME2,
        ErrorMessage NVARCHAR(500),
        RetryCount INT DEFAULT 0,
        CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
        FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
    );
END;
GO

-- Send Email Notification
CREATE OR ALTER PROCEDURE sp_SendEmailNotification
    @AgentId UNIQUEIDENTIFIER,
    @ToEmail NVARCHAR(200),
    @Subject NVARCHAR(200),
    @Body NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @NotificationId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO Notifications (
        NotificationId, AgentId, NotificationType, Recipient, Subject, Body, Status
    )
    VALUES (
        @NotificationId, @AgentId, 'Email', @ToEmail, @Subject, @Body, 'Pending'
    );
    
    -- In a real implementation, this would integrate with an email service
    -- For now, we'll just mark it as sent
    UPDATE Notifications 
    SET Status = 'Sent', SentTime = GETUTCDATE()
    WHERE NotificationId = @NotificationId;
    
    SELECT @NotificationId AS NotificationId, 1 AS Success;
END;
GO

-- Send SMS Notification
CREATE OR ALTER PROCEDURE sp_SendSMSNotification
    @AgentId UNIQUEIDENTIFIER,
    @PhoneNumber NVARCHAR(20),
    @Message NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @NotificationId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO Notifications (
        NotificationId, AgentId, NotificationType, Recipient, Body, Status
    )
    VALUES (
        @NotificationId, @AgentId, 'SMS', @PhoneNumber, @Message, 'Pending'
    );
    
    -- In a real implementation, this would integrate with an SMS service
    -- For now, we'll simulate success/failure
    DECLARE @Success BIT = CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 1 THEN 1 ELSE 0 END;
    
    IF @Success = 1
    BEGIN
        UPDATE Notifications 
        SET Status = 'Sent', SentTime = GETUTCDATE()
        WHERE NotificationId = @NotificationId;
    END
    ELSE
    BEGIN
        UPDATE Notifications 
        SET Status = 'Failed', ErrorMessage = 'Simulated SMS delivery failure'
        WHERE NotificationId = @NotificationId;
    END
    
    SELECT @NotificationId AS NotificationId, @Success AS Success;
END;
GO

-- Send WhatsApp Notification
CREATE OR ALTER PROCEDURE sp_SendWhatsAppNotification
    @AgentId UNIQUEIDENTIFIER,
    @PhoneNumber NVARCHAR(20),
    @Message NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @NotificationId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO Notifications (
        NotificationId, AgentId, NotificationType, Recipient, Body, Status
    )
    VALUES (
        @NotificationId, @AgentId, 'WhatsApp', @PhoneNumber, @Message, 'Pending'
    );
    
    -- In a real implementation, this would integrate with WhatsApp Business API
    -- For now, we'll simulate success
    UPDATE Notifications 
    SET Status = 'Sent', SentTime = GETUTCDATE()
    WHERE NotificationId = @NotificationId;
    
    SELECT @NotificationId AS NotificationId, 1 AS Success;
END;
GO

-- Send Push Notification
CREATE OR ALTER PROCEDURE sp_SendPushNotification
    @AgentId UNIQUEIDENTIFIER,
    @Title NVARCHAR(200),
    @Body NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @NotificationId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO Notifications (
        NotificationId, AgentId, NotificationType, Recipient, Subject, Body, Status
    )
    VALUES (
        @NotificationId, @AgentId, 'Push', CAST(@AgentId AS NVARCHAR), @Title, @Body, 'Pending'
    );
    
    -- In a real implementation, this would integrate with push notification service
    UPDATE Notifications 
    SET Status = 'Sent', SentTime = GETUTCDATE()
    WHERE NotificationId = @NotificationId;
    
    SELECT @NotificationId AS NotificationId, 1 AS Success;
END;
GO

-- Schedule Notification
CREATE OR ALTER PROCEDURE sp_ScheduleNotification
    @AgentId UNIQUEIDENTIFIER,
    @ScheduledTime DATETIME2,
    @NotificationType NVARCHAR(20),
    @Recipient NVARCHAR(200),
    @Subject NVARCHAR(200) = NULL,
    @Body NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @NotificationId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO Notifications (
        NotificationId, AgentId, NotificationType, Recipient, Subject, Body, ScheduledTime, Status
    )
    VALUES (
        @NotificationId, @AgentId, @NotificationType, @Recipient, @Subject, @Body, @ScheduledTime, 'Pending'
    );
    
    SELECT @NotificationId AS NotificationId;
END;
GO

-- Cancel Scheduled Notification
CREATE OR ALTER PROCEDURE sp_CancelScheduledNotification
    @NotificationId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE Notifications 
    SET Status = 'Cancelled'
    WHERE NotificationId = @NotificationId 
        AND AgentId = @AgentId 
        AND Status = 'Pending';
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Process Scheduled Notifications
CREATE OR ALTER PROCEDURE sp_ProcessScheduledNotifications
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        NotificationId,
        AgentId,
        NotificationType,
        Recipient,
        Subject,
        Body,
        ScheduledTime
    FROM Notifications
    WHERE Status = 'Pending'
        AND ScheduledTime IS NOT NULL
        AND ScheduledTime <= GETUTCDATE()
    ORDER BY ScheduledTime ASC;
END;
GO

-- Get Notification History
CREATE OR ALTER PROCEDURE sp_GetNotificationHistory
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @NotificationType NVARCHAR(20) = NULL,
    @Status NVARCHAR(20) = NULL,
    @PageSize INT = 50,
    @PageNumber INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(DAY, -30, GETDATE());
    
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT 
        NotificationId,
        NotificationType,
        Recipient,
        Subject,
        Body,
        Status,
        ScheduledTime,
        SentTime,
        ErrorMessage,
        RetryCount,
        CreatedDate
    FROM Notifications
    WHERE 
        AgentId = @AgentId
        AND CreatedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)
        AND (@NotificationType IS NULL OR NotificationType = @NotificationType)
        AND (@Status IS NULL OR Status = @Status)
    ORDER BY CreatedDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
    -- Get total count
    SELECT COUNT(*) AS TotalRecords
    FROM Notifications
    WHERE 
        AgentId = @AgentId
        AND CreatedDate BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)
        AND (@NotificationType IS NULL OR NotificationType = @NotificationType)
        AND (@Status IS NULL OR Status = @Status);
END;
GO

-- Update Notification Status
CREATE OR ALTER PROCEDURE sp_UpdateNotificationStatus
    @NotificationId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20),
    @ErrorMessage NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE Notifications 
    SET 
        Status = @Status,
        SentTime = CASE WHEN @Status = 'Sent' THEN GETUTCDATE() ELSE SentTime END,
        ErrorMessage = @ErrorMessage,
        RetryCount = CASE WHEN @Status = 'Failed' THEN RetryCount + 1 ELSE RetryCount END
    WHERE NotificationId = @NotificationId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO