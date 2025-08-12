-- /* =========================
--    UPSERT Policy Catalog
--    ========================= */
-- CREATE OR ALTER PROCEDURE sp_UpsertPolicyCatalog
--     @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
--     @AgentId UNIQUEIDENTIFIER,
--     @PolicyName NVARCHAR(100),
--     @PolicyType NVARCHAR(50),
--     @CompanyId UNIQUEIDENTIFIER,
--     @CompanyName NVARCHAR(100),
--     @CategoryId UNIQUEIDENTIFIER = NULL,
--     @Notes NVARCHAR(MAX) = NULL
-- AS
-- BEGIN 
--     SET NOCOUNT ON;
    
--     IF @PolicyCatalogId IS NULL
--     BEGIN
--         SET @PolicyCatalogId = NEWID();
        
--         INSERT INTO PolicyCatalog (
--             PolicyCatalogId, AgentId, PolicyName, PolicyType, 
--             CompanyId, CompanyName, CategoryId, Notes
--         )
--         VALUES (
--             @PolicyCatalogId, @AgentId, @PolicyName, @PolicyType,
--             @CompanyId, @CompanyName, @CategoryId, @Notes
--         );
        
--         INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
--         VALUES (@AgentId, 'policy_catalog_created', 'policy_catalog', @PolicyCatalogId, 
--                 'Policy "' + @PolicyName + '" added to catalog');
--     END
--     ELSE
--     BEGIN
--         UPDATE PolicyCatalog 
--         SET 
--             PolicyName = @PolicyName,
--             PolicyType = @PolicyType,
--             CompanyId = @CompanyId,
--             CompanyName = @CompanyName,
--             CategoryId = @CategoryId,
--             Notes = @Notes,
--             ModifiedDate = GETUTCDATE()
--         WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
        
--         INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
--         VALUES (@AgentId, 'policy_catalog_updated', 'policy_catalog', @PolicyCatalogId, 
--                 'Policy "' + @PolicyName + '" updated in catalog');
--     END

--     SELECT @PolicyCatalogId AS PolicyCatalogId;
-- END;
-- GO

-- /* =========================
--    GET Client Policies
--    ========================= */
-- CREATE OR ALTER PROCEDURE sp_GetClientPolicies
--     @ClientId UNIQUEIDENTIFIER
-- AS
-- BEGIN
--     SET NOCOUNT ON;
    
--     SELECT 
--         cp.PolicyId,
--         cp.PolicyCatalogId,
--         pc.PolicyName,
--         pc.PolicyType,
--         pc.CompanyName,
--         pc.CategoryId,
--         cat.CategoryName,
--         cp.Status,
--         cp.StartDate,
--         cp.EndDate,
--         cp.Notes,
--         cp.CreatedDate,
--         cp.ModifiedDate,
--         DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
--     FROM ClientPolicies cp
--     LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
--     LEFT JOIN PolicyCategories cat ON pc.CategoryId = cat.CategoryId
--     WHERE cp.ClientId = @ClientId AND cp.IsActive = 1
--     ORDER BY cp.EndDate DESC;
-- END;
-- GO

-- /* =========================
--    GET Expiring Policies
--    ========================= */
-- CREATE OR ALTER PROCEDURE sp_GetExpiringPolicies
--     @AgentId UNIQUEIDENTIFIER,
--     @DaysAhead INT = 30
-- AS
-- BEGIN
--     SET NOCOUNT ON;
    
--     SELECT 
--         cp.PolicyId,
--         cp.PolicyCatalogId,
--         pc.PolicyName,
--         pc.PolicyType,
--         pc.CompanyName,
--         pc.CategoryId,
--         cat.CategoryName,
--         cp.Status,
--         cp.StartDate,
--         cp.EndDate,
--         cp.Notes,
--         c.ClientId,
--         c.FirstName + ' ' + c.Surname AS ClientName,
--         c.PhoneNumber,
--         c.Email,
--         DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
--     FROM ClientPolicies cp
--     INNER JOIN Clients c ON cp.ClientId = c.ClientId
--     LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
--     LEFT JOIN PolicyCategories cat ON pc.CategoryId = cat.CategoryId
--     WHERE 
--         c.AgentId = @AgentId 
--         AND cp.IsActive = 1
--         AND c.IsActive = 1
--         AND cp.Status = 'Active'
--         AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, @DaysAhead, GETDATE())
--     ORDER BY cp.EndDate ASC;
-- END;
-- GO

-- /* =========================
--    GET Policy Statistics
--    ========================= */
-- CREATE OR ALTER PROCEDURE sp_GetPolicyStatistics
--     @AgentId UNIQUEIDENTIFIER
-- AS
-- BEGIN
--     SET NOCOUNT ON;
    
--     SELECT 
--         COUNT(CASE WHEN cp.Status = 'Active' THEN 1 END) AS ActivePolicies,
--         COUNT(CASE WHEN cp.Status = 'Expired' THEN 1 END) AS ExpiredPolicies,
--         COUNT(CASE WHEN cp.Status = 'Lapsed' THEN 1 END) AS LapsedPolicies,
--         COUNT(CASE WHEN cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE()) THEN 1 END) AS ExpiringPolicies,
--         COUNT(DISTINCT pc.PolicyType) AS PolicyTypes,
--         COUNT(DISTINCT pc.CompanyName) AS InsuranceCompanies,
--         COUNT(DISTINCT pc.CategoryId) AS PolicyCategoriesCount
--     FROM ClientPolicies cp
--     INNER JOIN Clients c ON cp.ClientId = c.ClientId
--     LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
--     WHERE c.AgentId = @AgentId AND cp.IsActive = 1 AND c.IsActive = 1;
-- END;
-- GO

