-- ============================================
-- Aminius Insurance Management System
-- Stored Procedures for Policy Management
-- ============================================

-- ============================================
-- POLICY CATALOG PROCEDURES
-- ============================================

-- Get Policy Catalog
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyCatalog')
    DROP PROCEDURE GetPolicyCatalog;
GO

CREATE PROCEDURE GetPolicyCatalog
    @AgentId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pc.PolicyCatalogId,
        pc.AgentId,
        pc.PolicyName,
        pc.CompanyId,
        ic.CompanyName,
        pc.Notes,
        pc.IsActive,
        pc.CreatedDate,
        pc.ModifiedDate,
        pc.CategoryId,
        pcat.CategoryName,
        pc.TypeId,
        pt.TypeName
    FROM PolicyCatalog pc
        LEFT JOIN InsuranceCompanies ic ON pc.CompanyId = ic.CompanyId
        LEFT JOIN PolicyCategories pcat ON pc.CategoryId = pcat.CategoryId
        LEFT JOIN PolicyTypes pt ON pc.TypeId = pt.TypeId
    WHERE (@AgentId IS NULL OR pc.AgentId = @AgentId)
        AND (@CompanyId IS NULL OR pc.CompanyId = @CompanyId)
        AND (@CategoryId IS NULL OR pc.CategoryId = @CategoryId)
        AND (@TypeId IS NULL OR pc.TypeId = @TypeId)
        AND (@IsActive IS NULL OR pc.IsActive = @IsActive)
    ORDER BY pc.PolicyName;
END
GO

-- Create Policy Catalog Item
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreatePolicyCatalogItem')
    DROP PROCEDURE CreatePolicyCatalogItem;
GO

CREATE PROCEDURE CreatePolicyCatalogItem
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @PolicyCatalogId = NEWID();
    
    INSERT INTO PolicyCatalog (
        PolicyCatalogId, AgentId, PolicyName, CompanyId, 
        Notes, CategoryId, TypeId, IsActive, CreatedDate
    )
    VALUES (
        @PolicyCatalogId, @AgentId, @PolicyName, @CompanyId,
        @Notes, @CategoryId, @TypeId, 1, GETDATE()
    );
    
    SELECT @PolicyCatalogId as PolicyCatalogId;
END
GO

-- Update Policy Catalog Item
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdatePolicyCatalogItem')
    DROP PROCEDURE UpdatePolicyCatalogItem;
GO

CREATE PROCEDURE UpdatePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyCatalog
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        Notes = ISNULL(@Notes, Notes),
        CategoryId = ISNULL(@CategoryId, CategoryId),
        TypeId = ISNULL(@TypeId, TypeId),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Delete Policy Catalog Item
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'DeletePolicyCatalogItem')
    DROP PROCEDURE DeletePolicyCatalogItem;
GO

CREATE PROCEDURE DeletePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @HardDelete = 1
    BEGIN
        DELETE FROM PolicyCatalog WHERE PolicyCatalogId = @PolicyCatalogId;
    END
    ELSE
    BEGIN
        UPDATE PolicyCatalog 
        SET IsActive = 0, ModifiedDate = GETDATE()
        WHERE PolicyCatalogId = @PolicyCatalogId;
    END
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Upsert Policy Catalog
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpsertPolicyCatalog')
    DROP PROCEDURE UpsertPolicyCatalog;
GO

CREATE PROCEDURE UpsertPolicyCatalog
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @PolicyCatalogId IS NULL OR NOT EXISTS (SELECT 1 FROM PolicyCatalog WHERE PolicyCatalogId = @PolicyCatalogId)
    BEGIN
        -- Insert new record
        SET @PolicyCatalogId = NEWID();
        INSERT INTO PolicyCatalog (
            PolicyCatalogId, AgentId, PolicyName, CompanyId, 
            Notes, CategoryId, TypeId, IsActive, CreatedDate
        )
        VALUES (
            @PolicyCatalogId, @AgentId, @PolicyName, @CompanyId,
            @Notes, @CategoryId, @TypeId, 1, GETDATE()
        );
    END
    ELSE
    BEGIN
        -- Update existing record
        UPDATE PolicyCatalog
        SET 
            PolicyName = @PolicyName,
            CompanyId = @CompanyId,
            Notes = @Notes,
            CategoryId = @CategoryId,
            TypeId = @TypeId,
            ModifiedDate = GETDATE()
        WHERE PolicyCatalogId = @PolicyCatalogId;
    END
    
    SELECT @PolicyCatalogId as PolicyCatalogId;
END
GO

-- ============================================
-- CLIENT POLICIES PROCEDURES
-- ============================================

-- Get Client Policies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetClientPolicies')
    DROP PROCEDURE GetClientPolicies;
GO

CREATE PROCEDURE GetClientPolicies
    @ClientId UNIQUEIDENTIFIER = NULL,
    @AgentId UNIQUEIDENTIFIER = NULL,
    @Status NVARCHAR(20) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.IsActive,
        cp.PolicyCatalogId,
        pc.PolicyName as CatalogPolicyName,
        cp.TypeId,
        pt.TypeName,
        cp.CompanyId,
        ic.CompanyName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE (@ClientId IS NULL OR cp.ClientId = @ClientId)
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@IsActive IS NULL OR cp.IsActive = @IsActive)
    ORDER BY cp.EndDate DESC;
END
GO
EXEC GetClientPolicies
-- Get Policy By ID
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyById')
    DROP PROCEDURE GetPolicyById;
GO

