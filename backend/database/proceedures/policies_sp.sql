CREATE OR ALTER PROCEDURE sp_UpsertPolicyCatalog
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @CompanyId UNIQUEIDENTIFIER,
    @CompanyName NVARCHAR(100),
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @PolicyCatalogId IS NULL
    BEGIN
        -- Create new policy catalog item
        SET @PolicyCatalogId = NEWID();
        
        INSERT INTO PolicyCatalog (
            PolicyCatalogId, AgentId, PolicyName, PolicyType, 
            CompanyId, CompanyName, Notes
        )
        VALUES (
            @PolicyCatalogId, @AgentId, @PolicyName, @PolicyType,
            @CompanyId, @CompanyName, @Notes
        );
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'policy_catalog_created', 'policy_catalog', @PolicyCatalogId, 
                'Policy "' + @PolicyName + '" added to catalog');
    END
    ELSE
    BEGIN
        -- Update existing policy catalog item
        UPDATE PolicyCatalog 
        SET 
            PolicyName = @PolicyName,
            PolicyType = @PolicyType,
            CompanyId = @CompanyId,
            CompanyName = @CompanyName,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'policy_catalog_updated', 'policy_catalog', @PolicyCatalogId, 
                'Policy "' + @PolicyName + '" updated in catalog');
    END

    SELECT @PolicyCatalogId AS PolicyCatalogId;
END;
GO

-- Get Client Policies
CREATE OR ALTER PROCEDURE sp_GetClientPolicies
    @ClientId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        PolicyId,
        PolicyName,
        PolicyType,
        CompanyName,
        Status,
        StartDate,
        EndDate,
        Notes,
        CreatedDate,
        ModifiedDate,
        DATEDIFF(DAY, GETDATE(), EndDate) AS DaysUntilExpiry
    FROM ClientPolicies
    WHERE ClientId = @ClientId AND IsActive = 1
    ORDER BY EndDate DESC;
END;
GO

-- Get Expiring Policies
CREATE OR ALTER PROCEDURE sp_GetExpiringPolicies
    @AgentId UNIQUEIDENTIFIER,
    @DaysAhead INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.PolicyName,
        cp.PolicyType,
        cp.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        c.ClientId,
        c.FirstName + ' ' + c.Surname AS ClientName,
        c.PhoneNumber,
        c.Email,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE 
        c.AgentId = @AgentId 
        AND cp.IsActive = 1
        AND c.IsActive = 1
        AND cp.Status = 'Active'
        AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, @DaysAhead, GETDATE())
    ORDER BY cp.EndDate ASC;
END;
GO

-- Get Policy Statistics
CREATE OR ALTER PROCEDURE sp_GetPolicyStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        COUNT(CASE WHEN cp.Status = 'Active' THEN 1 END) AS ActivePolicies,
        COUNT(CASE WHEN cp.Status = 'Expired' THEN 1 END) AS ExpiredPolicies,
        COUNT(CASE WHEN cp.Status = 'Lapsed' THEN 1 END) AS LapsedPolicies,
        COUNT(CASE WHEN cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE()) THEN 1 END) AS ExpiringPolicies,
        COUNT(DISTINCT cp.PolicyType) AS PolicyTypes,
        COUNT(DISTINCT cp.CompanyName) AS InsuranceCompanies
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE c.AgentId = @AgentId AND cp.IsActive = 1 AND c.IsActive = 1;
END;
GO

