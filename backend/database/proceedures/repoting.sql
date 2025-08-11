
-- Get Daily Notes
CREATE OR ALTER PROCEDURE sp_GetDailyNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
END;
GO

-- Save Daily Notes
CREATE OR ALTER PROCEDURE sp_SaveDailyNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE,
    @Notes NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM DailyNotes WHERE AgentId = @AgentId AND NoteDate = @NoteDate)
    BEGIN
        UPDATE DailyNotes 
        SET 
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
    END
    ELSE
    BEGIN
        INSERT INTO DailyNotes (AgentId, NoteDate, Notes)
        VALUES (@AgentId, @NoteDate, @Notes);
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get All Notes
CREATE OR ALTER PROCEDURE sp_GetAllNotes
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(MONTH, -3, GETDATE()); -- Last 3 months default
    
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE 
        AgentId = @AgentId 
        AND NoteDate BETWEEN @StartDate AND @EndDate
    ORDER BY NoteDate DESC;
END;
GO

-- Search Notes
CREATE OR ALTER PROCEDURE sp_SearchNotes
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE 
        AgentId = @AgentId 
        AND Notes LIKE '%' + @SearchTerm + '%'
    ORDER BY NoteDate DESC;
END;
GO

-- Delete Notes
CREATE OR ALTER PROCEDURE sp_DeleteNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DELETE FROM DailyNotes 
    WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get Daily Notes
CREATE OR ALTER PROCEDURE sp_GetDailyNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
END;
GO

-- Save Daily Notes
CREATE OR ALTER PROCEDURE sp_SaveDailyNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE,
    @Notes NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM DailyNotes WHERE AgentId = @AgentId AND NoteDate = @NoteDate)
    BEGIN
        UPDATE DailyNotes 
        SET 
            Notes = @Notes,
            ModifiedDate = GETUTCDATE()
        WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
    END
    ELSE
    BEGIN
        INSERT INTO DailyNotes (AgentId, NoteDate, Notes)
        VALUES (@AgentId, @NoteDate, @Notes);
    END
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO

-- Get All Notes
CREATE OR ALTER PROCEDURE sp_GetAllNotes
    @AgentId UNIQUEIDENTIFIER,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(MONTH, -3, GETDATE()); -- Last 3 months default
    
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE 
        AgentId = @AgentId 
        AND NoteDate BETWEEN @StartDate AND @EndDate
    ORDER BY NoteDate DESC;
END;
GO

-- Search Notes
CREATE OR ALTER PROCEDURE sp_SearchNotes
    @AgentId UNIQUEIDENTIFIER,
    @SearchTerm NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        NoteId,
        AgentId,
        NoteDate,
        Notes,
        CreatedDate,
        ModifiedDate
    FROM DailyNotes
    WHERE 
        AgentId = @AgentId 
        AND Notes LIKE '%' + @SearchTerm + '%'
    ORDER BY NoteDate DESC;
END;
GO

-- Delete Notes
CREATE OR ALTER PROCEDURE sp_DeleteNotes
    @AgentId UNIQUEIDENTIFIER,
    @NoteDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DELETE FROM DailyNotes 
    WHERE AgentId = @AgentId AND NoteDate = @NoteDate;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END;
GO