CREATE PROCEDURE GetPolicyById
    @PolicyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.IsActive,
        cp.PolicyCatalogId,
        pc.PolicyName as CatalogPolicyName,
        cp.TypeId,
        pt.TypeName,
        cp.CompanyId,
        ic.CompanyName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.PolicyId = @PolicyId;
END
GO

-- Create Client Policy
ALTER PROCEDURE CreateClientPolicy
    @ClientId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @PolicyId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @PolicyId = NEWID();

    DECLARE @CompanyId UNIQUEIDENTIFIER;
    DECLARE @TypeId UNIQUEIDENTIFIER;

    -- Pull CompanyId and TypeId from PolicyCatalog
    SELECT 
        @CompanyId = CompanyId,
        @TypeId = TypeId
    FROM PolicyCatalog
    WHERE PolicyCatalogId = @PolicyCatalogId;

    INSERT INTO ClientPolicies (
        PolicyId, ClientId, PolicyName, Status, StartDate, EndDate,
        Notes, PolicyCatalogId, TypeId, CompanyId, IsActive, CreatedDate
    )
    VALUES (
        @PolicyId, @ClientId, @PolicyName, @Status, @StartDate, @EndDate,
        @Notes, @PolicyCatalogId, @TypeId, @CompanyId, 1, GETDATE()
    );
    
    SELECT @PolicyId as PolicyId;
END
go

-- Update Client Policy
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdateClientPolicy')
    DROP PROCEDURE UpdateClientPolicy;
GO

CREATE PROCEDURE UpdateClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @Status NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE ClientPolicies
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        Status = ISNULL(@Status, Status),
        StartDate = ISNULL(@StartDate, StartDate),
        EndDate = ISNULL(@EndDate, EndDate),
        Notes = ISNULL(@Notes, Notes),
        PolicyCatalogId = ISNULL(@PolicyCatalogId, PolicyCatalogId),
        TypeId = ISNULL(@TypeId, TypeId),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETDATE()
    WHERE PolicyId = @PolicyId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Delete Client Policy
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'DeleteClientPolicy')
    DROP PROCEDURE DeleteClientPolicy;
GO

CREATE PROCEDURE DeleteClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @HardDelete = 1
    BEGIN
        DELETE FROM ClientPolicies WHERE PolicyId = @PolicyId;
    END
    ELSE
    BEGIN
        UPDATE ClientPolicies 
        SET IsActive = 0, Status = 'Cancelled', ModifiedDate = GETDATE()
        WHERE PolicyId = @PolicyId;
    END
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Upsert Client Policy
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpsertClientPolicy')
    DROP PROCEDURE UpsertClientPolicy;
GO

CREATE PROCEDURE UpsertClientPolicy
    @PolicyId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @PolicyId IS NULL OR NOT EXISTS (SELECT 1 FROM ClientPolicies WHERE PolicyId = @PolicyId)
    BEGIN
        -- Insert new record
        SET @PolicyId = NEWID();
        INSERT INTO ClientPolicies (
            PolicyId, ClientId, PolicyName, Status, StartDate, EndDate,
            Notes, PolicyCatalogId, TypeId, CompanyId, IsActive, CreatedDate
        )
        VALUES (
            @PolicyId, @ClientId, @PolicyName, @Status, @StartDate, @EndDate,
            @Notes, @PolicyCatalogId, @TypeId, @CompanyId, 1, GETDATE()
        );
    END
    ELSE
    BEGIN
        -- Update existing record
        UPDATE ClientPolicies
        SET 
            PolicyName = @PolicyName,
            Status = @Status,
            StartDate = @StartDate,
            EndDate = @EndDate,
            Notes = @Notes,
            PolicyCatalogId = @PolicyCatalogId,
            TypeId = @TypeId,
            CompanyId = @CompanyId,
            ModifiedDate = GETDATE()
        WHERE PolicyId = @PolicyId;
    END
    
    SELECT @PolicyId as PolicyId;
END
GO

-- Get Expiring Policies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetExpiringPolicies')
    DROP PROCEDURE GetExpiringPolicies;
GO

CREATE PROCEDURE GetExpiringPolicies
    @AgentId UNIQUEIDENTIFIER = NULL,
    @DaysAhead INT = 30,
    @Status NVARCHAR(20) = 'Active'
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.IsActive = 1
        AND cp.Status = @Status
        AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, @DaysAhead, GETDATE())
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    ORDER BY cp.EndDate;
END
GO
exec GetPolicyStatistics
-- Get Policy Statistics
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyStatistics')
    DROP PROCEDURE GetPolicyStatistics;
GO

CREATE PROCEDURE GetPolicyStatistics
    @AgentId UNIQUEIDENTIFIER = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @StartDate = ISNULL(@StartDate, DATEADD(YEAR, -1, GETDATE()));
    SET @EndDate = ISNULL(@EndDate, GETDATE());
    
    SELECT 
        COUNT(*) as TotalPolicies,
        SUM(CASE WHEN Status = 'Active' THEN 1 ELSE 0 END) as ActivePolicies,
        SUM(CASE WHEN Status = 'Expired' THEN 1 ELSE 0 END) as ExpiredPolicies,
        SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) as CancelledPolicies,
        SUM(CASE WHEN EndDate BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE()) THEN 1 ELSE 0 END) as ExpiringIn30Days,
        SUM(CASE WHEN EndDate BETWEEN GETDATE() AND DATEADD(DAY, 60, GETDATE()) THEN 1 ELSE 0 END) as ExpiringIn60Days
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE cp.IsActive = 1
        AND cp.CreatedDate BETWEEN @StartDate AND @EndDate
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId);
END
GO

