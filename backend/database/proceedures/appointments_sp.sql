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
GO