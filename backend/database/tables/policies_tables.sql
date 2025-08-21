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


INSERT INTO PolicyTypes (TypeId, TypeName)
VALUES (NEWID(), 'Auto Policy');
INSERT INTO PolicyCatalog (AgentId, PolicyName, CompanyId, CategoryId, TypeId)
VALUES (@AgentId, 'Test Policy', @CompanyId, @CategoryId, @TypeId);
INSERT INTO PolicyCategories (CategoryId, CategoryName)
VALUES (NEWID(), 'Life Insurance');

-- -- CREATE SYNONYM InsuranceCompany FOR dbo.InsuranceCompanies;
-- -- CREATE SYNONYM PolicyType FOR dbo.PolicyTypes;
-- -- CREATE SYNONYM PolicyCategory FOR dbo.PolicyCategories;
-- -- CREATE SYNONYM PolicyTemplate FOR dbo.PolicyTemplates;


SELECT * FROM PolicyCategories




-- 1. ClientPolicies
-- Stores individual client’s policy details.

-- Links to:

-- Clients (ClientId)

-- PolicyCatalog (PolicyCatalogId)

-- PolicyTypes (TypeId)

-- InsuranceCompanies (CompanyId)

-- Fields: PolicyId, ClientId, PolicyName, Status, StartDate, EndDate, Notes, IsActive, etc.

-- 2. PolicyCatalog
-- Master list of available policies (product definitions).

-- Links to:

-- PolicyCategories (CategoryId)

-- PolicyTypes (TypeId)

-- InsuranceCompanies via PolicyCompanyRelationships

-- Fields: PolicyCatalogId, AgentId, PolicyName, CompanyId, Notes, IsActive, etc.

-- 3. PolicyCategories
-- Categories or classifications of policies.

-- Fields: CategoryId, CategoryName, Description, IsActive.

-- 4. PolicyCompanyRelationships
-- Defines which company offers which catalog policy and under what terms.

-- Links to:

-- PolicyCatalog (PolicyCatalogId)

-- InsuranceCompanies (CompanyId)

-- Fields: BasePremium, CommissionRate, IsPreferred, etc.

-- 5. PolicyTemplates
-- Stores reusable templates for creating new policies.

-- Links to:

-- PolicyCatalog (PolicyCatalogId)

-- PolicyCategories (CategoryId)

-- PolicyTypes (TypeId)

-- Fields: TemplateId, TemplateName, DefaultTermMonths, DefaultPremium, CoverageDescription, etc.

-- 6. PolicyTypes
-- Defines the type/class of policy.

-- Fields: TypeId, TypeName, IsActive.

-- 7. InsuranceCompanies
-- Holds insurance company information.

-- Fields: CompanyId, CompanyName, IsActive.