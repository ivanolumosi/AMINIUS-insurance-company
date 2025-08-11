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