-- Get Policy Statistics Detailed
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyStatisticsDetailed')
    DROP PROCEDURE GetPolicyStatisticsDetailed;
GO

CREATE PROCEDURE GetPolicyStatisticsDetailed
    @AgentId UNIQUEIDENTIFIER = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @StartDate = ISNULL(@StartDate, DATEADD(YEAR, -1, GETDATE()));
    SET @EndDate = ISNULL(@EndDate, GETDATE());
    
    -- By Company
    SELECT 
        'By Company' as GroupType,
        ic.CompanyName as GroupName,
        COUNT(*) as PolicyCount,
        SUM(CASE WHEN cp.Status = 'Active' THEN 1 ELSE 0 END) as ActiveCount
    FROM ClientPolicies cp
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE cp.IsActive = 1
        AND cp.CreatedDate BETWEEN @StartDate AND @EndDate
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    GROUP BY ic.CompanyName
    
    UNION ALL
    
    -- By Type
    SELECT 
        'By Type' as GroupType,
        pt.TypeName as GroupName,
        COUNT(*) as PolicyCount,
        SUM(CASE WHEN cp.Status = 'Active' THEN 1 ELSE 0 END) as ActiveCount
    FROM ClientPolicies cp
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE cp.IsActive = 1
        AND cp.CreatedDate BETWEEN @StartDate AND @EndDate
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    GROUP BY pt.TypeName
    
    ORDER BY GroupType, PolicyCount DESC;
END
GO

-- ============================================
-- POLICY SEARCH AND FILTERING PROCEDURES
-- ============================================

-- Search Policies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'SearchPolicies')
    DROP PROCEDURE SearchPolicies;
GO

CREATE PROCEDURE SearchPolicies
    @SearchTerm NVARCHAR(100) = NULL,
    @AgentId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @Status NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @PageSize INT = 50,
    @PageNumber INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        cp.PolicyCatalogId,
        pc.PolicyName as CatalogPolicyName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.IsActive = 1
        AND (@SearchTerm IS NULL OR cp.PolicyName LIKE '%' + @SearchTerm + '%' OR cp.Notes LIKE '%' + @SearchTerm + '%')
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
        AND (@ClientId IS NULL OR cp.ClientId = @ClientId)
        AND (@CompanyId IS NULL OR cp.CompanyId = @CompanyId)
        AND (@TypeId IS NULL OR cp.TypeId = @TypeId)
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@StartDate IS NULL OR cp.StartDate >= @StartDate)
        AND (@EndDate IS NULL OR cp.EndDate <= @EndDate)
    ORDER BY cp.CreatedDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- Get Policies By Status
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPoliciesByStatus')
    DROP PROCEDURE GetPoliciesByStatus;
GO

CREATE PROCEDURE GetPoliciesByStatus
    @Status NVARCHAR(20),
    @AgentId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.IsActive = 1
        AND cp.Status = @Status
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    ORDER BY cp.EndDate;
END
GO

-- ============================================
-- POLICY MANAGEMENT ACTIONS
-- ============================================

-- Renew Policy
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'RenewPolicy')
    DROP PROCEDURE RenewPolicy;
GO

CREATE PROCEDURE RenewPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @NewStartDate DATE,
    @NewEndDate DATE,
    @NewPolicyName NVARCHAR(100) = NULL,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Update old policy status
        UPDATE ClientPolicies 
        SET Status = 'Renewed', ModifiedDate = GETDATE()
        WHERE PolicyId = @PolicyId;
        
        -- Get policy details for renewal
        DECLARE @ClientId UNIQUEIDENTIFIER, @PolicyName NVARCHAR(100), 
                @PolicyCatalogId UNIQUEIDENTIFIER, @TypeId UNIQUEIDENTIFIER, 
                @CompanyId UNIQUEIDENTIFIER;
        
        SELECT 
            @ClientId = ClientId,
            @PolicyName = ISNULL(@NewPolicyName, PolicyName),
            @PolicyCatalogId = PolicyCatalogId,
            @TypeId = TypeId,
            @CompanyId = CompanyId
        FROM ClientPolicies 
        WHERE PolicyId = @PolicyId;
        
        -- Create new policy
        DECLARE @NewPolicyId UNIQUEIDENTIFIER = NEWID();
        INSERT INTO ClientPolicies (
            PolicyId, ClientId, PolicyName, Status, StartDate, EndDate,
            Notes, PolicyCatalogId, TypeId, CompanyId, IsActive, CreatedDate
        )
        VALUES (
            @NewPolicyId, @ClientId, @PolicyName, 'Active', @NewStartDate, @NewEndDate,
            @Notes, @PolicyCatalogId, @TypeId, @CompanyId, 1, GETDATE()
        );
        
        COMMIT TRANSACTION;
        
        SELECT @NewPolicyId as NewPolicyId, @@ROWCOUNT as RowsAffected;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Bulk Update Policy Status
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'BulkUpdatePolicyStatus')
    DROP PROCEDURE BulkUpdatePolicyStatus;
GO

