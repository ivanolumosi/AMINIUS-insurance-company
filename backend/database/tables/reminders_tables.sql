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