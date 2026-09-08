using System.ComponentModel.DataAnnotations;

namespace triosuite_invoice_erp_api.Models;

public sealed record CustomerDto(int Id, string Code, string NameAr, string NameEn);
public sealed record CurrencyDto(int Id, string Code, string NameAr, string NameEn, string? Symbol, bool IsBaseCurrency);
public sealed record UnitDto(int Id, string Code, string NameAr, string NameEn);
public sealed record TaxModeDto(int Id, string Code, string NameAr, string NameEn);

public sealed record ItemDto(
    int Id,
    string Code,
    string NameAr,
    string NameEn,
    string? Barcode,
    int UnitId,
    string UnitCode,
    decimal UnitPrice,
    decimal TaxRate);

public sealed class LookupsDto
{
    public List<CustomerDto> Customers { get; init; } = [];
    public List<ItemDto> Items { get; init; } = [];
    public List<CurrencyDto> Currencies { get; init; } = [];
    public List<UnitDto> Units { get; init; } = [];
    public List<TaxModeDto> TaxModes { get; init; } = [];
}

public sealed class SettingsDto
{
    public int? Id { get; init; }
    public string CompanyNameAr { get; init; } = string.Empty;
    public string CompanyNameEn { get; init; } = string.Empty;
    public int DefaultCurrencyId { get; init; }
    public string? DefaultCurrencyCode { get; init; }
    public string InvoicePrefix { get; init; } = "INV";
}

public sealed class SaveSettingsRequest
{
    [Required, MaxLength(200)]
    public string CompanyNameAr { get; set; } = string.Empty;

    [Required, MaxLength(200)]
    public string CompanyNameEn { get; set; } = string.Empty;

    [Range(1, int.MaxValue)]
    public int DefaultCurrencyId { get; set; }

    [Required, MaxLength(20)]
    public string InvoicePrefix { get; set; } = "INV";
}
