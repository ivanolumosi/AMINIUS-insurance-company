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

-- Client Policies Table
CREATE TABLE ClientPolicies (
    PolicyId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    ClientId UNIQUEIDENTIFIER NOT NULL,
    PolicyName NVARCHAR(100) NOT NULL,
    PolicyType NVARCHAR(50) NOT NULL,
    CompanyName NVARCHAR(100) NOT NULL,
    Status NVARCHAR(20) NOT NULL CHECK (Status IN ('Active', 'Inactive', 'Expired', 'Lapsed')),
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    Notes NVARCHAR(MAX),
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    IsActive BIT DEFAULT 1,
    FOREIGN KEY (ClientId) REFERENCES Clients(ClientId) ON DELETE CASCADE
);

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