-- /* =========================
--    UPSERT Client Policy
--    ========================= */
-- CREATE OR ALTER PROCEDURE sp_UpsertClientPolicy
--     @PolicyId UNIQUEIDENTIFIER = NULL,
--     @ClientId UNIQUEIDENTIFIER,
--     @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
--     @Status NVARCHAR(20),
--     @StartDate DATE,
--     @EndDate DATE,
--     @Notes NVARCHAR(MAX) = NULL
-- AS
-- BEGIN
--     SET NOCOUNT ON;

--     DECLARE @AgentId UNIQUEIDENTIFIER, @PolicyName NVARCHAR(100);

--     SELECT @AgentId = AgentId FROM Clients WHERE ClientId = @ClientId;
--     SELECT @PolicyName = PolicyName FROM PolicyCatalog WHERE PolicyCatalogId = @PolicyCatalogId;

--     IF @PolicyId IS NULL
--     BEGIN
--         SET @PolicyId = NEWID();

--         INSERT INTO ClientPolicies (
--             PolicyId, ClientId, PolicyCatalogId, Status, StartDate, EndDate, Notes
--         )
--         VALUES (
--             @PolicyId, @ClientId, @PolicyCatalogId, @Status, @StartDate, @EndDate, @Notes
--         );

--         INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
--         VALUES (
--             @AgentId, 'client_policy_created', 'client_policy', @PolicyId, 
--             'Policy "' + ISNULL(@PolicyName,'(Unknown)') + '" assigned to client'
--         );
--     END
--     ELSE
--     BEGIN
--         UPDATE ClientPolicies 
--         SET 
--             PolicyCatalogId = @PolicyCatalogId,
--             Status = @Status,
--             StartDate = @StartDate,
--             EndDate = @EndDate,
--             Notes = @Notes,
--             ModifiedDate = GETUTCDATE()
--         WHERE PolicyId = @PolicyId;

--         INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
--         VALUES (
--             @AgentId, 'client_policy_updated', 'client_policy', @PolicyId, 
--             'Policy "' + ISNULL(@PolicyName,'(Unknown)') + '" updated for client'
--         );
--     END

--     SELECT @PolicyId AS PolicyId;
-- END;
-- GO


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
    
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (
        @AgentId, 'policy_template_created', 'policy_template', @TemplateId, 
        'Policy template "' + @TemplateName + '" created'
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
CREATE OR ALTER PROCEDURE sp_DeletePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyTemplates 
    SET IsActive = 0
    WHERE TemplateId = @TemplateId AND AgentId = @AgentId;
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'policy_template_deleted', 'policy_template', @TemplateId, 
            'Policy template deleted'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO



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
    
    -- Soft delete (without ModifiedDate)
    UPDATE PolicyCatalog 
    SET IsActive = 0
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
        -- Update existing client policy (no ModifiedDate)
        UPDATE ClientPolicies 
        SET 
            PolicyName = @PolicyName,
            PolicyType = @PolicyType,
            CompanyName = @CompanyName,
            Status = @Status,
            StartDate = @StartDate,
            EndDate = @EndDate,
            Notes = @Notes
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
        ic.CompanyName AS InsuranceCompanyName,
        pc.Notes,
        pc.IsActive,
        pc.CreatedDate,
        pc.ModifiedDate,
        ic.IsActive AS CompanyActive
    FROM PolicyCatalog pc
    LEFT JOIN InsuranceCompanies ic 
        ON pc.CompanyId = ic.CompanyId
    WHERE 
        pc.AgentId = @AgentId
        AND (@PolicyType IS NULL OR pc.PolicyType = @PolicyType)
        AND (@CompanyId IS NULL OR pc.CompanyId = @CompanyId)
        AND (@CompanyName IS NULL OR ic.CompanyName LIKE '%' + @CompanyName + '%')
        AND (@SearchTerm IS NULL 
             OR pc.PolicyName LIKE '%' + @SearchTerm + '%'
             OR ic.CompanyName LIKE '%' + @SearchTerm + '%')
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
    WHERE CompanyId = @CompanyId AND IsActive = 1;
    
    IF @CompanyName IS NULL
    BEGIN
        SELECT 'Company not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    INSERT INTO PolicyCatalog (
        PolicyCatalogId, AgentId, PolicyName, PolicyType, 
        CompanyId, CompanyName, Notes, IsActive, CreatedDate
    )
    VALUES (
        @PolicyCatalogId, @AgentId, @PolicyName, @PolicyType, 
        @CompanyId, @CompanyName, @Notes, 1, GETUTCDATE()
    );
    
    SELECT @PolicyCatalogId AS PolicyCatalogId;
END;
GO
/* ==============================================
   Update Policy Catalog Item
   ============================================== */
/* ==============================================
   Update Policy Catalog Item
   ============================================== */
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
        WHERE CompanyId = @CompanyId AND IsActive = 1;
        
        IF @CompanyName IS NULL
        BEGIN
            SELECT 'Company not found or inactive' AS ErrorMessage;
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
    WHERE PolicyCatalogId = @PolicyCatalogId 
      AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO


/* ==============================================
   Delete Policy Catalog Item (Soft Delete)
   ============================================== */
CREATE OR ALTER PROCEDURE sp_DeletePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    -- Mark as inactive
    UPDATE PolicyCatalog 
    SET IsActive = 0,
        ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId 
      AND AgentId = @AgentId;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO


/* ==============================================
   Get Client Policies (linked to PolicyCatalog)
   ============================================== */
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
        cp.PolicyCatalogId,
        pc.PolicyName,
        pc.PolicyType,
        pc.CompanyName,
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
    INNER JOIN Clients c 
        ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyCatalog pc
        ON cp.PolicyCatalogId = pc.PolicyCatalogId
    WHERE 
        cp.ClientId = @ClientId
        AND cp.IsActive = 1
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@PolicyType IS NULL OR pc.PolicyType = @PolicyType)
    ORDER BY cp.StartDate DESC;
END;
GO


/* ==============================================
   Create Client Policy (linked to PolicyCatalog)
   ============================================== */
CREATE OR ALTER PROCEDURE sp_CreateClientPolicy
    @ClientId UNIQUEIDENTIFIER,
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PolicyId UNIQUEIDENTIFIER = NEWID();
    DECLARE @PolicyName NVARCHAR(100);
    DECLARE @PolicyType NVARCHAR(50);
    DECLARE @CompanyName NVARCHAR(100);

    -- Get policy details from PolicyCatalog
    SELECT 
        @PolicyName = PolicyName,
        @PolicyType = PolicyType,
        @CompanyName = CompanyName
    FROM PolicyCatalog
    WHERE PolicyCatalogId = @PolicyCatalogId AND IsActive = 1;

    IF @PolicyName IS NULL
    BEGIN
        SELECT 'Policy Catalog item not found or inactive' AS ErrorMessage;
        RETURN;
    END

    INSERT INTO ClientPolicies (
        PolicyId, ClientId, PolicyCatalogId, PolicyName, PolicyType, CompanyName, 
        Status, StartDate, EndDate, Notes, IsActive, CreatedDate
    )
    VALUES (
        @PolicyId, @ClientId, @PolicyCatalogId, @PolicyName, @PolicyType, @CompanyName,
        @Status, @StartDate, @EndDate, @Notes, 1, GETUTCDATE()
    );
    
    SELECT @PolicyId AS PolicyId;
END;
GO
-- /* ==============================================
--    Update Client Policy (linked to PolicyCatalog)
--    ============================================== */
-- CREATE OR ALTER PROCEDURE sp_UpdateClientPolicy
--     @PolicyId UNIQUEIDENTIFIER,
--     @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
--     @Status NVARCHAR(20) = NULL,
--     @StartDate DATE = NULL,
--     @EndDate DATE = NULL,
--     @Notes NVARCHAR(MAX) = NULL,
--     @IsActive BIT = NULL
-- AS
-- BEGIN
--     SET NOCOUNT ON;

--     -- If PolicyCatalogId provided, ensure it exists and is active
--     IF @PolicyCatalogId IS NOT NULL
--     BEGIN
--         IF NOT EXISTS (
--             SELECT 1 
--             FROM PolicyCatalog 
--             WHERE PolicyCatalogId = @PolicyCatalogId 
--               AND IsActive = 1
--         )
--         BEGIN
--             SELECT 'Policy Catalog item not found or inactive' AS ErrorMessage;
--             RETURN;
--         END
--     END

--     UPDATE ClientPolicies 
--     SET 
--         PolicyCatalogId = ISNULL(@PolicyCatalogId, PolicyCatalogId),
--         Status = ISNULL(@Status, Status),
--         StartDate = ISNULL(@StartDate, StartDate),
--         EndDate = ISNULL(@EndDate, EndDate),
--         Notes = ISNULL(@Notes, Notes),
--         IsActive = ISNULL(@IsActive, IsActive),
--         ModifiedDate = GETUTCDATE()
--     WHERE PolicyId = @PolicyId;
    
--     SELECT @@ROWCOUNT AS RowsAffected;
-- END;
-- GO


-- /* ==============================================
--    Get Expiring Policies (linked to PolicyCatalog)
--    ============================================== */
-- CREATE OR ALTER PROCEDURE sp_GetExpiringPolicies
--     @AgentId UNIQUEIDENTIFIER,
--     @DaysAhead INT = 30
-- AS
-- BEGIN
--     SET NOCOUNT ON;

--     DECLARE @StartDate DATE = CAST(GETDATE() AS DATE);
--     DECLARE @EndDate DATE = DATEADD(DAY, @DaysAhead, @StartDate);

--     SELECT 
--         cp.PolicyId,
--         cp.ClientId,
--         pc.PolicyName,
--         pc.PolicyType,
--         pc.CompanyName,
--         cp.Status,
--         cp.StartDate,
--         cp.EndDate,
--         cp.Notes,
--         c.FirstName + ' ' + c.Surname AS ClientName,
--         c.PhoneNumber AS ClientPhone,
--         c.Email AS ClientEmail,
--         DATEDIFF(DAY, @StartDate, cp.EndDate) AS DaysUntilExpiry
--     FROM ClientPolicies cp
--     INNER JOIN Clients c 
--         ON cp.ClientId = c.ClientId
--     LEFT JOIN PolicyCatalog pc 
--         ON cp.PolicyCatalogId = pc.PolicyCatalogId
--     WHERE 
--         c.AgentId = @AgentId 
--         AND cp.Status = 'Active'
--         AND cp.IsActive = 1
--         AND c.IsActive = 1
--         AND cp.EndDate BETWEEN @StartDate AND @EndDate
--     ORDER BY cp.EndDate ASC;
-- END;
-- GO


-- /* ==============================================
--    Get Policy Statistics (linked to PolicyCatalog)
--    ============================================== */
-- CREATE OR ALTER PROCEDURE sp_GetPolicyStatistics
--     @AgentId UNIQUEIDENTIFIER
-- AS
-- BEGIN
--     SET NOCOUNT ON;

