/*
    Triosuite Invoice ERP API
    Script 1 of 3: Create the database, tables, constraints, and indexes.

    This script is idempotent. It can be executed again without deleting
    existing business data.
*/

USE master;
GO

IF DB_ID(N'SalesInvoiceDB') IS NULL
    CREATE DATABASE SalesInvoiceDB;
GO

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

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
        Username NVARCHAR(100) NOT NULL CONSTRAINT UQ_Users_Username UNIQUE,
        PasswordHash NVARCHAR(500) NOT NULL,
        FullNameAr NVARCHAR(200) NOT NULL,
        FullNameEn NVARCHAR(200) NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSDATETIME())
    );
END;
GO

IF OBJECT_ID(N'dbo.RefreshTokens', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RefreshTokens
    (
        Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RefreshTokens PRIMARY KEY,
        UserId INT NOT NULL,
        TokenHash CHAR(64) NOT NULL CONSTRAINT UQ_RefreshTokens_TokenHash UNIQUE,
        FamilyId UNIQUEIDENTIFIER NOT NULL,
        ExpiresAt DATETIME2 NOT NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_RefreshTokens_CreatedAt DEFAULT (SYSUTCDATETIME()),
        RevokedAt DATETIME2 NULL,
        ReplacedByTokenHash CHAR(64) NULL,
        CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.RefreshTokens')
      AND name = N'IX_RefreshTokens_FamilyId')
    CREATE INDEX IX_RefreshTokens_FamilyId ON dbo.RefreshTokens(FamilyId);
GO

IF OBJECT_ID(N'dbo.Currencies', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Currencies
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Currencies PRIMARY KEY,
        Code NVARCHAR(10) NOT NULL CONSTRAINT UQ_Currencies_Code UNIQUE,
        NameAr NVARCHAR(100) NOT NULL,
        NameEn NVARCHAR(100) NOT NULL,
        Symbol NVARCHAR(10) NULL,
        IsBaseCurrency BIT NOT NULL CONSTRAINT DF_Currencies_IsBaseCurrency DEFAULT (0),
        IsActive BIT NOT NULL CONSTRAINT DF_Currencies_IsActive DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Units', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Units
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Units PRIMARY KEY,
        Code NVARCHAR(20) NOT NULL CONSTRAINT UQ_Units_Code UNIQUE,
        NameAr NVARCHAR(100) NOT NULL,
        NameEn NVARCHAR(100) NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_Units_IsActive DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.SystemCodes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SystemCodes
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SystemCodes PRIMARY KEY,
        Code NVARCHAR(50) NOT NULL CONSTRAINT UQ_SystemCodes_Code UNIQUE,
        NameAr NVARCHAR(100) NOT NULL,
        NameEn NVARCHAR(100) NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_SystemCodes_IsActive DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.SystemCodeValues', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SystemCodeValues
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SystemCodeValues PRIMARY KEY,
        SystemCodeId INT NOT NULL,
        Code NVARCHAR(50) NOT NULL,
        NameAr NVARCHAR(100) NOT NULL,
        NameEn NVARCHAR(100) NOT NULL,
        SortOrder INT NOT NULL CONSTRAINT DF_SystemCodeValues_SortOrder DEFAULT (0),
        IsActive BIT NOT NULL CONSTRAINT DF_SystemCodeValues_IsActive DEFAULT (1),
        CONSTRAINT UQ_SystemCodeValues_SystemCode_Code UNIQUE (SystemCodeId, Code),
        CONSTRAINT FK_SystemCodeValues_SystemCodes FOREIGN KEY (SystemCodeId) REFERENCES dbo.SystemCodes(Id)
    );
END;
GO

IF OBJECT_ID(N'dbo.Customers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Customers
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
        Code NVARCHAR(50) NOT NULL CONSTRAINT UQ_Customers_Code UNIQUE,
        NameAr NVARCHAR(200) NOT NULL,
        NameEn NVARCHAR(200) NOT NULL,
        Phone NVARCHAR(50) NULL,
        Email NVARCHAR(150) NULL,
        AddressAr NVARCHAR(500) NULL,
        AddressEn NVARCHAR(500) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_Customers_IsActive DEFAULT (1),
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Customers_CreatedAt DEFAULT (SYSDATETIME())
    );
END;
GO

IF OBJECT_ID(N'dbo.Items', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Items
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Items PRIMARY KEY,
        Code NVARCHAR(50) NOT NULL CONSTRAINT UQ_Items_Code UNIQUE,
        NameAr NVARCHAR(200) NOT NULL,
        NameEn NVARCHAR(200) NOT NULL,
        Barcode NVARCHAR(100) NULL,
        UnitId INT NOT NULL,
        UnitPrice DECIMAL(18,3) NOT NULL CONSTRAINT DF_Items_UnitPrice DEFAULT (0),
        TaxRate DECIMAL(5,2) NOT NULL CONSTRAINT DF_Items_TaxRate DEFAULT (0),
        IsActive BIT NOT NULL CONSTRAINT DF_Items_IsActive DEFAULT (1),
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Items_CreatedAt DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_Items_Units FOREIGN KEY (UnitId) REFERENCES dbo.Units(Id)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Items') AND name = N'UX_Items_Barcode')
    CREATE UNIQUE INDEX UX_Items_Barcode ON dbo.Items(Barcode) WHERE Barcode IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Currencies') AND name = N'UX_Currencies_BaseCurrency')
    CREATE UNIQUE INDEX UX_Currencies_BaseCurrency ON dbo.Currencies(IsBaseCurrency) WHERE IsBaseCurrency = 1;
GO

IF OBJECT_ID(N'dbo.Settings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Settings
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Settings PRIMARY KEY,
        CompanyNameAr NVARCHAR(200) NOT NULL,
        CompanyNameEn NVARCHAR(200) NOT NULL,
        DefaultCurrencyId INT NOT NULL,
        InvoicePrefix NVARCHAR(20) NOT NULL CONSTRAINT DF_Settings_InvoicePrefix DEFAULT (N'INV'),
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Settings_CreatedAt DEFAULT (SYSDATETIME()),
        UpdatedAt DATETIME2 NULL,
        CONSTRAINT FK_Settings_DefaultCurrency FOREIGN KEY (DefaultCurrencyId) REFERENCES dbo.Currencies(Id)
    );
END;
GO

IF OBJECT_ID(N'dbo.SalesInvoices', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SalesInvoices
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesInvoices PRIMARY KEY,
        InvoiceNumber NVARCHAR(50) NOT NULL CONSTRAINT UQ_SalesInvoices_InvoiceNumber UNIQUE,
        InvoiceDate DATETIME2 NOT NULL CONSTRAINT DF_SalesInvoices_InvoiceDate DEFAULT (SYSDATETIME()),
        CustomerId INT NOT NULL,
        CurrencyId INT NOT NULL,
        ExchangeRate DECIMAL(18,6) NOT NULL CONSTRAINT DF_SalesInvoices_ExchangeRate DEFAULT (1),
        TaxModeId INT NOT NULL,
        InvoiceStatusId INT NOT NULL,
        SubTotal DECIMAL(18,3) NOT NULL CONSTRAINT DF_SalesInvoices_SubTotal DEFAULT (0),
        TaxAmount DECIMAL(18,3) NOT NULL CONSTRAINT DF_SalesInvoices_TaxAmount DEFAULT (0),
        TotalAmount DECIMAL(18,3) NOT NULL CONSTRAINT DF_SalesInvoices_TotalAmount DEFAULT (0),
        NotesAr NVARCHAR(500) NULL,
        NotesEn NVARCHAR(500) NULL,
        CreatedBy INT NOT NULL,
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_SalesInvoices_CreatedAt DEFAULT (SYSDATETIME()),
        ApprovedAt DATETIME2 NULL,
        ApprovedBy INT NULL,
        CancelledAt DATETIME2 NULL,
        CancelledBy INT NULL,
        CancellationReasonAr NVARCHAR(500) NULL,
        CancellationReasonEn NVARCHAR(500) NULL,
        CONSTRAINT FK_SalesInvoices_Customers FOREIGN KEY (CustomerId) REFERENCES dbo.Customers(Id),
        CONSTRAINT FK_SalesInvoices_Currencies FOREIGN KEY (CurrencyId) REFERENCES dbo.Currencies(Id),
        CONSTRAINT FK_SalesInvoices_TaxMode FOREIGN KEY (TaxModeId) REFERENCES dbo.SystemCodeValues(Id),
        CONSTRAINT FK_SalesInvoices_Status FOREIGN KEY (InvoiceStatusId) REFERENCES dbo.SystemCodeValues(Id),
        CONSTRAINT FK_SalesInvoices_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(Id),
        CONSTRAINT FK_SalesInvoices_ApprovedBy FOREIGN KEY (ApprovedBy) REFERENCES dbo.Users(Id),
        CONSTRAINT FK_SalesInvoices_CancelledBy FOREIGN KEY (CancelledBy) REFERENCES dbo.Users(Id)
    );
END;
GO

IF OBJECT_ID(N'dbo.SalesInvoiceItems', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SalesInvoiceItems
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesInvoiceItems PRIMARY KEY,
        SalesInvoiceId INT NOT NULL,
        ItemId INT NOT NULL,
        UnitId INT NOT NULL,
        Quantity DECIMAL(18,3) NOT NULL,
        UnitPrice DECIMAL(18,3) NOT NULL,
        TaxRate DECIMAL(5,2) NOT NULL CONSTRAINT DF_SalesInvoiceItems_TaxRate DEFAULT (0),
        TaxAmount DECIMAL(18,3) NOT NULL CONSTRAINT DF_SalesInvoiceItems_TaxAmount DEFAULT (0),
        LineSubTotal DECIMAL(18,3) NOT NULL CONSTRAINT DF_SalesInvoiceItems_LineSubTotal DEFAULT (0),
        LineTotal DECIMAL(18,3) NOT NULL CONSTRAINT DF_SalesInvoiceItems_LineTotal DEFAULT (0),
        CONSTRAINT FK_SalesInvoiceItems_SalesInvoices FOREIGN KEY (SalesInvoiceId) REFERENCES dbo.SalesInvoices(Id),
        CONSTRAINT FK_SalesInvoiceItems_Items FOREIGN KEY (ItemId) REFERENCES dbo.Items(Id),
        CONSTRAINT FK_SalesInvoiceItems_Units FOREIGN KEY (UnitId) REFERENCES dbo.Units(Id)
    );
END;
GO

PRINT N'Database tables and indexes are ready.';
GO