CREATE PROCEDURE BulkUpdatePolicyStatus
    @PolicyIds NVARCHAR(MAX), -- Comma-separated list of GUIDs
    @NewStatus NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create temp table for policy IDs
    CREATE TABLE #PolicyIdList (PolicyId UNIQUEIDENTIFIER);
    
    -- Parse the comma-separated list
    INSERT INTO #PolicyIdList (PolicyId)
    SELECT TRY_CAST(value AS UNIQUEIDENTIFIER)
    FROM STRING_SPLIT(@PolicyIds, ',')
    WHERE TRY_CAST(value AS UNIQUEIDENTIFIER) IS NOT NULL;
    
    -- Update policies
    UPDATE cp
    SET Status = @NewStatus, ModifiedDate = GETDATE()
    FROM ClientPolicies cp
    INNER JOIN #PolicyIdList pil ON cp.PolicyId = pil.PolicyId;
    
    SELECT @@ROWCOUNT as RowsAffected;
    
    DROP TABLE #PolicyIdList;
END
GO

-- ============================================
-- POLICY TEMPLATES PROCEDURES
-- ============================================

-- Get Policy Templates
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyTemplates')
    DROP PROCEDURE GetPolicyTemplates;
GO

CREATE PROCEDURE GetPolicyTemplates
    @AgentId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pt.TemplateId,
        pt.AgentId,
        pt.TemplateName,
        pt.DefaultTermMonths,
        pt.DefaultPremium,
        pt.CoverageDescription,
        pt.Terms,
        pt.IsActive,
        pt.CreatedDate,
        pt.CategoryId,
        pc.CategoryName,
        pt.PolicyCatalogId,
        pol.PolicyName as CatalogPolicyName,
        pt.TypeId,
        pty.TypeName
    FROM PolicyTemplates pt
        LEFT JOIN PolicyCategories pc ON pt.CategoryId = pc.CategoryId
        LEFT JOIN PolicyCatalog pol ON pt.PolicyCatalogId = pol.PolicyCatalogId
        LEFT JOIN PolicyTypes pty ON pt.TypeId = pty.TypeId
    WHERE (@AgentId IS NULL OR pt.AgentId = @AgentId)
        AND (@CategoryId IS NULL OR pt.CategoryId = @CategoryId)
        AND (@TypeId IS NULL OR pt.TypeId = @TypeId)
        AND (@IsActive IS NULL OR pt.IsActive = @IsActive)
    ORDER BY pt.TemplateName;
END
GO

-- Create Policy Template
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreatePolicyTemplate')
    DROP PROCEDURE CreatePolicyTemplate;
GO

CREATE PROCEDURE CreatePolicyTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(18, 2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @TemplateId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @TemplateId = NEWID();
    
    INSERT INTO PolicyTemplates (
        TemplateId, AgentId, TemplateName, DefaultTermMonths, DefaultPremium,
        CoverageDescription, Terms, CategoryId, PolicyCatalogId, TypeId, IsActive, CreatedDate
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @DefaultTermMonths, @DefaultPremium,
        @CoverageDescription, @Terms, @CategoryId, @PolicyCatalogId, @TypeId, 1, GETDATE()
    );
    
    SELECT @TemplateId as TemplateId;
END
GO

-- Update Policy Template
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdatePolicyTemplate')
    DROP PROCEDURE UpdatePolicyTemplate;
GO

CREATE PROCEDURE UpdatePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100) = NULL,
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(18, 2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyTemplates
    SET 
        TemplateName = ISNULL(@TemplateName, TemplateName),
        DefaultTermMonths = ISNULL(@DefaultTermMonths, DefaultTermMonths),
        DefaultPremium = ISNULL(@DefaultPremium, DefaultPremium),
        CoverageDescription = ISNULL(@CoverageDescription, CoverageDescription),
        Terms = ISNULL(@Terms, Terms),
        CategoryId = ISNULL(@CategoryId, CategoryId),
        PolicyCatalogId = ISNULL(@PolicyCatalogId, PolicyCatalogId),
        TypeId = ISNULL(@TypeId, TypeId),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE TemplateId = @TemplateId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Delete Policy Template
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'DeletePolicyTemplate')
    DROP PROCEDURE DeletePolicyTemplate;
GO

CREATE PROCEDURE DeletePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @HardDelete = 1
    BEGIN
        DELETE FROM PolicyTemplates WHERE TemplateId = @TemplateId;
    END
    ELSE
    BEGIN
        UPDATE PolicyTemplates 
        SET IsActive = 0
        WHERE TemplateId = @TemplateId;
    END
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- ============================================
-- REFERENCE DATA PROCEDURES
-- ============================================

-- Get Insurance Companies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetInsuranceCompanies')
    DROP PROCEDURE GetInsuranceCompanies;
GO

CREATE PROCEDURE GetInsuranceCompanies
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
    ORDER BY CompanyName;
END
GO

-- Get Policy Types
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyTypes')
    DROP PROCEDURE GetPolicyTypes;
GO

CREATE PROCEDURE GetPolicyTypes
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
    ORDER BY TypeName;
END
GO

-- Get Policy Categories
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyCategories')
    DROP PROCEDURE GetPolicyCategories;
GO

CREATE PROCEDURE GetPolicyCategories
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CategoryId,
        CategoryName,
        Description,
        IsActive,
        CreatedDate
    FROM PolicyCategories
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY CategoryName;
END
GO

-- Create Policy Category
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreatePolicyCategory')
    DROP PROCEDURE CreatePolicyCategory;
GO

CREATE PROCEDURE CreatePolicyCategory
    @CategoryName NVARCHAR(50),
    @Description NVARCHAR(200) = NULL,
    @CategoryId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @CategoryId = NEWID();
    
    INSERT INTO PolicyCategories (
        CategoryId, CategoryName, Description, IsActive, CreatedDate
    )
    VALUES (
        @CategoryId, @CategoryName, @Description, 1, GETDATE()
    );
    
    SELECT @CategoryId as CategoryId;
END
GO