--     DECLARE @Today DATE = CAST(GETDATE() AS DATE);
--     DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
--     DECLARE @MonthEnd DATE = EOMONTH(@Today);

--     SELECT 
--         -- Total Policies
--         COUNT(DISTINCT cp.PolicyId) AS TotalPolicies,
--         COUNT(DISTINCT CASE WHEN cp.Status = 'Active' THEN cp.PolicyId END) AS ActivePolicies,
--         COUNT(DISTINCT CASE WHEN cp.Status = 'Expired' THEN cp.PolicyId END) AS ExpiredPolicies,
--         COUNT(DISTINCT CASE WHEN cp.Status = 'Lapsed' THEN cp.PolicyId END) AS LapsedPolicies,
--         COUNT(DISTINCT CASE WHEN cp.Status = 'Inactive' THEN cp.PolicyId END) AS InactivePolicies,

--         -- Expiring Soon (next 30 days)
--         COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 30, @Today) 
--                              AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn30Days,
--         COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 7, @Today) 
--                              AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn7Days,

--         -- New Policies This Month
--         COUNT(DISTINCT CASE WHEN cp.StartDate BETWEEN @MonthStart AND @MonthEnd THEN cp.PolicyId END) AS NewPoliciesThisMonth,

--         -- Policies by Type
--         COUNT(DISTINCT CASE WHEN pc.PolicyType = 'Motor' THEN cp.PolicyId END) AS MotorPolicies,
--         COUNT(DISTINCT CASE WHEN pc.PolicyType = 'Life' THEN cp.PolicyId END) AS LifePolicies,
--         COUNT(DISTINCT CASE WHEN pc.PolicyType = 'Health' THEN cp.PolicyId END) AS HealthPolicies,
--         COUNT(DISTINCT CASE WHEN pc.PolicyType = 'Travel' THEN cp.PolicyId END) AS TravelPolicies,
--         COUNT(DISTINCT CASE WHEN pc.PolicyType = 'Property' THEN cp.PolicyId END) AS PropertyPolicies,
--         COUNT(DISTINCT CASE WHEN pc.PolicyType = 'Marine' THEN cp.PolicyId END) AS MarinePolicies,
--         COUNT(DISTINCT CASE WHEN pc.PolicyType = 'Business' THEN cp.PolicyId END) AS BusinessPolicies,

--         -- Catalog Statistics
--         COUNT(DISTINCT pc.PolicyCatalogId) AS CatalogPolicies
        
--     FROM ClientPolicies cp
--     INNER JOIN Clients c 
--         ON cp.ClientId = c.ClientId
--     LEFT JOIN PolicyCatalog pc 
--         ON cp.PolicyCatalogId = pc.PolicyCatalogId
--     WHERE c.AgentId = @AgentId 
--       AND cp.IsActive = 1 
--       AND c.IsActive = 1;
-- END;
-- GO

-- Get Insurance Companies (unchanged except still linked)
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


-- Get Policy Types (linked)
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


-- Get Policy Templates (linked)
CREATE OR ALTER PROCEDURE sp_GetPolicyTemplates
    @AgentId UNIQUEIDENTIFIER,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        t.TemplateId,
        t.AgentId,
        t.TemplateName,
        t.TypeId,
        pt.TypeName,
        t.DefaultTermMonths,
        t.DefaultPremium,
        t.CoverageDescription,
        t.Terms,
        t.IsActive,
        t.CreatedDate
    FROM PolicyTemplates t
    INNER JOIN PolicyTypes pt ON t.TypeId = pt.TypeId
    WHERE 
        t.AgentId = @AgentId
        AND (@TypeId IS NULL OR t.TypeId = @TypeId)
        AND (@IsActive IS NULL OR t.IsActive = @IsActive)
    ORDER BY t.TemplateName ASC;
END;
GO


-- Create Policy Template (linked)
CREATE OR ALTER PROCEDURE sp_CreatePolicyTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(10,2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TemplateId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO PolicyTemplates (
        TemplateId, AgentId, TemplateName, TypeId, DefaultTermMonths, DefaultPremium, CoverageDescription, Terms
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @TypeId, @DefaultTermMonths, @DefaultPremium, @CoverageDescription, @Terms
    );
    
    SELECT @TemplateId AS TemplateId;
END;
GO


-- Validate Policy Data (linked)
CREATE OR ALTER PROCEDURE sp_ValidatePolicyData
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
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
    
    -- Validate Policy Type ID
    IF @TypeId IS NULL OR NOT EXISTS (SELECT 1 FROM PolicyTypes WHERE TypeId = @TypeId AND IsActive = 1)
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


-- Get Expiring Policies (linked)
CREATE OR ALTER PROCEDURE GetExpiringPolicies
    @Period NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Days INT;

    SET @Days = CASE UPPER(@Period)
                    WHEN '1D' THEN 1
                    WHEN '1W' THEN 7
                    WHEN '1M' THEN 30
                    WHEN '1Y' THEN 365
                    WHEN '2Y' THEN 730
                    WHEN '3Y' THEN 1095
                    ELSE NULL
                END;

    IF @Days IS NULL
    BEGIN
        RAISERROR('Invalid period specified. Use 1D, 1W, 1M, 1Y, 2Y, or 3Y.', 16, 1);
        RETURN;
    END

    SELECT 
        cp.PolicyId,
        cp.ClientId,
        CONCAT(c.FirstName, ' ', c.LastName) AS ClientName,
        cp.PolicyName,
        ic.CompanyName,
        cp.StartDate,
        cp.EndDate,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    INNER JOIN InsuranceCompanies ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        cp.IsActive = 1
        AND cp.Status = 'Active'
        AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, @Days, GETDATE())
    ORDER BY cp.EndDate ASC;
