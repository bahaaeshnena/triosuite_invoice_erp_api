/*
    Triosuite Invoice ERP API
    Script 3 of 3: Insert required reference data and demo records.

    Run the scripts in this order:
      1. 01_CreateDatabaseAndTables.sql
      2. 02_CreateStoredProcedures.sql
      3. 03_SeedData.sql

    This script is idempotent. Existing demo customers and items are not
    overwritten, and reference data is synchronized by its unique code.
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

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    ---------------------------------------------------------------------------
    -- System codes
    ---------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodes WHERE Code = N'INVOICE_STATUS')
        INSERT dbo.SystemCodes (Code, NameAr, NameEn)
        VALUES (N'INVOICE_STATUS', N'حالة الفاتورة', N'Invoice Status');
    ELSE
        UPDATE dbo.SystemCodes
        SET NameAr = N'حالة الفاتورة', NameEn = N'Invoice Status', IsActive = 1
        WHERE Code = N'INVOICE_STATUS';

    IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodes WHERE Code = N'TAX_MODE')
        INSERT dbo.SystemCodes (Code, NameAr, NameEn)
        VALUES (N'TAX_MODE', N'طريقة الضريبة', N'Tax Mode');
    ELSE
        UPDATE dbo.SystemCodes
        SET NameAr = N'طريقة الضريبة', NameEn = N'Tax Mode', IsActive = 1
        WHERE Code = N'TAX_MODE';

    DECLARE @InvoiceStatusId INT =
        (SELECT Id FROM dbo.SystemCodes WHERE Code = N'INVOICE_STATUS');
    DECLARE @TaxModeId INT =
        (SELECT Id FROM dbo.SystemCodes WHERE Code = N'TAX_MODE');

    IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @InvoiceStatusId AND Code = N'DRAFT')
        INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder)
        VALUES (@InvoiceStatusId, N'DRAFT', N'مسودة', N'Draft', 1);
    ELSE
        UPDATE dbo.SystemCodeValues SET NameAr = N'مسودة', NameEn = N'Draft', SortOrder = 1, IsActive = 1
        WHERE SystemCodeId = @InvoiceStatusId AND Code = N'DRAFT';

    IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @InvoiceStatusId AND Code = N'APPROVED')
        INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder)
        VALUES (@InvoiceStatusId, N'APPROVED', N'معتمدة', N'Approved', 2);
    ELSE
        UPDATE dbo.SystemCodeValues SET NameAr = N'معتمدة', NameEn = N'Approved', SortOrder = 2, IsActive = 1
        WHERE SystemCodeId = @InvoiceStatusId AND Code = N'APPROVED';

    IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @InvoiceStatusId AND Code = N'CANCELLED')
        INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder)
        VALUES (@InvoiceStatusId, N'CANCELLED', N'ملغاة', N'Cancelled', 3);
    ELSE
        UPDATE dbo.SystemCodeValues SET NameAr = N'ملغاة', NameEn = N'Cancelled', SortOrder = 3, IsActive = 1
        WHERE SystemCodeId = @InvoiceStatusId AND Code = N'CANCELLED';

    IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @TaxModeId AND Code = N'INCLUSIVE')
        INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder)
        VALUES (@TaxModeId, N'INCLUSIVE', N'شاملة الضريبة', N'Tax Inclusive', 1);
    ELSE
        UPDATE dbo.SystemCodeValues SET NameAr = N'شاملة الضريبة', NameEn = N'Tax Inclusive', SortOrder = 1, IsActive = 1
        WHERE SystemCodeId = @TaxModeId AND Code = N'INCLUSIVE';

    IF NOT EXISTS (SELECT 1 FROM dbo.SystemCodeValues WHERE SystemCodeId = @TaxModeId AND Code = N'EXCLUSIVE')
        INSERT dbo.SystemCodeValues (SystemCodeId, Code, NameAr, NameEn, SortOrder)
        VALUES (@TaxModeId, N'EXCLUSIVE', N'غير شاملة الضريبة', N'Tax Exclusive', 2);
    ELSE
        UPDATE dbo.SystemCodeValues SET NameAr = N'غير شاملة الضريبة', NameEn = N'Tax Exclusive', SortOrder = 2, IsActive = 1
        WHERE SystemCodeId = @TaxModeId AND Code = N'EXCLUSIVE';

    ---------------------------------------------------------------------------
    -- Currencies (JOD is the default/base currency)
    ---------------------------------------------------------------------------
    UPDATE dbo.Currencies SET IsBaseCurrency = 0
    WHERE Code <> N'JOD' AND IsBaseCurrency = 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Code = N'JOD')
        INSERT dbo.Currencies (Code, NameAr, NameEn, Symbol, IsBaseCurrency)
        VALUES (N'JOD', N'دينار أردني', N'Jordanian Dinar', N'JD', 1);
    ELSE
        UPDATE dbo.Currencies SET NameAr = N'دينار أردني', NameEn = N'Jordanian Dinar', Symbol = N'JD', IsBaseCurrency = 1, IsActive = 1
        WHERE Code = N'JOD';

    IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Code = N'USD')
        INSERT dbo.Currencies (Code, NameAr, NameEn, Symbol)
        VALUES (N'USD', N'دولار أمريكي', N'US Dollar', N'$');
    ELSE
        UPDATE dbo.Currencies SET NameAr = N'دولار أمريكي', NameEn = N'US Dollar', Symbol = N'$', IsActive = 1
        WHERE Code = N'USD';

    IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Code = N'EUR')
        INSERT dbo.Currencies (Code, NameAr, NameEn, Symbol)
        VALUES (N'EUR', N'يورو', N'Euro', N'€');
    ELSE
        UPDATE dbo.Currencies SET NameAr = N'يورو', NameEn = N'Euro', Symbol = N'€', IsActive = 1
        WHERE Code = N'EUR';

    IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Code = N'GBP')
        INSERT dbo.Currencies (Code, NameAr, NameEn, Symbol)
        VALUES (N'GBP', N'جنيه إسترليني', N'Pound Sterling', N'£');
    ELSE
        UPDATE dbo.Currencies SET NameAr = N'جنيه إسترليني', NameEn = N'Pound Sterling', Symbol = N'£', IsActive = 1
        WHERE Code = N'GBP';

    IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Code = N'SAR')
        INSERT dbo.Currencies (Code, NameAr, NameEn, Symbol)
        VALUES (N'SAR', N'ريال سعودي', N'Saudi Riyal', N'SR');
    ELSE
        UPDATE dbo.Currencies SET NameAr = N'ريال سعودي', NameEn = N'Saudi Riyal', Symbol = N'SR', IsActive = 1
        WHERE Code = N'SAR';

    IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE Code = N'AED')
        INSERT dbo.Currencies (Code, NameAr, NameEn, Symbol)
        VALUES (N'AED', N'درهم إماراتي', N'UAE Dirham', N'AED');
    ELSE
        UPDATE dbo.Currencies SET NameAr = N'درهم إماراتي', NameEn = N'UAE Dirham', Symbol = N'AED', IsActive = 1
        WHERE Code = N'AED';

    ---------------------------------------------------------------------------
    -- Units of measure
    ---------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.Units WHERE Code = N'PCS')
        INSERT dbo.Units (Code, NameAr, NameEn) VALUES (N'PCS', N'قطعة', N'Piece');
    ELSE
        UPDATE dbo.Units SET NameAr = N'قطعة', NameEn = N'Piece', IsActive = 1 WHERE Code = N'PCS';

    IF NOT EXISTS (SELECT 1 FROM dbo.Units WHERE Code = N'BOX')
        INSERT dbo.Units (Code, NameAr, NameEn) VALUES (N'BOX', N'صندوق', N'Box');
    ELSE
        UPDATE dbo.Units SET NameAr = N'صندوق', NameEn = N'Box', IsActive = 1 WHERE Code = N'BOX';

    IF NOT EXISTS (SELECT 1 FROM dbo.Units WHERE Code = N'KG')
        INSERT dbo.Units (Code, NameAr, NameEn) VALUES (N'KG', N'كيلوغرام', N'Kilogram');
    ELSE
        UPDATE dbo.Units SET NameAr = N'كيلوغرام', NameEn = N'Kilogram', IsActive = 1 WHERE Code = N'KG';

    IF NOT EXISTS (SELECT 1 FROM dbo.Units WHERE Code = N'LTR')
        INSERT dbo.Units (Code, NameAr, NameEn) VALUES (N'LTR', N'لتر', N'Liter');
    ELSE
        UPDATE dbo.Units SET NameAr = N'لتر', NameEn = N'Liter', IsActive = 1 WHERE Code = N'LTR';

    IF NOT EXISTS (SELECT 1 FROM dbo.Units WHERE Code = N'HOUR')
        INSERT dbo.Units (Code, NameAr, NameEn) VALUES (N'HOUR', N'ساعة', N'Hour');
    ELSE
        UPDATE dbo.Units SET NameAr = N'ساعة', NameEn = N'Hour', IsActive = 1 WHERE Code = N'HOUR';

    ---------------------------------------------------------------------------
    -- Demo administrator (username: admin, password: Admin@123)
    ---------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Username = N'admin')
        INSERT dbo.Users (Username, PasswordHash, FullNameAr, FullNameEn)
        VALUES
        (
            N'admin',
            N'PBKDF2$100000$j8taFikDRauGQ7QSH2EnvA==$/JWFXidhlNUmrOLHdYEiuYKTWkWU/fMT2EW+MSOwEZg=',
            N'مدير النظام',
            N'System Administrator'
        );

    ---------------------------------------------------------------------------
    -- Demo customers
    ---------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE Code = N'CUST-001')
        INSERT dbo.Customers (Code, NameAr, NameEn, Phone, Email, AddressAr, AddressEn)
        VALUES (N'CUST-001', N'شركة النور', N'Al Noor Company', N'0790000001', N'accounts@alnoor.example', N'عمان، الأردن', N'Amman, Jordan');

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE Code = N'CUST-002')
        INSERT dbo.Customers (Code, NameAr, NameEn, Phone, Email, AddressAr, AddressEn)
        VALUES (N'CUST-002', N'مؤسسة الأمل', N'Al Amal Establishment', N'0790000002', N'info@alamal.example', N'إربد، الأردن', N'Irbid, Jordan');

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE Code = N'CUST-003')
        INSERT dbo.Customers (Code, NameAr, NameEn, Phone, Email, AddressAr, AddressEn)
        VALUES (N'CUST-003', N'شركة المستقبل للتقنية', N'Future Technology Company', N'0790000003', N'sales@future-tech.example', N'الزرقاء، الأردن', N'Zarqa, Jordan');

    ---------------------------------------------------------------------------
    -- Demo items
    ---------------------------------------------------------------------------
    DECLARE @PieceUnitId INT = (SELECT Id FROM dbo.Units WHERE Code = N'PCS');
    DECLARE @BoxUnitId INT = (SELECT Id FROM dbo.Units WHERE Code = N'BOX');
    DECLARE @HourUnitId INT = (SELECT Id FROM dbo.Units WHERE Code = N'HOUR');

    IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE Code = N'ITEM-001')
        INSERT dbo.Items (Code, NameAr, NameEn, Barcode, UnitId, UnitPrice, TaxRate)
        VALUES (N'ITEM-001', N'لوحة مفاتيح', N'Keyboard', N'625100000001', @PieceUnitId, 18.000, 16.00);

    IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE Code = N'ITEM-002')
        INSERT dbo.Items (Code, NameAr, NameEn, Barcode, UnitId, UnitPrice, TaxRate)
        VALUES (N'ITEM-002', N'فأرة لاسلكية', N'Wireless Mouse', N'625100000002', @PieceUnitId, 12.500, 16.00);

    IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE Code = N'ITEM-003')
        INSERT dbo.Items (Code, NameAr, NameEn, Barcode, UnitId, UnitPrice, TaxRate)
        VALUES (N'ITEM-003', N'شاشة', N'Monitor', N'625100000003', @PieceUnitId, 125.000, 16.00);

    IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE Code = N'ITEM-004')
        INSERT dbo.Items (Code, NameAr, NameEn, Barcode, UnitId, UnitPrice, TaxRate)
        VALUES (N'ITEM-004', N'كابل شبكة - صندوق', N'Network Cable - Box', N'625100000004', @BoxUnitId, 45.000, 16.00);

    IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE Code = N'SVC-001')
        INSERT dbo.Items (Code, NameAr, NameEn, Barcode, UnitId, UnitPrice, TaxRate)
        VALUES (N'SVC-001', N'دعم فني', N'Technical Support', NULL, @HourUnitId, 25.000, 16.00);

    ---------------------------------------------------------------------------
    -- Initial company settings
    ---------------------------------------------------------------------------
    DECLARE @JodCurrencyId INT = (SELECT Id FROM dbo.Currencies WHERE Code = N'JOD');

    IF NOT EXISTS (SELECT 1 FROM dbo.Settings)
        INSERT dbo.Settings (CompanyNameAr, CompanyNameEn, DefaultCurrencyId, InvoicePrefix)
        VALUES (N'شركة ترايوسويت التجريبية', N'Triosuite Demo Company', @JodCurrencyId, N'INV');

    COMMIT TRANSACTION;
    PRINT N'Reference and demo data are ready.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
