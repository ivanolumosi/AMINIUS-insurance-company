-- ============================================
-- Create or Update Client (Trigger manages InsuranceType)
-- ============================================
CREATE OR ALTER PROCEDURE sp_UpsertClient
    @ClientId UNIQUEIDENTIFIER = NULL,
    @AgentId UNIQUEIDENTIFIER,
    @FirstName NVARCHAR(50),
    @Surname NVARCHAR(50),
    @LastName NVARCHAR(50),
    @PhoneNumber NVARCHAR(20),
    @Email NVARCHAR(100),
    @Address NVARCHAR(500),
    @NationalId NVARCHAR(20),
    @DateOfBirth DATE,
    @IsClient BIT,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ClientId IS NULL
    BEGIN
        -- Create new client
        SET @ClientId = NEWID();
        
        INSERT INTO Clients (
            ClientId, AgentId, FirstName, Surname, LastName, PhoneNumber, 
            Email, Address, NationalId, DateOfBirth, IsClient, Notes
        )
        VALUES (
            @ClientId, @AgentId, @FirstName, @Surname, @LastName, @PhoneNumber,
            @Email, @Address, @NationalId, @DateOfBirth, @IsClient, @Notes
        );
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'client_created', 'client', @ClientId, 
                @FirstName + ' ' + @Surname + ' added as ' + CASE WHEN @IsClient = 1 THEN 'client' ELSE 'prospect' END);
    END
    ELSE
    BEGIN
        -- Update existing client
        UPDATE Clients 
        SET 
            FirstName = @FirstName,
            Surname = @Surname,
            LastName = @LastName,
            PhoneNumber = @PhoneNumber,
            Email = @Email,
            Address = @Address,
            NationalId = @NationalId,
            DateOfBirth = @DateOfBirth,
            IsClient = @IsClient,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE ClientId = @ClientId;
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'client_updated', 'client', @ClientId, @FirstName + ' ' + @Surname + ' updated');
    END
    
    SELECT @ClientId AS ClientId;
END;
GO


CREATE OR ALTER PROCEDURE sp_GetClients
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(100) = NULL,
    @FilterType NVARCHAR(20) = 'all', -- 'all', 'clients', 'prospects'
    @InsuranceType NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.NationalId,
        c.DateOfBirth,
        c.IsClient,
        c.InsuranceType,   -- ✅ always reliable now (trigger keeps it synced)
        c.Notes,
        c.CreatedDate,
        c.ModifiedDate,

        -- Policy Info from related tables
        cp.PolicyId,
        cp.PolicyName,
        pt.TypeName AS PolicyType,
        ic.CompanyName AS PolicyCompany,
        cp.Status AS PolicyStatus,
        cp.StartDate AS PolicyStartDate,
        cp.EndDate AS PolicyEndDate,
        cp.Notes AS PolicyNotes
    FROM Clients c
    LEFT JOIN ClientPolicies cp 
        ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    LEFT JOIN PolicyCatalog pc
        ON cp.PolicyCatalogId = pc.PolicyCatalogId
    LEFT JOIN PolicyTypes pt
        ON pc.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompanies ic
        ON pc.CompanyId = ic.CompanyId
    WHERE 
        c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND (
            @SearchTerm IS NULL OR 
            c.FirstName LIKE '%' + @SearchTerm + '%' OR
            c.Surname LIKE '%' + @SearchTerm + '%' OR
            c.LastName LIKE '%' + @SearchTerm + '%' OR
            c.PhoneNumber LIKE '%' + @SearchTerm + '%' OR
            c.Email LIKE '%' + @SearchTerm + '%'
        )
        AND (
            @FilterType = 'all' OR 
            (@FilterType = 'clients' AND c.IsClient = 1) OR
            (@FilterType = 'prospects' AND c.IsClient = 0)
        )
        AND (@InsuranceType IS NULL OR c.InsuranceType = @InsuranceType)
    ORDER BY c.FirstName, c.Surname;
END;
GO
CREATE OR ALTER PROCEDURE sp_GetClient
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Main client details with linked policy info
    SELECT 
        c.*,
        cp.PolicyId,
        cp.PolicyName,
        pt.TypeName AS PolicyType,
        ic.CompanyName AS PolicyCompany,
        cp.Status AS PolicyStatus,
        cp.StartDate AS PolicyStartDate,
        cp.EndDate AS PolicyEndDate,
        cp.Notes AS PolicyNotes
    FROM Clients c
    LEFT JOIN ClientPolicies cp 
        ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    LEFT JOIN PolicyCatalog pc 
        ON cp.PolicyCatalogId = pc.PolicyCatalogId
    LEFT JOIN PolicyTypes pt 
        ON pc.TypeId = pt.TypeId
    LEFT JOIN InsuranceCompanies ic 
        ON pc.CompanyId = ic.CompanyId
    WHERE 
        c.ClientId = @ClientId 
        AND c.AgentId = @AgentId 
        AND c.IsActive = 1;
    
    -- Appointments for the client
    SELECT 
        AppointmentId,
        Title,
        AppointmentDate,
        StartTime,
        EndTime,
        Type,
        Status,
        Location
    FROM Appointments
    WHERE 
        ClientId = @ClientId 
        AND AgentId = @AgentId 
        AND IsActive = 1
    ORDER BY AppointmentDate DESC, StartTime DESC;
