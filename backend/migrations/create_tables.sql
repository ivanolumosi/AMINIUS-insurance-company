
CREATE TABLE Agent (
    AgentId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(256) NOT NULL, -- store securely hashed password
    Phone NVARCHAR(20) NOT NULL,
    Avatar NVARCHAR(MAX), -- Base64 or file path
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    IsActive BIT DEFAULT 1
);

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
ALTER TABLE Clients
ADD CONSTRAINT DF_Clients_InsuranceType DEFAULT 'N/A' FOR InsuranceType;
go
CREATE TRIGGER trg_UpdateInsuranceType
ON ClientPolicies
AFTER INSERT, UPDATE
AS
BEGIN
    UPDATE c
    SET c.InsuranceType = i.PolicyName
    FROM Clients c
    INNER JOIN inserted i ON c.ClientId = i.ClientId;
END;
go

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
-- 1. ClientPolicies
-- ============================================
CREATE TABLE ClientPolicies (
    PolicyId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    ClientId UNIQUEIDENTIFIER NOT NULL,
    PolicyName NVARCHAR(100) NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    Notes NVARCHAR(MAX) NULL,
    CreatedDate DATETIME2 NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME2 NULL,
    IsActive BIT NULL DEFAULT 1,
    PolicyCatalogId UNIQUEIDENTIFIER NULL,
    TypeId UNIQUEIDENTIFIER NULL,
    CompanyId UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_ClientPolicies_PolicyCatalog FOREIGN KEY (PolicyCatalogId) REFERENCES PolicyCatalog(PolicyCatalogId),
    CONSTRAINT FK_ClientPolicies_Type FOREIGN KEY (TypeId) REFERENCES PolicyTypes(TypeId),
    CONSTRAINT FK_ClientPolicies_Company FOREIGN KEY (CompanyId) REFERENCES InsuranceCompanies(CompanyId)
);
select * from ClientPolicies
-- ============================================
-- 2. InsuranceCompanies
-- ============================================
CREATE TABLE InsuranceCompanies (
    CompanyId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    CompanyName NVARCHAR(100) NOT NULL,
    IsActive BIT NULL DEFAULT 1,
    CreatedDate DATETIME2 NULL DEFAULT GETDATE()
);

-- ============================================
-- 3. PolicyCatalog
-- ============================================
CREATE TABLE PolicyCatalog (
    PolicyCatalogId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    PolicyName NVARCHAR(100) NOT NULL,
    CompanyId UNIQUEIDENTIFIER NOT NULL,
    Notes NVARCHAR(MAX) NULL,
    IsActive BIT NULL DEFAULT 1,
    CreatedDate DATETIME2 NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME2 NULL,
    CategoryId UNIQUEIDENTIFIER NULL,
    TypeId UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_PolicyCatalog_Company FOREIGN KEY (CompanyId) REFERENCES InsuranceCompanies(CompanyId),
    CONSTRAINT FK_PolicyCatalog_Category FOREIGN KEY (CategoryId) REFERENCES PolicyCategories(CategoryId),
    CONSTRAINT FK_PolicyCatalog_Type FOREIGN KEY (TypeId) REFERENCES PolicyTypes(TypeId)
);
SELECT * from PolicyCatalog
-- ============================================
-- 4. PolicyCategories
-- ============================================
CREATE TABLE PolicyCategories (
    CategoryId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    CategoryName NVARCHAR(50) NOT NULL,
    Description NVARCHAR(200) NULL,
    IsActive BIT NULL DEFAULT 1,
    CreatedDate DATETIME2 NULL DEFAULT GETDATE()
);

-- ============================================
-- 5. PolicyTemplates
-- ============================================
CREATE TABLE PolicyTemplates (
    TemplateId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    TemplateName NVARCHAR(100) NOT NULL,
    DefaultTermMonths INT NULL,
    DefaultPremium DECIMAL(18, 2) NULL,
    CoverageDescription NVARCHAR(MAX) NULL,
    Terms NVARCHAR(MAX) NULL,
    IsActive BIT NULL DEFAULT 1,
    CreatedDate DATETIME2 NULL DEFAULT GETDATE(),
    CategoryId UNIQUEIDENTIFIER NULL,
    PolicyCatalogId UNIQUEIDENTIFIER NULL,
    TypeId UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_PolicyTemplates_Category FOREIGN KEY (CategoryId) REFERENCES PolicyCategories(CategoryId),
    CONSTRAINT FK_PolicyTemplates_Catalog FOREIGN KEY (PolicyCatalogId) REFERENCES PolicyCatalog(PolicyCatalogId),
    CONSTRAINT FK_PolicyTemplates_Type FOREIGN KEY (TypeId) REFERENCES PolicyTypes(TypeId)
);

