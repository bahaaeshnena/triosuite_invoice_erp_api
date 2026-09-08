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

IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodes WHERE Code = N'INVOICE_STATUS')
    INSERT dbo.SystemCodes (Code, NameAr, NameEn) VALUES (N'INVOICE_STATUS', N'حالة الفاتورة', N'Invoice Status');
IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodes WHERE Code = N'TAX_MODE')
    INSERT dbo.SystemCodes (Code, NameAr, NameEn) VALUES (N'TAX_MODE', N'طريقة الضريبة', N'Tax Mode');

DECLARE @InvoiceStatusId INT = (SELECT Id FROM dbo.SystemCodes WHERE Code = N'INVOICE_STATUS');
DECLARE @TaxModeId INT = (SELECT Id FROM dbo.SystemCodes WHERE Code = N'TAX_MODE');
IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @InvoiceStatusId AND Code = N'DRAFT')
    INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder) VALUES (@InvoiceStatusId, N'DRAFT', N'مسودة', N'Draft', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @InvoiceStatusId AND Code = N'APPROVED')
    INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder) VALUES (@InvoiceStatusId, N'APPROVED', N'معتمدة', N'Approved', 2);
IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @InvoiceStatusId AND Code = N'CANCELLED')
    INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder) VALUES (@InvoiceStatusId, N'CANCELLED', N'ملغاة', N'Cancelled', 3);
IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @TaxModeId AND Code = N'INCLUSIVE')
    INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder) VALUES (@TaxModeId, N'INCLUSIVE', N'شاملة الضريبة', N'Tax Inclusive', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @TaxModeId AND Code = N'EXCLUSIVE')
    INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder) VALUES (@TaxModeId, N'EXCLUSIVE', N'غير شاملة الضريبة', N'Tax Exclusive', 2);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Code = N'JOD')
    INSERT dbo.Currencies (Code, NameAr, NameEn, Symbol, IsBaseCurrency) VALUES (N'JOD', N'دينار أردني', N'Jordanian Dinar', N'JD', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Code = N'USD')
    INSERT dbo.Currencies (Code, NameAr, NameEn, Symbol) VALUES (N'USD', N'دولار أمريكي', N'US Dollar', N'$');
IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Code = N'EUR')
    INSERT dbo.Currencies (Code, NameAr, NameEn, Symbol) VALUES (N'EUR', N'يورو', N'Euro', N'€');
IF NOT EXISTS (SELECT 1 FROM dbo.Units WHERE Code = N'PCS')
    INSERT dbo.Units (Code, NameAr, NameEn) VALUES (N'PCS', N'قطعة', N'Piece');
IF NOT EXISTS (SELECT 1 FROM dbo.Units WHERE Code = N'BOX')
    INSERT dbo.Units (Code, NameAr, NameEn) VALUES (N'BOX', N'صندوق', N'Box');
IF NOT EXISTS (SELECT 1 FROM dbo.Units WHERE Code = N'KG')
    INSERT dbo.Units (Code, NameAr, NameEn) VALUES (N'KG', N'كيلوغرام', N'Kilogram');
IF NOT EXISTS (SELECT 1 FROM dbo.Units WHERE Code = N'LTR')
    INSERT dbo.Units (Code, NameAr, NameEn) VALUES (N'LTR', N'لتر', N'Liter');
GO

-- Demo login: admin / Admin@123
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Username = N'admin')
    INSERT dbo.Users (Username, PasswordHash, FullNameAr, FullNameEn)
    VALUES (N'admin', N'PBKDF2$100000$j8taFikDRauGQ7QSH2EnvA==$/JWFXidhlNUmrOLHdYEiuYKTWkWU/fMT2EW+MSOwEZg=', N'مدير النظام', N'System Administrator');

IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE Code = N'CUST-001')
    INSERT dbo.Customers (Code, NameAr, NameEn, Phone) VALUES (N'CUST-001', N'شركة النور', N'Al Noor Company', N'0790000001');
IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE Code = N'CUST-002')
    INSERT dbo.Customers (Code, NameAr, NameEn, Phone) VALUES (N'CUST-002', N'مؤسسة الأمل', N'Al Amal Establishment', N'0790000002');

DECLARE @PieceUnitId INT = (SELECT Id FROM dbo.Units WHERE Code = N'PCS');
IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE Code = N'ITEM-001')
    INSERT dbo.Items (Code, NameAr, NameEn, Barcode, UnitId, UnitPrice, TaxRate) VALUES (N'ITEM-001', N'لوحة مفاتيح', N'Keyboard', N'625100000001', @PieceUnitId, 18.000, 16.00);
IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE Code = N'ITEM-002')
    INSERT dbo.Items (Code, NameAr, NameEn, Barcode, UnitId, UnitPrice, TaxRate) VALUES (N'ITEM-002', N'فأرة لاسلكية', N'Wireless Mouse', N'625100000002', @PieceUnitId, 12.500, 16.00);
IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE Code = N'ITEM-003')
    INSERT dbo.Items (Code, NameAr, NameEn, Barcode, UnitId, UnitPrice, TaxRate) VALUES (N'ITEM-003', N'شاشة', N'Monitor', N'625100000003', @PieceUnitId, 125.000, 16.00);

IF NOT EXISTS (SELECT 1 FROM dbo.Settings)
    INSERT dbo.Settings (CompanyNameAr, CompanyNameEn, DefaultCurrencyId, InvoicePrefix)
    SELECT N'شركة ترايوسويت التجريبية', N'Triosuite Demo Company', Id, N'INV'
    FROM dbo.Currencies WHERE Code = N'JOD';

-- Keep the demo Arabic text correct when this seed script is re-run.
UPDATE dbo.Users SET FullNameAr = N'مدير النظام' WHERE Username = N'admin';
UPDATE dbo.Customers SET NameAr = N'شركة النور' WHERE Code = N'CUST-001';
UPDATE dbo.Customers SET NameAr = N'مؤسسة الأمل' WHERE Code = N'CUST-002';
UPDATE dbo.Items SET NameAr = N'لوحة مفاتيح' WHERE Code = N'ITEM-001';
UPDATE dbo.Items SET NameAr = N'فأرة لاسلكية' WHERE Code = N'ITEM-002';
UPDATE dbo.Items SET NameAr = N'شاشة' WHERE Code = N'ITEM-003';
UPDATE dbo.Settings SET CompanyNameAr = N'شركة ترايوسويت التجريبية' WHERE CompanyNameEn = N'Triosuite Demo Company';
GO