-- Create Policy Template
CREATE OR ALTER PROCEDURE sp_CreatePolicyTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(10,2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TemplateId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO PolicyTemplates (
        TemplateId, AgentId, TemplateName, PolicyType,
        DefaultTermMonths, DefaultPremium, CoverageDescription, Terms
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @PolicyType,
        @DefaultTermMonths, @DefaultPremium, @CoverageDescription, @Terms
    );
    
    SELECT @TemplateId AS TemplateId;
END;
GO

-- Get Policy Templates
CREATE OR ALTER PROCEDURE sp_GetPolicyTemplates
    @AgentId UNIQUEIDENTIFIER,
    @PolicyType NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        TemplateId,
        TemplateName,
        PolicyType,
        DefaultTermMonths,
        DefaultPremium,
        CoverageDescription,
        Terms,
        CreatedDate
    FROM PolicyTemplates
    WHERE 
        AgentId = @AgentId 
        AND IsActive = 1
        AND (@PolicyType IS NULL OR PolicyType = @PolicyType)
    ORDER BY PolicyType, TemplateName;
END;
GO

-- -- Delete Policy Template
-- CREATE OR ALTER PROCEDURE sp_DeletePolicyTemplate
--     @TemplateId UNIQUEIDENTIFIER,
--     @AgentId UNIQUEIDENTIFIER
-- AS
-- BEGIN
--     SET NOCOUNT ON;
    
--     UPDATE PolicyTemplates 
--     SET IsActive = 0
--     WHERE TemplateId = @TemplateId AND AgentId = @AgentId;
    
--     SELECT @@ROWCOUNT AS RowsAffected;
-- END;
--         INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
--         VALUES (@AgentId, 'policy_catalog_created', 'policy_catalog', @PolicyCatalogId, 
--                 'Policy "' + @PolicyName + '" added to catalog');
--     END
--     ELSE
--     BEGIN
--         -- Update existing policy catalog item
--         UPDATE PolicyCatalog 
--         SET 
--             PolicyName = @PolicyName,
--             PolicyType = @PolicyType,
--             CompanyId = @CompanyId,
--             CompanyName = @CompanyName,
--             Notes = @Notes,
--             ModifiedDate = GETUTCDATE()
--         WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
        
--         -- Log activity
--         INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
--         VALUES (@AgentId, 'policy_catalog_updated', 'policy_catalog', @PolicyCatalogId, 
--                 'Policy "' + @PolicyName + '" updated in catalog');
--     END
    
--     SELECT @PolicyCatalogId AS PolicyCatalogId;
-- END;
-- GO

-- Get Policy Catalog for Agent
CREATE OR ALTER PROCEDURE sp_GetPolicyCatalog
    @AgentId UNIQUEIDENTIFIER,
    @PolicyType NVARCHAR(50) = NULL,
    @CompanyName NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pc.PolicyCatalogId,
        pc.PolicyName,
        pc.PolicyType,
        pc.CompanyId,
        pc.CompanyName,
        pc.Notes,
        pc.CreatedDate,
        pc.ModifiedDate,
        ic.CompanyName AS InsuranceCompanyName
    FROM PolicyCatalog pc
    LEFT JOIN InsuranceCompanies ic ON pc.CompanyId = ic.CompanyId
    WHERE 
        pc.AgentId = @AgentId 
        AND pc.IsActive = 1
        AND (@PolicyType IS NULL OR pc.PolicyType = @PolicyType)
        AND (@CompanyName IS NULL OR pc.CompanyName LIKE '%' + @CompanyName + '%')
    ORDER BY pc.PolicyType, pc.PolicyName;
END;
GO

-- Delete Policy from Catalog
CREATE OR ALTER PROCEDURE sp_DeletePolicyCatalog
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyName NVARCHAR(100);
    
    -- Get policy name for logging
    SELECT @PolicyName = PolicyName FROM PolicyCatalog WHERE PolicyCatalogId = @PolicyCatalogId;
    
    -- Soft delete
    UPDATE PolicyCatalog 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'policy_catalog_deleted', 'policy_catalog', @PolicyCatalogId, 
            'Policy "' + @PolicyName + '" removed from catalog');
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO
-- Create or Update Client Policy
CREATE OR ALTER PROCEDURE sp_UpsertClientPolicy
    @PolicyId UNIQUEIDENTIFIER = NULL,
    @ClientId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @CompanyName NVARCHAR(100),
    @Status NVARCHAR(20),
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AgentId UNIQUEIDENTIFIER;

    -- Get agent ID from client
    SELECT @AgentId = AgentId FROM Clients WHERE ClientId = @ClientId;

    IF @PolicyId IS NULL
    BEGIN
        -- Create new client policy
        SET @PolicyId = NEWID();

        INSERT INTO ClientPolicies (
            PolicyId, ClientId, PolicyName, PolicyType, CompanyName,
            Status, StartDate, EndDate, Notes
        )
        VALUES (
            @PolicyId, @ClientId, @PolicyName, @PolicyType, @CompanyName,
            @Status, @StartDate, @EndDate, @Notes
        );

        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_created', 'client_policy', @PolicyId, 
            'Policy "' + @PolicyName + '" assigned to client'
        );
    END
    ELSE
    BEGIN
        -- Update existing client policy
        UPDATE ClientPolicies 
        SET 
            PolicyName = @PolicyName,
            PolicyType = @PolicyType,
            CompanyName = @CompanyName,
            Status = @Status,
            StartDate = @StartDate,
            EndDate = @EndDate,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE PolicyId = @PolicyId;

        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_updated', 'client_policy', @PolicyId, 
            'Policy "' + @PolicyName + '" updated for client'
        );
    END

    -- Return the policy ID
    SELECT @PolicyId AS PolicyId;
