/*
    Triosuite Invoice ERP API
    Script 2 of 3: Create or update all stored procedures used by the API.

    Run 01_CreateDatabaseAndTables.sql before this script.
*/

USE SalesInvoiceDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Auth_GetUserByUsername
    @Username NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Username, PasswordHash, FullNameAr, FullNameEn
    FROM dbo.Users
    WHERE Username = @Username AND IsActive = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Auth_CreateRefreshToken
    @UserId INT,
    @TokenHash CHAR(64),
    @FamilyId UNIQUEIDENTIFIER,
    @ExpiresAt DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.RefreshTokens (UserId, TokenHash, FamilyId, ExpiresAt)
    VALUES (@UserId, @TokenHash, @FamilyId, @ExpiresAt);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Auth_RotateRefreshToken
    @CurrentTokenHash CHAR(64),
    @NewTokenHash CHAR(64),
    @NewExpiresAt DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DECLARE @UserId INT, @FamilyId UNIQUEIDENTIFIER, @RevokedAt DATETIME2, @ExpiresAt DATETIME2;
    SELECT
        @UserId = rt.UserId,
        @FamilyId = rt.FamilyId,
        @RevokedAt = rt.RevokedAt,
        @ExpiresAt = rt.ExpiresAt
    FROM dbo.RefreshTokens rt WITH (UPDLOCK, HOLDLOCK)
    WHERE rt.TokenHash = @CurrentTokenHash;

    IF @UserId IS NULL OR @ExpiresAt <= SYSUTCDATETIME()
    BEGIN
        COMMIT TRANSACTION;
        RETURN;
    END;

    -- A rotated token being presented again indicates possible token theft.
    -- Revoke the whole token family so the newest descendant cannot be reused.
    IF @RevokedAt IS NOT NULL
    BEGIN
        UPDATE dbo.RefreshTokens
        SET RevokedAt = COALESCE(RevokedAt, SYSUTCDATETIME())
        WHERE FamilyId = @FamilyId;

        COMMIT TRANSACTION;
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1)
    BEGIN
        UPDATE dbo.RefreshTokens SET RevokedAt = SYSUTCDATETIME()
        WHERE FamilyId = @FamilyId AND RevokedAt IS NULL;

        COMMIT TRANSACTION;
        RETURN;
    END;

    UPDATE dbo.RefreshTokens
    SET RevokedAt = SYSUTCDATETIME(), ReplacedByTokenHash = @NewTokenHash
    WHERE TokenHash = @CurrentTokenHash;

    INSERT dbo.RefreshTokens (UserId, TokenHash, FamilyId, ExpiresAt)
    VALUES (@UserId, @NewTokenHash, @FamilyId, @NewExpiresAt);

    SELECT Id, Username, FullNameAr, FullNameEn
    FROM dbo.Users
    WHERE Id = @UserId;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Auth_RevokeRefreshTokenFamily
    @TokenHash CHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FamilyId UNIQUEIDENTIFIER = (
        SELECT FamilyId FROM dbo.RefreshTokens WHERE TokenHash = @TokenHash
    );

    IF @FamilyId IS NOT NULL
        UPDATE dbo.RefreshTokens
        SET RevokedAt = COALESCE(RevokedAt, SYSUTCDATETIME())
        WHERE FamilyId = @FamilyId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Lookups_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Code, NameAr, NameEn FROM dbo.Customers WHERE IsActive = 1 ORDER BY NameEn;

    SELECT i.Id, i.Code, i.NameAr, i.NameEn, i.Barcode, i.UnitId, u.Code AS UnitCode, i.UnitPrice, i.TaxRate
    FROM dbo.Items i INNER JOIN dbo.Units u ON u.Id = i.UnitId
    WHERE i.IsActive = 1 ORDER BY i.NameEn;

    SELECT Id, Code, NameAr, NameEn, Symbol, IsBaseCurrency
    FROM dbo.Currencies WHERE IsActive = 1 ORDER BY IsBaseCurrency DESC, Code;

    SELECT Id, Code, NameAr, NameEn FROM dbo.Units WHERE IsActive = 1 ORDER BY Code;

    SELECT v.Id, v.Code, v.NameAr, v.NameEn
    FROM dbo.SystemCodeValues v INNER JOIN dbo.SystemCodes c ON c.Id = v.SystemCodeId
    WHERE c.Code = N'TAX_MODE' AND v.IsActive = 1 ORDER BY v.SortOrder;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Item_GetByBarcode
    @Barcode NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT i.Id, i.Code, i.NameAr, i.NameEn, i.Barcode, i.UnitId, u.Code AS UnitCode, i.UnitPrice, i.TaxRate
    FROM dbo.Items i INNER JOIN dbo.Units u ON u.Id = i.UnitId
    WHERE i.Barcode = @Barcode AND i.IsActive = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Settings_Get
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) s.Id, s.CompanyNameAr, s.CompanyNameEn, s.DefaultCurrencyId,
           c.Code AS DefaultCurrencyCode, s.InvoicePrefix
    FROM dbo.Settings s
    INNER JOIN dbo.Currencies c ON c.Id = s.DefaultCurrencyId
    ORDER BY s.Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Settings_Save
    @CompanyNameAr NVARCHAR(200),
    @CompanyNameEn NVARCHAR(200),
    @DefaultCurrencyId INT,
    @InvoicePrefix NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@CompanyNameAr)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@CompanyNameEn)), N'') IS NULL
        THROW 50001, 'Company names are required.', 1;
    IF NULLIF(LTRIM(RTRIM(@InvoicePrefix)), N'') IS NULL
        THROW 50002, 'Invoice prefix is required.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Id = @DefaultCurrencyId AND IsActive = 1)
        THROW 50003, 'Default currency is invalid.', 1;

    DECLARE @Id INT = (SELECT TOP (1) Id FROM dbo.Settings ORDER BY Id);
    IF @Id IS NULL
    BEGIN
        INSERT dbo.Settings (CompanyNameAr, CompanyNameEn, DefaultCurrencyId, InvoicePrefix)
        VALUES (@CompanyNameAr, @CompanyNameEn, @DefaultCurrencyId, @InvoicePrefix);
        SET @Id = SCOPE_IDENTITY();
    END
    ELSE
        UPDATE dbo.Settings
        SET CompanyNameAr = @CompanyNameAr, CompanyNameEn = @CompanyNameEn,
            DefaultCurrencyId = @DefaultCurrencyId, InvoicePrefix = @InvoicePrefix, UpdatedAt = SYSDATETIME()
        WHERE Id = @Id;

    SELECT s.Id, s.CompanyNameAr, s.CompanyNameEn, s.DefaultCurrencyId,
           c.Code AS DefaultCurrencyCode, s.InvoicePrefix
    FROM dbo.Settings s INNER JOIN dbo.Currencies c ON c.Id = s.DefaultCurrencyId
    WHERE s.Id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_List
    @Status NVARCHAR(50) = NULL,
    @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT i.Id, i.InvoiceNumber, i.InvoiceDate, i.CustomerId,
           c.NameAr AS CustomerNameAr, c.NameEn AS CustomerNameEn,
           cur.Code AS CurrencyCode, tm.Code AS TaxMode, st.Code AS Status, i.TotalAmount
    FROM dbo.SalesInvoices i
    INNER JOIN dbo.Customers c ON c.Id = i.CustomerId
    INNER JOIN dbo.Currencies cur ON cur.Id = i.CurrencyId
    INNER JOIN dbo.SystemCodeValues tm ON tm.Id = i.TaxModeId
    INNER JOIN dbo.SystemCodeValues st ON st.Id = i.InvoiceStatusId
    WHERE (@Status IS NULL OR st.Code = @Status)
      AND (@Search IS NULL OR i.InvoiceNumber LIKE N'%' + @Search + N'%'
           OR c.NameAr LIKE N'%' + @Search + N'%' OR c.NameEn LIKE N'%' + @Search + N'%')
    ORDER BY i.InvoiceDate DESC, i.Id DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_GetById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT i.Id, i.InvoiceNumber, i.InvoiceDate, i.CustomerId,
           c.NameAr AS CustomerNameAr, c.NameEn AS CustomerNameEn,
           i.CurrencyId, cur.Code AS CurrencyCode, i.ExchangeRate,
           tm.Code AS TaxMode, st.Code AS Status,
           i.SubTotal, i.TaxAmount, i.TotalAmount,
           ROUND(i.TotalAmount * i.ExchangeRate, 3) AS BaseCurrencyTotal,
           i.NotesAr, i.NotesEn, i.CreatedAt, i.ApprovedAt, i.CancelledAt,
           i.CancellationReasonAr, i.CancellationReasonEn
    FROM dbo.SalesInvoices i
    INNER JOIN dbo.Customers c ON c.Id = i.CustomerId
    INNER JOIN dbo.Currencies cur ON cur.Id = i.CurrencyId
    INNER JOIN dbo.SystemCodeValues tm ON tm.Id = i.TaxModeId
    INNER JOIN dbo.SystemCodeValues st ON st.Id = i.InvoiceStatusId
    WHERE i.Id = @Id;

    SELECT d.Id, d.ItemId, item.Code AS ItemCode, item.NameAr AS ItemNameAr,
           item.NameEn AS ItemNameEn, item.Barcode, d.UnitId, u.Code AS UnitCode,
           d.Quantity, d.UnitPrice, d.TaxRate, d.TaxAmount, d.LineSubTotal, d.LineTotal
    FROM dbo.SalesInvoiceItems d
    INNER JOIN dbo.Items item ON item.Id = d.ItemId
    INNER JOIN dbo.Units u ON u.Id = d.UnitId
    WHERE d.SalesInvoiceId = @Id ORDER BY d.Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_Save
    @Id INT = NULL,
    @InvoiceDate DATETIME2,
    @CustomerId INT,
    @CurrencyId INT,
    @ExchangeRate DECIMAL(18,6),
    @TaxModeCode NVARCHAR(50),
    @NotesAr NVARCHAR(500) = NULL,
    @NotesEn NVARCHAR(500) = NULL,
    @ItemsJson NVARCHAR(MAX),
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ExchangeRate <= 0 THROW 50004, 'Exchange rate must be greater than zero.', 1;
    IF ISJSON(@ItemsJson) <> 1 THROW 50005, 'Invoice items JSON is invalid.', 1;
    IF NOT EXISTS (SELECT 1 FROM OPENJSON(@ItemsJson)) THROW 50006, 'Invoice must contain at least one item.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1) THROW 50007, 'User is invalid.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE Id = @CustomerId AND IsActive = 1) THROW 50008, 'Customer is invalid.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Id = @CurrencyId AND IsActive = 1) THROW 50009, 'Currency is invalid.', 1;

    DECLARE @TaxModeId INT = (
        SELECT v.Id FROM dbo.SystemCodeValues v
        INNER JOIN dbo.SystemCodes c ON c.Id = v.SystemCodeId
        WHERE c.Code = N'TAX_MODE' AND v.Code = @TaxModeCode AND v.IsActive = 1);
    DECLARE @DraftStatusId INT = (
        SELECT v.Id FROM dbo.SystemCodeValues v
        INNER JOIN dbo.SystemCodes c ON c.Id = v.SystemCodeId
        WHERE c.Code = N'INVOICE_STATUS' AND v.Code = N'DRAFT');
    IF @TaxModeId IS NULL THROW 50010, 'Tax mode must be INCLUSIVE or EXCLUSIVE.', 1;

    DECLARE @Lines TABLE
    (
        ItemId INT NOT NULL, UnitId INT NOT NULL,
        Quantity DECIMAL(18,3) NOT NULL, UnitPrice DECIMAL(18,3) NOT NULL,
        TaxRate DECIMAL(5,2) NOT NULL, TaxAmount DECIMAL(18,3) NULL,
        LineSubTotal DECIMAL(18,3) NULL, LineTotal DECIMAL(18,3) NULL
    );

    INSERT @Lines (ItemId, UnitId, Quantity, UnitPrice, TaxRate)
    SELECT ItemId, UnitId, Quantity, UnitPrice, TaxRate
    FROM OPENJSON(@ItemsJson)
    WITH
    (
        ItemId INT '$.ItemId', UnitId INT '$.UnitId', Quantity DECIMAL(18,3) '$.Quantity',
        UnitPrice DECIMAL(18,3) '$.UnitPrice', TaxRate DECIMAL(5,2) '$.TaxRate'
    );

    IF EXISTS (SELECT 1 FROM @Lines WHERE Quantity <= 0 OR UnitPrice < 0 OR TaxRate < 0 OR TaxRate > 100)
        THROW 50011, 'One or more invoice items are invalid.', 1;
    IF EXISTS (SELECT 1 FROM @Lines l LEFT JOIN dbo.Items i ON i.Id = l.ItemId AND i.IsActive = 1 WHERE i.Id IS NULL)
        THROW 50012, 'One or more items do not exist.', 1;
    IF EXISTS (SELECT 1 FROM @Lines l LEFT JOIN dbo.Units u ON u.Id = l.UnitId AND u.IsActive = 1 WHERE u.Id IS NULL)
        THROW 50013, 'One or more units do not exist.', 1;

    UPDATE @Lines
    SET LineSubTotal = CASE WHEN @TaxModeCode = N'INCLUSIVE'
            THEN ROUND((Quantity * UnitPrice) / (1 + TaxRate / 100.0), 3)
            ELSE ROUND(Quantity * UnitPrice, 3) END,
        LineTotal = CASE WHEN @TaxModeCode = N'INCLUSIVE'
            THEN ROUND(Quantity * UnitPrice, 3)
            ELSE ROUND((Quantity * UnitPrice) * (1 + TaxRate / 100.0), 3) END;
    UPDATE @Lines SET TaxAmount = LineTotal - LineSubTotal;

    DECLARE @SubTotal DECIMAL(18,3), @TaxAmount DECIMAL(18,3), @TotalAmount DECIMAL(18,3);
    SELECT @SubTotal = SUM(LineSubTotal), @TaxAmount = SUM(TaxAmount), @TotalAmount = SUM(LineTotal) FROM @Lines;

    BEGIN TRANSACTION;
    DECLARE @InvoiceId INT = @Id;
    DECLARE @InvoiceNumber NVARCHAR(50);
    IF @InvoiceId IS NULL
    BEGIN
        INSERT dbo.SalesInvoices
        (InvoiceNumber, InvoiceDate, CustomerId, CurrencyId, ExchangeRate, TaxModeId, InvoiceStatusId,
         SubTotal, TaxAmount, TotalAmount, NotesAr, NotesEn, CreatedBy)
        VALUES
        (N'TEMP-' + CONVERT(NVARCHAR(36), NEWID()), @InvoiceDate, @CustomerId, @CurrencyId, @ExchangeRate,
         @TaxModeId, @DraftStatusId, @SubTotal, @TaxAmount, @TotalAmount, @NotesAr, @NotesEn, @UserId);

        SET @InvoiceId = SCOPE_IDENTITY();
        DECLARE @Prefix NVARCHAR(20) = COALESCE((SELECT TOP (1) InvoicePrefix FROM dbo.Settings ORDER BY Id), N'INV');
        SET @InvoiceNumber = CONCAT(@Prefix, N'-', YEAR(@InvoiceDate), N'-', RIGHT(N'000000' + CONVERT(NVARCHAR(20), @InvoiceId), 6));
        UPDATE dbo.SalesInvoices SET InvoiceNumber = @InvoiceNumber WHERE Id = @InvoiceId;
    END
    ELSE
    BEGIN
        DECLARE @CurrentStatus NVARCHAR(50);
        SELECT @CurrentStatus = st.Code, @InvoiceNumber = i.InvoiceNumber
        FROM dbo.SalesInvoices i WITH (UPDLOCK)
        INNER JOIN dbo.SystemCodeValues st ON st.Id = i.InvoiceStatusId
        WHERE i.Id = @InvoiceId;

        IF @CurrentStatus IS NULL THROW 50014, 'Invoice not found.', 1;
        IF @CurrentStatus <> N'DRAFT' THROW 50015, 'Only draft invoices can be edited.', 1;

        UPDATE dbo.SalesInvoices
        SET InvoiceDate = @InvoiceDate, CustomerId = @CustomerId, CurrencyId = @CurrencyId,
            ExchangeRate = @ExchangeRate, TaxModeId = @TaxModeId, SubTotal = @SubTotal,
            TaxAmount = @TaxAmount, TotalAmount = @TotalAmount, NotesAr = @NotesAr, NotesEn = @NotesEn
        WHERE Id = @InvoiceId;
        DELETE dbo.SalesInvoiceItems WHERE SalesInvoiceId = @InvoiceId;
    END;

    INSERT dbo.SalesInvoiceItems
        (SalesInvoiceId, ItemId, UnitId, Quantity, UnitPrice, TaxRate, TaxAmount, LineSubTotal, LineTotal)
    SELECT @InvoiceId, ItemId, UnitId, Quantity, UnitPrice, TaxRate, TaxAmount, LineSubTotal, LineTotal FROM @Lines;

    COMMIT TRANSACTION;
    SELECT @InvoiceId AS Id, @InvoiceNumber AS InvoiceNumber;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_Approve
    @Id INT,
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @DraftId INT, @ApprovedId INT, @CurrentStatusId INT;
    SELECT @DraftId = v.Id FROM dbo.SystemCodeValues v INNER JOIN dbo.SystemCodes c ON c.Id = v.SystemCodeId WHERE c.Code = N'INVOICE_STATUS' AND v.Code = N'DRAFT';
    SELECT @ApprovedId = v.Id FROM dbo.SystemCodeValues v INNER JOIN dbo.SystemCodes c ON c.Id = v.SystemCodeId WHERE c.Code = N'INVOICE_STATUS' AND v.Code = N'APPROVED';
    SELECT @CurrentStatusId = InvoiceStatusId FROM dbo.SalesInvoices WITH (UPDLOCK) WHERE Id = @Id;

    IF @CurrentStatusId IS NULL THROW 50014, 'Invoice not found.', 1;
    IF @CurrentStatusId <> @DraftId THROW 50016, 'Only draft invoices can be approved.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1) THROW 50007, 'User is invalid.', 1;

    UPDATE dbo.SalesInvoices
    SET InvoiceStatusId = @ApprovedId, ApprovedAt = SYSDATETIME(), ApprovedBy = @UserId
    WHERE Id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SalesInvoice_Cancel
    @Id INT,
    @UserId INT,
    @ReasonAr NVARCHAR(500),
    @ReasonEn NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@ReasonAr)), N'') IS NULL THROW 50017, 'Cancellation reason is required.', 1;

    DECLARE @CancelledId INT, @CurrentStatusId INT;
    SELECT @CancelledId = v.Id FROM dbo.SystemCodeValues v INNER JOIN dbo.SystemCodes c ON c.Id = v.SystemCodeId WHERE c.Code = N'INVOICE_STATUS' AND v.Code = N'CANCELLED';
    SELECT @CurrentStatusId = InvoiceStatusId FROM dbo.SalesInvoices WITH (UPDLOCK) WHERE Id = @Id;

    IF @CurrentStatusId IS NULL THROW 50014, 'Invoice not found.', 1;
    IF @CurrentStatusId = @CancelledId THROW 50018, 'Invoice is already cancelled.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1) THROW 50007, 'User is invalid.', 1;

    UPDATE dbo.SalesInvoices
    SET InvoiceStatusId = @CancelledId, CancelledAt = SYSDATETIME(), CancelledBy = @UserId,
        CancellationReasonAr = @ReasonAr, CancellationReasonEn = @ReasonEn
    WHERE Id = @Id;
END;
GO

PRINT N'Stored procedures are ready.';
GO
