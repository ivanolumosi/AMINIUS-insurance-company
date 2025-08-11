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