END;
GO



-- ============================================
-- Missing Policy Service Stored Procedures
-- ============================================

-- Get Policy Catalog with Filters
CREATE OR ALTER PROCEDURE sp_GetPolicyCatalog
    @AgentId UNIQUEIDENTIFIER,
    @PolicyType NVARCHAR(50) = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CompanyName NVARCHAR(100) = NULL,
    @SearchTerm NVARCHAR(100) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pc.PolicyCatalogId,
        pc.AgentId,
        pc.PolicyName,
        pc.PolicyType,
        pc.CompanyId,
        pc.CompanyName,
        pc.Notes,
        pc.IsActive,
        pc.CreatedDate,
        pc.ModifiedDate,
        ic.IsActive AS CompanyActive
    FROM PolicyCatalog pc
    LEFT JOIN InsuranceCompanies ic ON pc.CompanyId = ic.CompanyId
    WHERE 
        pc.AgentId = @AgentId
        AND (@PolicyType IS NULL OR pc.PolicyType = @PolicyType)
        AND (@CompanyId IS NULL OR pc.CompanyId = @CompanyId)
        AND (@CompanyName IS NULL OR pc.CompanyName LIKE '%' + @CompanyName + '%')
        AND (@SearchTerm IS NULL OR pc.PolicyName LIKE '%' + @SearchTerm + '%')
        AND (@IsActive IS NULL OR pc.IsActive = @IsActive)
    ORDER BY pc.PolicyName ASC;
END;
GO

-- Create Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_CreatePolicyCatalogItem
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @CompanyId UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyCatalogId UNIQUEIDENTIFIER = NEWID();
    DECLARE @CompanyName NVARCHAR(100);
    
    -- Get company name
    SELECT @CompanyName = CompanyName 
    FROM InsuranceCompanies 
    WHERE CompanyId = @CompanyId;
    
    IF @CompanyName IS NULL
    BEGIN
        SELECT 'Company not found' AS ErrorMessage;
        RETURN;
    END
    
    INSERT INTO PolicyCatalog (
        PolicyCatalogId, AgentId, PolicyName, PolicyType, CompanyId, CompanyName, Notes
    )
    VALUES (
        @PolicyCatalogId, @AgentId, @PolicyName, @PolicyType, @CompanyId, @CompanyName, @Notes
    );
    
    SELECT @PolicyCatalogId AS PolicyCatalogId;
END;
GO

