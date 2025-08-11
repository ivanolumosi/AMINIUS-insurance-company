-- ============================================
-- Client Management Stored Procedures
-- ============================================

-- Create or Update Client
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
    @InsuranceType NVARCHAR(50),
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
            Email, Address, NationalId, DateOfBirth, IsClient, InsuranceType, Notes
        )
        VALUES (
            @ClientId, @AgentId, @FirstName, @Surname, @LastName, @PhoneNumber,
            @Email, @Address, @NationalId, @DateOfBirth, @IsClient, @InsuranceType, @Notes
        );
        
        -- Log activity
        INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
        VALUES (@AgentId, 'client_created', 'client', @ClientId, @FirstName + ' ' + @Surname + ' added as ' + CASE WHEN @IsClient = 1 THEN 'client' ELSE 'prospect' END);
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
            InsuranceType = @InsuranceType,
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

-- Get All Clients for Agent
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
        c.InsuranceType,
        c.Notes,
        c.CreatedDate,
        c.ModifiedDate,
        -- Include policy information if exists
        cp.PolicyId,
        cp.PolicyName,
        cp.PolicyType,
        cp.CompanyName AS PolicyCompany,
        cp.Status AS PolicyStatus,
        cp.StartDate AS PolicyStartDate,
        cp.EndDate AS PolicyEndDate,
        cp.Notes AS PolicyNotes
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
        AND (@FilterType = 'all' OR 
             (@FilterType = 'clients' AND c.IsClient = 1) OR
             (@FilterType = 'prospects' AND c.IsClient = 0))
        AND (@InsuranceType IS NULL OR c.InsuranceType = @InsuranceType)
    ORDER BY c.FirstName, c.Surname;
END;
GO

-- Get Single Client with Details
CREATE OR ALTER PROCEDURE sp_GetClient
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.*,
        -- Policy details
        cp.PolicyId,
        cp.PolicyName,
        cp.PolicyType,
        cp.CompanyName AS PolicyCompany,
        cp.Status AS PolicyStatus,
        cp.StartDate AS PolicyStartDate,
        cp.EndDate AS PolicyEndDate,
        cp.Notes AS PolicyNotes
    FROM Clients c
    LEFT JOIN ClientPolicies cp ON c.ClientId = cp.ClientId AND cp.IsActive = 1
    WHERE c.ClientId = @ClientId AND c.AgentId = @AgentId AND c.IsActive = 1;
    
    -- Get appointments for this client
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
    WHERE ClientId = @ClientId AND AgentId = @AgentId AND IsActive = 1
    ORDER BY AppointmentDate DESC, StartTime DESC;
END;
GO

-- Convert Prospect to Client
CREATE OR ALTER PROCEDURE sp_ConvertToClient
    @ClientId UNIQUEIDENTIFIER,
    @AgentId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ClientName NVARCHAR(150);
    
    -- Get client name for logging
    SELECT @ClientName = FirstName + ' ' + Surname FROM Clients WHERE ClientId = @ClientId;
    
    UPDATE Clients 
    SET IsClient = 1, ModifiedDate = GETUTCDATE()
    WHERE ClientId = @ClientId AND AgentId = @AgentId;
    
    -- Log activity
    INSERT INTO ActivityLog (AgentId, ActivityType, EntityType, EntityId, Description)
    VALUES (@AgentId, 'prospect_converted', 'client', @ClientId, @ClientName + ' converted from prospect to client');
    
    SELECT @@ROWCOUNT AS RowsAffected;
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