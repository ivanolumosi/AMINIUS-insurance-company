ALTER TABLE AgentNotificationPreferences DROP CONSTRAINT FK__AgentNoti__Agent__01D345B0;
ALTER TABLE ReminderSettings DROP CONSTRAINT FK__ReminderS__Agent__04E4BC85;
ALTER TABLE SystemPreferences DROP CONSTRAINT FK__SystemPre__Agent__0880433F;
ALTER TABLE BackupSettings DROP CONSTRAINT FK__BackupSet__Agent__14E61A24;
ALTER TABLE MessageTemplates DROP CONSTRAINT FK__MessageTe__Agent__1C873BEC;
ALTER TABLE ActivityLog DROP CONSTRAINT FK__ActivityL__Agent__214BF109;
ALTER TABLE Appointments DROP CONSTRAINT FK__Appointme__Agent__2BFE89A6;
ALTER TABLE DashboardStatistics DROP CONSTRAINT FK__Dashboard__Agent__318258D2;
ALTER TABLE PolicyCatalog DROP CONSTRAINT FK__PolicyCat__Agent__32AB8735;
ALTER TABLE PolicyTemplates DROP CONSTRAINT FK__PolicyTem__Agent__395884C4;
ALTER TABLE PerformanceMetrics DROP CONSTRAINT FK__Performan__Agent__3DE82FB7;
ALTER TABLE TaskSummary DROP CONSTRAINT FK__TaskSumma__Agent__467D75B8;
ALTER TABLE AgentSettings DROP CONSTRAINT FK__AgentSett__Agent__46E78A0C;
ALTER TABLE Reminders DROP CONSTRAINT FK__Reminders__Agent__56E8E7AB;
ALTER TABLE MonthlyReports DROP CONSTRAINT FK__MonthlyRe__Agent__59904A2C;
ALTER TABLE Clients DROP CONSTRAINT FK__Clients__AgentId__59FA5E80;
ALTER TABLE DashboardViewsCache DROP CONSTRAINT FK__Dashboard__Agent__5F492382;
ALTER TABLE AutomatedMessages DROP CONSTRAINT FK__Automated__Agent__607251E5;
ALTER TABLE DailyNotes DROP CONSTRAINT FK__DailyNote__Agent__6DCC4D03;



ALTER TABLE AgentNotificationPreferences 
ADD CONSTRAINT FK_AgentNotificationPreferences_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE ReminderSettings 
ADD CONSTRAINT FK_ReminderSettings_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE SystemPreferences 
ADD CONSTRAINT FK_SystemPreferences_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE BackupSettings 
ADD CONSTRAINT FK_BackupSettings_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE MessageTemplates 
ADD CONSTRAINT FK_MessageTemplates_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE ActivityLog 
ADD CONSTRAINT FK_ActivityLog_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE Appointments 
ADD CONSTRAINT FK_Appointments_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE DashboardStatistics 
ADD CONSTRAINT FK_DashboardStatistics_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE PolicyCatalog 
ADD CONSTRAINT FK_PolicyCatalog_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE PolicyTemplates 
ADD CONSTRAINT FK_PolicyTemplates_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE PerformanceMetrics 
ADD CONSTRAINT FK_PerformanceMetrics_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE TaskSummary 
ADD CONSTRAINT FK_TaskSummary_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE AgentSettings 
ADD CONSTRAINT FK_AgentSettings_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE Reminders 
ADD CONSTRAINT FK_Reminders_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE MonthlyReports 
ADD CONSTRAINT FK_MonthlyReports_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE Clients 
ADD CONSTRAINT FK_Clients_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE DashboardViewsCache 
ADD CONSTRAINT FK_DashboardViewsCache_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE AutomatedMessages 
ADD CONSTRAINT FK_AutomatedMessages_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;

ALTER TABLE DailyNotes 
ADD CONSTRAINT FK_DailyNotes_Agent 
FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE;




ALTER TABLE PolicyCatalog
ADD CategoryId UNIQUEIDENTIFIER NULL;