-- Update Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_UpdatePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @PolicyType NVARCHAR(50) = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CompanyName NVARCHAR(100);
    
    -- Get company name if CompanyId is provided
    IF @CompanyId IS NOT NULL
    BEGIN
        SELECT @CompanyName = CompanyName 
        FROM InsuranceCompanies 
        WHERE CompanyId = @CompanyId;
        
        IF @CompanyName IS NULL
        BEGIN
            SELECT 'Company not found' AS ErrorMessage;
            RETURN;
        END
    END
    
    UPDATE PolicyCatalog 
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        PolicyType = ISNULL(@PolicyType, PolicyType),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        CompanyName = ISNULL(@CompanyName, CompanyName),
        Notes = ISNULL(@Notes, Notes),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_DeletePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Soft delete by setting IsActive to 0
    UPDATE PolicyCatalog 
    SET 
        IsActive = 0,
        ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Client Policies
CREATE OR ALTER PROCEDURE sp_GetClientPolicies
    @ClientId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = NULL,
    @PolicyType NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.PolicyType,
        cp.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        cp.CreatedDate,
        cp.ModifiedDate,
        cp.IsActive,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry,
        c.FirstName + ' ' + c.Surname AS ClientName,
        c.PhoneNumber AS ClientPhone
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE 
        cp.ClientId = @ClientId
        AND cp.IsActive = 1
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@PolicyType IS NULL OR cp.PolicyType = @PolicyType)
    ORDER BY cp.StartDate DESC;
END;
GO

-- Create Client Policy
CREATE OR ALTER PROCEDURE sp_CreateClientPolicy
    @ClientId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @CompanyName NVARCHAR(100),
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO ClientPolicies (
        PolicyId, ClientId, PolicyName, PolicyType, CompanyName, Status, StartDate, EndDate, Notes
    )
    VALUES (
        @PolicyId, @ClientId, @PolicyName, @PolicyType, @CompanyName, @Status, @StartDate, @EndDate, @Notes
    );
    
    SELECT @PolicyId AS PolicyId;
END;
GO

-- Update Client Policy
CREATE OR ALTER PROCEDURE sp_UpdateClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @PolicyType NVARCHAR(50) = NULL,
    @CompanyName NVARCHAR(100) = NULL,
    @Status NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE ClientPolicies 
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        PolicyType = ISNULL(@PolicyType, PolicyType),
        CompanyName = ISNULL(@CompanyName, CompanyName),
        Status = ISNULL(@Status, Status),
        StartDate = ISNULL(@StartDate, StartDate),
        EndDate = ISNULL(@EndDate, EndDate),
        Notes = ISNULL(@Notes, Notes),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETUTCDATE()
    WHERE PolicyId = @PolicyId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Expiring Policies
CREATE OR ALTER PROCEDURE sp_GetExpiringPolicies
    @AgentId UNIQUEIDENTIFIER,
    @DaysAhead INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @EndDate DATE = DATEADD(DAY, @DaysAhead, @StartDate);
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyName,
        cp.PolicyType,
        cp.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        cp.Notes,
        c.FirstName + ' ' + c.Surname AS ClientName,
        c.PhoneNumber AS ClientPhone,
        c.Email AS ClientEmail,
        DATEDIFF(DAY, @StartDate, cp.EndDate) AS DaysUntilExpiry
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE 
        c.AgentId = @AgentId 
        AND cp.Status = 'Active'
        AND cp.IsActive = 1
        AND c.IsActive = 1
        AND cp.EndDate BETWEEN @StartDate AND @EndDate
    ORDER BY cp.EndDate ASC;
END;
GO

