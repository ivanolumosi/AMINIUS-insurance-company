-- -- ============================================
-- -- Agent Management Tables
-- -- ============================================

-- -- Agent Profile Table
-- DROP TABLE IF EXISTS Agent;
-- GO

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
-- SELECT 
--     f.name AS ForeignKey,
--     OBJECT_NAME(f.parent_object_id) AS TableName,
--     COL_NAME(fc.parent_object_id, fc.parent_column_id) AS ColumnName
-- FROM sys.foreign_keys AS f
-- INNER JOIN sys.foreign_key_columns AS fc 
--     ON f.object_id = fc.constraint_object_id
-- WHERE OBJECT_NAME(f.referenced_object_id) = 'Agent';

-- ALTER TABLE Agent DROP COLUMN Company;
-- ALTER TABLE Agent DROP COLUMN LicenseNumber;

-- ALTER TABLE Agent ADD PasswordHash NVARCHAR(200) NOT NULL;
-- ALTER TABLE Agent
-- ADD PasswordHash NVARCHAR(200) NOT NULL DEFAULT '';

-- select * from Agent;
select * from appointments
-- -- Agent Settings Table
-- CREATE TABLE AgentSettings (
--     SettingId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     AgentId UNIQUEIDENTIFIER NOT NULL,
--     DarkMode BIT DEFAULT 0,
--     EmailNotifications BIT DEFAULT 1,
--     SmsNotifications BIT DEFAULT 1,
--     WhatsappNotifications BIT DEFAULT 1,
--     PushNotifications BIT DEFAULT 1,
--     SoundEnabled BIT DEFAULT 1,
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
--     ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
--     FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
-- );

-- -- Insurance Companies Master Table
-- CREATE TABLE InsuranceCompanies (
--     CompanyId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     CompanyName NVARCHAR(100) NOT NULL UNIQUE,
--     IsActive BIT DEFAULT 1,
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE()
-- );

-- -- Insert default insurance companies
-- INSERT INTO InsuranceCompanies (CompanyName) VALUES
-- ('Jubilee Insurance'),
-- ('Britam'),
-- ('Old Mutual'),
-- ('AAR Insurance'),
-- ('CIC Insurance'),
-- ('Madison Insurance');

-- -- Policy Types Master Table
-- CREATE TABLE PolicyTypes (
--     TypeId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
--     TypeName NVARCHAR(50) NOT NULL UNIQUE,
--     IsActive BIT DEFAULT 1,
--     CreatedDate DATETIME2 DEFAULT GETUTCDATE()
-- );

-- -- Insert default policy types
-- INSERT INTO PolicyTypes (TypeName) VALUES
-- ('Motor'),
-- ('Life'),
-- ('Health'),
-- ('Travel'),
-- ('Property'),
-- ('Marine'),
-- ('Business');