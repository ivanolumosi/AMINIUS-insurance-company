-- ============================================
-- Policy Catalog Management Tables
-- ============================================

-- Policy Catalog Table (Available policies from different companies)
CREATE TABLE PolicyCatalog (
    PolicyCatalogId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    PolicyName NVARCHAR(100) NOT NULL,
    PolicyType NVARCHAR(50) NOT NULL,
    CompanyId UNIQUEIDENTIFIER NOT NULL,
    CompanyName NVARCHAR(100) NOT NULL, -- Denormalized for quick access
    Notes NVARCHAR(MAX),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    ModifiedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE,
    FOREIGN KEY (CompanyId) REFERENCES InsuranceCompanies(CompanyId)
);

-- Policy Templates Table (For common policy configurations)
CREATE TABLE PolicyTemplates (
    TemplateId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgentId UNIQUEIDENTIFIER NOT NULL,
    TemplateName NVARCHAR(100) NOT NULL,
    PolicyType NVARCHAR(50) NOT NULL,
    DefaultTermMonths INT,
    DefaultPremium DECIMAL(10,2),
    CoverageDescription NVARCHAR(MAX),
    Terms NVARCHAR(MAX),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (AgentId) REFERENCES Agent(AgentId) ON DELETE CASCADE
);

-- Policy Categories Table (For organizing policies)
CREATE TABLE PolicyCategories (
    CategoryId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    CategoryName NVARCHAR(50) NOT NULL,
    Description NVARCHAR(200),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE()
);

-- Insert default categories
INSERT INTO PolicyCategories (CategoryName, Description) VALUES
('Individual', 'Personal insurance policies'),
('Corporate', 'Business and corporate policies'),
('Family', 'Family package policies'),
('Specialized', 'Specialized coverage policies');

-- Policy Company Relationships (Many-to-many for policies offered by multiple companies)
CREATE TABLE PolicyCompanyRelationships (
    RelationshipId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    PolicyCatalogId UNIQUEIDENTIFIER NOT NULL,
    CompanyId UNIQUEIDENTIFIER NOT NULL,
    BasePremium DECIMAL(10,2),
    CommissionRate DECIMAL(5,2),
    IsPreferred BIT DEFAULT 0,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    FOREIGN KEY (PolicyCatalogId) REFERENCES PolicyCatalog(PolicyCatalogId) ON DELETE CASCADE,
    FOREIGN KEY (CompanyId) REFERENCES InsuranceCompanies(CompanyId) ON DELETE CASCADE
);