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