-- ============================================
-- ADDITIONAL RECOMMENDED PROCEDURES
-- ============================================

-- Create Insurance Company
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreateInsuranceCompany')
    DROP PROCEDURE CreateInsuranceCompany;
GO

CREATE PROCEDURE CreateInsuranceCompany
    @CompanyName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @CompanyId = NEWID();
    
    INSERT INTO InsuranceCompanies (
        CompanyId, CompanyName, IsActive, CreatedDate
    )
    VALUES (
        @CompanyId, @CompanyName, 1, GETDATE()
    );
    
    SELECT @CompanyId as CompanyId;
END
GO

-- Create Policy Type
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreatePolicyType')
    DROP PROCEDURE CreatePolicyType;
GO

CREATE PROCEDURE CreatePolicyType
    @TypeName NVARCHAR(50),
    @TypeId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @TypeId = NEWID();
    
    INSERT INTO PolicyTypes (
        TypeId, TypeName, IsActive, CreatedDate
    )
    VALUES (
        @TypeId, @TypeName, 1, GETDATE()
    );
    
    SELECT @TypeId as TypeId;
END
GO

-- Get Policy Renewal Candidates
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyRenewalCandidates')
    DROP PROCEDURE GetPolicyRenewalCandidates;
GO

CREATE PROCEDURE GetPolicyRenewalCandidates
    @AgentId UNIQUEIDENTIFIER = NULL,
    @DaysAhead INT = 60
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysUntilExpiry,
        CASE 
            WHEN DATEDIFF(DAY, GETDATE(), cp.EndDate) <= 30 THEN 'Urgent'
            WHEN DATEDIFF(DAY, GETDATE(), cp.EndDate) <= 45 THEN 'Soon'
            ELSE 'Upcoming'
        END as RenewalPriority
    FROM ClientPolicies cp
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.IsActive = 1
        AND cp.Status = 'Active'
        AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, @DaysAhead, GETDATE())
        AND (@AgentId IS NULL OR pc.AgentId = @AgentId)
    ORDER BY cp.EndDate, RenewalPriority;
END
GO

-- Get Agent Dashboard Summary
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetAgentDashboardSummary')
    DROP PROCEDURE GetAgentDashboardSummary;
GO

ALTER PROCEDURE GetAgentDashboardSummary
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalPolicies INT = 0, 
            @ActivePolicies INT = 0, 
            @ExpiringIn30Days INT = 0, 
            @ExpiringIn60Days INT = 0, 
            @TotalCompanies INT = 0, 
            @TotalClients INT = 0;
    
    -- Get policy counts
    SELECT 
        @TotalPolicies = COUNT(*),
        @ActivePolicies = SUM(CASE WHEN cp.Status = 'Active' AND cp.IsActive = 1 THEN 1 ELSE 0 END),
        @ExpiringIn30Days = SUM(
            CASE 
                WHEN cp.Status = 'Active' 
                     AND cp.IsActive = 1
                     AND cp.EndDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 30, CAST(GETDATE() AS DATE)) 
                THEN 1 ELSE 0 END),
        @ExpiringIn60Days = SUM(
            CASE 
                WHEN cp.Status = 'Active' 
                     AND cp.IsActive = 1
                     AND cp.EndDate BETWEEN DATEADD(DAY, 31, CAST(GETDATE() AS DATE)) AND DATEADD(DAY, 60, CAST(GETDATE() AS DATE)) 
                THEN 1 ELSE 0 END)
    FROM ClientPolicies cp
        INNER JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE pc.AgentId = @AgentId;

    -- Get company count (companies actually used in policies for this agent)
    SELECT @TotalCompanies = COUNT(DISTINCT cp.CompanyId)
    FROM ClientPolicies cp
        INNER JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE pc.AgentId = @AgentId
      AND cp.IsActive = 1
      AND cp.CompanyId IS NOT NULL;

    -- Get client count (all clients of the agent, regardless of policy)
    SELECT @TotalClients = COUNT(*)
    FROM Clients c
    WHERE c.AgentId = @AgentId
      AND c.IsActive = 1;

    -- Final result
    SELECT 
        @TotalPolicies as TotalPolicies,
        @ActivePolicies as ActivePolicies,
        @ExpiringIn30Days as ExpiringIn30Days,
        @ExpiringIn60Days as ExpiringIn60Days,
        @TotalCompanies as TotalCompanies,
        @TotalClients as TotalClients,
        (@TotalPolicies - @ActivePolicies) as InactivePolicies;
END
GO

-- Update Policy Category
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdatePolicyCategory')
    DROP PROCEDURE UpdatePolicyCategory;
GO

CREATE PROCEDURE UpdatePolicyCategory
    @CategoryId UNIQUEIDENTIFIER,
    @CategoryName NVARCHAR(50) = NULL,
    @Description NVARCHAR(200) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyCategories
    SET 
        CategoryName = ISNULL(@CategoryName, CategoryName),
        Description = ISNULL(@Description, Description),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE CategoryId = @CategoryId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Update Insurance Company
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdateInsuranceCompany')
    DROP PROCEDURE UpdateInsuranceCompany;
GO

CREATE PROCEDURE UpdateInsuranceCompany
    @CompanyId UNIQUEIDENTIFIER,
    @CompanyName NVARCHAR(100) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE InsuranceCompanies
    SET 
        CompanyName = ISNULL(@CompanyName, CompanyName),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE CompanyId = @CompanyId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Update Policy Type
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'UpdatePolicyType')
    DROP PROCEDURE UpdatePolicyType;
GO