END;
GO


-- Create Policy Category (linked table remains the same)
CREATE OR ALTER PROCEDURE CreatePolicyCategory
    @CategoryName NVARCHAR(50),
    @Description NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM PolicyCategories WHERE CategoryName = @CategoryName)
    BEGIN
        RAISERROR('Category already exists.', 16, 1);
        RETURN;
    END

    INSERT INTO PolicyCategories (CategoryName, Description, IsActive, CreatedDate)
    VALUES (@CategoryName, @Description, 1, GETUTCDATE());

    SELECT SCOPE_IDENTITY() AS NewCategoryId;
END;
GO


-- Create Policy Catalog (linked)
CREATE OR ALTER PROCEDURE CreatePolicyCatalog
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO PolicyCatalog (
        AgentId,
        PolicyName,
        TypeId,
        CompanyId,
        Notes,
        IsActive,
        CreatedDate,
        ModifiedDate
    )
    VALUES (
        @AgentId,
        @PolicyName,
        @TypeId,
        @CompanyId,
        @Notes,
        1,
        GETUTCDATE(),
        GETUTCDATE()
    );

    SELECT SCOPE_IDENTITY() AS NewPolicyCatalogId;
END;
GO
-- ============================================
-- Updated Stored Procedures for Policy Management
-- Matching the updated table schema with foreign keys
-- ============================================

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
        COUNT(DISTINCT pt.TypeId) AS PolicyTypes,
        COUNT(DISTINCT ic.CompanyId) AS InsuranceCompanies
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE c.AgentId = @AgentId AND cp.IsActive = 1 AND c.IsActive = 1;
END;
GO

-- Create Policy Template
CREATE OR ALTER PROCEDURE sp_CreatePolicyTemplate
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(18,2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TemplateId UNIQUEIDENTIFIER = NEWID();
    
    INSERT INTO PolicyTemplate (
        TemplateId, AgentId, TemplateName, TypeId, CategoryId,
        DefaultTermMonths, DefaultPremium, CoverageDescription, Terms
    )
    VALUES (
        @TemplateId, @AgentId, @TemplateName, @TypeId, @CategoryId,
        @DefaultTermMonths, @DefaultPremium, @CoverageDescription, @Terms
    );
    
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (
        @AgentId, 'policy_template_created', 'policy_template', @TemplateId, 
        'Policy template "' + @TemplateName + '" created'
    );

    SELECT @TemplateId AS TemplateId;
END;
GO

-- Get Policy Templates
CREATE OR ALTER PROCEDURE sp_GetPolicyTemplates
    @AgentId UNIQUEIDENTIFIER,
    @TypeId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pt.TemplateId,
        pt.TemplateName,
        pt.TypeId,
        ptype.TypeName,
        pt.DefaultTermMonths,
        pt.DefaultPremium,
        pt.CoverageDescription,
        pt.Terms,
        pt.CategoryId,
        pc.CategoryName,
        pt.CreatedDate
    FROM PolicyTemplate pt
    LEFT JOIN PolicyType ptype ON pt.TypeId = ptype.TypeId
    LEFT JOIN PolicyCategory pc ON pt.CategoryId = pc.CategoryId
    WHERE 
        pt.AgentId = @AgentId 
        AND pt.IsActive = 1
        AND (@TypeId IS NULL OR pt.TypeId = @TypeId)
    ORDER BY ptype.TypeName, pt.TemplateName;
END;
GO

-- Delete Policy Template
CREATE OR ALTER PROCEDURE sp_DeletePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE PolicyTemplate 
    SET IsActive = 0
    WHERE TemplateId = @TemplateId AND AgentId = @AgentId;
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'policy_template_deleted', 'policy_template', @TemplateId, 
            'Policy template deleted'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Policy Catalog for Agent
CREATE OR ALTER PROCEDURE sp_GetPolicyCatalog
    @AgentId UNIQUEIDENTIFIER,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        pc.PolicyCatalogId,
        pc.PolicyName,
        pc.TypeId,
        pt.TypeName,
        pc.CompanyId,
        ic.CompanyName,
        pc.CategoryId,
        pcat.CategoryName,
        pc.Notes,
        pc.CreatedDate,
        pc.ModifiedDate
    FROM PolicyCatalog pc
    LEFT JOIN PolicyType pt ON pc.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON pc.CompanyId = ic.CompanyId
    LEFT JOIN PolicyCategory pcat ON pc.CategoryId = pcat.CategoryId
    WHERE 
        pc.AgentId = @AgentId 
        AND pc.IsActive = 1
        AND (@TypeId IS NULL OR pc.TypeId = @TypeId)
        AND (@CompanyId IS NULL OR pc.CompanyId = @CompanyId)
    ORDER BY pt.TypeName, pc.PolicyName;
END;
GO

-- Create Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_CreatePolicyCatalogItem
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyCatalogId UNIQUEIDENTIFIER = NEWID();
    
    -- Validate TypeId exists
    IF NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    INSERT INTO PolicyCatalog (
        PolicyCatalogId, AgentId, PolicyName, TypeId, 
        CompanyId, CategoryId, Notes, IsActive, CreatedDate
    )
    VALUES (
        @PolicyCatalogId, @AgentId, @PolicyName, @TypeId, 
        @CompanyId, @CategoryId, @Notes, 1, GETUTCDATE()
    );
    
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'policy_catalog_created', 'policy_catalog', @PolicyCatalogId, 
            'Policy "' + @PolicyName + '" added to catalog');
    
    SELECT @PolicyCatalogId AS PolicyCatalogId;