ALTER TABLE PolicyCatalog
ADD CONSTRAINT FK_PolicyCatalog_PolicyCategories
FOREIGN KEY (CategoryId) REFERENCES PolicyCategories(CategoryId) ON DELETE SET NULL;

ALTER TABLE ClientPolicies
ADD PolicyCatalogId UNIQUEIDENTIFIER NULL;

ALTER TABLE ClientPolicies
ADD PolicyCatalogId UNIQUEIDENTIFIER NULL;

ALTER TABLE ClientPolicies
ADD CONSTRAINT FK_ClientPolicies_PolicyCatalog
FOREIGN KEY (PolicyCatalogId)
REFERENCES PolicyCatalog(PolicyCatalogId)
ON DELETE SET NULL
ON UPDATE NO ACTION;



SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ClientPolicies';


-- First, make sure column exists only once
ALTER TABLE ClientPolicies
ADD PolicyCatalogId UNIQUEIDENTIFIER NULL;

-- Then create FK without cascade
ALTER TABLE ClientPolicies
ADD CONSTRAINT FK_ClientPolicies_PolicyCatalog
FOREIGN KEY (PolicyCatalogId)
REFERENCES PolicyCatalog(PolicyCatalogId)
ON DELETE NO ACTION
ON UPDATE NO ACTION;


ALTER TABLE PolicyCatalog
ADD CategoryId UNIQUEIDENTIFIER NULL;

ALTER TABLE PolicyCatalog
ADD CONSTRAINT FK_PolicyCatalog_PolicyCategories
FOREIGN KEY (CategoryId) 
REFERENCES PolicyCategories(CategoryId) 
ON DELETE SET NULL;


ALTER TABLE PolicyTemplates
ADD CategoryId UNIQUEIDENTIFIER NULL;

ALTER TABLE PolicyTemplates
ADD CONSTRAINT FK_PolicyTemplates_PolicyCategories
FOREIGN KEY (CategoryId) 
REFERENCES PolicyCategories(CategoryId)
ON DELETE SET NULL;

ALTER TABLE PolicyTemplates
ADD PolicyCatalogId UNIQUEIDENTIFIER NULL;

ALTER TABLE PolicyTemplates
ADD CONSTRAINT FK_PolicyTemplates_PolicyCatalog
FOREIGN KEY (PolicyCatalogId)
REFERENCES PolicyCatalog(PolicyCatalogId)
ON DELETE NO ACTION;



-- -- ============================================
-- -- Policy Catalog Management Tables
-- -- ============================================

-- -- Policy Categories Table (For organizing policies)
-- CREATE TABLE PolicyCategories (
--     CategoryId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     CategoryName NVARCHAR(50) NOT NULL,
--     Description NVARCHAR(200),
--     IsActive BIT DEFAULT 1,
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE()
-- );

-- -- Insert default categories
-- INSERT INTO PolicyCategories (CategoryName, Description) VALUES
-- ('Individual', 'Personal insurance policies'),
-- ('Corporate', 'Business and corporate policies'),
-- ('Family', 'Family package policies'),
-- ('Specialized', 'Specialized coverage policies');

-- -- Policy Catalog Table (Available policies from different companies)
-- CREATE TABLE PolicyCatalog (
--     PolicyCatalogId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     AgentId UNIQUEIDENTIFIER NOT NULL,
--     PolicyName NVARCHAR(100) NOT NULL,
--     PolicyType NVARCHAR(50) NOT NULL,
--     CompanyId UNIQUEIDENTIFIER NOT NULL,
--     CompanyName NVARCHAR(100) NOT NULL, -- Denormalized for quick access
--     CategoryId UNIQUEIDENTIFIER NULL, -- Link to categories
--     Notes NVARCHAR(MAX),
--     IsActive BIT DEFAULT 1,
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
--     ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
--     FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
--     FOREIGN KEY (CompanyId) REFERENCES InsuranceCompanies(CompanyId),
--     FOREIGN KEY (CategoryId) REFERENCES PolicyCategories(CategoryId) ON DELETE SET NULL
-- );