CREATE PROCEDURE UpdatePolicyType
    @TypeId UNIQUEIDENTIFIER,
    @TypeName NVARCHAR(50) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyTypes
    SET 
        TypeName = ISNULL(@TypeName, TypeName),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE TypeId = @TypeId;
    
    SELECT @@ROWCOUNT as RowsAffected;
END
GO

-- Get Policy History for Client
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetPolicyHistoryForClient')
    DROP PROCEDURE GetPolicyHistoryForClient;
GO

CREATE PROCEDURE GetPolicyHistoryForClient
    @ClientId UNIQUEIDENTIFIER,
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.CompanyId,
        ic.CompanyName,
        cp.TypeId,
        pt.TypeName,
        DATEDIFF(DAY, cp.StartDate, cp.EndDate) as PolicyDurationDays,
        CASE 
            WHEN cp.Status = 'Active' AND cp.EndDate > GETDATE() THEN 'Current'
            WHEN cp.Status = 'Active' AND cp.EndDate <= GETDATE() THEN 'Expired'
            ELSE cp.Status
        END as PolicyState
    FROM ClientPolicies cp
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE cp.ClientId = @ClientId
        AND (@IncludeInactive = 1 OR cp.IsActive = 1)
    ORDER BY cp.StartDate DESC, cp.CreatedDate DESC;
END
GO

-- Batch Expire Policies
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'BatchExpirePolicies')
    DROP PROCEDURE BatchExpirePolicies;
GO

CREATE PROCEDURE BatchExpirePolicies
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @AsOfDate = ISNULL(@AsOfDate, GETDATE());
    
    UPDATE ClientPolicies
    SET Status = 'Expired', ModifiedDate = GETDATE()
    WHERE Status = 'Active' 
        AND EndDate < @AsOfDate
        AND IsActive = 1;
    
    SELECT @@ROWCOUNT as PoliciesExpired;
END
GO

-- ============================================
-- UTILITY PROCEDURES
-- ============================================

-- Cleanup Soft Deleted Records
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CleanupSoftDeletedRecords')
    DROP PROCEDURE CleanupSoftDeletedRecords;
GO

CREATE PROCEDURE CleanupSoftDeletedRecords
    @DaysOld INT = 365,
    @DryRun BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@DaysOld, GETDATE());
    
    IF @DryRun = 1
    BEGIN
        -- Show what would be deleted
        SELECT 'ClientPolicies' as TableName, COUNT(*) as RecordsToDelete
        FROM ClientPolicies 
        WHERE IsActive = 0 AND ModifiedDate < @CutoffDate
        
        UNION ALL
        
        SELECT 'PolicyCatalog' as TableName, COUNT(*) as RecordsToDelete
        FROM PolicyCatalog 
        WHERE IsActive = 0 AND ModifiedDate < @CutoffDate
        
        UNION ALL
        
        SELECT 'PolicyTemplates' as TableName, COUNT(*) as RecordsToDelete
        FROM PolicyTemplates 
        WHERE IsActive = 0 AND CreatedDate < @CutoffDate;
    END
    ELSE
    BEGIN
        -- Actually delete the records
        DECLARE @DeletedCount INT = 0;
        
        DELETE FROM ClientPolicies 
        WHERE IsActive = 0 AND ModifiedDate < @CutoffDate;
        SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
        
        DELETE FROM PolicyCatalog 
        WHERE IsActive = 0 AND ModifiedDate < @CutoffDate;
        SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
        
        DELETE FROM PolicyTemplates 
        WHERE IsActive = 0 AND CreatedDate < @CutoffDate;
        SET @DeletedCount = @DeletedCount + @@ROWCOUNT;
        
        SELECT @DeletedCount as TotalRecordsDeleted;
    END
END
GO

-- ============================================
-- END OF STORED PROCEDURES
-- ============================================

PRINT 'All Aminius Insurance Management stored procedures have been created successfully!';
GO

-- ============================================
-- 1. Create Insurance Company
-- ============================================
CREATE OR ALTER PROCEDURE sp_CreateInsuranceCompany
    @CompanyName NVARCHAR(100),
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO InsuranceCompanies (CompanyId, CompanyName, IsActive, CreatedDate)
    VALUES (NEWID(), @CompanyName, @IsActive, GETDATE());
END
GO

-- ============================================
-- 2. Get All Insurance Companies
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetInsuranceCompanies
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CompanyId, CompanyName, IsActive, CreatedDate
    FROM InsuranceCompanies
    ORDER BY CompanyName;
END
GO

-- ============================================
-- 3. Get Insurance Company by ID
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetInsuranceCompanyById
    @CompanyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CompanyId, CompanyName, IsActive, CreatedDate
    FROM InsuranceCompanies
    WHERE CompanyId = @CompanyId;
END
GO

-- ============================================
-- 4. Update Insurance Company
-- ============================================
CREATE OR ALTER PROCEDURE sp_UpdateInsuranceCompany
    @CompanyId UNIQUEIDENTIFIER,
    @CompanyName NVARCHAR(100),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE InsuranceCompanies
    SET CompanyName = @CompanyName,
        IsActive = @IsActive
    WHERE CompanyId = @CompanyId;
END
GO

-- ============================================
-- 5. Delete Insurance Company (Soft Delete)
-- ============================================
CREATE OR ALTER PROCEDURE sp_DeleteInsuranceCompany
    @CompanyId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @HardDelete = 1
    BEGIN
        DELETE FROM InsuranceCompanies
        WHERE CompanyId = @CompanyId;
    END
    ELSE
    BEGIN
        UPDATE InsuranceCompanies
        SET IsActive = 0
        WHERE CompanyId = @CompanyId;
    END
