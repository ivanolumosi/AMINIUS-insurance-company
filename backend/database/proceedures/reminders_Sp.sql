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