END;
GO

-- Delete Client
CREATE OR ALTER PROCEDURE sp_DeleteClient
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ClientName NVARCHAR(150);
    
    -- Get client name for logging
    SELECT @ClientName = FirstName + ' ' + Surname FROM Clients WHERE ClientId = @ClientId;
    
    -- Soft delete - set IsActive to 0
    UPDATE Clients 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE ClientId = @ClientId AND AgentId = @AgentId;
    
    -- Also soft delete related appointments
    UPDATE Appointments 
    SET IsActive = 0, ModifiedDate = GETUTCDATE()
    WHERE ClientId = @ClientId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'client_deleted', 'client', @ClientId, @ClientName + ' deleted');
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Client Statistics
CREATE OR ALTER PROCEDURE sp_GetClientStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        COUNT(*) AS TotalContacts,
        SUM(CASE WHEN IsClient = 1 THEN 1 ELSE 0 END) AS TotalClients,
        SUM(CASE WHEN IsClient = 0 THEN 1 ELSE 0 END) AS TotalProspects,
        COUNT(CASE WHEN DAY(DateOfBirth) = DAY(GETDATE()) AND MONTH(DateOfBirth) = MONTH(GETDATE()) THEN 1 END) AS TodayBirthdays
    FROM Clients
    WHERE AgentId = @AgentId AND IsActive = 1;
END;
GO

-- Get Today's Birthdays
CREATE OR ALTER PROCEDURE sp_GetTodayBirthdays
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ClientId,
        FirstName,
        Surname,
        LastName,
        PhoneNumber,
        Email,
        InsuranceType,
        DateOfBirth,
        DATEDIFF(YEAR, DateOfBirth, GETDATE()) AS Age
    FROM Clients
    WHERE 
        AgentId = @AgentId 
        AND IsActive = 1
        AND DAY(DateOfBirth) = DAY(GETDATE())
        AND MONTH(DateOfBirth) = MONTH(GETDATE())
    ORDER BY FirstName, Surname;
END;
GO

-- 1. Get All Clients with Advanced Filters
CREATE OR ALTER PROCEDURE sp_GetAllClients
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(100) = NULL,
    @InsuranceType NVARCHAR(50) = NULL,
    @IsClient BIT = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.NationalId,
        c.DateOfBirth,
        DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) as Age,
        c.IsClient,
        c.InsuranceType,
        c.Notes,
        c.CreatedDate,
        c.ModifiedDate,
        COUNT(cp.PolicyId) as PolicyCount,
        MAX(cp.EndDate) as NextExpiryDate
    FROM Clients c
    LEFT JOIN ClientPolicies cp ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    WHERE 
        c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND (@SearchTerm IS NULL OR 
             c.FirstName LIKE '%' + @SearchTerm + '%' OR 
             c.Surname LIKE '%' + @SearchTerm + '%' OR
             c.LastName LIKE '%' + @SearchTerm + '%' OR
             c.PhoneNumber LIKE '%' + @SearchTerm + '%' OR
             c.Email LIKE '%' + @SearchTerm + '%')
        AND (@InsuranceType IS NULL OR c.InsuranceType = @InsuranceType)
        AND (@IsClient IS NULL OR c.IsClient = @IsClient)
    GROUP BY 
        c.ClientId, c.FirstName, c.Surname, c.LastName, c.PhoneNumber,
        c.Email, c.Address, c.NationalId, c.DateOfBirth, c.IsClient,
        c.InsuranceType, c.Notes, c.CreatedDate, c.ModifiedDate
    ORDER BY c.CreatedDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- 2. Search Clients
CREATE OR ALTER PROCEDURE sp_SearchClients
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.IsClient,
        c.InsuranceType,
        DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) as Age
    FROM Clients c
    WHERE 
        c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND (
            c.FirstName LIKE '%' + @SearchTerm + '%' OR 
            c.Surname LIKE '%' + @SearchTerm + '%' OR
            c.LastName LIKE '%' + @SearchTerm + '%' OR
            c.PhoneNumber LIKE '%' + @SearchTerm + '%' OR
            c.Email LIKE '%' + @SearchTerm + '%' OR
            c.NationalId LIKE '%' + @SearchTerm + '%'
        )
    ORDER BY c.FirstName, c.Surname;