END
GO
-- ============================================
-- 1. Create Policy Category
-- ============================================
CREATE OR ALTER PROCEDURE sp_CreatePolicyCategory
    @CategoryName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO PolicyCategories (CategoryId, CategoryName, CompanyId, IsActive, CreatedDate)
    VALUES (NEWID(), @CategoryName, @CompanyId, @IsActive, GETDATE());
END
GO

-- ============================================
-- 2. Get All Policy Categories
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetPolicyCategories
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CategoryId, c.CategoryName, c.CompanyId, ic.CompanyName, c.IsActive, c.CreatedDate
    FROM PolicyCategories c
    INNER JOIN InsuranceCompanies ic ON c.CompanyId = ic.CompanyId
    ORDER BY ic.CompanyName, c.CategoryName;
END
GO

-- ============================================
-- 3. Get Policy Category by ID
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetPolicyCategoryById
    @CategoryId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CategoryId, c.CategoryName, c.CompanyId, ic.CompanyName, c.IsActive, c.CreatedDate
    FROM PolicyCategories c
    INNER JOIN InsuranceCompanies ic ON c.CompanyId = ic.CompanyId
    WHERE c.CategoryId = @CategoryId;
END
GO

-- ============================================
-- 4. Update Policy Category
-- ============================================
CREATE OR ALTER PROCEDURE sp_UpdatePolicyCategory
    @CategoryId UNIQUEIDENTIFIER,
    @CategoryName NVARCHAR(100),
    @CompanyId UNIQUEIDENTIFIER,
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCategories
    SET CategoryName = @CategoryName,
        CompanyId = @CompanyId,
        IsActive = @IsActive
    WHERE CategoryId = @CategoryId;
END
GO

-- ============================================
-- 5. Delete Policy Category (Soft Delete)
-- ============================================
CREATE OR ALTER PROCEDURE sp_DeletePolicyCategory
    @CategoryId UNIQUEIDENTIFIER,
    @HardDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @HardDelete = 1
    BEGIN
        DELETE FROM PolicyCategories
        WHERE CategoryId = @CategoryId;
    END
    ELSE
    BEGIN
        UPDATE PolicyCategories
        SET IsActive = 0
        WHERE CategoryId = @CategoryId;
    END
END
GO
-- ============================================
-- Create Policy Type (GUID Primary Key)
-- ============================================
CREATE OR ALTER PROCEDURE sp_CreatePolicyType
    @TypeName NVARCHAR(50),
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewId UNIQUEIDENTIFIER = NEWID();

    INSERT INTO PolicyTypes (TypeId, TypeName, IsActive)
    VALUES (@NewId, @TypeName, @IsActive);

    SELECT * FROM PolicyTypes WHERE TypeId = @NewId;
END
GO


-- ============================================
-- Get All Policy Types
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetPolicyTypes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM PolicyTypes
    ORDER BY CreatedDate DESC;
END
GO

-- ============================================
-- Get Policy Type By Id
-- ============================================
CREATE OR ALTER PROCEDURE sp_GetPolicyTypeById
    @TypeId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM PolicyTypes
    WHERE TypeId = @TypeId;
END
GO

-- ============================================
-- Update Policy Type
-- ============================================
CREATE OR ALTER PROCEDURE sp_UpdatePolicyType
    @TypeId UNIQUEIDENTIFIER,
    @TypeName NVARCHAR(50),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyTypes
    SET TypeName = @TypeName,
        IsActive = @IsActive
    WHERE TypeId = @TypeId;
END
GO

-- ============================================
-- Delete Policy Type
-- ============================================
CREATE OR ALTER PROCEDURE sp_DeletePolicyType
    @TypeId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM PolicyTypes
    WHERE TypeId = @TypeId;
END
GO



CREATE OR ALTER PROCEDURE sp_SoftDeletePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyTemplates
    SET IsActive = 0
    WHERE TemplateId = @TemplateId;
END

GO

CREATE OR ALTER PROCEDURE sp_SoftDeletePolicyCatalog
    @PolicyCatalogId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCatalog
    SET IsActive = 0,
        ModifiedDate = GETDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId;
END

GO

CREATE OR ALTER PROCEDURE sp_SoftDeletePolicyCategory
    @CategoryId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCategories
    SET IsActive = 0
    WHERE CategoryId = @CategoryId;
END

GO

CREATE OR ALTER PROCEDURE sp_SoftDeleteInsuranceCompany
    @CompanyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE InsuranceCompanies
    SET IsActive = 0
    WHERE CompanyId = @CompanyId;
END

GO

CREATE OR ALTER PROCEDURE sp_SoftDeleteClientPolicy
    @PolicyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ClientPolicies
    SET IsActive = 0,
        ModifiedDate = GETDATE()
    WHERE PolicyId = @PolicyId;
END
GO


CREATE PROCEDURE ClientPolicies_SoftDelete
    @PolicyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ClientPolicies
    SET IsActive = 0,
        ModifiedDate = GETDATE()
    WHERE PolicyId = @PolicyId AND IsActive = 1;
END;
go
CREATE PROCEDURE InsuranceCompanies_SoftDelete
    @CompanyId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE InsuranceCompanies
    SET IsActive = 0,
        CreatedDate = CreatedDate -- keep original
    WHERE CompanyId = @CompanyId AND IsActive = 1;
END;
go
CREATE PROCEDURE PolicyCatalog_SoftDelete
    @PolicyCatalogId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCatalog
    SET IsActive = 0,
        ModifiedDate = GETDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId AND IsActive = 1;