END;
GO

-- Update Policy Catalog Item
CREATE OR ALTER PROCEDURE sp_UpdatePolicyCatalogItem
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate TypeId if provided
    IF @TypeId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    UPDATE PolicyCatalog 
    SET 
        PolicyName = ISNULL(@PolicyName, PolicyName),
        TypeId = ISNULL(@TypeId, TypeId),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        CategoryId = ISNULL(@CategoryId, CategoryId),
        Notes = ISNULL(@Notes, Notes),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETUTCDATE()
    WHERE PolicyCatalogId = @PolicyCatalogId 
      AND AgentId = @AgentId;
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'policy_catalog_updated', 'policy_catalog', @PolicyCatalogId, 
                'Policy catalog item updated');
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
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
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
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

    -- Validate TypeId
    IF NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END

    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END

    IF @PolicyId IS NULL
    BEGIN
        -- Create new client policy
        SET @PolicyId = NEWID();

        INSERT INTO ClientPolicies (
            PolicyId, ClientId, PolicyName, TypeId, CompanyId, PolicyCatalogId,
            Status, StartDate, EndDate, Notes
        )
        VALUES (
            @PolicyId, @ClientId, @PolicyName, @TypeId, @CompanyId, @PolicyCatalogId,
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
            TypeId = @TypeId,
            CompanyId = @CompanyId,
            PolicyCatalogId = @PolicyCatalogId,
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

-- Get Client Policies
CREATE OR ALTER PROCEDURE sp_GetClientPolicies
    @ClientId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cp.PolicyId,
        cp.ClientId,
        cp.PolicyCatalogId,
        cp.PolicyName,
        cp.TypeId,
        pt.TypeName,
        cp.CompanyId,
        ic.CompanyName,
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
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        cp.ClientId = @ClientId
        AND cp.IsActive = 1
        AND (@Status IS NULL OR cp.Status = @Status)
        AND (@TypeId IS NULL OR cp.TypeId = @TypeId)
    ORDER BY cp.StartDate DESC;
END;
GO

-- Create Client Policy (using PolicyCatalog)
CREATE OR ALTER PROCEDURE sp_CreateClientPolicy
    @ClientId UNIQUEIDENTIFIER,
    @PolicyCatalogId UNIQUEIDENTIFIER,
    @Status NVARCHAR(20) = 'Active',
    @StartDate DATE,
    @EndDate DATE,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PolicyId UNIQUEIDENTIFIER = NEWID();
    DECLARE @PolicyName NVARCHAR(100);
    DECLARE @TypeId UNIQUEIDENTIFIER;
    DECLARE @CompanyId UNIQUEIDENTIFIER;
    DECLARE @AgentId UNIQUEIDENTIFIER;

    -- Get policy details from PolicyCatalog
    SELECT 
        @PolicyName = pc.PolicyName,
        @TypeId = pc.TypeId,
        @CompanyId = pc.CompanyId
    FROM PolicyCatalog pc
    WHERE pc.PolicyCatalogId = @PolicyCatalogId AND pc.IsActive = 1;

    IF @PolicyName IS NULL
    BEGIN
        SELECT 'Policy Catalog item not found or inactive' AS ErrorMessage;
        RETURN;
    END

    -- Get agent ID
    SELECT @AgentId = AgentId FROM Clients WHERE ClientId = @ClientId;

    INSERT INTO ClientPolicies (
        PolicyId, ClientId, PolicyCatalogId, PolicyName, TypeId, CompanyId, 
        Status, StartDate, EndDate, Notes, IsActive, CreatedDate
    )
    VALUES (
        @PolicyId, @ClientId, @PolicyCatalogId, @PolicyName, @TypeId, @CompanyId,
        @Status, @StartDate, @EndDate, @Notes, 1, GETUTCDATE()
    );
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (
        @AgentId, 'client_policy_created', 'client_policy', @PolicyId, 
        'Policy "' + @PolicyName + '" assigned to client from catalog'
    );
    
    SELECT @PolicyId AS PolicyId;
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
        pt.TypeName,
        ic.CompanyName,
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
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        c.AgentId = @AgentId 
        AND cp.Status = 'Active'
        AND cp.IsActive = 1
        AND c.IsActive = 1
        AND cp.EndDate BETWEEN @StartDate AND @EndDate
    ORDER BY cp.EndDate ASC;
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
    FROM InsuranceCompany
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
    FROM PolicyType
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY TypeName ASC;
END;
GO

-- Get Policy Categories
CREATE OR ALTER PROCEDURE sp_GetPolicyCategories
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
    FROM PolicyCategory
    WHERE (@IsActive IS NULL OR IsActive = @IsActive)
    ORDER BY CategoryName ASC;
END;
GO

-- Validate Policy Data
CREATE OR ALTER PROCEDURE sp_ValidatePolicyData
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
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
    
    -- Validate Policy Type ID
    IF @TypeId IS NULL OR NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SET @IsValid = 0;
        SET @ValidationErrors = @ValidationErrors + 'Valid policy type is required. ';
    END
    
    -- Validate Company
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
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

-- ============================================
-- MISSING PROCEDURES FROM ORIGINAL CODE
-- ============================================

-- Update Client Policy
CREATE OR ALTER PROCEDURE sp_UpdateClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @PolicyName NVARCHAR(100) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @Status NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AgentId UNIQUEIDENTIFIER;

    -- Get agent ID from the client associated with this policy
    SELECT @AgentId = c.AgentId 
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE cp.PolicyId = @PolicyId;

    -- Validate PolicyCatalogId if provided
    IF @PolicyCatalogId IS NOT NULL
    BEGIN
        IF NOT EXISTS (
            SELECT 1 
            FROM PolicyCatalog 
            WHERE PolicyCatalogId = @PolicyCatalogId 
              AND IsActive = 1
        )
        BEGIN
            SELECT 'Policy Catalog item not found or inactive' AS ErrorMessage;
            RETURN;
        END
    END

    -- Validate TypeId if provided
    IF @TypeId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END

    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END

    UPDATE ClientPolicies 
    SET 
        PolicyCatalogId = ISNULL(@PolicyCatalogId, PolicyCatalogId),
        PolicyName = ISNULL(@PolicyName, PolicyName),
        TypeId = ISNULL(@TypeId, TypeId),
        CompanyId = ISNULL(@CompanyId, CompanyId),
        Status = ISNULL(@Status, Status),
        StartDate = ISNULL(@StartDate, StartDate),
        EndDate = ISNULL(@EndDate, EndDate),
        Notes = ISNULL(@Notes, Notes),
        IsActive = ISNULL(@IsActive, IsActive),
        ModifiedDate = GETUTCDATE()
    WHERE PolicyId = @PolicyId;
    
    IF @@ROWCOUNT > 0 AND @AgentId IS NOT NULL
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_updated', 'client_policy', @PolicyId, 
            'Client policy updated'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Policy Statistics (Enhanced Version)
CREATE OR ALTER PROCEDURE sp_GetPolicyStatisticsDetailed
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
        COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 30, @Today) 
                             AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn30Days,
        COUNT(DISTINCT CASE WHEN cp.EndDate BETWEEN @Today AND DATEADD(DAY, 7, @Today) 
                             AND cp.Status = 'Active' THEN cp.PolicyId END) AS ExpiringIn7Days,

        -- New Policies This Month
        COUNT(DISTINCT CASE WHEN cp.StartDate BETWEEN @MonthStart AND @MonthEnd THEN cp.PolicyId END) AS NewPoliciesThisMonth,

        -- Policies by Type (using joins to get actual type names)
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Motor' THEN cp.PolicyId END) AS MotorPolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Life' THEN cp.PolicyId END) AS LifePolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Health' THEN cp.PolicyId END) AS HealthPolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Travel' THEN cp.PolicyId END) AS TravelPolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Property' THEN cp.PolicyId END) AS PropertyPolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Marine' THEN cp.PolicyId END) AS MarinePolicies,
        COUNT(DISTINCT CASE WHEN pt.TypeName = 'Business' THEN cp.PolicyId END) AS BusinessPolicies,

        -- Catalog Statistics
        COUNT(DISTINCT pc.PolicyCatalogId) AS CatalogPolicies,
        COUNT(DISTINCT pt.TypeId) AS PolicyTypes,
        COUNT(DISTINCT ic.CompanyId) AS InsuranceCompanies
        
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyCatalog pc ON cp.PolicyCatalogId = pc.PolicyCatalogId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE c.AgentId = @AgentId 
      AND cp.IsActive = 1 
      AND c.IsActive = 1;