END;
GO

-- 3. Get Clients by Insurance Type
CREATE OR ALTER PROCEDURE sp_GetClientsByInsuranceType
    @AgentId UNIQUEIDENTIFIER,
    @InsuranceType NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.DateOfBirth,
        DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) as Age,
        c.IsClient,
        c.InsuranceType,
        c.CreatedDate,
        COUNT(cp.PolicyId) as PolicyCount
    FROM Clients c
    LEFT JOIN ClientPolicies cp ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    WHERE 
        c.AgentId = @AgentId 
        AND c.IsActive = 1
        AND c.InsuranceType = @InsuranceType
    GROUP BY 
        c.ClientId, c.FirstName, c.Surname, c.LastName, c.PhoneNumber,
        c.Email, c.Address, c.DateOfBirth, c.IsClient, c.InsuranceType, c.CreatedDate
    ORDER BY c.FirstName, c.Surname;
END;
GO

-- 4. Get Client with Full Details (including policies)
CREATE OR ALTER PROCEDURE sp_GetClientWithPolicies
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Client details
    SELECT 
        c.ClientId,
        c.FirstName,
        c.Surname,
        c.LastName,
        c.PhoneNumber,
        c.Email,
        c.Address,
        c.NationalId,
        c.DateOfBirth,
        DATEDIFF(YEAR, c.DateOfBirth, GETDATE()) as Age,
        c.IsClient,
        c.InsuranceType,
        c.Notes,
        c.CreatedDate,
        c.ModifiedDate
    FROM Clients c
    WHERE c.ClientId = @ClientId AND c.AgentId = @AgentId AND c.IsActive = 1;
    
    -- Client policies
    SELECT 
        cp.PolicyId,
        cp.PolicyName,
        cp.PolicyType,
        cp.CompanyName,
        cp.Status,
        cp.StartDate,
        cp.EndDate,
        DATEDIFF(DAY, GETDATE(), cp.EndDate) as DaysToExpiry,
        cp.Notes,
        cp.CreatedDate
    FROM ClientPolicies cp
    WHERE cp.ClientId = @ClientId AND cp.IsActive = 1
    ORDER BY cp.EndDate DESC;
    
    -- Recent appointments
    SELECT TOP 5
        a.AppointmentId,
        a.Title,
        a.AppointmentDate,
        a.StartTime,
        a.Type,
        a.Status
    FROM Appointments a
    WHERE a.ClientId = @ClientId AND a.IsActive = 1
    ORDER BY a.AppointmentDate DESC, a.StartTime DESC;
    
    -- Active reminders
    SELECT 
        r.ReminderId,
        r.Title,
        r.ReminderDate,
        r.ReminderTime,
        r.ReminderType,
        r.Priority,
        r.Status
    FROM Reminders r
    WHERE r.ClientId = @ClientId AND r.Status = 'Active'
    ORDER BY r.ReminderDate, r.ReminderTime;
END;
GO

