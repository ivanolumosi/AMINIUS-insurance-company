
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