END;
GO

-- Get Expiring Policies with Period Parameter
CREATE OR ALTER PROCEDURE sp_GetExpiringPoliciesByPeriod
    @AgentId UNIQUEIDENTIFIER = NULL,
    @Period NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Days INT;

    SET @Days = CASE UPPER(@Period)
                    WHEN '1D' THEN 1
                    WHEN '1W' THEN 7
                    WHEN '1M' THEN 30
                    WHEN '1Y' THEN 365
                    WHEN '2Y' THEN 730
                    WHEN '3Y' THEN 1095
                    ELSE NULL
                END;

    IF @Days IS NULL
    BEGIN
        RAISERROR('Invalid period specified. Use 1D, 1W, 1M, 1Y, 2Y, or 3Y.', 16, 1);
        RETURN;
    END

    SELECT 
        cp.PolicyId,
        cp.ClientId,
        CONCAT(c.FirstName, ' ', c.Surname) AS ClientName,
        c.PhoneNumber AS ClientPhone,
        c.Email AS ClientEmail,
        cp.PolicyName,
        pt.TypeName AS PolicyType,
        ic.CompanyName,
        cp.StartDate,
        cp.EndDate,
        cp.Status,
        cp.Notes,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) AS DaysUntilExpiry
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    LEFT JOIN PolicyType pt ON cp.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompany ic ON cp.CompanyId = ic.CompanyId
    WHERE 
        cp.IsActive = 1
        AND cp.Status = 'Active'
        AND c.IsActive = 1
        AND (@AgentId IS NULL OR c.AgentId = @AgentId)
        AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, @Days, GETDATE())
    ORDER BY cp.EndDate ASC;
END;
GO

-- Create Policy Category
CREATE OR ALTER PROCEDURE sp_CreatePolicyCategory
    @CategoryName NVARCHAR(50),
    @Description NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM PolicyCategory WHERE CategoryName = @CategoryName AND IsActive = 1)
    BEGIN
        SELECT 'Category already exists' AS ErrorMessage;
        RETURN;
    END

    DECLARE @CategoryId UNIQUEIDENTIFIER = NEWID();

    INSERT INTO PolicyCategory (CategoryId, CategoryName, Description, IsActive, CreatedDate)
    VALUES (@CategoryId, @CategoryName, @Description, 1, GETUTCDATE());

    SELECT @CategoryId AS CategoryId;
END;
GO