-- -- Policy Templates Table (For common policy configurations)
-- CREATE TABLE PolicyTemplates (
--     TemplateId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     AgentId UNIQUEIDENTIFIER NOT NULL,
--     TemplateName NVARCHAR(100) NOT NULL,
--     PolicyType NVARCHAR(50) NOT NULL,
--     CategoryId UNIQUEIDENTIFIER NULL, -- Link to categories
--     PolicyCatalogId UNIQUEIDENTIFIER NULL, -- Optional link to catalog
--     DefaultTermMonths INT,
--     DefaultPremium DECIMAL(10,2),
--     CoverageDescription NVARCHAR(MAX),
--     Terms NVARCHAR(MAX),
--     IsActive BIT DEFAULT 1,
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
--     FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
--     FOREIGN KEY (CategoryId) REFERENCES PolicyCategories(CategoryId) ON DELETE SET NULL,
--     FOREIGN KEY (PolicyCatalogId) REFERENCES PolicyCatalog(PolicyCatalogId) ON DELETE NO ACTION
-- );

-- -- Policy Company Relationships (Many-to-many for policies offered by multiple companies)
-- CREATE TABLE PolicyCompanyRelationships (
--     RelationshipId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     PolicyCatalogId UNIQUEIDENTIFIER NOT NULL,
--     CompanyId UNIQUEIDENTIFIER NOT NULL,
--     BasePremium DECIMAL(10,2),
--     CommissionRate DECIMAL(5,2),
--     IsPreferred BIT DEFAULT 0,
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
--     FOREIGN KEY (PolicyCatalogId) REFERENCES PolicyCatalog(PolicyCatalogId) ON DELETE CASCADE,
--     FOREIGN KEY (CompanyId) REFERENCES InsuranceCompanies(CompanyId) ON DELETE CASCADE
-- );

-- -- ============================================
-- -- Client Management Tables
-- -- ============================================

-- -- Clients Table
-- CREATE TABLE Clients (
--     ClientId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     AgentId UNIQUEIDENTIFIER NOT NULL,
--     FirstName NVARCHAR(50) NOT NULL,
--     Surname NVARCHAR(50) NOT NULL,
--     LastName NVARCHAR(50) NOT NULL,
--     PhoneNumber NVARCHAR(20) NOT NULL,
--     Email NVARCHAR(100) NOT NULL,
--     Address NVARCHAR(500) NOT NULL,
--     NationalId NVARCHAR(20) NOT NULL,
--     DateOfBirth DATE NOT NULL,
--     IsClient BIT NOT NULL DEFAULT 0, -- 0 = Prospect, 1 = Client
--     InsuranceType NVARCHAR(50) NOT NULL,
--     Notes NVARCHAR(MAX),
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
--     ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
--     IsActive BIT DEFAULT 1,
--     FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
-- );

-- -- Client Policies Table
-- CREATE TABLE ClientPolicies (
--     PolicyId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     ClientId UNIQUEIDENTIFIER NOT NULL,
--     PolicyCatalogId UNIQUEIDENTIFIER NULL, -- Link to policy catalog
--     PolicyName NVARCHAR(100) NOT NULL,
--     PolicyType NVARCHAR(50) NOT NULL,
--     CompanyName NVARCHAR(100) NOT NULL,
--     Status NVARCHAR(20) NOT NULL CHECK (Status IN ('Active', 'Inactive', 'Expired', 'Lapsed')),
--     StartDate DATE NOT NULL,
--     EndDate DATE NOT NULL,
--     Notes NVARCHAR(MAX),
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
--     ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
--     IsActive BIT DEFAULT 1,
--     FOREIGN KEY (ClientId) REFERENCES Clients(ClientId) ON DELETE CASCADE,
--     FOREIGN KEY (PolicyCatalogId) REFERENCES PolicyCatalog(PolicyCatalogId) ON DELETE NO ACTION
-- );