-- ============================================
-- 6. PolicyTypes
-- ============================================
CREATE TABLE PolicyTypes (
    TypeId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    TypeName NVARCHAR(50) NOT NULL,
    IsActive BIT NULL DEFAULT 1,
    CreatedDate DATETIME2 NULL DEFAULT GETDATE()
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
-- ============================================
-- Analytics and Dashboard Tables
-- ============================================

-- Activity Log Table (For tracking all user activities)
CREATE TABLE ActivityLog (
    ActivityId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    ActivityType NVARCHAR(50) NOT NULL, -- 'appointment_created', 'client_added', 'reminder_completed', etc.
    EntityType NVARCHAR(50), -- 'client', 'appointment', 'reminder', etc.
    EntityId UNIQUEIDENTIFIER,
    Description NVARCHAR(500),
    ActivityDate DATETIME2 DEFAULT GETUTCDATE(),
    AdditionalData NVARCHAR(MAX), -- JSON data for complex activity details
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);

-- Dashboard Statistics Table (For caching daily statistics)
CREATE TABLE DashboardStatistics (
    StatId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    StatDate DATE NOT NULL,
    TotalClients INT DEFAULT 0,
    TotalProspects INT DEFAULT 0,
    ActivePolicies INT DEFAULT 0,
    TodayAppointments INT DEFAULT 0,
    WeekAppointments INT DEFAULT 0,
    MonthAppointments INT DEFAULT 0,
    CompletedAppointments INT DEFAULT 0,
    PendingReminders INT DEFAULT 0,
    TodayBirthdays INT DEFAULT 0,
    ExpiringPolicies INT DEFAULT 0,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
    UNIQUE(AgentId, StatDate)
);

-- Performance Metrics Table (For tracking agent performance over time)
CREATE TABLE PerformanceMetrics (
    MetricId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    MetricDate DATE NOT NULL,
    NewClientsAdded INT DEFAULT 0,
    ProspectsConverted INT DEFAULT 0,
    AppointmentsCompleted INT DEFAULT 0,
    PoliciesSold INT DEFAULT 0,
    RemindersCompleted INT DEFAULT 0,
    MessagesSet INT DEFAULT 0,
    ClientInteractions INT DEFAULT 0,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
    UNIQUE(AgentId, MetricDate)
);

-- Task Summary Table (For dashboard task tracking)
CREATE TABLE TaskSummary (
    TaskId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    TaskDate DATE NOT NULL,
    TaskType NVARCHAR(50) NOT NULL, -- 'call', 'visit', 'follow_up', 'renewal'
    TaskDescription NVARCHAR(500),
    Priority NVARCHAR(10) CHECK (Priority IN ('High', 'Medium', 'Low')) DEFAULT 'Medium',
    Status NVARCHAR(20) CHECK (Status IN ('Pending', 'In Progress', 'Completed', 'Cancelled')) DEFAULT 'Pending',
    ClientId UNIQUEIDENTIFIER,
    AppointmentId UNIQUEIDENTIFIER,
    DueTime TIME,
    CompletedDate DATETIME2,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
    FOREIGN KEY (ClientId) REFERENCES Clients(ClientId),
    FOREIGN KEY (AppointmentId) REFERENCES Appointments(AppointmentId)
);

-- Monthly Reports Table (For generating monthly performance reports)
CREATE TABLE MonthlyReports (
    ReportId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    ReportMonth DATE NOT NULL, -- First day of the month
    TotalClientsAdded INT DEFAULT 0,
    TotalProspectsAdded INT DEFAULT 0,
    ProspectsConverted INT DEFAULT 0,
    TotalAppointments INT DEFAULT 0,
    CompletedAppointments INT DEFAULT 0,
    CancelledAppointments INT DEFAULT 0,
    TotalReminders INT DEFAULT 0,
    CompletedReminders INT DEFAULT 0,
    MessagesSent INT DEFAULT 0,
    NewPolicies INT DEFAULT 0,
    RenewedPolicies INT DEFAULT 0,
    ExpiredPolicies INT DEFAULT 0,
    GeneratedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
    UNIQUE(AgentId, ReportMonth)
);

-- Dashboard Views Cache Table (For caching complex dashboard queries)
CREATE TABLE DashboardViewsCache (
    CacheId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    ViewName NVARCHAR(100) NOT NULL, -- 'today_appointments', 'today_birthdays', etc.
    CacheDate DATE NOT NULL,
    CacheData NVARCHAR(MAX), -- JSON data
    ExpiresAt DATETIME2,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
    UNIQUE(AgentId, ViewName, CacheDate)
);