-- Get Policy Statistics
CREATE OR ALTER PROCEDURE sp_GetPolicyStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
    DECLARE @MonthEnd DATE = EOMONTH(@Today);
    
    SELECT 
        -- Total Policies
        COUNT(DISTINCT cp.PolicyId) AS TotalPolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Active' THEN cp.PolicyId END) AS ActivePolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Expired' THEN cp.PolicyId END) AS ExpiredPolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Lapsed' THEN cp.PolicyId END) AS LapsedPolicies,
        COUNT(DISTINCT CASE WHEN cp.Status = 'Inactive' THEN cp.PolicyId END) AS InactivePolicies,
        
        -- Expiring Soon (next 30 days)
        COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 30, @Today) AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn30Days,
        COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 7, @Today) AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn7Days,
        
        -- New Policies This Month
        COUNT(DISTINCT CASE WHEN cp.StartDate BETWEEN @MonthStart AND @MonthEnd THEN cp.PolicyId END) AS NewPoliciesThisMonth,
        
        -- Policies by Type
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Motor' THEN cp.PolicyId END) AS MotorPolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Life' THEN cp.PolicyId END) AS LifePolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Health' THEN cp.PolicyId END) AS HealthPolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Travel' THEN cp.PolicyId END) AS TravelPolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Property' THEN cp.PolicyId END) AS PropertyPolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Marine' THEN cp.PolicyId END) AS MarinePolicies,
        COUNT(DISTINCT CASE WHEN cp.PolicyType = 'Business' THEN cp.PolicyId END) AS BusinessPolicies,
        
        -- Catalog Statistics
        COUNT(DISTINCT pc.PolicyCatalogId) AS CatalogPolicies
        
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyCatalog pc ON pc.AgentId = c.AgentId AND pc.IsActive = 1
    WHERE c.AgentId = @AgentId AND cp.IsActive = 1 AND c.IsActive = 1;
END;
GO

-- Get Insurance Companies
CREATE OR ALTER PROCEDURE sp_GetInsuranceCompanies
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
    ORDER BY CompanyName ASC;
END;
GO

-- Get Policy Types
CREATE OR ALTER PROCEDURE sp_GetPolicyTypes
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
    ORDER BY TypeName ASC;
END;
GO

-- Get Policy Templates
CREATE OR ALTER PROCEDURE sp_GetPolicyTemplates
    @AgentId UNIQUEIDENTIFIER,
    @PolicyType NVARCHAR(50) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        TemplateId,
        AgentId,
        TemplateName,
        PolicyType,
        DefaultTermMonths,
        DefaultPremium,
        CoverageDescription,
        Terms,
        IsActive,
        CreatedDate
    FROM PolicyTemplates
    WHERE 
        AgentId = @AgentId
        AND (@PolicyType IS NULL OR PolicyType = @PolicyType)
        AND (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY TemplateName ASC;
END;
GO

-- Create Policy Template
CREATE OR ALTER PROCEDURE sp_CreatePolicyTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(10,2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TemplateId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO PolicyTemplates (
        TemplateId, AgentId, TemplateName, PolicyType, DefaultTermMonths, DefaultPremium, CoverageDescription, Terms
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @PolicyType, @DefaultTermMonths, @DefaultPremium, @CoverageDescription, @Terms
    );
    
    SELECT @TemplateId AS TemplateId;
END;
GO

-- Validate Policy Data
CREATE OR ALTER PROCEDURE sp_ValidatePolicyData
    @PolicyName NVARCHAR(100),
    @PolicyType NVARCHAR(50),
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @IsValid BIT = 1;
    DECLARE @ValidationErrors NVARCHAR(MAX) = '';
    
    -- Validate Policy Name
    IF @PolicyName IS NULL OR LEN(TRIM(@PolicyName)) = 0
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Policy name is required. ';
    END
    
    -- Validate Policy Type
    IF @PolicyType IS NULL OR NOT EXISTS (SELECT 1 FROM PolicyTypes WHERE TypeName = @PolicyType AND IsActive = 1)
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Valid policy type is required. ';
    END
    
    -- Validate Company
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompanies WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Valid insurance company is required. ';
    END
    
    -- Validate Dates
    IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate >= @EndDate
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'End date must be after start date. ';
    END
    
    SELECT 
        @IsValid AS IsValid,
        RTRIM(@ValidationErrors) AS ValidationErrors;
END;
GO