-- Update Policy Template
CREATE OR ALTER PROCEDURE sp_UpdatePolicyTemplate
    @TemplateId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @TemplateName NVARCHAR(100) = NULL,
    @TypeId UNIQUEIDENTIFIER = NULL,
    @DefaultTermMonths INT = NULL,
    @DefaultPremium DECIMAL(18,2) = NULL,
    @CoverageDescription NVARCHAR(MAX) = NULL,
    @Terms NVARCHAR(MAX) = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate TypeId if provided
    IF @TypeId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CategoryId if provided
    IF @CategoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PolicyCategory WHERE CategoryId = @CategoryId AND IsActive = 1)
    BEGIN
        SELECT 'Policy category not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    UPDATE PolicyTemplate 
    SET 
        TemplateName = ISNULL(@TemplateName, TemplateName),
        TypeId = ISNULL(@TypeId, TypeId),
        DefaultTermMonths = ISNULL(@DefaultTermMonths, DefaultTermMonths),
        DefaultPremium = ISNULL(@DefaultPremium, DefaultPremium),
        CoverageDescription = ISNULL(@CoverageDescription, CoverageDescription),
        Terms = ISNULL(@Terms, Terms),
        CategoryId = ISNULL(@CategoryId, CategoryId),
        IsActive = ISNULL(@IsActive, IsActive)
    WHERE TemplateId = @TemplateId 
      AND AgentId = @AgentId;
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'policy_template_updated', 'policy_template', @TemplateId, 
            'Policy template updated'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Delete Client Policy (Soft Delete)
CREATE OR ALTER PROCEDURE sp_DeleteClientPolicy
    @PolicyId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PolicyName NVARCHAR(100);
    
    -- Get policy name for logging
    SELECT @PolicyName = cp.PolicyName 
    FROM ClientPolicies cp
    INNER JOIN Clients c ON cp.ClientId = c.ClientId
    WHERE cp.PolicyId = @PolicyId AND c.AgentId = @AgentId;
    
    -- Soft delete
    UPDATE ClientPolicies 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE PolicyId = @PolicyId 
      AND EXISTS (
          SELECT 1 FROM Clients c 
          WHERE c.ClientId = ClientPolicies.ClientId 
            AND c.AgentId = @AgentId
      );
    
    IF @@ROWCOUNT > 0
    BEGIN
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 'client_policy_deleted', 'client_policy', @PolicyId, 
            'Policy "' + ISNULL(@PolicyName, 'Unknown') + '" deleted for client'
        );
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Missing UPSERT Policy Catalog (the commented one from original)
CREATE OR ALTER PROCEDURE sp_UpsertPolicyCatalog
    @PolicyCatalogId UNIQUEIDENTIFIER = NULL,
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER = NULL,
    @CategoryId UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate TypeId
    IF NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CompanyId if provided
    IF @CompanyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    IF @PolicyCatalogId IS NULL
    BEGIN
        SET @PolicyCatalogId = NEWID();
        
        INSERT INTO PolicyCatalog (
            PolicyCatalogId, AgentId, PolicyName, TypeId, 
            CompanyId, CategoryId, Notes, IsActive, CreatedDate
        )
        VALUES (
            @PolicyCatalogId, @AgentId, @PolicyName, @TypeId,
            @CompanyId, @CategoryId, @Notes, 1, GETUTCDATE()
        );
        
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'policy_catalog_created', 'policy_catalog', @PolicyCatalogId, 
                'Policy "' + @PolicyName + '" added to catalog');
    END
    ELSE
    BEGIN
        UPDATE PolicyCatalog 
        SET 
            PolicyName = @PolicyName,
            TypeId = @TypeId,
            CompanyId = @CompanyId,
            CategoryId = @CategoryId,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE PolicyCatalogId = @PolicyCatalogId AND AgentId = @AgentId;
        
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'policy_catalog_updated', 'policy_catalog', @PolicyCatalogId, 
                'Policy "' + @PolicyName + '" updated in catalog');
    END

    SELECT @PolicyCatalogId AS PolicyCatalogId;
END;
GO

-- Create Policy Catalog (the direct version from end of original)
CREATE OR ALTER PROCEDURE sp_CreatePolicyCatalog
    @AgentId UNIQUEIDENTIFIER,
    @PolicyName NVARCHAR(100),
    @TypeId UNIQUEIDENTIFIER,
    @CompanyId UNIQUEIDENTIFIER,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PolicyCatalogId UNIQUEIDENTIFIER = NEWID();

    -- Validate TypeId
    IF NOT EXISTS (SELECT 1 FROM PolicyType WHERE TypeId = @TypeId AND IsActive = 1)
    BEGIN
        SELECT 'Policy type not found or inactive' AS ErrorMessage;
        RETURN;
    END
    
    -- Validate CompanyId
    IF NOT EXISTS (SELECT 1 FROM InsuranceCompany WHERE CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        SELECT 'Insurance company not found or inactive' AS ErrorMessage;
        RETURN;
    END

    INSERT INTO PolicyCatalog (
        PolicyCatalogId,
        AgentId,
        PolicyName,
        TypeId,
        CompanyId,
        Notes,
        IsActive,
        CreatedDate,
        ModifiedDate
    )
    VALUES (
        @PolicyCatalogId,
        @AgentId,
        @PolicyName,
        @TypeId,
        @CompanyId,
        @Notes,
        1,
        GETUTCDATE(),
        GETUTCDATE()
    );

    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'policy_catalog_created', 'policy_catalog', @PolicyCatalogId, 
            'Policy "' + @PolicyName + '" created in catalog');

    SELECT @PolicyCatalogId AS PolicyCatalogId;
END;
GO