-- -- Appointments Table
-- CREATE TABLE Appointments (
--     AppointmentId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     ClientId UNIQUEIDENTIFIER NOT NULL,
--     AgentId UNIQUEIDENTIFIER NOT NULL,
--     ClientName NVARCHAR(150) NOT NULL, -- Computed from client names
--     ClientPhone NVARCHAR(20),
--     Title NVARCHAR(200) NOT NULL,
--     Description NVARCHAR(MAX),
--     AppointmentDate DATE NOT NULL,
--     StartTime TIME NOT NULL,
--     EndTime TIME NOT NULL,
--     Location NVARCHAR(200),
--     Type NVARCHAR(50) NOT NULL CHECK (Type IN ('Call', 'Meeting', 'Site Visit', 'Policy Review', 'Claim Processing')),
--     Status NVARCHAR(20) NOT NULL CHECK (Status IN ('Scheduled', 'Confirmed', 'In Progress', 'Completed', 'Cancelled', 'Rescheduled')),
--     Priority NVARCHAR(10) NOT NULL CHECK (Priority IN ('High', 'Medium', 'Low')),
--     Notes NVARCHAR(MAX),
--     ReminderSet BIT DEFAULT 0,
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
--     ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
--     IsActive BIT DEFAULT 1,
--     FOREIGN KEY (ClientId) REFERENCES Clients(ClientId) ON DELETE NO ACTION,
--     FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE NO ACTION
-- );



SELECT 
    t.TABLE_NAME AS TableName,
    c.COLUMN_NAME AS ColumnName,
    c.DATA_TYPE + 
        COALESCE('(' + CAST(c.CHARACTER_MAXIMUM_LENGTH AS VARCHAR) + ')', '') AS DataType,
    CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 'YES' ELSE 'NO' END AS IsPrimaryKey,
    fkInfo.ForeignKeyColumn,
    fkInfo.ReferencedTable,
    fkInfo.ReferencedColumn
FROM INFORMATION_SCHEMA.TABLES t
JOIN INFORMATION_SCHEMA.COLUMNS c
    ON t.TABLE_NAME = c.TABLE_NAME
    AND t.TABLE_SCHEMA = c.TABLE_SCHEMA
LEFT JOIN (
    SELECT ku.TABLE_NAME, ku.COLUMN_NAME
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
    JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku
        ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
    WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
) pk
    ON c.TABLE_NAME = pk.TABLE_NAME
    AND c.COLUMN_NAME = pk.COLUMN_NAME
LEFT JOIN (
    SELECT 
        fkc.parent_table AS TableName,
        fkc.parent_column AS ForeignKeyColumn,
        fkc.ref_table AS ReferencedTable,
        fkc.ref_column AS ReferencedColumn
    FROM (
        SELECT 
            OBJECT_NAME(f.parent_object_id) AS parent_table,
            COL_NAME(fc.parent_object_id, fc.parent_column_id) AS parent_column,
            OBJECT_NAME(f.referenced_object_id) AS ref_table,
            COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS ref_column
        FROM sys.foreign_keys AS f
        INNER JOIN sys.foreign_key_columns AS fc
            ON f.object_id = fc.constraint_object_id
    ) fkc
) fkInfo
    ON c.TABLE_NAME = fkInfo.TableName
    AND c.COLUMN_NAME = fkInfo.ForeignKeyColumn
WHERE t.TABLE_TYPE = 'BASE TABLE'
ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION;

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Appointments';


SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Clients';


SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ClientPolicies';

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PolicyCatalog';

SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PolicyTemplates';


SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PolicyCategories';


SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PolicyTypes';





-- List all policy-related tables and their columns
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%Policy%'
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;



SELECT 
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.IS_NULLABLE,
    c.CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.TABLES t
JOIN INFORMATION_SCHEMA.COLUMNS c
    ON t.TABLE_NAME = c.TABLE_NAME
    AND t.TABLE_SCHEMA = c.TABLE_SCHEMA
WHERE t.TABLE_TYPE = 'BASE TABLE'
ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME, c.ORDINAL_POSITION;


SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN (
    'Policies',
    'PolicyCategories',
    'PolicyCatalog',
    'PolicyTypes',
    'InsuranceCompanies',
    'ClientPolicies',
    'PolicyTemplates',
    'PolicyStatistics'
)
ORDER BY TABLE_NAME, ORDINAL_POSITION;