-- 5. Create New Client
CREATE OR ALTER PROCEDURE sp_CreateClient
    @AgentId UNIQUEIDENTIFIER,
    @FirstName NVARCHAR(50),
    @Surname NVARCHAR(50),
    @LastName NVARCHAR(50),
    @PhoneNumber NVARCHAR(20),
    @Email NVARCHAR(100),
    @Address NVARCHAR(500),
    @NationalId NVARCHAR(20),
    @DateOfBirth DATE,
    @IsClient BIT = 0,
    @InsuranceType NVARCHAR(50),
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ClientId UNIQUEIDENTIFIER = NEWID();
    
    -- Check for duplicate phone or email
    IF EXISTS(SELECT 1 FROM Clients WHERE PhoneNumber = @PhoneNumber AND AgentId = @AgentId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Phone number already exists' as Message,
            NULL as ClientId;
        RETURN;
    END
    
    IF EXISTS(SELECT 1 FROM Clients WHERE Email = @Email AND AgentId = @AgentId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Email already exists' as Message,
            NULL as ClientId;
        RETURN;
    END
    
    BEGIN TRY
        INSERT INTO Clients (
            ClientId, AgentId, FirstName, Surname, LastName, PhoneNumber,
            Email, Address, NationalId, DateOfBirth, IsClient, InsuranceType, Notes
        )
        VALUES (
            @ClientId, @AgentId, @FirstName, @Surname, @LastName, @PhoneNumber,
            @Email, @Address, @NationalId, @DateOfBirth, @IsClient, @InsuranceType, @Notes
        );
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 
            CASE WHEN @IsClient = 1 THEN 'client_added' ELSE 'prospect_added' END,
            'client', 
            @ClientId, 
            'Added new ' + CASE WHEN @IsClient = 1 THEN 'client' ELSE 'prospect' END + ': ' + @FirstName + ' ' + @Surname
        );
        
        SELECT 
            1 as Success,
            CASE WHEN @IsClient = 1 THEN 'Client created successfully' ELSE 'Prospect created successfully' END as Message,
            @ClientId as ClientId;
            
    END TRY
    BEGIN CATCH
        SELECT 
            0 as Success,
            ERROR_MESSAGE() as Message,
            NULL as ClientId;
    END CATCH
END;
GO

-- 6. Update Client
CREATE OR ALTER PROCEDURE sp_UpdateClient
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER,
    @FirstName NVARCHAR(50),
    @Surname NVARCHAR(50),
    @LastName NVARCHAR(50),
    @PhoneNumber NVARCHAR(20),
    @Email NVARCHAR(100),
    @Address NVARCHAR(500),
    @NationalId NVARCHAR(20),
    @DateOfBirth DATE,
    @InsuranceType NVARCHAR(50),
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if client exists and belongs to agent
    IF NOT EXISTS(SELECT 1 FROM Clients WHERE ClientId = @ClientId AND AgentId = @AgentId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Client not found' as Message;
        RETURN;
    END
    
    -- Check for duplicate phone or email (excluding current client)
    IF EXISTS(SELECT 1 FROM Clients WHERE PhoneNumber = @PhoneNumber AND AgentId = @AgentId AND ClientId != @ClientId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Phone number already exists for another client' as Message;
        RETURN;
    END
    
    IF EXISTS(SELECT 1 FROM Clients WHERE Email = @Email AND AgentId = @AgentId AND ClientId != @ClientId AND IsActive = 1)
    BEGIN
        SELECT 
            0 as Success,
            'Email already exists for another client' as Message;
        RETURN;
    END
    
    BEGIN TRY
        UPDATE Clients 
        SET 
            FirstName = @FirstName,
            Surname = @Surname,
            LastName = @LastName,
            PhoneNumber = @PhoneNumber,
            Email = @Email,
            Address = @Address,
            NationalId = @NationalId,
            DateOfBirth = @DateOfBirth,
            InsuranceType = @InsuranceType,
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE ClientId = @ClientId AND AgentId = @AgentId;
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (
            @AgentId, 
            'client_updated',
            'client', 
            @ClientId, 
            'Updated client: ' + @FirstName + ' ' + @Surname
        );
        
        SELECT 
            1 as Success,
            'Client updated successfully' as Message;
            
    END TRY
    BEGIN CATCH
        SELECT 
            0 as Success,
            ERROR_MESSAGE() as Message;
    END CATCH
END;
GO

-- 7. Get Enhanced Client Statistics
CREATE OR ALTER PROCEDURE sp_GetEnhancedClientStatistics
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        -- Client counts
        COUNT(CASE WHEN IsClient = 1 THEN 1 END) as TotalClients,
        COUNT(CASE WHEN IsClient = 0 THEN 1 END) as TotalProspects,
        COUNT(*) as TotalContacts,
        
        -- Policy statistics
        (SELECT COUNT(*) FROM ClientPolicies cp 
         INNER JOIN Clients c ON cp.ClientId = c.ClientId 
         WHERE c.AgentId = @AgentId AND cp.IsActive = 1 AND cp.Status = 'Active') as ActivePolicies,
        
        (SELECT COUNT(*) FROM ClientPolicies cp 
         INNER JOIN Clients c ON cp.ClientId = c.ClientId 
         WHERE c.AgentId = @AgentId AND cp.IsActive = 1 
         AND cp.EndDate BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE())) as ExpiringPolicies,
        
        -- Birthday statistics
        COUNT(CASE WHEN MONTH(DateOfBirth) = MONTH(GETDATE()) 
                   AND DAY(DateOfBirth) = DAY(GETDATE()) THEN 1 END) as TodayBirthdays,
        
        COUNT(CASE WHEN MONTH(DateOfBirth) = MONTH(GETDATE()) THEN 1 END) as MonthBirthdays,
        
        -- Recent additions
        COUNT(CASE WHEN CreatedDate >= DATEADD(DAY, -7, GETDATE()) THEN 1 END) as NewThisWeek,
        COUNT(CASE WHEN CreatedDate >= DATEADD(DAY, -30, GETDATE()) THEN 1 END) as NewThisMonth,
        
        -- Insurance type breakdown
        (SELECT 
            InsuranceType,
            COUNT(*) as Count,
            COUNT(CASE WHEN IsClient = 1 THEN 1 END) as ClientCount,
            COUNT(CASE WHEN IsClient = 0 THEN 1 END) as ProspectCount
         FROM Clients 
         WHERE AgentId = @AgentId AND IsActive = 1
         GROUP BY InsuranceType
         FOR JSON PATH) as InsuranceTypeBreakdown
         
    FROM Clients 
    WHERE AgentId = @AgentId AND IsActive = 1;
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