END;
go
CREATE PROCEDURE PolicyCategories_SoftDelete
    @CategoryId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyCategories
    SET IsActive = 0
    WHERE CategoryId = @CategoryId AND IsActive = 1;
END;
go 
CREATE PROCEDURE PolicyTemplates_SoftDelete
    @TemplateId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyTemplates
    SET IsActive = 0,
        CreatedDate = CreatedDate -- preserve
    WHERE TemplateId = @TemplateId AND IsActive = 1;
END;
go 
CREATE PROCEDURE PolicyTypes_SoftDelete
    @TypeId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PolicyTypes
    SET IsActive = 0
    WHERE TypeId = @TypeId AND IsActive = 1;
END;
go
exec GetClientsWithPolicies
go
ALTER PROCEDURE GetClientsWithPolicies
    @AgentId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER = NULL,
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        c.ClientId,
        c.AgentId,
        c.FirstName,
        c.Surname,
        c.LastName,
        (c.FirstName + ' ' + c.Surname + ' ' + c.LastName) AS FullName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.NationalId,
        c.DateOfBirth,
        c.IsClient,
        c.InsuranceType,
        c.Notes AS ClientNotes,
        c.CreatedDate AS ClientCreatedDate,
        c.ModifiedDate AS ClientModifiedDate,
        c.IsActive AS ClientIsActive,

        cp.PolicyId,
        cp.PolicyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes AS PolicyNotes,
        cp.CreatedDate AS PolicyCreatedDate,
        cp.ModifiedDate AS PolicyModifiedDate,
        cp.IsActive AS PolicyIsActive,
        cp.PolicyCatalogId,
        pc.PolicyName AS CatalogPolicyName,
        cp.TypeId,
        pt.TypeName,
        cp.CompanyId,
        ic.CompanyName,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
    FROM Clients c
        INNER JOIN ClientPolicies cp 
            ON c.ClientId = cp.ClientId
           AND cp.PolicyId IS NOT NULL
           AND cp.CompanyId IS NOT NULL
           AND cp.TypeId IS NOT NULL  -- ✅ ensure valid policy only
        LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
        LEFT JOIN PolicyTypes pt ON cp.TypeId = pt.TypeId
        LEFT JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        (@AgentId IS NULL OR c.AgentId = @AgentId)
        AND (@ClientId IS NULL OR c.ClientId = @ClientId)
        AND (
            @IncludeInactive = 1 
            OR (c.IsActive = 1 AND cp.IsActive = 1)
        )
    ORDER BY c.CreatedDate DESC, cp.EndDate DESC;
END;
GO


exec GetClientsWithPolicies
go
ALTER PROCEDURE GetAgentDashboardSummary
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalPolicies INT = 0,
            @ActivePolicies INT = 0,
            @ExpiringIn30Days INT = 0,
            @ExpiringIn60Days INT = 0,
            @TotalCompanies INT = 0,
            @TotalClients INT = 0;

    ;WITH AgentPolicies AS (
        SELECT
            cp.PolicyId,
            cp.ClientId,
            cp.CompanyId,
            cp.StartDate,
            cp.EndDate,
            -- normalize status once
            UPPER(LTRIM(RTRIM(cp.Status))) AS NormStatus,
            -- treat NULL as active
            CASE WHEN ISNULL(cp.IsActive, 1) = 1 THEN 1 ELSE 0 END AS IsActiveFlag
        FROM ClientPolicies cp
        INNER JOIN Clients c
            ON c.ClientId = cp.ClientId
        WHERE c.AgentId = @AgentId
          -- policy considered present in the dashboard only if (NULL -> active) or explicitly active
          AND ISNULL(cp.IsActive, 1) = 1
    )
    SELECT
        @TotalPolicies =
            COUNT(*),
        @ActivePolicies =
            SUM(CASE
                    WHEN NormStatus = 'ACTIVE'
                         AND EndDate >= CAST(GETDATE() AS DATE)
                    THEN 1 ELSE 0
                END),
        @ExpiringIn30Days =
            SUM(CASE
                    WHEN NormStatus = 'ACTIVE'
                         AND EndDate BETWEEN CAST(GETDATE() AS DATE)
                                         AND DATEADD(DAY, 30, CAST(GETDATE() AS DATE))
                    THEN 1 ELSE 0
                END),
        @ExpiringIn60Days =
            SUM(CASE
                    WHEN NormStatus = 'ACTIVE'
                         AND EndDate BETWEEN DATEADD(DAY, 31, CAST(GETDATE() AS DATE))
                                         AND DATEADD(DAY, 60, CAST(GETDATE() AS DATE))
                    THEN 1 ELSE 0
                END),
        @TotalCompanies =
            COUNT(DISTINCT CASE WHEN CompanyId IS NOT NULL THEN CompanyId END)
    FROM AgentPolicies;

    -- Count all active clients for this agent (not only those with policies)
    SELECT @TotalClients = COUNT(*)
    FROM Clients c
    WHERE c.AgentId = @AgentId
      AND ISNULL(c.IsActive, 1) = 1;

    SELECT
        @TotalPolicies      AS TotalPolicies,
        @ActivePolicies     AS ActivePolicies,
        @ExpiringIn30Days   AS ExpiringIn30Days,
        @ExpiringIn60Days   AS ExpiringIn60Days,
        @TotalCompanies     AS TotalCompanies,
        @TotalClients       AS TotalClients,
        (@TotalPolicies - @ActivePolicies) AS InactivePolicies;
END
GO
